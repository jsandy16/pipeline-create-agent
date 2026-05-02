"""Smart auto-fix agent for terraform plan/apply failures.

Analyses terraform errors and proposes targeted fixes to:
  - Terraform HCL (main.tf)
  - Pipeline YAML (pipeline.yaml)
  - Service specs (specs/*.yaml)

NEVER modifies Python source code. All fixes are data-layer only.

The agent returns a structured proposal that the user must confirm
before any changes are applied. If the fix requires regenerating
the pipeline from YAML, it signals that so the UI can ask for confirmation.

Error categories handled:
  - MISSING_PERMISSION: IAM policy missing an action → patch spec or HCL
  - CONFIG_MISMATCH: wrong attribute value → patch HCL or YAML config
  - SUBSCRIPTION_REQUIRED: service needs opt-in → inform user (no code fix)
  - PLACEHOLDER_VALUE: placeholder URL/ARN used → needs user input
  - NAME_LENGTH: resource name too long → auto-fix in HCL
  - INVALID_CHARS: forbidden characters → auto-fix in HCL
  - RESOURCE_NOT_FOUND: referenced resource missing → patch HCL or YAML
"""
from __future__ import annotations

import json
import os
import re
import logging
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any

log = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

@dataclass
class AutofixProposal:
    """A proposed fix for one or more terraform errors."""
    fixable: bool                          # True if the agent can propose a fix
    category: str                          # error category (MISSING_PERMISSION, etc.)
    summary: str                           # human-readable summary of what went wrong
    fix_description: str                   # what the fix will do
    changes: list[dict[str, Any]]          # list of file changes
    requires_regeneration: bool = False    # True if pipeline must be rebuilt from YAML
    user_action_required: str = ""         # instructions for manual steps (e.g. "enable EMR Serverless")
    errors_raw: str = ""                   # original error text

    def to_dict(self) -> dict:
        return asdict(self)


# ---------------------------------------------------------------------------
# Error classifiers — regex-based, fast, no LLM
# ---------------------------------------------------------------------------

_PERMISSION_RE = re.compile(
    r"(?:AccessDenied|UnauthorizedAccess|AccessDeniedException|is not authorized to perform|"
    r"does not have .+ permission|User: .+ is not authorized|"
    r"not authorized to perform: ([a-z0-9]+:[A-Za-z]+))",
    re.I,
)

_SUBSCRIPTION_RE = re.compile(
    r"SubscriptionRequiredException|needs a subscription for the service",
    re.I,
)

_PLACEHOLDER_RE = re.compile(
    r"placeholder[-_]",
    re.I,
)

_NAME_LENGTH_RE = re.compile(
    r"cannot be longer than \d+ characters|"
    r"expected length of .+ to be in the range",
    re.I,
)

_INVALID_CHARS_RE = re.compile(
    r"must contain only|invalid character|must be lowercase|"
    r"must not (?:start|end) with",
    re.I,
)

_RESOURCE_NOT_FOUND_RE = re.compile(
    r"(?:Could not find|does not exist|No such|not found|EntityNotFoundException|"
    r"ResourceNotFoundException|NoSuchEntity|NoSuchBucket|404)",
    re.I,
)

_CONFIG_MISMATCH_RE = re.compile(
    r"(?:ValidationException|InvalidParameterValue|expected .+ to be one of|"
    r"incompatible with|mutually exclusive|must be between|invalid value for|"
    r"expected .+ to be one of \[)",
    re.I,
)


def classify_error(error_text: str) -> str:
    """Classify a single terraform error block into a category."""
    if _SUBSCRIPTION_RE.search(error_text):
        return "SUBSCRIPTION_REQUIRED"
    if _PLACEHOLDER_RE.search(error_text):
        return "PLACEHOLDER_VALUE"
    if _PERMISSION_RE.search(error_text):
        return "MISSING_PERMISSION"
    if _NAME_LENGTH_RE.search(error_text):
        return "NAME_LENGTH"
    if _INVALID_CHARS_RE.search(error_text):
        return "INVALID_CHARS"
    if _RESOURCE_NOT_FOUND_RE.search(error_text):
        return "RESOURCE_NOT_FOUND"
    if _CONFIG_MISMATCH_RE.search(error_text):
        return "CONFIG_MISMATCH"
    return "UNKNOWN"


def classify_all_errors(plan_stderr: str) -> list[tuple[str, str]]:
    """Parse and classify all error blocks. Returns [(category, error_text), ...]."""
    blocks = re.findall(r"Error:.*?(?=\nError:|\Z)", plan_stderr, re.S)
    if not blocks:
        return []
    return [(classify_error(b), b.strip()) for b in blocks]


# ---------------------------------------------------------------------------
# LLM-based fix proposal
# ---------------------------------------------------------------------------

_AUTOFIX_SYSTEM_PROMPT = """\
You are an expert AWS infrastructure engineer and Terraform specialist.

A terraform plan or apply has failed. You must analyse the errors and propose \
a MINIMAL, TARGETED fix. You will be given the error text, the current main.tf, \
and optionally the pipeline YAML that generated it.

## RULES — read carefully

1. You MUST return a valid JSON object with this exact schema:
   {
     "fixable": true/false,
     "summary": "one-line description of the root cause",
     "fix_description": "what the fix does, in 1-3 sentences",
     "changes": [
       {
         "file": "main.tf" | "pipeline.yaml" | "specs/<type>.yaml",
         "action": "replace",
         "search": "exact string to find",
         "replace": "exact replacement string"
       }
     ],
     "requires_regeneration": true/false,
     "user_action_required": "manual steps the user must take (empty string if none)"
   }

2. NEVER propose changes to Python files (.py). You can ONLY modify:
   - main.tf (Terraform HCL)
   - pipeline.yaml (pipeline definition)
   - specs/*.yaml (service type specs)

3. For MISSING PERMISSION errors:
   - Find the IAM policy resource in main.tf that covers the failing service
   - Add the missing IAM action to that policy's Action list
   - Set requires_regeneration=false (HCL-only fix)

4. For CONFIG MISMATCH errors (e.g. "expected repository_name to be one of [...]"):
   - Find the exact attribute with the wrong value in main.tf
   - Replace with the correct value from the error message
   - Set requires_regeneration=false

5. For PLACEHOLDER VALUE errors:
   - Set fixable=false
   - Explain in user_action_required what the user needs to provide

6. For SUBSCRIPTION REQUIRED errors:
   - Set fixable=false
   - Explain in user_action_required which service needs activation and where

7. For NAME LENGTH / INVALID CHARS:
   - Fix directly in main.tf by shortening or sanitizing the value
   - Set requires_regeneration=false

8. If a fix requires changing pipeline.yaml or specs/*.yaml (which means the \
   pipeline must be regenerated from scratch), set requires_regeneration=true.

9. Keep changes minimal. Do NOT rewrite entire files. Each change entry should \
   target a small, specific string replacement.

10. The "search" field must be an EXACT substring match from the current file. \
    Copy it character-for-character. If you can't find the exact string, set \
    fixable=false.

11. Return ONLY the JSON object. No markdown fences. No commentary.
"""


def propose_fix(
    error_text: str,
    work_dir: Path,
    categories: list[tuple[str, str]],
    api_key: str | None = None,
    model: str = "claude-haiku-4-5-20251001",
) -> AutofixProposal:
    """Use LLM to analyse errors and propose a fix.

    Returns an AutofixProposal that the user must confirm.
    """

    # Fast-path: subscription errors don't need LLM
    sub_errors = [c for c in categories if c[0] == "SUBSCRIPTION_REQUIRED"]
    if sub_errors:
        services = set()
        for _, err in sub_errors:
            if "EMR" in err or "emr" in err:
                services.add("EMR Serverless")
            else:
                services.add("the failing service")
        svc_list = ", ".join(services)
        return AutofixProposal(
            fixable=False,
            category="SUBSCRIPTION_REQUIRED",
            summary=f"{svc_list} requires account activation before deployment.",
            fix_description="No code fix — manual AWS Console action required.",
            changes=[],
            user_action_required=(
                f"Enable {svc_list} in your AWS account:\n"
                f"  1. Go to AWS Console → {svc_list} → Get started\n"
                f"  2. Complete the one-time activation (per account, per region)\n"
                f"  3. Then re-run the plan"
            ),
            errors_raw=error_text,
        )

    # Fast-path: pure placeholder errors
    placeholder_errors = [c for c in categories if c[0] == "PLACEHOLDER_VALUE"]
    if placeholder_errors and all(c[0] == "PLACEHOLDER_VALUE" for c in categories):
        return AutofixProposal(
            fixable=False,
            category="PLACEHOLDER_VALUE",
            summary="Pipeline uses placeholder resource references that don't exist in AWS.",
            fix_description="No auto-fix — real S3 bucket/resource paths must be provided.",
            changes=[],
            user_action_required=(
                "Update your pipeline YAML to provide real resource paths:\n"
                "  - For SageMaker: set model_data_url to your actual S3 model path\n"
                "  - For other services: add integrations to wire real resources\n"
                "  Then regenerate the pipeline."
            ),
            errors_raw=error_text,
        )

    # LLM-assisted fix for other error types
    import anthropic
    from dotenv import load_dotenv
    load_dotenv()

    key = api_key or os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        return AutofixProposal(
            fixable=False,
            category=categories[0][0] if categories else "UNKNOWN",
            summary="Cannot analyse errors — no API key configured.",
            fix_description="",
            changes=[],
            user_action_required="Configure ANTHROPIC_API_KEY to enable auto-fix analysis.",
            errors_raw=error_text,
        )

    client = anthropic.Anthropic(api_key=key)

    # Build context
    hcl_path = work_dir / "main.tf"
    yaml_path = work_dir / "pipeline.yaml"

    hcl_content = hcl_path.read_text() if hcl_path.exists() else ""
    yaml_content = yaml_path.read_text() if yaml_path.exists() else ""

    user_msg_parts = [
        f"=== TERRAFORM ERRORS ===\n{error_text}\n",
        f"=== ERROR CATEGORIES ===\n{json.dumps([(c, e[:200]) for c, e in categories])}\n",
        f"=== main.tf ({len(hcl_content)} chars) ===\n{hcl_content}\n",
    ]
    if yaml_content:
        user_msg_parts.append(f"=== pipeline.yaml ===\n{yaml_content}\n")

    user_msg = "\n".join(user_msg_parts)

    log.info("[autofix] Sending %d-char context to LLM for analysis…", len(user_msg))

    try:
        response = client.messages.create(
            model=model,
            max_tokens=4096,
            system=_AUTOFIX_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_msg}],
        )
        raw = response.content[0].text.strip()
        # Strip markdown fences if present
        if raw.startswith("```"):
            raw = re.sub(r"^```[^\n]*\n?", "", raw)
            raw = re.sub(r"\n?```$", "", raw.strip())

        proposal = json.loads(raw)

        return AutofixProposal(
            fixable=proposal.get("fixable", False),
            category=categories[0][0] if categories else "UNKNOWN",
            summary=proposal.get("summary", ""),
            fix_description=proposal.get("fix_description", ""),
            changes=proposal.get("changes", []),
            requires_regeneration=proposal.get("requires_regeneration", False),
            user_action_required=proposal.get("user_action_required", ""),
            errors_raw=error_text,
        )

    except json.JSONDecodeError as e:
        log.error("[autofix] LLM response was not valid JSON: %s", e)
        return AutofixProposal(
            fixable=False,
            category=categories[0][0] if categories else "UNKNOWN",
            summary="Auto-fix analysis failed — could not parse LLM response.",
            fix_description="",
            changes=[],
            errors_raw=error_text,
        )
    except Exception as e:
        log.error("[autofix] LLM call failed: %s", e)
        return AutofixProposal(
            fixable=False,
            category=categories[0][0] if categories else "UNKNOWN",
            summary=f"Auto-fix analysis failed: {e}",
            fix_description="",
            changes=[],
            errors_raw=error_text,
        )


def apply_proposal(proposal: AutofixProposal, work_dir: Path) -> tuple[bool, str]:
    """Apply an approved autofix proposal to the files on disk.

    Returns (success: bool, message: str).
    Only touches files within work_dir or the specs/ directory.
    Never touches .py files.
    """
    if not proposal.fixable or not proposal.changes:
        return False, "No changes to apply."

    specs_dir = Path(__file__).resolve().parent.parent / "specs"
    applied: list[str] = []
    backups: dict[Path, str] = {}

    try:
        for change in proposal.changes:
            file_name = change.get("file", "")
            action = change.get("action", "replace")

            # Security: NEVER modify .py files
            if file_name.endswith(".py"):
                log.warning("[autofix] Skipping prohibited .py file: %s", file_name)
                continue

            # Resolve file path
            if file_name.startswith("specs/"):
                file_path = specs_dir / file_name.removeprefix("specs/")
            else:
                file_path = work_dir / file_name

            if not file_path.exists():
                log.warning("[autofix] File not found: %s", file_path)
                continue

            content = file_path.read_text()

            # Backup before modifying
            if file_path not in backups:
                backups[file_path] = content
                backup_path = file_path.with_suffix(file_path.suffix + ".pre-autofix")
                backup_path.write_text(content)

            if action == "replace":
                search = change.get("search", "")
                replace = change.get("replace", "")
                if search and search in content:
                    content = content.replace(search, replace, 1)
                    file_path.write_text(content)
                    applied.append(f"  {file_name}: replaced '{search[:60]}…' → '{replace[:60]}…'")
                else:
                    log.warning("[autofix] Search string not found in %s: '%s'",
                                file_name, search[:80])

        if applied:
            msg = f"Applied {len(applied)} change(s):\n" + "\n".join(applied)
            log.info("[autofix] %s", msg)
            return True, msg
        else:
            return False, "No changes could be applied (search strings not found)."

    except Exception as e:
        # Restore backups on failure
        for path, original in backups.items():
            path.write_text(original)
        log.error("[autofix] Failed to apply changes, restored originals: %s", e)
        return False, f"Apply failed: {e}. Original files restored."
