"""Operations Agent — generates monitoring, alerting, and scheduling configs.

Takes the monitoring/scheduling sections from RequirementsPlan plus the service
list and generates CloudWatch dashboards, alarms, EventBridge rules, and SNS
notification topics.

Uses Haiku for cost efficiency (single call).
"""
from __future__ import annotations

import json
import logging
import os
from pathlib import Path

from schemas_orchestrator import RequirementsPlan

logger = logging.getLogger(__name__)

PROMPTS_DIR = Path(__file__).resolve().parent.parent / "prompts"


def _load_prompt() -> str:
    return (PROMPTS_DIR / "operations.md").read_text()


def _strip_fences(text: str) -> str:
    s = text.strip()
    if s.startswith("```"):
        lines = s.splitlines()
        if lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip().startswith("```"):
            lines = lines[:-1]
        s = "\n".join(lines).strip()
    return s


def _build_context(plan: RequirementsPlan) -> str:
    """Build context string for operations generation."""
    parts = [
        f"## PIPELINE: {plan.pipeline_name}",
        f"Summary: {plan.summary}",
        "",
        f"## SERVICES ({len(plan.services)} total)",
    ]

    for svc in plan.services:
        parts.append(f"  - {svc.name} ({svc.type}): {svc.purpose}")

    parts.append(f"\n## INTEGRATIONS ({len(plan.integrations)} total)")
    for integ in plan.integrations:
        parts.append(f"  - {integ.source} -> {integ.target} ({integ.event})")

    if plan.scheduling:
        parts.append(f"\n## SCHEDULING")
        parts.append(f"  Expression: {plan.scheduling.schedule_expression}")
        parts.append(f"  Timezone: {plan.scheduling.timezone}")
        parts.append(f"  Description: {plan.scheduling.description}")
        if plan.scheduling.trigger_chain:
            parts.append(f"  Trigger chain: {' -> '.join(plan.scheduling.trigger_chain)}")

    if plan.monitoring:
        parts.append(f"\n## MONITORING REQUIREMENTS")
        if plan.monitoring.metrics:
            parts.append("  Metrics:")
            for m in plan.monitoring.metrics:
                parts.append(f"    - {json.dumps(m)}")
        if plan.monitoring.alarms:
            parts.append("  Alarms:")
            for a in plan.monitoring.alarms:
                parts.append(f"    - {json.dumps(a)}")
        if plan.monitoring.dashboard_widgets:
            parts.append("  Dashboard widgets:")
            for w in plan.monitoring.dashboard_widgets:
                parts.append(f"    - {json.dumps(w)}")
        if plan.monitoring.notification_topics:
            parts.append(f"  Notification topics: {plan.monitoring.notification_topics}")

    if plan.security_notes:
        parts.append(f"\n## SECURITY NOTES")
        for note in plan.security_notes:
            parts.append(f"  - {note}")

    return "\n".join(parts)


class OperationsAgent:
    """Generates monitoring, alerting, and scheduling configurations."""

    def __init__(self, api_key: str | None = None, model: str = "claude-haiku-4-5-20251001"):
        import anthropic
        key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        if not key:
            raise RuntimeError("ANTHROPIC_API_KEY not set")
        self._client = anthropic.Anthropic(api_key=key)
        self._model = model
        self._prompt = _load_prompt()

    def generate(self, plan: RequirementsPlan) -> dict[str, str]:
        """Generate all operations artifacts in a single call.

        Args:
            plan: Full requirements plan with monitoring/scheduling config.

        Returns:
            Dict mapping relative file paths to content.
        """
        context = _build_context(plan)

        logger.info(
            "[OperationsAgent] generating ops config for %d services",
            len(plan.services),
        )

        resp = self._client.messages.create(
            model=self._model,
            max_tokens=12288,
            system=[{
                "type": "text",
                "text": self._prompt,
                "cache_control": {"type": "ephemeral"},
            }],
            messages=[{"role": "user", "content": context}],
        )

        raw = "".join(
            b.text for b in resp.content if getattr(b, "type", None) == "text"
        ).strip()

        raw = _strip_fences(raw)

        try:
            data = json.loads(raw)
            files = data.get("files", {})
            notes = data.get("notes", "")
            if notes:
                logger.info("[OperationsAgent] %s", notes)

            # Ensure paths are prefixed correctly
            result = {}
            for path, content in files.items():
                if not path.startswith("operations/"):
                    path = f"operations/{path}"
                result[path] = content

            return result

        except (json.JSONDecodeError, TypeError):
            logger.warning("[OperationsAgent] response was not JSON")
            return {"operations/config.txt": raw}
