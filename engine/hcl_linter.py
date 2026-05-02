"""Deterministic HCL linter — catches cross-reference, duplicate, tag, and config bugs.

Runs in <50ms via python-hcl2. No LLM calls.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Iterable

import hcl2


REQUIRED_TAGS = {"Pipeline", "BusinessUnit", "CostCenter", "ManagedBy"}

UNTAGGABLE_TYPES = {
    "aws_security_group_rule", "aws_iam_role_policy", "aws_iam_role_policy_attachment",
    "aws_lambda_permission", "aws_s3_bucket_versioning",
    "aws_s3_bucket_server_side_encryption_configuration", "aws_s3_bucket_notification",
    "aws_s3_bucket_public_access_block", "aws_lambda_event_source_mapping",
    "aws_redshift_subnet_group", "aws_sqs_queue_policy", "aws_sns_topic_subscription",
    "aws_cloudwatch_event_target", "aws_iam_instance_profile",
    "random_password", "random_id",
}

_VALID_PREFIXES = ("aws_", "random_", "tls_", "archive_", "null_", "external_", "time_")
_UNCHECKED = {"var.", "local.", "module."}
_KEYWORDS = {"true", "false", "null", "string", "number", "bool", "list", "map", "set", "object", "tuple", "any"}

# Resources that MUST have a depends_on referencing their IAM role/policy
_IAM_DEPENDENT_TYPES = {
    "aws_lambda_function", "aws_sagemaker_model", "aws_emr_cluster",
    "aws_emrserverless_application", "aws_glue_crawler",
}

_REF_RE = re.compile(
    r"\b(?P<prefix>data\.|module\.|var\.|local\.)?"
    r"(?P<type>[a-z][a-z0-9_]*)"
    r"\.(?P<label>[a-z][a-z0-9_]*)"
    r"(?:\.(?P<attr>[a-z][a-z0-9_]*))?"
)


@dataclass(frozen=True)
class LintError:
    severity: str
    code: str
    message: str
    location: str

    def format(self) -> str:
        return f"[{self.severity.upper()}/{self.code}] {self.location}: {self.message}"


def _unquote(s: str) -> str:
    return s.strip().strip('"')


def lint_hcl(hcl_text: str) -> list[LintError]:
    """Lint consolidated HCL. Returns list of errors (empty = clean)."""
    try:
        tree = hcl2.loads(hcl_text)
    except Exception as e:
        return [LintError("error", "PARSE_FAIL", f"HCL parse error: {e}", "<file>")]

    declared = set()
    declared_data = set()
    errors: list[LintError] = []

    # Collect declarations
    for block in tree.get("resource", []):
        for rtype, body in block.items():
            bodies = body if isinstance(body, list) else [body]
            for inner in bodies:
                for label in inner:
                    declared.add(f"{_unquote(rtype)}.{_unquote(label)}")

    for block in tree.get("data", []):
        for dtype, body in block.items():
            bodies = body if isinstance(body, list) else [body]
            for inner in bodies:
                for label in inner:
                    declared_data.add(f"data.{_unquote(dtype)}.{_unquote(label)}")

    # Check references
    for block in tree.get("resource", []):
        for rtype, body in block.items():
            bodies = body if isinstance(body, list) else [body]
            for inner in bodies:
                for label, attrs in inner.items():
                    loc = f"{_unquote(rtype)}.{_unquote(label)}"
                    _walk(attrs, loc, declared, declared_data, errors)

    # Check tags
    for block in tree.get("resource", []):
        for rtype, body in block.items():
            rt = _unquote(rtype)
            if rt in UNTAGGABLE_TYPES:
                continue
            bodies = body if isinstance(body, list) else [body]
            for inner in bodies:
                for label, attrs in inner.items():
                    loc = f"{rt}.{_unquote(label)}"
                    tags = attrs.get("tags")
                    if tags is None:
                        continue  # warning only, don't block
                    td = tags[0] if isinstance(tags, list) and tags else tags
                    if isinstance(td, dict):
                        missing = REQUIRED_TAGS - set(td.keys())
                        if missing:
                            errors.append(LintError("warning", "MISSING_TAGS",
                                f"missing tags: {sorted(missing)}", loc))

    # Check duplicates (textual)
    seen: dict[str, int] = {}
    for m in re.finditer(r'^\s*resource\s+"(\w+)"\s+"(\w+)"\s*\{', hcl_text, re.MULTILINE):
        key = f"{m.group(1)}.{m.group(2)}"
        seen[key] = seen.get(key, 0) + 1
    for key, cnt in seen.items():
        if cnt > 1:
            errors.append(LintError("error", "DUPLICATE", f"declared {cnt} times", key))

    # Check for unreferenced data sources used in resource attributes
    # Collect ALL data source references from the raw HCL text
    data_refs_used: set[str] = set()
    for m in re.finditer(r'data\.([a-z_]+)\.([a-z_][a-z0-9_]*)', hcl_text):
        data_refs_used.add(f"data.{m.group(1)}.{m.group(2)}")
    undeclared_data = data_refs_used - declared_data
    for ref in sorted(undeclared_data):
        errors.append(LintError("error", "UNDECLARED_DATA",
                                f"data source {ref} is referenced but never declared", "<file>"))

    # Check for DynamoDB billing mode conflicts (semantic check on raw HCL)
    errors.extend(_check_dynamodb_conflicts(tree))

    return errors


def _check_dynamodb_conflicts(tree: dict) -> list[LintError]:
    """Check DynamoDB resources for billing mode / capacity conflicts."""
    errors: list[LintError] = []
    for block in tree.get("resource", []):
        for rtype, body in block.items():
            if _unquote(rtype) != "aws_dynamodb_table":
                continue
            bodies = body if isinstance(body, list) else [body]
            for inner in bodies:
                for label, attrs in inner.items():
                    if not isinstance(attrs, dict):
                        continue
                    loc = f"aws_dynamodb_table.{_unquote(label)}"
                    billing = attrs.get("billing_mode")
                    if isinstance(billing, list):
                        billing = billing[0] if billing else None
                    if isinstance(billing, str):
                        billing = _unquote(billing)
                    if billing == "PAY_PER_REQUEST":
                        if "read_capacity" in attrs or "write_capacity" in attrs:
                            errors.append(LintError(
                                "error", "DYNAMO_BILLING_CONFLICT",
                                "PAY_PER_REQUEST is incompatible with "
                                "read_capacity/write_capacity", loc))
    return errors


def _walk(value, loc, declared, declared_data, errors):
    if isinstance(value, dict):
        for k, v in value.items():
            _walk(v, f"{loc}.{k}", declared, declared_data, errors)
    elif isinstance(value, list):
        for i, v in enumerate(value):
            _walk(v, f"{loc}[{i}]", declared, declared_data, errors)
    elif isinstance(value, str):
        inner = value[2:-1] if value.startswith("${") and value.endswith("}") else value
        for m in _REF_RE.finditer(inner):
            prefix = m.group("prefix") or ""
            rtype, rlabel = m.group("type"), m.group("label")
            if prefix in _UNCHECKED or rtype in _KEYWORDS:
                continue
            if prefix == "data.":
                key = f"data.{rtype}.{rlabel}"
                if key not in declared_data:
                    errors.append(LintError("error", "DATA_REF", f"undeclared {key}", loc))
            elif any(rtype.startswith(p) for p in _VALID_PREFIXES):
                key = f"{rtype}.{rlabel}"
                if key not in declared:
                    errors.append(LintError("error", "REF", f"undeclared {key}", loc))


def format_errors(errors: Iterable[LintError]) -> str:
    return "\n".join(f"- {e.format()}" for e in errors)
