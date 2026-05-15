"""Requirements Analyzer Agent — parses detailed requirements into structured plans.

Takes a comprehensive requirements document (architecture descriptions, data models,
service responsibilities, scheduling, monitoring, security, etc.) and decomposes it
into a structured RequirementsPlan that the orchestrator uses to delegate work.

Single LLM call (Sonnet). Returns structured JSON.
"""
from __future__ import annotations

import json
import logging
import os
from pathlib import Path

from schemas_orchestrator import (
    AppCodeTask,
    DataModelTask,
    IntegrationDefinition,
    MonitoringConfig,
    RequirementsPlan,
    SchedulingConfig,
    ServiceDefinition,
)

logger = logging.getLogger(__name__)

PROMPTS_DIR = Path(__file__).resolve().parent.parent / "prompts"
SPECS_DIR = Path(__file__).resolve().parent.parent / "specs"


def _load_prompt() -> str:
    return (PROMPTS_DIR / "requirements_analyzer.md").read_text()


def _get_valid_service_types() -> list[str]:
    """Get list of valid service types from specs directory."""
    return sorted(
        p.stem for p in SPECS_DIR.glob("*.yaml") if p.stem != "__pycache__"
    )


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


class RequirementsAnalyzerAgent:
    """Parses requirements documents into structured RequirementsPlan."""

    def __init__(self, api_key: str | None = None, model: str = "claude-sonnet-4-5"):
        import anthropic
        key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        if not key:
            raise RuntimeError("ANTHROPIC_API_KEY not set")
        self._client = anthropic.Anthropic(api_key=key)
        self._model = model
        self._prompt = _load_prompt()

    def analyze(self, requirements: str) -> RequirementsPlan:
        """Analyze a requirements document and return a structured plan.

        Args:
            requirements: Full requirements document text.

        Returns:
            RequirementsPlan with services, integrations, app code tasks, etc.
        """
        valid_types = _get_valid_service_types()

        user_content = (
            f"Available service types: {', '.join(valid_types)}\n\n"
            f"## REQUIREMENTS DOCUMENT\n\n{requirements}"
        )

        logger.info(
            "[RequirementsAnalyzer] analyzing requirements (%d chars)",
            len(requirements),
        )

        resp = self._client.messages.create(
            model=self._model,
            max_tokens=16384,
            system=[{
                "type": "text",
                "text": self._prompt,
                "cache_control": {"type": "ephemeral"},
            }],
            messages=[{"role": "user", "content": user_content}],
        )

        raw = "".join(
            b.text for b in resp.content if getattr(b, "type", None) == "text"
        ).strip()

        raw = _strip_fences(raw)

        try:
            data = json.loads(raw)
        except json.JSONDecodeError as exc:
            logger.error("[RequirementsAnalyzer] Failed to parse JSON: %s", exc)
            raise ValueError(f"Requirements analysis produced invalid JSON: {exc}")

        # Validate service types against available specs
        for svc in data.get("services", []):
            if svc.get("type") not in valid_types:
                logger.warning(
                    "[RequirementsAnalyzer] Unknown service type '%s', skipping",
                    svc.get("type"),
                )

        # Build and validate the plan
        plan = RequirementsPlan(
            pipeline_name=data.get("pipeline_name", "unnamed_pipeline"),
            summary=data.get("summary", ""),
            services=[
                ServiceDefinition(**s)
                for s in data.get("services", [])
                if s.get("type") in valid_types
            ],
            integrations=[
                IntegrationDefinition(**i)
                for i in data.get("integrations", [])
            ],
            app_code_tasks=[
                AppCodeTask(**t)
                for t in data.get("app_code_tasks", [])
            ],
            data_model_tasks=[
                DataModelTask(**t)
                for t in data.get("data_model_tasks", [])
            ],
            scheduling=SchedulingConfig(**data["scheduling"])
            if "scheduling" in data else SchedulingConfig(),
            monitoring=MonitoringConfig(**data["monitoring"])
            if "monitoring" in data else MonitoringConfig(),
            security_notes=data.get("security_notes", []),
            s3_structure=data.get("s3_structure", {}),
        )

        # Validate integration references
        service_names = {s.name for s in plan.services}
        valid_integrations = []
        for integ in plan.integrations:
            if integ.source in service_names and integ.target in service_names:
                valid_integrations.append(integ)
            else:
                logger.warning(
                    "[RequirementsAnalyzer] Dropping integration %s->%s: "
                    "references unknown service",
                    integ.source, integ.target,
                )
        plan.integrations = valid_integrations

        logger.info(
            "[RequirementsAnalyzer] Plan: %d services, %d integrations, "
            "%d app code tasks, %d data model tasks",
            len(plan.services), len(plan.integrations),
            len(plan.app_code_tasks), len(plan.data_model_tasks),
        )

        return plan
