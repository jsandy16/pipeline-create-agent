"""Feature index and Tier 0 keyword resolver for config chat.

Parses all specs_new/*_spec_develop.yaml files at construction and builds
an in-memory index mapping natural-language keywords to config patches.
Resolves ~70% of user requests with zero LLM calls.
"""
from __future__ import annotations

import difflib
import glob
import logging
import os
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

from engine.config_registry import (
    SUPPORTED_CONFIG,
    ConfigKeyInfo,
    get_supported_keys,
    get_supported_key_names,
    validate_config_patch,
)

logger = logging.getLogger(__name__)

_SPECS_NEW_DIR = Path(__file__).resolve().parent.parent / "specs_new"
_TEMPLATES_DIR = Path(__file__).resolve().parent.parent / "config_templates"


# ── Data models ─────────────────────────────────────────────────────────────

@dataclass
class FeatureEntry:
    """A single indexable feature mapped to a config key."""
    service_type: str
    feature_name: str
    config_key: str
    keywords: list[str]
    value_map: dict[str, Any]       # keyword → config value
    default_value: Any
    description: str
    section_path: str               # top-level YAML section name
    cost_warning: str | None = None


@dataclass
class ConfigResolution:
    """Result of resolving a user message to a config patch."""
    tier: int
    service_name: str
    config_patch: dict[str, Any]
    confidence: float
    explanation: str
    warnings: list[str] = field(default_factory=list)
    cost_warning: str | None = None


# ── Keyword synonyms ────────────────────────────────────────────────────────
# Common user phrasings that map to config key names.

_KEYWORD_ALIASES: dict[str, list[str]] = {
    "versioning_status": ["versioning", "version", "version control", "versions"],
    "runtime": ["runtime", "language", "python", "nodejs", "node", "java", "ruby", "dotnet"],
    "handler": ["handler", "entry point", "entrypoint"],
    "memory_size": ["memory", "ram", "mem"],
    "timeout": ["timeout", "time out", "max duration", "execution time"],
    "visibility_timeout_seconds": ["visibility timeout", "visibility"],
    "message_retention_seconds": ["message retention", "retention", "message ttl"],
    "billing_mode": ["billing", "billing mode", "capacity mode", "on demand",
                     "on-demand", "provisioned", "pay per request"],
    "hash_key": ["partition key", "hash key", "primary key"],
    "hash_key_type": ["key type", "partition key type"],
    "read_capacity": ["read capacity", "rcu", "read units"],
    "write_capacity": ["write capacity", "wcu", "write units"],
    "type": ["type", "state machine type", "application type", "data source type"],
    "schedule_expression": ["schedule", "cron", "rate", "interval", "frequency",
                            "every", "recurring"],
    "event_pattern": ["event pattern", "pattern", "event filter"],
    "instance_type": ["instance type", "instance", "instance size", "machine type",
                      "node type", "vm size"],
    "stream_mode": ["stream mode", "capacity mode"],
    "shard_count": ["shards", "shard count", "number of shards"],
    "retention_period": ["retention", "retention period", "data retention"],
    "buffering_size": ["buffer size", "buffering size"],
    "buffering_interval": ["buffer interval", "buffering interval", "flush interval"],
    "compression_format": ["compression", "compress", "gzip", "snappy", "zip"],
    "runtime_environment": ["runtime", "flink", "sql", "analytics runtime"],
    "kafka_version": ["kafka version", "kafka"],
    "number_of_broker_nodes": ["broker nodes", "brokers", "number of brokers"],
    "broker_instance_type": ["broker instance", "broker type", "broker size"],
    "volume_size": ["volume size", "disk size", "storage size", "ebs size", "disk"],
    "replication_instance_class": ["replication instance", "dms instance"],
    "allocated_storage": ["storage", "allocated storage", "disk space"],
    "node_type": ["node type", "node size"],
    "number_of_nodes": ["nodes", "number of nodes", "node count", "cluster size"],
    "database_name": ["database name", "database", "db name", "db"],
    "master_username": ["master username", "admin user", "username", "admin"],
    "engine": ["engine", "database engine", "aurora engine"],
    "engine_version": ["engine version", "db version", "aurora version"],
    "min_capacity": ["min capacity", "minimum capacity", "min acu"],
    "max_capacity": ["max capacity", "maximum capacity", "max acu"],
    "release_label": ["release", "emr release", "emr version"],
    "master_instance_type": ["master instance", "master node type", "master type"],
    "core_instance_type": ["core instance", "core node type", "core type"],
    "core_instance_count": ["core count", "core nodes", "number of core nodes"],
    "applications": ["applications", "apps", "install", "spark", "hive", "presto", "flink"],
    "architecture": ["architecture", "arch", "cpu architecture", "arm", "x86"],
    "idle_timeout_minutes": ["idle timeout", "auto stop", "idle"],
    "initial_instance_count": ["instance count", "endpoint instances"],
    "container_image": ["container image", "docker image", "ecr image", "custom image"],
    "framework": ["framework", "ml framework", "scikit", "pytorch", "tensorflow",
                   "xgboost", "huggingface"],
    "image_tag": ["image tag", "tag"],
    "model_data_url": ["model url", "model path", "model s3", "model data",
                       "model artifacts"],
    "direct_internet_access": ["internet access", "direct internet"],
    "work_group": ["workgroup", "work group", "athena workgroup"],
    "description": ["description", "catalog description"],
    "path": ["path", "iam path", "role path"],
    "max_session_duration": ["session duration", "max session"],
}

# Enable/disable intent keywords
_ENABLE_KEYWORDS = {"enable", "turn on", "activate", "start", "yes", "true", "on"}
_DISABLE_KEYWORDS = {"disable", "turn off", "deactivate", "stop", "no", "false", "off"}

# Value aliases for common enum values
_VALUE_ALIASES: dict[str, dict[str, Any]] = {
    "versioning_status": {
        "enable": "Enabled", "on": "Enabled", "yes": "Enabled", "true": "Enabled",
        "disable": "Suspended", "off": "Suspended", "no": "Suspended", "false": "Suspended",
        "suspend": "Suspended",
    },
    "billing_mode": {
        "provisioned": "PROVISIONED", "on demand": "PAY_PER_REQUEST",
        "on-demand": "PAY_PER_REQUEST", "pay per request": "PAY_PER_REQUEST",
        "ondemand": "PAY_PER_REQUEST",
    },
    "stream_mode": {
        "on demand": "ON_DEMAND", "on-demand": "ON_DEMAND", "ondemand": "ON_DEMAND",
        "provisioned": "PROVISIONED",
    },
    "direct_internet_access": {
        "enable": "Enabled", "on": "Enabled", "yes": "Enabled",
        "disable": "Disabled", "off": "Disabled", "no": "Disabled",
    },
    "compression_format": {
        "gzip": "GZIP", "zip": "ZIP", "snappy": "Snappy",
        "uncompressed": "UNCOMPRESSED", "none": "UNCOMPRESSED",
    },
}


# ── Feature Index ────────────────────────────────────────────────────────────

class FeatureIndex:
    """In-memory index of all config features across all service types.

    Built at construction by parsing specs_new/*_spec_develop.yaml.
    Only indexes features whose config_key is in SUPPORTED_CONFIG.
    """

    def __init__(self) -> None:
        self._entries: list[FeatureEntry] = []
        self._by_service: dict[str, list[FeatureEntry]] = {}
        self._spec_cache: dict[str, dict] = {}
        self._templates_cache: dict[str, list[dict]] = {}
        self._build_index()
        self._load_templates()

    # ── Index construction ──────────────────────────────────────────────

    def _build_index(self) -> None:
        """Parse all spec_develop.yaml files and build the feature index."""
        spec_files = sorted(_SPECS_NEW_DIR.glob("*_spec_develop.yaml"))
        if not spec_files:
            logger.warning("No spec_develop.yaml files found in %s", _SPECS_NEW_DIR)
            return

        for path in spec_files:
            try:
                with open(path) as f:
                    spec = yaml.safe_load(f)
                if not spec or "identity" not in spec:
                    continue

                stype = spec["identity"]["service_type"]
                self._spec_cache[stype] = spec
                supported_keys = get_supported_key_names(stype)
                if not supported_keys:
                    continue

                # Index from defaults section
                self._index_defaults(stype, spec, supported_keys)

                # Index from service-specific feature sections
                self._index_feature_sections(stype, spec, supported_keys)

            except Exception as e:
                logger.warning("Failed to parse %s: %s", path, e)

        logger.info(
            "Feature index built: %d entries across %d service types",
            len(self._entries),
            len(self._by_service),
        )

    def _index_defaults(
        self, stype: str, spec: dict, supported_keys: set[str]
    ) -> None:
        """Index entries from the defaults section."""
        defaults = spec.get("defaults", {})
        free_tier = spec.get("identity", {}).get("free_tier", {})
        cost_warning = None
        if free_tier.get("status") == "never_free":
            cost_warning = f"This service is NOT free tier eligible"

        key_info_map = {k.key: k for k in get_supported_keys(stype)}

        for key, default_val in defaults.items():
            if key not in supported_keys:
                continue
            if isinstance(default_val, (dict, list)):
                continue  # skip complex nested defaults
            if key.startswith("#"):
                continue  # skip comments

            info = key_info_map.get(key)
            keywords = _KEYWORD_ALIASES.get(key, [key.replace("_", " ")])
            value_map = _VALUE_ALIASES.get(key, {})

            # Build value_map from allowed_values if not already defined
            if not value_map and info and info.allowed_values:
                for av in info.allowed_values:
                    if isinstance(av, str):
                        value_map[av.lower()] = av

            entry = FeatureEntry(
                service_type=stype,
                feature_name=key,
                config_key=key,
                keywords=keywords,
                value_map=value_map,
                default_value=default_val,
                description=info.description if info else key.replace("_", " "),
                section_path="defaults",
                cost_warning=cost_warning,
            )
            self._entries.append(entry)
            self._by_service.setdefault(stype, []).append(entry)

    def _index_feature_sections(
        self, stype: str, spec: dict, supported_keys: set[str]
    ) -> None:
        """Walk service-specific sections for terraform_attribute pointers."""
        # Sections to skip (they're infrastructure, not user features)
        skip_sections = {
            "identity", "naming", "defaults", "quotas", "iam", "env_vars",
            "vpc_triggers", "integrations", "terraform_resources",
            "boto3_operations", "runtime_diagnostics", "tags", "code_update",
        }

        for section_name, section_data in spec.items():
            if section_name in skip_sections:
                continue
            if not isinstance(section_data, dict):
                continue
            self._walk_section_for_features(
                stype, section_name, section_data, supported_keys
            )

    def _walk_section_for_features(
        self,
        stype: str,
        section_name: str,
        data: dict,
        supported_keys: set[str],
        depth: int = 0,
    ) -> None:
        """Recursively find terraform_attribute or config-key-matching fields."""
        if depth > 3:
            return

        # Check if this dict has a terraform_attribute that matches a supported key
        tf_attr = data.get("terraform_attribute", "")
        if isinstance(tf_attr, str):
            # Clean up complex attributes like "mfa_delete"
            clean_attr = tf_attr.split("=")[0].strip().split("{")[0].strip()
            if clean_attr in supported_keys:
                # Check if we already have this key indexed
                existing = [
                    e for e in self._by_service.get(stype, [])
                    if e.config_key == clean_attr
                ]
                if existing:
                    # Enrich keywords from this section
                    existing[0].keywords = list(set(
                        existing[0].keywords
                        + [section_name, section_name.replace("_", " ")]
                    ))
                    if existing[0].section_path == "defaults":
                        existing[0].section_path = section_name

        # Recurse into sub-dicts
        for key, value in data.items():
            if isinstance(value, dict):
                self._walk_section_for_features(
                    stype, section_name, value, supported_keys, depth + 1
                )

    def _load_templates(self) -> None:
        """Load config templates from config_templates/*.yaml."""
        if not _TEMPLATES_DIR.exists():
            return
        for path in _TEMPLATES_DIR.glob("*.yaml"):
            try:
                with open(path) as f:
                    data = yaml.safe_load(f)
                if data and "templates" in data:
                    stype = path.stem  # e.g. "lambda" from "lambda.yaml"
                    templates = []
                    for tname, tdata in data["templates"].items():
                        templates.append({
                            "id": tname,
                            "display_name": tdata.get("display_name", tname),
                            "description": tdata.get("description", ""),
                            "config": tdata.get("config", {}),
                        })
                    self._templates_cache[stype] = templates
            except Exception as e:
                logger.warning("Failed to load template %s: %s", path, e)

    # ── Tier 0 resolution ───────────────────────────────────────────────

    def resolve_tier0(
        self,
        message: str,
        service_type: str | None = None,
        service_name: str | None = None,
        pipeline_services: list[dict] | None = None,
    ) -> ConfigResolution | None:
        """Attempt zero-LLM keyword resolution.

        Args:
            message: User's natural language request.
            service_type: If known, scope search to this service type.
            service_name: The pipeline service name to patch.
            pipeline_services: List of {"name": ..., "type": ...} from pipeline.

        Returns:
            ConfigResolution if confident, None if Tier 0 cannot resolve.
        """
        msg_lower = message.lower().strip()
        tokens = self._tokenize(msg_lower)

        # Determine which service types to search
        if service_type:
            candidates = self._by_service.get(service_type, [])
        elif pipeline_services:
            candidates = []
            for svc in pipeline_services:
                candidates.extend(self._by_service.get(svc["type"], []))
        else:
            candidates = self._entries

        if not candidates:
            return None

        # Score each feature entry
        scored: list[tuple[float, FeatureEntry]] = []
        for entry in candidates:
            score = self._score_entry(msg_lower, tokens, entry)
            if score > 0.0:
                scored.append((score, entry))

        if not scored:
            return None

        scored.sort(key=lambda x: x[0], reverse=True)
        best_score, best_entry = scored[0]
        second_score = scored[1][0] if len(scored) > 1 else 0.0

        # Confidence threshold: must be high enough and clearly best
        if best_score < 0.5:
            return None
        if best_score < 0.7 and second_score > best_score * 0.8:
            return None  # too ambiguous

        # Extract value intent
        value = self._extract_value(msg_lower, tokens, best_entry)
        if value is None:
            return None  # can't determine what value to set

        # Resolve service name
        resolved_name = service_name
        if not resolved_name and pipeline_services:
            matching = [
                s for s in pipeline_services
                if s["type"] == best_entry.service_type
            ]
            if len(matching) == 1:
                resolved_name = matching[0]["name"]
            elif len(matching) > 1:
                # Ambiguous — check if message mentions a service name
                # Use word boundary matching to avoid false positives
                for s in matching:
                    name_lower = s["name"].lower()
                    # Require the name to appear as a distinct word/token
                    pattern = r'\b' + re.escape(name_lower) + r'\b'
                    if re.search(pattern, msg_lower) and len(name_lower) > 1:
                        resolved_name = s["name"]
                        break
                if not resolved_name:
                    return None  # can't determine which service

        if not resolved_name:
            return None

        # Validate the patch
        patch = {best_entry.config_key: value}
        clean_patch, warnings = validate_config_patch(
            best_entry.service_type, patch
        )
        if not clean_patch:
            return ConfigResolution(
                tier=0,
                service_name=resolved_name,
                config_patch={},
                confidence=best_score,
                explanation=f"Could not apply: {'; '.join(warnings)}",
                warnings=warnings,
            )

        # Build explanation
        explanation = (
            f"Set {best_entry.config_key} = {value} "
            f"on {resolved_name} ({best_entry.service_type})"
        )
        if value == best_entry.default_value:
            explanation += " (this is already the default)"

        # Cost warning
        cost_warning = best_entry.cost_warning
        if best_entry.config_key == "billing_mode" and value == "PAY_PER_REQUEST":
            cost_warning = (
                "PAY_PER_REQUEST mode is NOT included in the free tier. "
                "Only PROVISIONED mode (<=25 RCU/WCU) qualifies."
            )

        return ConfigResolution(
            tier=0,
            service_name=resolved_name,
            config_patch=clean_patch,
            confidence=best_score,
            explanation=explanation,
            warnings=warnings,
            cost_warning=cost_warning,
        )

    # ── Scoring ─────────────────────────────────────────────────────────

    def _tokenize(self, text: str) -> list[str]:
        """Split text into lowercase tokens, stripping punctuation."""
        text = re.sub(r"[^\w\s-]", " ", text)
        return [t for t in text.lower().split() if len(t) > 1]

    def _score_entry(
        self, msg_lower: str, tokens: list[str], entry: FeatureEntry
    ) -> float:
        """Score how well a message matches a feature entry. 0.0-1.0."""
        best = 0.0

        for kw in entry.keywords:
            kw_lower = kw.lower()

            # Exact substring match in the full message
            if kw_lower in msg_lower:
                # Longer keyword matches are more specific → higher score
                score = min(0.7 + len(kw_lower) * 0.02, 1.0)
                best = max(best, score)
                continue

            # Token-level matching
            kw_tokens = kw_lower.split()
            if len(kw_tokens) == 1:
                for t in tokens:
                    if t == kw_lower:
                        best = max(best, 0.8)
                    elif kw_lower.startswith(t) or t.startswith(kw_lower):
                        best = max(best, 0.5)
                    else:
                        ratio = difflib.SequenceMatcher(
                            None, t, kw_lower
                        ).ratio()
                        if ratio > 0.75:
                            best = max(best, ratio * 0.6)
            else:
                # Multi-word keyword: check if all tokens present
                found = sum(1 for kt in kw_tokens if kt in tokens)
                if found == len(kw_tokens):
                    best = max(best, 0.85)
                elif found >= len(kw_tokens) - 1 and len(kw_tokens) > 1:
                    best = max(best, 0.6)

        # Also check value_map keys — if the user mentions a specific value,
        # that's a strong signal for this feature
        for vk in entry.value_map:
            if vk.lower() in msg_lower:
                best = max(best, 0.7)

        return best

    def _extract_value(
        self, msg_lower: str, tokens: list[str], entry: FeatureEntry
    ) -> Any | None:
        """Extract the intended value from the message."""
        # 1. Check value_map for explicit value matches
        for vk, vv in entry.value_map.items():
            if vk.lower() in msg_lower:
                return vv

        # 2. Check enable/disable intent for boolean-like features
        if entry.value_map:
            has_enable = any(ek in msg_lower for ek in _ENABLE_KEYWORDS)
            has_disable = any(dk in msg_lower for dk in _DISABLE_KEYWORDS)

            if has_enable and not has_disable:
                # Find the "enabled" value in value_map
                for vk, vv in entry.value_map.items():
                    if vk in ("enable", "on", "yes", "true"):
                        return vv
            if has_disable and not has_enable:
                for vk, vv in entry.value_map.items():
                    if vk in ("disable", "off", "no", "false", "suspend"):
                        return vv

        # 3. Numeric extraction for int/float keys
        info_map = {k.key: k for k in get_supported_keys(entry.service_type)}
        info = info_map.get(entry.config_key)
        if info and info.type in (int, float):
            numbers = re.findall(r"\b(\d+(?:\.\d+)?)\b", msg_lower)
            if numbers:
                val = info.type(numbers[-1])  # use the last number mentioned
                return val

        # 4. String value extraction for allowed_values
        if info and info.allowed_values and info.type is str:
            for av in info.allowed_values:
                if av.lower() in msg_lower:
                    return av

        # 5. If the feature has enable/disable semantics and user just mentioned
        #    the feature name, default to "enable"
        if entry.value_map:
            for vk, vv in entry.value_map.items():
                if vk in ("enable", "on", "yes", "true"):
                    return vv

        return None

    # ── Spec section extraction (for Tier 1) ────────────────────────────

    def get_relevant_sections(
        self, service_type: str, keywords: list[str]
    ) -> str:
        """Extract relevant YAML sections for LLM context (Tier 1/2).

        Returns a string with only the matching sections, keeping
        token count low for cheap LLM calls.
        """
        spec = self._spec_cache.get(service_type)
        if not spec:
            return ""

        relevant_keys = {"identity", "defaults"}  # always include these

        # Find sections matching keywords
        for section_name in spec:
            section_lower = section_name.lower().replace("_", " ")
            for kw in keywords:
                kw_lower = kw.lower()
                if (kw_lower in section_lower
                        or section_lower in kw_lower
                        or difflib.SequenceMatcher(
                            None, kw_lower, section_lower
                        ).ratio() > 0.6):
                    relevant_keys.add(section_name)

        # Build YAML output with only relevant sections
        lines = []
        for key in spec:
            if key in relevant_keys:
                lines.append(yaml.dump(
                    {key: spec[key]},
                    default_flow_style=False,
                    sort_keys=False,
                ))

        return "\n".join(lines)

    # ── Templates ───────────────────────────────────────────────────────

    def get_templates(self, service_type: str) -> list[dict]:
        """Return config templates for a service type."""
        return self._templates_cache.get(service_type, [])

    # ── Introspection ───────────────────────────────────────────────────

    def get_entries_for_service(self, service_type: str) -> list[FeatureEntry]:
        """Return all indexed features for a service type."""
        return self._by_service.get(service_type, [])

    @property
    def total_entries(self) -> int:
        return len(self._entries)

    @property
    def indexed_service_types(self) -> list[str]:
        return sorted(self._by_service.keys())
