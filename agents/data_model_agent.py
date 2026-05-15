"""Data Model Agent — generates Athena DDL, Glue catalog definitions, data dictionary.

Takes DataModelTask list from the RequirementsPlan and generates all data model
artifacts in a single batched LLM call (Haiku for cost efficiency).
"""
from __future__ import annotations

import json
import logging
import os
from pathlib import Path

from schemas_orchestrator import DataModelTask, RequirementsPlan

logger = logging.getLogger(__name__)

PROMPTS_DIR = Path(__file__).resolve().parent.parent / "prompts"


def _load_prompt() -> str:
    return (PROMPTS_DIR / "data_model.md").read_text()


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


def _build_context(tasks: list[DataModelTask], plan: RequirementsPlan) -> str:
    """Build context string for data model generation."""
    parts = [
        f"## PIPELINE: {plan.pipeline_name}",
        f"Summary: {plan.summary}",
        "",
        f"## DATA MODEL TASKS ({len(tasks)} tables)",
    ]

    for i, task in enumerate(tasks, 1):
        parts.append(f"\n### Table {i}: {task.entity_name}")
        parts.append(f"Type: {task.model_type}")
        parts.append(f"Database: {task.database_name}")
        parts.append(f"Format: {task.file_format}")
        if task.source_datasets:
            parts.append(f"Source datasets: {', '.join(task.source_datasets)}")
        if task.partitioning:
            parts.append(f"Partitioning: {json.dumps(task.partitioning)}")
        if task.fields:
            parts.append("Fields:")
            for field in task.fields:
                parts.append(f"  - {json.dumps(field)}")

    if plan.s3_structure:
        parts.append(f"\n## S3 STRUCTURE")
        parts.append(json.dumps(plan.s3_structure, indent=2))

    # Include any analytics queries mentioned in the requirements
    if plan.monitoring and plan.monitoring.dashboard_widgets:
        parts.append(f"\n## ANALYTICS CONTEXT")
        for widget in plan.monitoring.dashboard_widgets:
            parts.append(f"  - {widget.get('title', 'Widget')}: {widget.get('type', '')}")

    return "\n".join(parts)


class DataModelAgent:
    """Generates data model artifacts (DDL, catalog, documentation)."""

    def __init__(self, api_key: str | None = None, model: str = "claude-haiku-4-5-20251001"):
        import anthropic
        key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        if not key:
            raise RuntimeError("ANTHROPIC_API_KEY not set")
        self._client = anthropic.Anthropic(api_key=key)
        self._model = model
        self._prompt = _load_prompt()

    def generate(
        self, tasks: list[DataModelTask], plan: RequirementsPlan
    ) -> dict[str, str]:
        """Generate all data model artifacts in a single call.

        Args:
            tasks: List of data model tasks.
            plan: Full requirements plan for context.

        Returns:
            Dict mapping relative file paths to content.
        """
        if not tasks:
            logger.info("[DataModelAgent] No data model tasks, skipping")
            return {}

        context = _build_context(tasks, plan)

        logger.info(
            "[DataModelAgent] generating models for %d tables",
            len(tasks),
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
                logger.info("[DataModelAgent] %s", notes)

            # Prefix paths with data_model/ directory
            result = {}
            for path, content in files.items():
                if not path.startswith("data_model/"):
                    path = f"data_model/{path}"
                result[path] = content

            return result

        except (json.JSONDecodeError, TypeError):
            logger.warning("[DataModelAgent] response was not JSON, treating as raw SQL")
            return {"data_model/athena/create_tables.sql": raw}
