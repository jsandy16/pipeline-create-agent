"""Build a ServiceBlueprint deterministically from specs + pipeline context.

Replaces the T1 Researcher (LLM) + T2 SpecValidator (LLM) with a pure
Python function that runs in <1ms. Zero LLM calls. Zero flakiness.

The blueprint contains everything the HCL renderer needs:
  - required_configuration (from spec defaults + user config hints)
  - iam_permissions (from spec IAM patterns + pipeline integrations)
  - env_vars (from spec env var patterns + pipeline integrations)
  - vpc_required (from spec vpc_triggers + peer service types)
  - tags (from pipeline metadata)
"""
from __future__ import annotations

import logging
from typing import Any

from schemas import IntegrationSpec, PipelineRequest, ServiceBlueprint, ServiceSpec
from engine.naming import resource_label, resource_name, label_for
from engine.spec_loader import load_spec, ServiceTypeSpec

logger = logging.getLogger(__name__)


def build_blueprint(
    service: ServiceSpec,
    request: PipelineRequest,
) -> ServiceBlueprint:
    """Build a complete ServiceBlueprint for one service instance.

    This is the deterministic core of the engine. It reads the spec YAML,
    merges user config hints, computes IAM from integration patterns, and
    returns a fully-populated blueprint ready for HCL rendering.
    """
    spec = load_spec(service.type)
    if spec is None:
        raise ValueError(
            f"No spec found for service type '{service.type}'. "
            f"Create specs/{service.type}.yaml to add support."
        )

    r_label = resource_label(request, service)
    r_name = resource_name(request, service)

    # Partition integrations for this service
    as_source = [i for i in request.integrations if i.source == service.name]
    as_target = [i for i in request.integrations if i.target == service.name]

    # Merge configs: spec defaults ← user hints (user wins)
    config = dict(spec.defaults)
    config.update(service.config)

    # Compute IAM permissions from integration patterns
    iam = _compute_iam(spec, as_source, as_target, request)

    # Compute environment variables from integration patterns
    env_vars = _compute_env_vars(spec, as_source, request)

    # Determine VPC requirement
    vpc_required = _needs_vpc(spec, as_source, as_target, request)
    if vpc_required and spec.is_principal:
        # Lambda/EC2 in VPC needs ENI permissions
        for perm in ["ec2:CreateNetworkInterface",
                     "ec2:DescribeNetworkInterfaces",
                     "ec2:DeleteNetworkInterface"]:
            if perm not in iam:
                iam.append(perm)

    # Tags
    tags = {
        "Pipeline": request.pipeline_name,
        "BusinessUnit": request.business_unit,
        "CostCenter": request.cost_center,
        "ManagedBy": "aws-pipeline-engine",
    }

    # Check integration completeness — warn on missing spec rules
    _check_integration_coverage(spec, service, as_source, as_target, request)

    return ServiceBlueprint(
        service_name=service.name,
        service_type=service.type,
        resource_label=r_label,
        resource_name=r_name,
        is_principal=spec.is_principal,
        required_configuration=config,
        iam_permissions=iam,
        env_vars=env_vars,
        vpc_required=vpc_required,
        integrations_as_source=as_source,
        integrations_as_target=as_target,
        tags=tags,
    )


def _compute_iam(
    spec: ServiceTypeSpec,
    as_source: list[IntegrationSpec],
    as_target: list[IntegrationSpec],
    request: PipelineRequest,
) -> list[str]:
    """Compute IAM permissions from spec patterns + actual integrations."""
    if not spec.is_principal:
        return []

    seen: set[str] = set()
    result: list[str] = []

    def _add(actions: list[str]) -> None:
        for a in actions:
            if a not in seen:
                seen.add(a)
                result.append(a)

    # Always-on permissions
    _add(spec.iam_always)

    # Permissions when this service is the TARGET of an integration
    for integ in as_target:
        source_svc = _find_svc(integ.source, request)
        if source_svc and source_svc.type in spec.iam_as_target_of:
            _add(spec.iam_as_target_of[source_svc.type])

    # Permissions when this service is the SOURCE of an integration
    for integ in as_source:
        target_svc = _find_svc(integ.target, request)
        if target_svc and target_svc.type in spec.iam_as_source_to:
            _add(spec.iam_as_source_to[target_svc.type])

    return result


def _compute_env_vars(
    spec: ServiceTypeSpec,
    as_source: list[IntegrationSpec],
    request: PipelineRequest,
) -> dict[str, str]:
    """Compute environment variables from spec patterns + actual integrations.

    env_var_as_source_to is always a dict[str, list[dict]] after spec_loader
    normalization, so each peer type can wire multiple env vars (e.g. EMR
    Serverless needs both APPLICATION_ID and EXECUTION_ROLE_ARN).
    """
    if not spec.is_principal:
        return {}

    env: dict[str, str] = {}
    for integ in as_source:
        target_svc = _find_svc(integ.target, request)
        if target_svc is None:
            continue
        rules = spec.env_var_as_source_to.get(target_svc.type)
        if not rules:
            continue
        peer_label = label_for(integ.target, target_svc.type, request)
        peer_upper = integ.target.upper()
        for rule in rules:
            var_name = rule["pattern"].replace("{PEER_UPPER}", peer_upper)
            var_ref = rule["ref"].replace("{peer_label}", peer_label)
            env[var_name] = var_ref
    return env


def _needs_vpc(
    spec: ServiceTypeSpec,
    as_source: list[IntegrationSpec],
    as_target: list[IntegrationSpec],
    request: PipelineRequest,
) -> bool:
    """Check if any connected peer requires VPC placement."""
    if not spec.vpc_triggers:
        return False
    all_peers = set()
    for i in as_source:
        peer = _find_svc(i.target, request)
        if peer:
            all_peers.add(peer.type)
    for i in as_target:
        peer = _find_svc(i.source, request)
        if peer:
            all_peers.add(peer.type)
    return bool(all_peers & set(spec.vpc_triggers))


def _find_svc(name: str, request: PipelineRequest) -> ServiceSpec | None:
    for s in request.services:
        if s.name == name:
            return s
    return None


def _check_integration_coverage(
    spec: ServiceTypeSpec,
    service: ServiceSpec,
    as_source: list[IntegrationSpec],
    as_target: list[IntegrationSpec],
    request: PipelineRequest,
) -> None:
    """Warn when integrations reference peer types with no matching spec rules.

    This catches the case where a pipeline connects two services but the spec
    doesn't define IAM rules for that integration direction — meaning the
    generated IAM policy will be incomplete and cause runtime AccessDenied.
    """
    if not spec.is_principal:
        return

    # Check outgoing integrations (this service → peer)
    for integ in as_source:
        peer = _find_svc(integ.target, request)
        if peer is None:
            continue
        if peer.type not in spec.iam_as_source_to:
            logger.warning(
                "[%s] no IAM rule in specs/%s.yaml for as_source_to.%s "
                "(integration: %s → %s). IAM permissions may be incomplete — "
                "the service may get AccessDenied at runtime when writing to %s.",
                service.name, service.type, peer.type,
                service.name, peer.name, peer.name,
            )

    # Check incoming integrations (peer → this service)
    for integ in as_target:
        peer = _find_svc(integ.source, request)
        if peer is None:
            continue
        if peer.type not in spec.iam_as_target_of:
            logger.warning(
                "[%s] no IAM rule in specs/%s.yaml for as_target_of.%s "
                "(integration: %s → %s). IAM permissions may be incomplete — "
                "the service may get AccessDenied at runtime when reading from %s.",
                service.name, service.type, peer.type,
                peer.name, service.name, peer.name,
            )
