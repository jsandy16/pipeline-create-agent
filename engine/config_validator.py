"""Pre-render config validation — catches AWS constraint violations before HCL generation.

Runs in <1ms per blueprint. No LLM calls. No network.

Each rule checks a specific class of misconfiguration that would pass
terraform validate but fail at terraform apply (or cause silent runtime errors).
"""
from __future__ import annotations

import re
import logging
from dataclasses import dataclass
from typing import Any

from schemas import ServiceBlueprint

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class ValidationError:
    """A config validation error detected before HCL rendering."""
    severity: str          # "error" or "warning"
    service_name: str
    rule: str              # machine-readable rule ID
    message: str           # human-readable description

    def format(self) -> str:
        return f"[{self.severity.upper()}/{self.rule}] {self.service_name}: {self.message}"


def validate_blueprint(bp: ServiceBlueprint) -> list[ValidationError]:
    """Validate a single blueprint's config against known AWS constraints.

    Returns a list of ValidationErrors (empty = clean).
    """
    errors: list[ValidationError] = []
    cfg = bp.required_configuration

    # Dispatch to type-specific validators
    validator = _VALIDATORS.get(bp.service_type)
    if validator:
        errors.extend(validator(bp, cfg))

    # Universal checks
    errors.extend(_check_universal(bp, cfg))

    return errors


# ---------------------------------------------------------------------------
# Universal checks (apply to all service types)
# ---------------------------------------------------------------------------

def _check_universal(bp: ServiceBlueprint, cfg: dict[str, Any]) -> list[ValidationError]:
    errors: list[ValidationError] = []

    # Check for empty required IAM on principal services with integrations
    if (bp.is_principal
            and not bp.iam_permissions
            and (bp.integrations_as_source or bp.integrations_as_target)):
        errors.append(ValidationError(
            "warning", bp.service_name, "NO_IAM_WITH_INTEGRATIONS",
            f"Principal service '{bp.service_type}' has integrations but no IAM "
            f"permissions were computed. Check specs/{bp.service_type}.yaml IAM rules."
        ))

    return errors


# ---------------------------------------------------------------------------
# DynamoDB
# ---------------------------------------------------------------------------

def _validate_dynamodb(bp: ServiceBlueprint, cfg: dict[str, Any]) -> list[ValidationError]:
    errors: list[ValidationError] = []
    billing = cfg.get("billing_mode", "PROVISIONED")

    if billing == "PAY_PER_REQUEST":
        if "read_capacity" in cfg or "write_capacity" in cfg:
            errors.append(ValidationError(
                "error", bp.service_name, "DYNAMO_BILLING_CONFLICT",
                "DynamoDB billing_mode=PAY_PER_REQUEST is incompatible with "
                "read_capacity/write_capacity. Remove capacity settings or use PROVISIONED."
            ))
    elif billing == "PROVISIONED":
        rcu = cfg.get("read_capacity", 5)
        wcu = cfg.get("write_capacity", 5)
        if not isinstance(rcu, (int, float)) or rcu < 1:
            errors.append(ValidationError(
                "error", bp.service_name, "DYNAMO_INVALID_RCU",
                f"read_capacity must be >= 1, got {rcu}"
            ))
        if not isinstance(wcu, (int, float)) or wcu < 1:
            errors.append(ValidationError(
                "error", bp.service_name, "DYNAMO_INVALID_WCU",
                f"write_capacity must be >= 1, got {wcu}"
            ))
    else:
        errors.append(ValidationError(
            "error", bp.service_name, "DYNAMO_INVALID_BILLING",
            f"billing_mode must be PROVISIONED or PAY_PER_REQUEST, got '{billing}'"
        ))

    return errors


# ---------------------------------------------------------------------------
# EMR Serverless
# ---------------------------------------------------------------------------

def _parse_vcpu(val: str) -> float:
    """Parse a vCPU string like '4vCPU' or '0.5vCPU' to a float."""
    m = re.match(r"(\d+(?:\.\d+)?)\s*v?cpu", str(val), re.IGNORECASE)
    return float(m.group(1)) if m else 0.0


def _parse_mem(val: str) -> float:
    """Parse a memory string like '8gb' or '2048mb' to GB."""
    m = re.match(r"(\d+(?:\.\d+)?)\s*(gb|mb)", str(val), re.IGNORECASE)
    if not m:
        return 0.0
    v = float(m.group(1))
    return v if m.group(2).lower() == "gb" else v / 1024


def _validate_emr_serverless(bp: ServiceBlueprint, cfg: dict[str, Any]) -> list[ValidationError]:
    errors: list[ValidationError] = []

    # EMR Serverless requires a one-time opt-in per account/region
    errors.append(ValidationError(
        "warning", bp.service_name, "EMR_SERVERLESS_SUBSCRIPTION_REQUIRED",
        "EMR Serverless requires a one-time account activation before terraform apply. "
        "Go to: AWS Console → EMR → EMR Serverless → Get started. "
        "Without this step, apply will fail with SubscriptionRequiredException."
    ))

    # Check initial capacity doesn't exceed maximum
    drv_cpu = _parse_vcpu(cfg.get("initial_capacity_driver_cpu", "1vCPU"))
    exc_cpu = _parse_vcpu(cfg.get("initial_capacity_executor_cpu", "1vCPU"))
    exc_count = int(cfg.get("initial_capacity_executor_count", 1))
    max_cpu = _parse_vcpu(cfg.get("max_cpu", "4vCPU"))

    total_initial_cpu = drv_cpu + (exc_cpu * exc_count)
    if max_cpu > 0 and total_initial_cpu > max_cpu:
        errors.append(ValidationError(
            "error", bp.service_name, "EMR_CAPACITY_EXCEEDS_MAX",
            f"Initial CPU capacity ({total_initial_cpu} vCPU: {drv_cpu} driver + "
            f"{exc_cpu}x{exc_count} executor) exceeds max_cpu ({max_cpu} vCPU). "
            f"Increase max_cpu or reduce initial capacity."
        ))

    drv_mem = _parse_mem(cfg.get("initial_capacity_driver_memory", "2gb"))
    exc_mem = _parse_mem(cfg.get("initial_capacity_executor_memory", "2gb"))
    max_mem = _parse_mem(cfg.get("max_memory", "8gb"))

    total_initial_mem = drv_mem + (exc_mem * exc_count)
    if max_mem > 0 and total_initial_mem > max_mem:
        errors.append(ValidationError(
            "error", bp.service_name, "EMR_MEMORY_EXCEEDS_MAX",
            f"Initial memory ({total_initial_mem}GB) exceeds max_memory ({max_mem}GB). "
            f"Increase max_memory or reduce initial capacity."
        ))

    # Check disk: AWS assigns 20GB per worker by default.
    # Total initial disk = num_workers * 20GB, must not exceed max_disk.
    num_workers = 1 + exc_count  # 1 driver + N executors
    default_disk_per_worker = 20  # AWS default
    total_initial_disk = num_workers * default_disk_per_worker
    max_disk = _parse_mem(cfg.get("max_disk", "40gb"))
    if max_disk > 0 and total_initial_disk > max_disk:
        errors.append(ValidationError(
            "error", bp.service_name, "EMR_DISK_EXCEEDS_MAX",
            f"Initial disk ({total_initial_disk}GB: {num_workers} workers x "
            f"{default_disk_per_worker}GB default) exceeds max_disk ({max_disk}GB). "
            f"Increase max_disk to at least {total_initial_disk}gb."
        ))

    # Validate release label format
    release = cfg.get("release_label", "")
    if release and not re.match(r"^emr-\d+\.\d+\.\d+$", release):
        errors.append(ValidationError(
            "warning", bp.service_name, "EMR_RELEASE_FORMAT",
            f"release_label '{release}' doesn't match expected format 'emr-X.Y.Z'"
        ))

    return errors


# ---------------------------------------------------------------------------
# Lambda
# ---------------------------------------------------------------------------

def _validate_lambda(bp: ServiceBlueprint, cfg: dict[str, Any]) -> list[ValidationError]:
    errors: list[ValidationError] = []

    memory = cfg.get("memory_size", 128)
    if isinstance(memory, (int, float)):
        if memory < 128:
            errors.append(ValidationError(
                "error", bp.service_name, "LAMBDA_MEMORY_TOO_LOW",
                f"Lambda memory_size must be >= 128 MB, got {memory}"
            ))
        if memory > 10240:
            errors.append(ValidationError(
                "error", bp.service_name, "LAMBDA_MEMORY_TOO_HIGH",
                f"Lambda memory_size must be <= 10240 MB, got {memory}"
            ))

    timeout = cfg.get("timeout", 30)
    if isinstance(timeout, (int, float)):
        if timeout < 1:
            errors.append(ValidationError(
                "error", bp.service_name, "LAMBDA_TIMEOUT_TOO_LOW",
                f"Lambda timeout must be >= 1 second, got {timeout}"
            ))
        if timeout > 900:
            errors.append(ValidationError(
                "error", bp.service_name, "LAMBDA_TIMEOUT_TOO_HIGH",
                f"Lambda timeout must be <= 900 seconds, got {timeout}"
            ))

    return errors


# ---------------------------------------------------------------------------
# Kinesis Streams
# ---------------------------------------------------------------------------

def _validate_kinesis_streams(bp: ServiceBlueprint, cfg: dict[str, Any]) -> list[ValidationError]:
    errors: list[ValidationError] = []

    mode = cfg.get("stream_mode", "ON_DEMAND")
    if mode not in ("ON_DEMAND", "PROVISIONED"):
        errors.append(ValidationError(
            "error", bp.service_name, "KINESIS_INVALID_MODE",
            f"stream_mode must be ON_DEMAND or PROVISIONED, got '{mode}'"
        ))

    retention = cfg.get("retention_period", 24)
    if isinstance(retention, (int, float)):
        if retention < 24:
            errors.append(ValidationError(
                "error", bp.service_name, "KINESIS_RETENTION_LOW",
                f"retention_period must be >= 24 hours, got {retention}"
            ))
        if retention > 8760:
            errors.append(ValidationError(
                "error", bp.service_name, "KINESIS_RETENTION_HIGH",
                f"retention_period must be <= 8760 hours (365 days), got {retention}"
            ))

    return errors


# ---------------------------------------------------------------------------
# SageMaker
# ---------------------------------------------------------------------------

_VALID_SAGEMAKER_REPOS = {
    "autogluon-training", "autogluon-inference", "blazingtext",
    "sagemaker-chainer", "sagemaker-clarify-processing", "djl-inference",
    "sagemaker-data-wrangler-container", "sagemaker-debugger-rules",
    "forecasting-deepar", "factorization-machines",
    "huggingface-tensorflow-training", "huggingface-pytorch-training",
    "huggingface-pytorch-training-neuronx", "huggingface-pytorch-trcomp-training",
    "huggingface-tensorflow-trcomp-training", "huggingface-tensorflow-inference",
    "huggingface-pytorch-inference", "huggingface-pytorch-inference-neuron",
    "huggingface-pytorch-inference-neuronx", "huggingface-pytorch-tgi-inference",
    "tei", "tei-cpu", "ipinsights", "image-classification",
    "sagemaker-neo-mxnet", "sagemaker-neo-pytorch", "kmeans", "knn", "lda",
    "linear-learner", "sagemaker-model-monitor-analyzer",
    "mxnet-training", "mxnet-inference", "mxnet-inference-eia",
    "sagemaker-rl-mxnet", "ntm", "image-classification-neo",
    "sagemaker-inference-mxnet", "sagemaker-inference-pytorch",
    "sagemaker-inference-tensorflow", "xgboost-neo", "sagemaker-tritonserver",
    "object-detection", "object2vec", "pca",
    "pytorch-training", "pytorch-training-neuronx", "pytorch-trcomp-training",
    "pytorch-inference", "pytorch-inference-eia", "pytorch-inference-graviton",
    "pytorch-inference-neuronx", "randomcutforest",
    "sagemaker-rl-ray-container", "sagemaker-rl-coach-container",
    "sagemaker-base-python", "sagemaker-geospatial-v1-0",
    "sagemaker-mxnet", "sagemaker-mxnet-serving", "sagemaker-mxnet-eia",
    "sagemaker-mxnet-serving-eia", "sagemaker-pytorch",
    "sagemaker-tensorflow", "sagemaker-tensorflow-eia",
    "sagemaker-scikit-learn", "semantic-segmentation", "seq2seq",
    "sagemaker-spark-processing", "sagemaker-sparkml-serving",
    "tensorflow-training", "tensorflow-inference", "tensorflow-inference-eia",
    "tensorflow-inference-graviton", "sagemaker-tensorflow-serving",
    "sagemaker-tensorflow-serving-eia", "sagemaker-tensorflow-scriptmode",
    "sagemaker-rl-tensorflow", "sagemaker-neo-tensorflow",
    "stabilityai-pytorch-inference", "sagemaker-rl-vw-container",
    "sagemaker-xgboost",
}


def _validate_sagemaker(bp: ServiceBlueprint, cfg: dict[str, Any]) -> list[ValidationError]:
    errors: list[ValidationError] = []

    instance_type = cfg.get("instance_type", "ml.t2.medium")
    if not instance_type.startswith("ml."):
        errors.append(ValidationError(
            "error", bp.service_name, "SAGEMAKER_INVALID_INSTANCE",
            f"SageMaker instance_type must start with 'ml.', got '{instance_type}'"
        ))

    count = cfg.get("initial_instance_count", 1)
    if isinstance(count, (int, float)) and count < 1:
        errors.append(ValidationError(
            "error", bp.service_name, "SAGEMAKER_INSTANCE_COUNT",
            f"initial_instance_count must be >= 1, got {count}"
        ))

    # Warn when using the placeholder model URL — apply will fail
    model_url = cfg.get("model_data_url", "s3://placeholder-model-bucket/model.tar.gz")
    if "placeholder" in model_url:
        errors.append(ValidationError(
            "error", bp.service_name, "SAGEMAKER_PLACEHOLDER_MODEL_URL",
            f"model_data_url is '{model_url}' — this placeholder S3 path does not exist "
            f"and terraform apply will fail with ValidationException. "
            f"Either: (1) add an S3 → {bp.service_name} integration pointing to your "
            f"model artifact bucket, or (2) set model_data_url in config to the real "
            f"s3://your-bucket/path/model.tar.gz"
        ))

    # Validate framework (ECR repository name) when no custom image
    if not cfg.get("container_image"):
        framework = cfg.get("framework", "sagemaker-scikit-learn")
        if framework not in _VALID_SAGEMAKER_REPOS:
            errors.append(ValidationError(
                "error", bp.service_name, "SAGEMAKER_INVALID_FRAMEWORK",
                f"SageMaker framework '{framework}' is not a valid ECR repository name. "
                f"Common valid values: sagemaker-scikit-learn, sagemaker-xgboost, "
                f"pytorch-inference, tensorflow-inference, huggingface-pytorch-inference"
            ))

    return errors


# ---------------------------------------------------------------------------
# Redshift
# ---------------------------------------------------------------------------

def _validate_redshift(bp: ServiceBlueprint, cfg: dict[str, Any]) -> list[ValidationError]:
    errors: list[ValidationError] = []

    num_nodes = cfg.get("number_of_nodes", 1)
    node_type = cfg.get("node_type", "dc2.large")
    if isinstance(num_nodes, int) and num_nodes > 1:
        # Multi-node requires at least 2 nodes
        if num_nodes < 2:
            errors.append(ValidationError(
                "error", bp.service_name, "REDSHIFT_NODE_COUNT",
                f"Multi-node clusters require at least 2 nodes, got {num_nodes}"
            ))

    password = cfg.get("master_password", "ChangeMe123!")
    if password and len(password) < 8:
        errors.append(ValidationError(
            "error", bp.service_name, "REDSHIFT_PASSWORD_SHORT",
            "master_password must be at least 8 characters"
        ))

    return errors


# ---------------------------------------------------------------------------
# MSK
# ---------------------------------------------------------------------------

def _validate_msk(bp: ServiceBlueprint, cfg: dict[str, Any]) -> list[ValidationError]:
    errors: list[ValidationError] = []

    broker_count = cfg.get("number_of_broker_nodes", 3)
    if isinstance(broker_count, int):
        if broker_count < 1:
            errors.append(ValidationError(
                "error", bp.service_name, "MSK_BROKER_COUNT",
                f"number_of_broker_nodes must be >= 1, got {broker_count}"
            ))
        if broker_count % 3 != 0 and broker_count != 1:
            errors.append(ValidationError(
                "warning", bp.service_name, "MSK_BROKER_AZ_MISMATCH",
                f"number_of_broker_nodes ({broker_count}) should be a multiple of 3 "
                f"for even AZ distribution"
            ))

    return errors


# ---------------------------------------------------------------------------
# QuickSight
# ---------------------------------------------------------------------------

_VALID_QS_TYPES = {
    "ATHENA", "S3", "REDSHIFT", "AURORA_POSTGRESQL", "AURORA",
    "MYSQL", "POSTGRESQL", "SQLSERVER", "MARIADB", "PRESTO",
    "SPARK", "TWITTER", "JIRA", "SERVICENOW",
}


def _validate_quicksight(bp: ServiceBlueprint, cfg: dict[str, Any]) -> list[ValidationError]:
    errors: list[ValidationError] = []

    ds_type = cfg.get("type", "ATHENA")
    if ds_type not in _VALID_QS_TYPES:
        errors.append(ValidationError(
            "error", bp.service_name, "QS_INVALID_TYPE",
            f"QuickSight data source type '{ds_type}' is not recognized. "
            f"Valid types: {sorted(_VALID_QS_TYPES)}"
        ))

    return errors


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

_VALIDATORS: dict[str, Any] = {
    "dynamodb": _validate_dynamodb,
    "emr_serverless": _validate_emr_serverless,
    "lambda": _validate_lambda,
    "kinesis_streams": _validate_kinesis_streams,
    "sagemaker": _validate_sagemaker,
    "redshift": _validate_redshift,
    "msk": _validate_msk,
    "quicksight": _validate_quicksight,
}
