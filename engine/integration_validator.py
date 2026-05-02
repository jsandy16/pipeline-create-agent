"""Pre-render validation of integration completeness.

Checks every declared integration has:
  1. IAM rules in the source service's spec (as_source_to.<target_type>)
  2. IAM rules in the target service's spec (as_target_of.<source_type>)
     — only when the target is a principal service
  3. Known renderer wiring for the integration pattern

Runs before HCL rendering (<1ms). Fails fast with actionable errors
instead of producing broken HCL that fails at terraform apply time.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass

from schemas import PipelineRequest, IntegrationSpec, ServiceSpec
from engine.spec_loader import load_spec

logger = logging.getLogger(__name__)


@dataclass
class IntegrationWarning:
    """A non-fatal integration coverage gap."""
    integration: str      # "source_name → target_name"
    source_type: str
    target_type: str
    message: str

    def __str__(self) -> str:
        return f"[{self.integration}] {self.message}"


# Integration pairs where renderer creates wiring resources.
# Format: (source_type, target_type) — the renderer of whichever service
# "owns" the wiring is responsible for creating the Terraform resources.
_WIRED_PATTERNS: set[tuple[str, str]] = {
    # S3 → Lambda (S3 creates notification + lambda_permission)
    ("s3", "lambda"),
    # S3 → SQS (S3 creates notification, SQS creates queue_policy)
    ("s3", "sqs"),
    # SQS → Lambda (Lambda creates event_source_mapping)
    ("sqs", "lambda"),
    # Kinesis Streams → Lambda (Lambda creates event_source_mapping)
    ("kinesis_streams", "lambda"),
    # DynamoDB → Lambda (Lambda creates event_source_mapping via streams)
    ("dynamodb", "lambda"),
    # SNS → Lambda (SNS creates subscription)
    ("sns", "lambda"),
    # SNS → SQS (SNS creates subscription)
    ("sns", "sqs"),
    # CloudWatch/EventBridge → Lambda (CW creates target + permission)
    ("cloudwatch", "lambda"),
    ("eventbridge", "lambda"),
    # CloudWatch/EventBridge → SQS (CW creates target, SQS creates policy)
    ("cloudwatch", "sqs"),
    ("eventbridge", "sqs"),
    # Lambda → Lambda (Lambda creates permission on target)
    ("lambda", "lambda"),
    # Kinesis Streams → Firehose (Firehose creates kinesis_source_configuration)
    ("kinesis_streams", "kinesis_firehose"),
    # Kinesis Streams/Firehose → Analytics (Analytics creates input config)
    ("kinesis_streams", "kinesis_analytics"),
    ("kinesis_firehose", "kinesis_analytics"),
    # Step Functions → * (SF creates state machine definition with task states)
    ("stepfunctions", "lambda"),
    ("stepfunctions", "glue"),
    ("stepfunctions", "dynamodb"),
    ("stepfunctions", "sqs"),
    ("stepfunctions", "sns"),
    ("stepfunctions", "s3"),
    ("stepfunctions", "emr_serverless"),
    ("stepfunctions", "emr"),
    ("stepfunctions", "sagemaker"),
    ("stepfunctions", "athena"),
    ("stepfunctions", "eventbridge"),
    # Glue → S3 (Glue creates crawler s3_target)
    ("glue", "s3"),
    ("s3", "glue"),
    # Firehose → S3 (Firehose creates extended_s3_configuration)
    ("kinesis_firehose", "s3"),
    # Firehose → Redshift (Firehose creates redshift_configuration)
    ("kinesis_firehose", "redshift"),
}

# Patterns where IAM is sufficient (no special Terraform wiring needed).
# The services communicate via SDK calls at runtime, not via event triggers.
_IAM_ONLY_PATTERNS: set[tuple[str, str]] = {
    # Lambda → * (Lambda calls APIs at runtime via IAM permissions)
    ("lambda", "s3"),
    ("lambda", "sqs"),
    ("lambda", "sns"),
    ("lambda", "dynamodb"),
    ("lambda", "stepfunctions"),
    ("lambda", "kinesis_streams"),
    ("lambda", "kinesis_firehose"),
    ("lambda", "redshift"),
    ("lambda", "aurora"),
    ("lambda", "sagemaker"),
    ("lambda", "eventbridge"),
    ("lambda", "athena"),
    # EC2 → * (EC2 calls APIs at runtime)
    ("ec2", "s3"),
    ("ec2", "sqs"),
    ("ec2", "dynamodb"),
    ("ec2", "sns"),
    ("ec2", "kinesis_streams"),
    ("ec2", "kinesis_firehose"),
    ("ec2", "redshift"),
    ("ec2", "aurora"),
    ("ec2", "lambda"),
    ("ec2", "stepfunctions"),
    ("ec2", "sagemaker"),
    ("ec2", "athena"),
    ("ec2", "msk"),
    # EMR / EMR Serverless → * (runtime SDK calls)
    ("emr", "s3"),
    ("emr", "dynamodb"),
    ("emr", "glue"),
    ("emr", "glue_data_catalog"),
    ("emr", "kinesis_streams"),
    ("emr", "redshift"),
    ("emr", "aurora"),
    ("emr", "msk"),
    ("emr_serverless", "s3"),
    ("emr_serverless", "glue"),
    ("emr_serverless", "glue_data_catalog"),
    ("emr_serverless", "dynamodb"),
    ("emr_serverless", "redshift"),
    ("emr_serverless", "aurora"),
    ("emr_serverless", "kinesis_streams"),
    ("emr_serverless", "msk"),
    # DMS → * (runtime replication)
    ("dms", "s3"),
    ("dms", "dynamodb"),
    ("dms", "redshift"),
    ("dms", "aurora"),
    ("dms", "kinesis_streams"),
    # SageMaker → *
    ("sagemaker", "s3"),
    ("sagemaker", "lambda"),
    ("sagemaker", "dynamodb"),
    ("sagemaker", "kinesis_streams"),
    ("sagemaker", "sns"),
    ("sagemaker", "sqs"),
    # SageMaker Notebook → *
    ("sagemaker_notebook", "s3"),
    ("sagemaker_notebook", "athena"),
    ("sagemaker_notebook", "dynamodb"),
    ("sagemaker_notebook", "redshift"),
    ("sagemaker_notebook", "aurora"),
    ("sagemaker_notebook", "glue"),
    ("sagemaker_notebook", "glue_data_catalog"),
    ("sagemaker_notebook", "sagemaker"),
    ("sagemaker_notebook", "lambda"),
    ("sagemaker_notebook", "stepfunctions"),
    # Glue DataBrew → *
    ("glue_databrew", "s3"),
    ("glue_databrew", "dynamodb"),
    ("glue_databrew", "redshift"),
    # Glue → *
    ("glue", "dynamodb"),
    ("glue", "redshift"),
    ("glue", "aurora"),
    ("glue", "kinesis_streams"),
    ("glue", "glue_data_catalog"),
    # Kinesis Analytics → *
    ("kinesis_analytics", "kinesis_streams"),
    ("kinesis_analytics", "kinesis_firehose"),
    ("kinesis_analytics", "s3"),
    ("kinesis_analytics", "lambda"),
    # Kinesis Firehose → Lambda (transformation)
    ("kinesis_firehose", "lambda"),
    # Redshift → *
    ("redshift", "s3"),
    ("redshift", "lambda"),
    # QuickSight → *
    ("quicksight", "athena"),
    ("quicksight", "s3"),
    ("quicksight", "redshift"),
    ("quicksight", "aurora"),
    ("quicksight", "glue_data_catalog"),
    # Aurora / Redshift inbound
    ("aurora", "lambda"),
    ("aurora", "s3"),
    # DMS inbound from Aurora/S3
    ("aurora", "dms"),
    ("s3", "dms"),
    # S3 inbound from various data producers
    ("s3", "glue_databrew"),
    ("s3", "sagemaker"),
    ("s3", "sagemaker_notebook"),
    ("s3", "emr"),
    ("s3", "emr_serverless"),
    ("s3", "redshift"),
}


def _find_svc(name: str, request: PipelineRequest) -> ServiceSpec | None:
    for s in request.services:
        if s.name == name:
            return s
    return None


def validate_integrations(request: PipelineRequest) -> list[IntegrationWarning]:
    """Validate all integrations in a pipeline request.

    Returns a list of warnings for integration gaps. Each warning describes
    what's missing and how to fix it.
    """
    warnings: list[IntegrationWarning] = []

    for integ in request.integrations:
        source_svc = _find_svc(integ.source, request)
        target_svc = _find_svc(integ.target, request)

        if not source_svc or not target_svc:
            continue

        pair = (source_svc.type, target_svc.type)
        integ_str = f"{integ.source} ({source_svc.type}) → {integ.target} ({target_svc.type})"

        # Check 1: Source service has IAM rules for this target type
        source_spec = load_spec(source_svc.type)
        if source_spec and source_spec.is_principal:
            if target_svc.type not in source_spec.iam_as_source_to:
                warnings.append(IntegrationWarning(
                    integration=integ_str,
                    source_type=source_svc.type,
                    target_type=target_svc.type,
                    message=(
                        f"No IAM rules in specs/{source_svc.type}.yaml for "
                        f"as_source_to.{target_svc.type}. The {source_svc.type} "
                        f"service may get AccessDenied when writing to {target_svc.type}. "
                        f"Add IAM rules to fix."
                    ),
                ))

        # Check 2: Target service has IAM rules for this source type (if principal)
        target_spec = load_spec(target_svc.type)
        if target_spec and target_spec.is_principal:
            if source_svc.type not in target_spec.iam_as_target_of:
                warnings.append(IntegrationWarning(
                    integration=integ_str,
                    source_type=source_svc.type,
                    target_type=target_svc.type,
                    message=(
                        f"No IAM rules in specs/{target_svc.type}.yaml for "
                        f"as_target_of.{source_svc.type}. The {target_svc.type} "
                        f"service may lack permissions to receive data from {source_svc.type}. "
                        f"Add IAM rules to fix."
                    ),
                ))

        # Check 3: Integration has known wiring or is IAM-only
        if pair not in _WIRED_PATTERNS and pair not in _IAM_ONLY_PATTERNS:
            warnings.append(IntegrationWarning(
                integration=integ_str,
                source_type=source_svc.type,
                target_type=target_svc.type,
                message=(
                    f"No known wiring pattern for {source_svc.type} → {target_svc.type}. "
                    f"The integration may not work at runtime. Consider adding wiring "
                    f"in _render_{source_svc.type}() or _render_{target_svc.type}() "
                    f"in engine/hcl_renderer.py."
                ),
            ))

        # Check 4: Env var wiring exists for principal sources
        if source_spec and source_spec.is_principal:
            if target_svc.type not in source_spec.env_var_as_source_to:
                # Only warn for common runtime services where env vars matter
                _env_var_important = {
                    "s3", "sqs", "sns", "dynamodb", "kinesis_streams",
                    "stepfunctions", "lambda",
                }
                if target_svc.type in _env_var_important:
                    warnings.append(IntegrationWarning(
                        integration=integ_str,
                        source_type=source_svc.type,
                        target_type=target_svc.type,
                        message=(
                            f"No env_var rule in specs/{source_svc.type}.yaml for "
                            f"as_source_to.{target_svc.type}. The {source_svc.type} "
                            f"service won't have an environment variable pointing to "
                            f"the {target_svc.type} resource. Add an env_var rule to fix."
                        ),
                    ))

    return warnings
