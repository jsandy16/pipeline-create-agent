"""Deterministic, length-safe resource naming.

AWS limits: S3=63, IAM/Lambda=64, OpenSearch=28, SQS=80, DynamoDB=255, etc.
When the concatenated name exceeds the limit, truncate with a stable hash suffix.

S3 bucket names also have strict character/format rules enforced by _sanitize_s3_name().
"""
from __future__ import annotations

import hashlib
import re

from schemas import PipelineRequest, ServiceSpec

_NAME_LIMITS: dict[str, int] = {
    "s3": 63, "lambda": 64, "iam": 64, "sqs": 80, "sns": 256,
    "dynamodb": 255, "cloudwatch": 512, "glue": 255, "athena": 128,
    "stepfunctions": 80, "kinesis_streams": 128, "kinesis_firehose": 64,
    "redshift": 63, "opensearch": 28, "eventbridge": 64, "ec2": 64,
    "emr": 256, "msk": 64, "mwaa": 80, "dms": 255,
    "sagemaker": 63, "emr_serverless": 64, "quicksight": 128,
}
_DEFAULT_LIMIT = 63

# Regex to detect IP-address-style names (invalid for S3)
_IP_RE = re.compile(r"^\d{1,3}(\.\d{1,3}){3}$")


def _shorten(full: str, limit: int) -> str:
    if len(full) <= limit:
        return full
    suffix = "-" + hashlib.sha1(full.encode()).hexdigest()[:7]
    head = full[:limit - len(suffix)].rstrip("-")
    return head + suffix


def suffixed_name(base: str, suffix: str, limit: int = 64) -> str:
    """Return base+suffix, shortening base with a stable hash if the total exceeds limit.

    Use this whenever a renderer appends a static suffix (e.g. '-role', '-policy',
    '-rule') to resource_name(), so the final AWS name never exceeds the limit.
    """
    if len(base) + len(suffix) <= limit:
        return base + suffix
    short_base = _shorten(base, limit - len(suffix))
    return short_base + suffix


def _sanitize_s3_name(name: str) -> str:
    """Apply all AWS S3 bucket naming rules after length-capping.

    Rules enforced (source: AWS S3 bucket naming rules):
    - Lowercase letters, digits, hyphens only (strip everything else)
    - No consecutive hyphens  → collapse to single hyphen
    - Cannot start with 'xn--' → strip prefix
    - Cannot start or end with a hyphen
    - Cannot look like an IP address → replace dots with hyphens
    - Minimum 3 characters → pad with 'x' if needed
    """
    # Strip dots (SSL issues) and any character that isn't a-z, 0-9, or -
    name = re.sub(r"[^a-z0-9-]", "-", name)
    # Collapse consecutive hyphens
    name = re.sub(r"-{2,}", "-", name)
    # Strip leading/trailing hyphens
    name = name.strip("-")
    # Remove forbidden 'xn--' IDNA prefix
    if name.startswith("xn--"):
        name = name[4:].lstrip("-")
    # If it looks like an IP address, replace dots (already done above) — check again
    if _IP_RE.match(name):
        name = name.replace(".", "-")
    # Enforce minimum 3 chars
    if len(name) < 3:
        name = (name + "xxx")[:3]
    return name


def _ordinal(req: PipelineRequest, svc: ServiceSpec) -> int | None:
    """Return 1-based ordinal when multiple services share the same type, else None.

    E.g. three S3 buckets → 1, 2, 3.  A lone Lambda → None (no suffix).
    Ordering follows the services list in the pipeline YAML.
    """
    same_type = [s for s in req.services if s.type == svc.type]
    if len(same_type) < 2:
        return None
    return same_type.index(svc) + 1


def _hash4(text: str) -> str:
    """Return a stable 4-character hex hash suffix."""
    return hashlib.sha1(text.encode()).hexdigest()[:4]


def resource_label(req: PipelineRequest, svc: ServiceSpec) -> str:
    """Terraform resource label: underscores, unlimited length.

    Format: <project>_<cost_center>_<business_unit>_<service_type>_<name>_<4hex>
    When multiple services share the same type, the ordinal is folded into
    the hash input so labels remain unique.
    """
    parts = [req.pipeline_name, req.cost_center, req.business_unit,
             svc.type, svc.name]
    label = "_".join(p.replace("-", "_").lower() for p in parts if p)
    n = _ordinal(req, svc)
    hash_input = label + (f"_{n}" if n is not None else "")
    label += "_" + _hash4(hash_input)
    return label


def resource_name(req: PipelineRequest, svc: ServiceSpec) -> str:
    """AWS resource name: hyphens, length-capped per service type.

    Format: <project>-<cost_center>-<business_unit>-<service_type>-<name>-<4hex>
    For S3, additional bucket naming rules are applied after length-capping.
    """
    parts = [req.pipeline_name, req.cost_center, req.business_unit,
             svc.type, svc.name]
    full = "-".join(p.replace("_", "-").lower() for p in parts if p)
    n = _ordinal(req, svc)
    hash_input = full + (f"-{n}" if n is not None else "")
    full += "-" + _hash4(hash_input)
    name = _shorten(full, _NAME_LIMITS.get(svc.type, _DEFAULT_LIMIT))
    if svc.type == "s3":
        name = _sanitize_s3_name(name)
    return name


def label_for(name: str, svc_type: str, req: PipelineRequest) -> str:
    """Compute resource_label for a service by logical name lookup."""
    svc = next((s for s in req.services if s.name == name), None)
    if svc is None:
        raise ValueError(f"Service '{name}' not found")
    return resource_label(req, svc)


def name_for(name: str, svc_type: str, req: PipelineRequest) -> str:
    """Compute resource_name for a service by logical name lookup."""
    svc = next((s for s in req.services if s.name == name), None)
    if svc is None:
        raise ValueError(f"Service '{name}' not found")
    return resource_name(req, svc)
