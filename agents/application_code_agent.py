"""Application Code Agent — generates Lambda handlers, Glue ETL scripts, etc.

Given an AppCodeTask from the RequirementsPlan, generates production-ready
application code that deploys alongside the Terraform infrastructure.

Uses Sonnet for code generation. One call per service.
"""
from __future__ import annotations

import json
import logging
import os
from pathlib import Path

from schemas_orchestrator import AppCodeTask, RequirementsPlan

logger = logging.getLogger(__name__)

PROMPTS_DIR = Path(__file__).resolve().parent.parent / "prompts"


def _load_prompt() -> str:
    return (PROMPTS_DIR / "application_code.md").read_text()


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


def _build_task_context(task: AppCodeTask, plan: RequirementsPlan) -> str:
    """Build context string for code generation."""
    parts = [
        f"## SERVICE CONTEXT",
        f"Service Name: {task.service_name}",
        f"Service Type: {task.service_type}",
        f"Code Type: {task.code_type}",
        f"",
        f"## TASK DESCRIPTION",
        f"{task.description}",
    ]

    if task.inputs:
        parts.append(f"\n## INPUTS")
        for inp in task.inputs:
            parts.append(f"  - {inp}")

    if task.outputs:
        parts.append(f"\n## OUTPUTS")
        for out in task.outputs:
            parts.append(f"  - {out}")

    if task.data_schema:
        parts.append(f"\n## DATA SCHEMA")
        parts.append(json.dumps(task.data_schema, indent=2))

    if task.dependencies:
        parts.append(f"\n## DEPENDENCIES (other services this code interacts with)")
        for dep in task.dependencies:
            # Find the service details from the plan
            dep_svc = next((s for s in plan.services if s.name == dep), None)
            if dep_svc:
                parts.append(f"  - {dep} ({dep_svc.type}): {dep_svc.purpose}")
            else:
                parts.append(f"  - {dep}")

    # Include S3 structure context if relevant
    if plan.s3_structure and task.service_type in ("lambda", "glue"):
        parts.append(f"\n## S3 DATA LAKE STRUCTURE")
        parts.append(json.dumps(plan.s3_structure, indent=2))

    # Include relevant data model info
    relevant_models = [
        m for m in plan.data_model_tasks
        if any(ds in task.inputs or ds in task.outputs
               for ds in m.source_datasets)
        or task.service_name in (m.entity_name, "")
    ]
    if relevant_models:
        parts.append(f"\n## RELATED DATA MODELS")
        for m in relevant_models[:5]:
            parts.append(f"  - {m.entity_name} ({m.model_type}): "
                         f"{len(m.fields)} fields, format={m.file_format}")
            if m.partitioning:
                parts.append(f"    Partitioning: {m.partitioning}")

    # Include pipeline name for resource naming
    parts.append(f"\n## PIPELINE CONTEXT")
    parts.append(f"Pipeline Name: {plan.pipeline_name}")

    # Find integrations involving this service
    relevant_integrations = [
        i for i in plan.integrations
        if i.source == task.service_name or i.target == task.service_name
    ]
    if relevant_integrations:
        parts.append(f"\n## INTEGRATIONS")
        for integ in relevant_integrations:
            direction = "outbound" if integ.source == task.service_name else "inbound"
            other = integ.target if integ.source == task.service_name else integ.source
            parts.append(f"  - {direction}: {integ.source} -> {integ.target} "
                         f"(event: {integ.event})")

    # Service config
    svc = next((s for s in plan.services if s.name == task.service_name), None)
    if svc and svc.config:
        parts.append(f"\n## SERVICE CONFIG")
        parts.append(json.dumps(svc.config, indent=2))

    return "\n".join(parts)


class ApplicationCodeAgent:
    """Generates application code for AWS services."""

    def __init__(self, api_key: str | None = None, model: str = "claude-sonnet-4-5"):
        import anthropic
        key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        if not key:
            raise RuntimeError("ANTHROPIC_API_KEY not set")
        self._client = anthropic.Anthropic(api_key=key)
        self._model = model
        self._prompt = _load_prompt()

    def generate(self, task: AppCodeTask, plan: RequirementsPlan) -> dict[str, str]:
        """Generate application code for a single task.

        Args:
            task: The code generation task.
            plan: The full requirements plan for context.

        Returns:
            Dict mapping relative file paths to code content.
        """
        context = _build_task_context(task, plan)

        logger.info(
            "[AppCodeAgent] generating %s for %s (%s)",
            task.code_type, task.service_name, task.service_type,
        )

        resp = self._client.messages.create(
            model=self._model,
            max_tokens=8192,
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
                logger.info("[AppCodeAgent] %s: %s", task.service_name, notes)
            return files
        except (json.JSONDecodeError, TypeError):
            # Fallback: treat as single file
            logger.warning(
                "[AppCodeAgent] response for %s was not JSON, treating as raw code",
                task.service_name,
            )
            ext = ".py" if task.service_type in ("lambda", "glue") else ".json"
            filename = f"{task.service_name}{ext}"
            return {filename: raw}

    def generate_all(
        self, tasks: list[AppCodeTask], plan: RequirementsPlan
    ) -> dict[str, str]:
        """Generate application code for all tasks.

        Returns:
            Dict mapping relative file paths to code content.
            Paths are prefixed with service type subdirectory.
        """
        all_files: dict[str, str] = {}

        for task in tasks:
            try:
                files = self.generate(task, plan)
                # Prefix with service type directory
                type_dir = _service_type_dir(task.service_type)
                for path, content in files.items():
                    full_path = f"app/{type_dir}/{path}"
                    all_files[full_path] = content
                    logger.info("[AppCodeAgent] generated: %s", full_path)
            except Exception as exc:
                logger.error(
                    "[AppCodeAgent] Failed to generate code for %s: %s",
                    task.service_name, exc,
                )
                all_files[f"app/{task.service_type}/{task.service_name}_ERROR.txt"] = (
                    f"Code generation failed: {exc}"
                )

        return all_files


def _service_type_dir(service_type: str) -> str:
    """Map service type to output subdirectory."""
    dirs = {
        "lambda": "lambda",
        "glue": "glue",
        "glue_databrew": "glue",
        "stepfunctions": "stepfunctions",
        "athena": "athena",
        "kinesis_analytics": "kinesis",
    }
    return dirs.get(service_type, service_type)
