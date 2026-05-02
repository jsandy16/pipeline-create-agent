"""Pipeline builder — deterministic orchestrator.

Takes a PipelineRequest, builds blueprints for each service from specs,
renders HCL via golden templates, lints, consolidates, and validates.

Zero LLM calls. Runs in <1 second (excluding terraform validate).
"""
from __future__ import annotations

import logging
from dataclasses import dataclass
from pathlib import Path

from schemas import PipelineRequest, ServiceBlueprint
from engine.spec_builder import build_blueprint
from engine.hcl_renderer import render
from engine.hcl_linter import lint_hcl, LintError
from engine.config_validator import validate_blueprint, ValidationError
from engine.integration_validator import validate_integrations

logger = logging.getLogger(__name__)


# Service types whose renderers reference data.aws_subnets.default / data.aws_vpc.default
# even when vpc_required is False on the blueprint (they always need VPC infra).
_ALWAYS_NEEDS_VPC_DATA = {"msk", "dms", "aurora"}


def _shared_data_sources(
    blueprints: dict[str, ServiceBlueprint],
    fragments: dict[str, str],
) -> str:
    """Return HCL data source blocks that should be injected into the header.

    Currently handles:
      - VPC + subnets: injected when any service has vpc_required=True or is
        a type that always references VPC data sources in its renderer.
    """
    needs_vpc = any(
        bp.vpc_required or bp.service_type in _ALWAYS_NEEDS_VPC_DATA
        for bp in blueprints.values()
    )
    # Also scan rendered fragments for references we might have missed
    if not needs_vpc:
        all_hcl = "\n".join(fragments.values())
        needs_vpc = (
            "data.aws_subnets.default" in all_hcl
            or "data.aws_vpc.default" in all_hcl
        )

    parts: list[str] = []
    if needs_vpc:
        parts.append(
            '# --- Shared VPC data sources ---\n'
            'data "aws_vpc" "default" {\n'
            '  default = true\n'
            '}\n\n'
            'data "aws_subnets" "default" {\n'
            '  filter {\n'
            '    name   = "vpc-id"\n'
            '    values = [data.aws_vpc.default.id]\n'
            '  }\n'
            '}'
        )
    return "\n\n".join(parts)


_SAGEMAKER_PLACEHOLDER = Path(__file__).resolve().parent.parent / "assets" / "sagemaker_placeholder_model.tar.gz"


def _copy_sagemaker_placeholder(
    blueprints: dict[str, ServiceBlueprint],
    output_dir: Path,
) -> None:
    """Copy the placeholder model.tar.gz into the output dir when needed.

    The SageMaker renderer emits an ``aws_s3_object`` that uploads this file
    so that ``terraform apply`` succeeds without manual pre-upload.
    """
    import shutil

    needs_placeholder = any(
        bp.service_type == "sagemaker"
        and any(True for i in bp.integrations_as_target
                if _peer_type(i.source, blueprints) == "s3")
        for bp in blueprints.values()
    )
    if not needs_placeholder:
        return

    dest = output_dir / "sagemaker_placeholder_model.tar.gz"
    if _SAGEMAKER_PLACEHOLDER.exists():
        shutil.copy2(_SAGEMAKER_PLACEHOLDER, dest)
        logger.info("copied sagemaker placeholder model to %s", dest)
    else:
        logger.warning("sagemaker placeholder model not found at %s", _SAGEMAKER_PLACEHOLDER)


def _peer_type(name: str, blueprints: dict[str, ServiceBlueprint]) -> str | None:
    """Return the service_type for a peer by name, or None."""
    bp = blueprints.get(name)
    return bp.service_type if bp else None


@dataclass
class PipelineResult:
    pipeline_name: str
    main_tf: str
    main_tf_path: Path | None
    blueprints: dict[str, ServiceBlueprint]
    lint_errors: list[LintError]
    validation_errors: list[ValidationError]
    terraform_ok: bool
    terraform_message: str


def build_pipeline(
    request: PipelineRequest,
    output_dir: Path | None = None,
    run_terraform: bool = True,
) -> PipelineResult:
    """Build a complete Terraform main.tf from a pipeline request.

    Steps:
      1. Build a ServiceBlueprint per service (deterministic, from specs)
      2. Render HCL fragment per service (deterministic, golden templates)
      3. Consolidate with terraform/provider header
      4. Lint (cross-reference check, tags, duplicates)
      5. Write to disk
      6. terraform fmt + validate (if available)

    Returns a PipelineResult with the final HCL, blueprints, and status.
    """
    # 1. Build blueprints
    blueprints: dict[str, ServiceBlueprint] = {}
    for svc in request.services:
        bp = build_blueprint(svc, request)
        blueprints[svc.name] = bp
        logger.info("[%s] blueprint built: type=%s, iam=%d, env=%d",
                     svc.name, svc.type, len(bp.iam_permissions), len(bp.env_vars))

    # 1b. Validate integration completeness
    integ_warnings = validate_integrations(request)
    for w in integ_warnings:
        logger.warning("[integration] %s", w)

    # 1c. Validate configs before rendering
    all_validation_errors: list[ValidationError] = []
    for name, bp in blueprints.items():
        v_errors = validate_blueprint(bp)
        if v_errors:
            all_validation_errors.extend(v_errors)
            for ve in v_errors:
                logger.warning("[%s] config validation: %s", name, ve.message)

    # 2. Render HCL fragments
    fragments: dict[str, str] = {}
    for name, bp in blueprints.items():
        hcl = render(bp, request)
        fragments[name] = hcl
        logger.debug("[%s] rendered %d chars of HCL", name, len(hcl))

    # 3. Consolidate
    # Add random provider if any service needs generated passwords (aurora, redshift)
    _needs_random = any(
        bp.service_type in ("aurora", "redshift")
        for bp in blueprints.values()
    )
    random_provider = ""
    if _needs_random:
        random_provider = (
            '    random = {\n'
            '      source  = "hashicorp/random"\n'
            '      version = "~> 3.0"\n'
            '    }\n'
        )

    header = (
        'terraform {\n'
        '  required_version = ">= 1.5.0"\n'
        '  required_providers {\n'
        '    aws = {\n'
        '      source  = "hashicorp/aws"\n'
        '      version = "~> 5.0"\n'
        '    }\n'
        '    archive = {\n'
        '      source  = "hashicorp/archive"\n'
        '      version = "~> 2.0"\n'
        '    }\n'
        '    time = {\n'
        '      source  = "hashicorp/time"\n'
        '      version = "~> 0.9"\n'
        '    }\n'
        f'{random_provider}'
        '  }\n'
        '}\n\n'
        f'provider "aws" {{\n  region = "{request.region}"\n}}\n'
    )

    # Auto-inject shared data sources when needed by any service
    shared_data = _shared_data_sources(blueprints, fragments)
    if shared_data:
        header += "\n" + shared_data + "\n"

    body = "\n\n".join(
        f"# --- {name} ---\n{hcl.strip()}" for name, hcl in fragments.items()
    )
    full_hcl = header + "\n\n" + body + "\n"

    # 4. Lint
    lint_errors = lint_hcl(full_hcl)
    hard_errors = [e for e in lint_errors if e.severity == "error"]
    if hard_errors:
        logger.warning("lint found %d hard error(s):", len(hard_errors))
        for e in hard_errors:
            logger.warning("  %s", e.format())
    else:
        logger.info("lint: clean (%d warnings)", len(lint_errors))

    # 5. Write to disk
    tf_path = None
    if output_dir:
        output_dir.mkdir(parents=True, exist_ok=True)
        tf_path = output_dir / "main.tf"
        tf_path.write_text(full_hcl)
        logger.info("wrote %s (%d bytes)", tf_path, len(full_hcl))

        # Copy SageMaker placeholder model artifact if any SageMaker service
        # has an S3 integration (the renderer emits an aws_s3_object that
        # references this file via ${path.module}/...).
        _copy_sagemaker_placeholder(blueprints, output_dir)

    # 6. Terraform validate
    tf_ok = False
    tf_msg = "skipped"
    if run_terraform and output_dir:
        from tools.terraform_cli import terraform_available, init_and_validate
        if terraform_available():
            result = init_and_validate(full_hcl, output_dir)
            tf_ok = result.ok
            tf_msg = (result.stdout + "\n" + result.stderr).strip()
            if result.ok:
                logger.info("terraform validate: PASSED")
                # Reformat
                from tools.terraform_cli import _run
                fmt = _run(["terraform", "fmt", "-no-color"], cwd=output_dir)
                if fmt.ok:
                    full_hcl = (output_dir / "main.tf").read_text()
                    tf_path = output_dir / "main.tf"
            else:
                logger.warning("terraform validate: FAILED\n%s", tf_msg)
        else:
            tf_msg = "terraform binary not on PATH"
            logger.info("terraform not available — skipping validate")

    return PipelineResult(
        pipeline_name=request.pipeline_name,
        main_tf=full_hcl,
        main_tf_path=tf_path,
        blueprints=blueprints,
        lint_errors=lint_errors,
        validation_errors=all_validation_errors,
        terraform_ok=tf_ok,
        terraform_message=tf_msg,
    )
