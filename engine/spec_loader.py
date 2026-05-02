"""Load service type specs from the specs/ directory.

Each YAML file defines the knowledge base for one AWS service type:
defaults, IAM patterns, env var wiring, VPC triggers, code update methods,
invocation requirements, and runtime diagnostics.

Adding a new service = dropping a new YAML in specs/. No code changes.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Any

import yaml

logger = logging.getLogger(__name__)

SPECS_DIR = Path(__file__).resolve().parent.parent / "specs_new"


@dataclass(frozen=True)
class ServiceTypeSpec:
    """Parsed, immutable spec for one AWS service type."""
    service_type: str
    is_principal: bool
    terraform_resource: str
    description: str
    defaults: dict[str, Any]
    iam_always: list[str]
    iam_as_target_of: dict[str, list[str]]
    iam_as_source_to: dict[str, list[str]]
    # Always a list[dict] — single-dict entries are normalized on load.
    # Each dict has keys: pattern (str), ref (str)
    env_var_as_source_to: dict[str, list[dict[str, str]]]
    vpc_triggers: list[str]
    # How to update this service's code/configuration after deployment.
    # Used by the Pipeline Inspector agent to generate targeted boto3 fixes.
    code_update: dict[str, Any]
    # What callers need to invoke this service (env vars, IAM, static params).
    # Present only on services that require special invocation parameters
    # (e.g. EMR Serverless needs executionRoleArn + cloudWatchLoggingConfiguration).
    invocation: dict[str, Any]
    # Common runtime errors with causes and resolution patterns.
    # The inspector checks these before making an LLM call.
    runtime_diagnostics: list[dict[str, Any]]
    # Declarative sub-component definitions (tables, prefixes, named queries, etc.).
    # Drives the generic sub-component renderer — no Python code needed per type.
    sub_components: dict[str, Any] = field(default_factory=dict)


def _normalize_env_var_rules(raw_env_source: dict) -> dict[str, list[dict[str, str]]]:
    """Normalize env_var rules: single dict → list[dict] for every peer type."""
    result: dict[str, list[dict[str, str]]] = {}
    for peer_type, rule in raw_env_source.items():
        if isinstance(rule, list):
            result[peer_type] = rule
        else:
            result[peer_type] = [rule]
    return result


def _parse_spec(raw: dict) -> ServiceTypeSpec:
    # specs_new/ nests identity fields under an `identity:` key;
    # fall back to top-level for backwards compatibility with specs/
    identity = raw.get("identity", raw)
    iam = raw.get("iam", {})
    env_vars = raw.get("env_vars", {})
    return ServiceTypeSpec(
        service_type=identity["service_type"],
        is_principal=identity.get("is_principal", False),
        terraform_resource=identity.get("terraform_resource", ""),
        description=identity.get("description", ""),
        defaults=raw.get("defaults", {}),
        iam_always=iam.get("always", []),
        iam_as_target_of=iam.get("as_target_of", {}),
        iam_as_source_to=iam.get("as_source_to", {}),
        env_var_as_source_to=_normalize_env_var_rules(env_vars.get("as_source_to", {})),
        vpc_triggers=raw.get("vpc_triggers", []),
        code_update=raw.get("code_update", {}),
        invocation=raw.get("invocation", {}),
        runtime_diagnostics=raw.get("runtime_diagnostics", []),
        sub_components=raw.get("sub_components", {}),
    )


@lru_cache(maxsize=64)
def load_spec(service_type: str) -> ServiceTypeSpec | None:
    """Load and cache a service type spec. Returns None if not found."""
    path = SPECS_DIR / f"{service_type}_spec_develop.yaml"
    if not path.exists():
        logger.warning("no spec found for service type '%s'", service_type)
        return None
    raw = yaml.safe_load(path.read_text())
    spec = _parse_spec(raw)
    logger.debug("loaded spec for '%s' from %s", service_type, path)
    return spec


def list_known_types() -> list[str]:
    """Return all service types that have specs on disk."""
    return sorted(
        p.stem.replace("_spec_develop", "")
        for p in SPECS_DIR.glob("*_spec_develop.yaml")
    )


def has_spec(service_type: str) -> bool:
    return (SPECS_DIR / f"{service_type}_spec_develop.yaml").exists()
