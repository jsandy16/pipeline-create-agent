"""LLM-backed config resolver for Tier 1 (Haiku) and Tier 2 (Sonnet).

Used as fallback when the Tier 0 keyword matcher in spec_index.py
cannot resolve the user's request with sufficient confidence.

Tier 1: Haiku for single-feature, single-service requests (~$0.0002/call)
Tier 2: Sonnet for complex/multi-feature requests (~$0.003/call)
"""
from __future__ import annotations

import json
import logging
import os
from pathlib import Path
from typing import Any

from engine.config_registry import (
    ConfigKeyInfo,
    get_supported_keys,
    validate_config_patch,
)
from engine.spec_index import ConfigResolution

logger = logging.getLogger(__name__)

_SPECS_NEW_DIR = Path(__file__).resolve().parent.parent / "specs_new"

# ── System prompts ──────────────────────────────────────────────────────────

TIER1_SYSTEM_PROMPT = """\
You are a config resolver for AWS infrastructure. Your job is to translate
a user's natural-language request into a JSON config patch.

RULES:
1. You can ONLY use config keys from the SUPPORTED KEYS list below.
2. Return ONLY valid JSON: {"config_key": value, ...}
3. Do NOT suggest keys outside the supported list.
4. Do NOT add explanations — return ONLY the JSON object.
5. If the request cannot be mapped to any supported key, return: {"_error": "explanation"}
6. Values must match the expected type and constraints for each key.
"""

TIER2_SYSTEM_PROMPT = """\
You are an infrastructure customization agent for an AWS pipeline engine.
Users describe what they want in natural language, and you resolve it to
a JSON config patch that the deterministic engine will use to render Terraform.

RULES:
1. You can ONLY use config keys from the SUPPORTED KEYS list.
2. Return a JSON object with this structure:
   {
     "config_patch": {"key": value, ...},
     "explanation": "Brief explanation of what this changes",
     "cost_warning": "Warning if this increases cost, or null"
   }
3. Do NOT suggest keys outside the supported list. If the user asks for a
   feature that isn't supported, explain what IS available.
4. If multiple config keys need to change, include all of them.
5. Consider cost implications — warn if moving away from free tier.
"""


class ConfigAgent:
    """LLM-backed config resolver for Tier 1 (Haiku) and Tier 2 (Sonnet)."""

    HAIKU_MODEL = "claude-haiku-4-5-20251001"
    SONNET_MODEL = "claude-sonnet-4-5-20241022"

    def __init__(self, api_key: str | None = None):
        import anthropic
        key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        if not key:
            raise RuntimeError("ANTHROPIC_API_KEY required for ConfigAgent")
        self._client = anthropic.Anthropic(api_key=key)

    def _call_llm(self, model: str, system: str, messages: list[dict],
                  max_tokens: int = 1024) -> str:
        """Make an LLM call and return the raw text response."""
        resp = self._client.messages.create(
            model=model,
            max_tokens=max_tokens,
            system=system,
            messages=messages,
        )
        return "".join(
            b.text for b in resp.content
            if getattr(b, "type", None) == "text"
        ).strip()

    def _format_supported_keys(self, service_type: str) -> str:
        """Format supported keys as context for the LLM."""
        keys = get_supported_keys(service_type)
        if not keys:
            return f"No configurable keys for {service_type}."

        lines = [f"SUPPORTED KEYS for {service_type}:"]
        for k in keys:
            line = f"  - {k.key} ({k.type.__name__}): {k.description}"
            if k.default is not None:
                line += f" [default: {k.default}]"
            if k.allowed_values:
                line += f" [allowed: {k.allowed_values}]"
            if k.min_value is not None:
                line += f" [min: {k.min_value}]"
            if k.max_value is not None:
                line += f" [max: {k.max_value}]"
            lines.append(line)
        return "\n".join(lines)

    def resolve_tier1(
        self,
        message: str,
        service_type: str,
        service_name: str,
        spec_section: str,
        current_config: dict,
    ) -> ConfigResolution:
        """Single-feature resolution via Haiku. ~$0.0002 per call.

        Args:
            message: User's request.
            service_type: AWS service type.
            service_name: Pipeline service name.
            spec_section: Relevant YAML section (50-200 lines, NOT full spec).
            current_config: Current service config.
        """
        supported_keys_text = self._format_supported_keys(service_type)

        user_content = (
            f"{supported_keys_text}\n\n"
            f"CURRENT CONFIG: {json.dumps(current_config)}\n\n"
            f"RELEVANT SPEC SECTION:\n{spec_section}\n\n"
            f"USER REQUEST: {message}"
        )

        logger.info("[ConfigAgent] Tier 1 (Haiku) for %s/%s: %s",
                     service_type, service_name, message[:100])

        try:
            raw = self._call_llm(
                self.HAIKU_MODEL,
                TIER1_SYSTEM_PROMPT,
                [{"role": "user", "content": user_content}],
                max_tokens=512,
            )
            patch = self._parse_json(raw)

            if "_error" in patch:
                return ConfigResolution(
                    tier=1,
                    service_name=service_name,
                    config_patch={},
                    confidence=0.0,
                    explanation=patch["_error"],
                    warnings=[patch["_error"]],
                )

            clean_patch, warnings = validate_config_patch(service_type, patch)

            return ConfigResolution(
                tier=1,
                service_name=service_name,
                config_patch=clean_patch,
                confidence=0.8,
                explanation=self._build_explanation(clean_patch, service_name),
                warnings=warnings,
            )

        except Exception as e:
            logger.error("[ConfigAgent] Tier 1 error: %s", e)
            return ConfigResolution(
                tier=1,
                service_name=service_name,
                config_patch={},
                confidence=0.0,
                explanation=f"LLM resolution failed: {e}",
                warnings=[str(e)],
            )

    def resolve_tier2(
        self,
        message: str,
        service_type: str,
        service_name: str,
        spec_sections: str,
        kb_content: str,
        current_config: dict,
        conversation_history: list[dict] | None = None,
    ) -> ConfigResolution:
        """Complex/multi-feature resolution via Sonnet. ~$0.003 per call.

        Args:
            message: User's request.
            service_type: AWS service type.
            service_name: Pipeline service name.
            spec_sections: Multiple relevant YAML sections.
            kb_content: Plain-English knowledge from *_spec_kb.md.
            current_config: Current service config.
            conversation_history: Prior messages for multi-turn.
        """
        supported_keys_text = self._format_supported_keys(service_type)

        user_content = (
            f"{supported_keys_text}\n\n"
            f"CURRENT CONFIG: {json.dumps(current_config)}\n\n"
            f"SPEC SECTIONS:\n{spec_sections}\n\n"
            f"KNOWLEDGE BASE:\n{kb_content[:3000]}\n\n"  # cap KB size
            f"USER REQUEST: {message}"
        )

        messages = []
        if conversation_history:
            messages.extend(conversation_history)
        messages.append({"role": "user", "content": user_content})

        logger.info("[ConfigAgent] Tier 2 (Sonnet) for %s/%s: %s",
                     service_type, service_name, message[:100])

        try:
            raw = self._call_llm(
                self.SONNET_MODEL,
                TIER2_SYSTEM_PROMPT,
                messages,
                max_tokens=1024,
            )
            result = self._parse_json(raw)

            patch = result.get("config_patch", result)
            # If result is flat (no config_patch key), treat it as the patch
            if "config_patch" not in result and "_error" not in result:
                patch = result

            if "_error" in result:
                return ConfigResolution(
                    tier=2,
                    service_name=service_name,
                    config_patch={},
                    confidence=0.0,
                    explanation=result["_error"],
                    warnings=[result["_error"]],
                )

            clean_patch, warnings = validate_config_patch(service_type, patch)
            explanation = result.get(
                "explanation",
                self._build_explanation(clean_patch, service_name),
            )
            cost_warning = result.get("cost_warning")

            return ConfigResolution(
                tier=2,
                service_name=service_name,
                config_patch=clean_patch,
                confidence=0.85,
                explanation=explanation,
                warnings=warnings,
                cost_warning=cost_warning,
            )

        except Exception as e:
            logger.error("[ConfigAgent] Tier 2 error: %s", e)
            return ConfigResolution(
                tier=2,
                service_name=service_name,
                config_patch={},
                confidence=0.0,
                explanation=f"LLM resolution failed: {e}",
                warnings=[str(e)],
            )

    # ── Helpers ──────────────────────────────────────────────────────────

    def _parse_json(self, raw: str) -> dict:
        """Extract JSON from LLM response, handling markdown fences."""
        text = raw.strip()
        if text.startswith("```"):
            lines = text.split("\n")
            lines = [l for l in lines if not l.strip().startswith("```")]
            text = "\n".join(lines).strip()
        return json.loads(text)

    def _build_explanation(self, patch: dict, service_name: str) -> str:
        if not patch:
            return "No config changes could be determined."
        changes = [f"{k} = {v}" for k, v in patch.items()]
        return f"Set {', '.join(changes)} on {service_name}"


def load_kb_content(service_type: str) -> str:
    """Load the knowledge base markdown for a service type."""
    kb_path = _SPECS_NEW_DIR / f"{service_type}_spec_kb.md"
    if kb_path.exists():
        return kb_path.read_text()
    return ""
