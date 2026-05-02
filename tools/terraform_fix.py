"""Terraform plan error auto-fix agent.

Classifies terraform plan errors as:
  - minor  → auto-fixable by the LLM agent (name length, invalid chars, etc.)
  - complex → requires human review

For minor errors the agent sends the broken main.tf + error list to Claude and
gets back a corrected HCL file.  No logic changes — only the specific
failing attributes are corrected.
"""
from __future__ import annotations

import os
import re
import logging
from pathlib import Path

log = logging.getLogger(__name__)

# ── Error patterns that are safe to auto-fix ─────────────────────────────────

_MINOR_PATTERNS = [
    re.compile(r"cannot be longer than \d+ characters", re.I),
    re.compile(r"expected length of .+ to be in the range", re.I),
    re.compile(r"invalid value for .+: must be between \d+ and \d+ characters", re.I),
    re.compile(r"must contain only", re.I),
    re.compile(r"invalid character", re.I),
    re.compile(r"must be lowercase", re.I),
    re.compile(r"must not (start|end) with", re.I),
]

_SYSTEM_PROMPT = """\
You are an expert Terraform HCL engineer. A terraform plan has failed with the errors below.
Your job is to fix ONLY the specific attribute values that caused those errors — do not \
change any resource logic, IAM permissions, tags, or anything else.

Rules you MUST follow:
1. Return ONLY the complete corrected HCL content. No markdown fences. No explanations.
2. For name-too-long errors: shorten the string value so it fits within the required limit. \
   Preserve uniqueness by keeping a distinctive suffix (e.g. last 7 chars of a hash).
3. For invalid-character errors: replace forbidden characters with hyphens or underscores \
   as appropriate for the resource type.
4. Never change resource types, Terraform identifiers (left side of "="), IAM actions, \
   or any attribute not mentioned in the errors.
5. Every line that was correct in the original must stay identical in the output.
"""


def classify_errors(plan_stderr: str) -> str:
    """Return 'minor', 'complex', or 'none'."""
    error_blocks = re.findall(r"Error:.*?(?=\nError:|\Z)", plan_stderr, re.S)
    if not error_blocks:
        return "none"
    for block in error_blocks:
        if not any(p.search(block) for p in _MINOR_PATTERNS):
            return "complex"
    return "minor"


def _is_complete_hcl(hcl: str) -> bool:
    """Return True if the HCL string has balanced braces and ends with a closing brace.

    A truncated LLM response will leave unclosed blocks, making depth > 0.
    """
    depth = 0
    in_str = False
    esc = False
    for ch in hcl:
        if esc:
            esc = False
            continue
        if ch == "\\" and in_str:
            esc = True
            continue
        if ch == '"':
            in_str = not in_str
            continue
        if in_str:
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
    return depth == 0 and hcl.rstrip().endswith("}")


def fix_hcl(hcl_path: Path, plan_errors: str, model: str = "claude-haiku-4-5-20251001",
            api_key: str | None = None) -> str:
    """Call Claude to fix minor terraform errors.  Returns corrected HCL string."""
    import anthropic
    from dotenv import load_dotenv
    load_dotenv()

    key = api_key or os.environ.get("ANTHROPIC_API_KEY")
    client = anthropic.Anthropic(api_key=key)
    original_hcl = hcl_path.read_text()

    user_msg = (
        f"=== TERRAFORM ERRORS ===\n{plan_errors}\n\n"
        f"=== main.tf ===\n{original_hcl}"
    )

    log.info("[terraform-fix] Sending %d-char HCL to LLM for auto-fix…", len(original_hcl))
    response = client.messages.create(
        model=model,
        max_tokens=16384,   # raised from 8192 — large pipelines need more output tokens
        system=_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_msg}],
    )
    fixed = response.content[0].text.strip()
    # Strip accidental markdown fences
    if fixed.startswith("```"):
        fixed = re.sub(r"^```[^\n]*\n?", "", fixed)
        fixed = re.sub(r"\n?```$", "", fixed.strip())
    return fixed


def attempt_autofix(work_dir: Path, plan_errors: str, model: str = "claude-haiku-4-5-20251001",
                    api_key: str | None = None) -> dict:
    """Top-level entry point called from the deploy flow.

    Returns:
        {"action": "fixed",   "message": "..."}  – HCL was fixed, re-run plan
        {"action": "human",   "message": "..."}  – complex error, needs review
        {"action": "none",    "message": "..."}  – no errors found
    """
    severity = classify_errors(plan_errors)

    if severity == "none":
        return {"action": "none", "message": "No errors detected."}

    if severity == "complex":
        return {
            "action": "human",
            "message": (
                "One or more errors require human review — they cannot be "
                "safely auto-fixed:\n\n" + plan_errors
            ),
        }

    # Minor errors → auto-fix
    hcl_path = work_dir / "main.tf"
    if not hcl_path.exists():
        return {"action": "human", "message": "main.tf not found — cannot auto-fix."}

    original_hcl = hcl_path.read_text()
    backup_path = work_dir / "main.tf.pre-fix"

    try:
        fixed_hcl = fix_hcl(hcl_path, plan_errors, model=model, api_key=api_key)

        # Guard: if the LLM response was truncated (unbalanced braces / incomplete),
        # do NOT overwrite the valid file — escalate to human review instead.
        if not _is_complete_hcl(fixed_hcl):
            log.error(
                "[terraform-fix] LLM response is incomplete (unbalanced braces or truncated). "
                "Original main.tf preserved. Escalating to human review."
            )
            return {
                "action": "human",
                "message": (
                    "Auto-fix response was truncated (the pipeline is too large for the model's "
                    "output window). Please fix the errors manually:\n\n" + plan_errors
                ),
            }

        # Write backup then apply fix
        backup_path.write_text(original_hcl)
        hcl_path.write_text(fixed_hcl)
        log.info("[terraform-fix] main.tf updated with auto-fix.")
        return {"action": "fixed", "message": "Minor errors auto-fixed. Re-running plan…"}

    except Exception as exc:
        # Restore original if something went wrong mid-write
        if backup_path.exists() and not _is_complete_hcl(hcl_path.read_text()):
            hcl_path.write_text(original_hcl)
            log.warning("[terraform-fix] Restored original main.tf after failed fix.")
        log.error("[terraform-fix] LLM fix failed: %s", exc)
        return {"action": "human", "message": f"Auto-fix failed ({exc}). Please review manually."}
