"""Orchestrator Agent — deterministic coordinator for multi-agent pipeline generation.

This is NOT an LLM agent. It is a Python orchestrator that sequences 5 phases:
  1. Requirements Analysis (RequirementsAnalyzerAgent)
  2. Infrastructure Design (PipelineBuilderAgent + Engine)
  3. Application Code Generation (ApplicationCodeAgent)
  4. Data Model Generation (DataModelAgent)
  5. Operations Configuration (OperationsAgent)

Each phase produces artifacts that are written to the output directory.
A progress_callback enables real-time WebSocket updates to the frontend.
"""
from __future__ import annotations

import json
import logging
import uuid
from pathlib import Path
from typing import Any, Callable

import yaml

from schemas import PipelineRequest, ServiceSpec, IntegrationSpec
from schemas_orchestrator import (
    OrchestrationResult,
    PhaseResult,
    RequirementsPlan,
)

logger = logging.getLogger(__name__)


class OrchestratorAgent:
    """Coordinates multiple agents to process full requirements documents."""

    def __init__(self, api_key: str, model: str = "claude-sonnet-4-5"):
        self._api_key = api_key
        self._model = model

    def orchestrate(
        self,
        requirements: str,
        orchestration_id: str | None = None,
        output_base: Path | None = None,
        progress_callback: Callable[[PhaseResult], None] | None = None,
    ) -> OrchestrationResult:
        """Run the full 5-phase orchestration pipeline.

        Args:
            requirements: Full requirements document text.
            orchestration_id: Unique ID (generated if None).
            output_base: Base output directory (default: output/).
            progress_callback: Called after each phase with PhaseResult.

        Returns:
            OrchestrationResult with all generated artifacts.
        """
        orch_id = orchestration_id or uuid.uuid4().hex
        output_base = output_base or Path("output")

        def _notify(phase_result: PhaseResult):
            if progress_callback:
                progress_callback(phase_result)

        result = OrchestrationResult(
            orchestration_id=orch_id,
            pipeline_name="",
            plan=RequirementsPlan(
                pipeline_name="pending",
                summary="",
                services=[],
                integrations=[],
            ),
            status="running",
        )

        # ── Phase 1: Requirements Analysis ──────────────────────────────
        _notify(PhaseResult(
            phase="analysis", status="running",
            message="Analyzing requirements document...",
        ))

        try:
            from agents.requirements_analyzer import RequirementsAnalyzerAgent
            analyzer = RequirementsAnalyzerAgent(
                api_key=self._api_key, model=self._model,
            )
            plan = analyzer.analyze(requirements)
            result.plan = plan
            result.pipeline_name = plan.pipeline_name

            _notify(PhaseResult(
                phase="analysis", status="completed",
                message=(
                    f"Identified {len(plan.services)} services, "
                    f"{len(plan.integrations)} integrations, "
                    f"{len(plan.app_code_tasks)} code tasks, "
                    f"{len(plan.data_model_tasks)} data models"
                ),
            ))

        except Exception as exc:
            logger.error("[Orchestrator] Phase 1 failed: %s", exc)
            _notify(PhaseResult(
                phase="analysis", status="failed",
                message=f"Requirements analysis failed: {exc}",
                errors=[str(exc)],
            ))
            result.status = "failed"
            return result

        # ── Phase 2: Infrastructure Design ──────────────────────────────
        _notify(PhaseResult(
            phase="infrastructure", status="running",
            message="Generating infrastructure (pipeline YAML + Terraform)...",
        ))

        try:
            # Convert plan to PipelineRequest for the engine
            pipeline_req = self._plan_to_pipeline_request(plan)

            # Generate diagram via PipelineBuilderAgent
            from agents.pipeline_builder_agent import PipelineBuilderAgent
            builder = PipelineBuilderAgent(
                api_key=self._api_key, model=self._model,
            )
            design_result = builder.design(requirements)
            result.diagram = design_result.get("diagram", "")

            # Use the analyzer's service/integration list (more reliable than
            # the builder's since it was parsed from structured requirements)
            # but keep the builder's diagram
            pipeline_yaml = yaml.dump(
                pipeline_req.model_dump(), allow_unicode=True,
            )
            result.pipeline_yaml = pipeline_yaml

            # Run the deterministic engine
            out_dir = output_base / plan.pipeline_name
            from engine.pipeline_builder import build_pipeline
            engine_result = build_pipeline(pipeline_req, out_dir, run_terraform=False)

            result.terraform_hcl = engine_result.main_tf

            # Save pipeline YAML
            try:
                (out_dir / "pipeline.yaml").write_text(pipeline_yaml)
            except Exception:
                pass

            _notify(PhaseResult(
                phase="infrastructure", status="completed",
                message=(
                    f"Generated Terraform HCL ({len(result.terraform_hcl)} chars) "
                    f"for {len(plan.services)} services"
                ),
                artifacts={"main.tf": result.terraform_hcl},
            ))

        except Exception as exc:
            logger.error("[Orchestrator] Phase 2 failed: %s", exc)
            _notify(PhaseResult(
                phase="infrastructure", status="failed",
                message=f"Infrastructure generation failed: {exc}",
                errors=[str(exc)],
            ))
            result.status = "failed"
            return result

        # ── Phase 3: Application Code ───────────────────────────────────
        if plan.app_code_tasks:
            _notify(PhaseResult(
                phase="application_code", status="running",
                message=f"Generating application code for {len(plan.app_code_tasks)} services...",
            ))

            try:
                from agents.application_code_agent import ApplicationCodeAgent
                app_agent = ApplicationCodeAgent(
                    api_key=self._api_key, model=self._model,
                )
                app_code = app_agent.generate_all(plan.app_code_tasks, plan)
                result.app_code = app_code

                # Write files to disk
                self._write_artifacts(out_dir, app_code)

                _notify(PhaseResult(
                    phase="application_code", status="completed",
                    message=f"Generated {len(app_code)} application code files",
                    artifacts=app_code,
                ))

            except Exception as exc:
                logger.error("[Orchestrator] Phase 3 failed: %s", exc)
                _notify(PhaseResult(
                    phase="application_code", status="failed",
                    message=f"Application code generation failed: {exc}",
                    errors=[str(exc)],
                ))
        else:
            _notify(PhaseResult(
                phase="application_code", status="completed",
                message="No application code tasks identified",
            ))

        # ── Phase 4: Data Models ────────────────────────────────────────
        if plan.data_model_tasks:
            _notify(PhaseResult(
                phase="data_models", status="running",
                message=f"Generating data models for {len(plan.data_model_tasks)} tables...",
            ))

            try:
                from agents.data_model_agent import DataModelAgent
                dm_agent = DataModelAgent(api_key=self._api_key)
                data_models = dm_agent.generate(plan.data_model_tasks, plan)
                result.data_models = data_models

                self._write_artifacts(out_dir, data_models)

                _notify(PhaseResult(
                    phase="data_models", status="completed",
                    message=f"Generated {len(data_models)} data model files",
                    artifacts=data_models,
                ))

            except Exception as exc:
                logger.error("[Orchestrator] Phase 4 failed: %s", exc)
                _notify(PhaseResult(
                    phase="data_models", status="failed",
                    message=f"Data model generation failed: {exc}",
                    errors=[str(exc)],
                ))
        else:
            _notify(PhaseResult(
                phase="data_models", status="completed",
                message="No data model tasks identified",
            ))

        # ── Phase 5: Operations ─────────────────────────────────────────
        _notify(PhaseResult(
            phase="operations", status="running",
            message="Generating monitoring, alerting, and scheduling configs...",
        ))

        try:
            from agents.operations_agent import OperationsAgent
            ops_agent = OperationsAgent(api_key=self._api_key)
            operations = ops_agent.generate(plan)
            result.operations = operations

            self._write_artifacts(out_dir, operations)

            _notify(PhaseResult(
                phase="operations", status="completed",
                message=f"Generated {len(operations)} operations files",
                artifacts=operations,
            ))

        except Exception as exc:
            logger.error("[Orchestrator] Phase 5 failed: %s", exc)
            _notify(PhaseResult(
                phase="operations", status="failed",
                message=f"Operations config generation failed: {exc}",
                errors=[str(exc)],
            ))

        result.status = "completed"
        logger.info(
            "[Orchestrator] Complete: %s — %d infra, %d app, %d model, %d ops files",
            plan.pipeline_name,
            1,  # main.tf
            len(result.app_code),
            len(result.data_models),
            len(result.operations),
        )

        return result

    def _plan_to_pipeline_request(self, plan: RequirementsPlan) -> PipelineRequest:
        """Convert a RequirementsPlan to a PipelineRequest for the engine."""
        services = [
            ServiceSpec(
                name=s.name,
                type=s.type,
                config=s.config,
            )
            for s in plan.services
        ]

        integrations = [
            IntegrationSpec(
                source=i.source,
                target=i.target,
                event=i.event,
                prefix=i.prefix,
                suffix=i.suffix,
            )
            for i in plan.integrations
        ]

        return PipelineRequest(
            pipeline_name=plan.pipeline_name,
            services=services,
            integrations=integrations,
        )

    def _write_artifacts(self, base_dir: Path, artifacts: dict[str, str]) -> None:
        """Write artifact files to disk."""
        for rel_path, content in artifacts.items():
            file_path = base_dir / rel_path
            file_path.parent.mkdir(parents=True, exist_ok=True)
            file_path.write_text(content)
            logger.debug("[Orchestrator] Wrote %s", file_path)
