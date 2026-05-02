"""Registry of config keys supported by each HCL renderer.

The chat agent MUST NOT suggest config keys absent from this registry,
because the renderer would silently ignore them. Every entry here
corresponds to a cfg.get() call in hcl_renderer.py.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class ConfigKeyInfo:
    """Metadata for a single renderer-supported config key."""
    key: str
    type: type
    default: Any
    description: str
    allowed_values: list | None = None
    min_value: Any | None = None
    max_value: Any | None = None


# ── Registry: one list per service type ─────────────────────────────────────
# Extracted from cfg.get() calls in engine/hcl_renderer.py.

SUPPORTED_CONFIG: dict[str, list[ConfigKeyInfo]] = {
    "s3": [
        ConfigKeyInfo("versioning_status", str, "Suspended",
                      "Bucket versioning state",
                      allowed_values=["Enabled", "Suspended"]),
        ConfigKeyInfo("prefixes", list, [],
                      "List of S3 prefix paths to create as folder objects"),
    ],
    "lambda": [
        ConfigKeyInfo("runtime", str, "python3.12",
                      "Lambda runtime environment",
                      allowed_values=[
                          "python3.12", "python3.11", "python3.10", "python3.9",
                          "nodejs20.x", "nodejs18.x",
                          "java21", "java17", "java11",
                          "dotnet8", "dotnet6",
                          "ruby3.3", "ruby3.2",
                          "provided.al2023", "provided.al2",
                      ]),
        ConfigKeyInfo("handler", str, "index.handler",
                      "Function handler path (e.g. index.handler)"),
        ConfigKeyInfo("memory_size", int, 128,
                      "Memory in MB",
                      min_value=128, max_value=10240),
        ConfigKeyInfo("timeout", int, 30,
                      "Timeout in seconds",
                      min_value=1, max_value=900),
        ConfigKeyInfo("handler_code", str, "",
                      "Inline Python handler code (replaces default placeholder)"),
    ],
    "sqs": [
        ConfigKeyInfo("visibility_timeout_seconds", int, 30,
                      "Visibility timeout in seconds",
                      min_value=0, max_value=43200),
        ConfigKeyInfo("message_retention_seconds", int, 86400,
                      "Message retention in seconds",
                      min_value=60, max_value=1209600),
    ],
    "dynamodb": [
        ConfigKeyInfo("billing_mode", str, "PROVISIONED",
                      "Capacity billing mode",
                      allowed_values=["PROVISIONED", "PAY_PER_REQUEST"]),
        ConfigKeyInfo("hash_key", str, "id",
                      "Partition key attribute name"),
        ConfigKeyInfo("hash_key_type", str, "S",
                      "Partition key type",
                      allowed_values=["S", "N", "B"]),
        ConfigKeyInfo("read_capacity", int, 5,
                      "Provisioned read capacity units (RCU)",
                      min_value=1, max_value=40000),
        ConfigKeyInfo("write_capacity", int, 5,
                      "Provisioned write capacity units (WCU)",
                      min_value=1, max_value=40000),
    ],
    "stepfunctions": [
        ConfigKeyInfo("type", str, "STANDARD",
                      "State machine type",
                      allowed_values=["STANDARD", "EXPRESS"]),
    ],
    "cloudwatch": [
        ConfigKeyInfo("schedule_expression", str, "rate(5 minutes)",
                      "CloudWatch event schedule (cron or rate expression)"),
    ],
    "kinesis_streams": [
        ConfigKeyInfo("stream_mode", str, "ON_DEMAND",
                      "Capacity mode",
                      allowed_values=["ON_DEMAND", "PROVISIONED"]),
        ConfigKeyInfo("shard_count", int, 1,
                      "Number of shards (only when PROVISIONED)",
                      min_value=1, max_value=10000),
        ConfigKeyInfo("retention_period", int, 24,
                      "Data retention in hours",
                      min_value=24, max_value=8760),
    ],
    "eventbridge": [
        ConfigKeyInfo("schedule_expression", str, "",
                      "EventBridge schedule (cron or rate expression)"),
        ConfigKeyInfo("event_pattern", str, "",
                      "EventBridge event pattern (JSON string)"),
    ],
    "ec2": [
        ConfigKeyInfo("instance_type", str, "t3.micro",
                      "EC2 instance type",
                      allowed_values=[
                          "t2.micro", "t2.small", "t2.medium",
                          "t3.micro", "t3.small", "t3.medium", "t3.large",
                          "m5.large", "m5.xlarge", "m5.2xlarge",
                          "c5.large", "c5.xlarge",
                      ]),
    ],
    "kinesis_firehose": [
        ConfigKeyInfo("buffering_size", int, 128,
                      "Buffer size in MB",
                      min_value=1, max_value=128),
        ConfigKeyInfo("buffering_interval", int, 300,
                      "Buffer interval in seconds",
                      min_value=0, max_value=900),
        ConfigKeyInfo("compression_format", str, "GZIP",
                      "Compression format for delivered files",
                      allowed_values=["GZIP", "ZIP", "Snappy", "HADOOP_SNAPPY", "UNCOMPRESSED"]),
    ],
    "kinesis_analytics": [
        ConfigKeyInfo("runtime_environment", str, "SQL-1_0",
                      "Analytics application runtime",
                      allowed_values=["SQL-1_0", "FLINK-1_6", "FLINK-1_8",
                                      "FLINK-1_11", "FLINK-1_13", "FLINK-1_15",
                                      "FLINK-1_18", "FLINK-1_19"]),
    ],
    "msk": [
        ConfigKeyInfo("kafka_version", str, "3.5.1",
                      "Apache Kafka version"),
        ConfigKeyInfo("number_of_broker_nodes", int, 3,
                      "Number of broker nodes",
                      min_value=1, max_value=30),
        ConfigKeyInfo("broker_instance_type", str, "kafka.m5.large",
                      "Broker instance type",
                      allowed_values=[
                          "kafka.t3.small", "kafka.m5.large", "kafka.m5.xlarge",
                          "kafka.m5.2xlarge", "kafka.m5.4xlarge",
                      ]),
        ConfigKeyInfo("volume_size", int, 100,
                      "EBS volume size in GB per broker",
                      min_value=1, max_value=16384),
    ],
    "dms": [
        ConfigKeyInfo("replication_instance_class", str, "dms.t3.medium",
                      "DMS replication instance class",
                      allowed_values=[
                          "dms.t2.micro", "dms.t2.small", "dms.t2.medium", "dms.t2.large",
                          "dms.t3.micro", "dms.t3.small", "dms.t3.medium", "dms.t3.large",
                          "dms.r5.large", "dms.r5.xlarge",
                      ]),
        ConfigKeyInfo("allocated_storage", int, 50,
                      "Storage in GB",
                      min_value=5, max_value=6144),
    ],
    "redshift": [
        ConfigKeyInfo("node_type", str, "dc2.large",
                      "Redshift node type",
                      allowed_values=["dc2.large", "dc2.8xlarge", "ra3.xlplus",
                                      "ra3.4xlarge", "ra3.16xlarge"]),
        ConfigKeyInfo("number_of_nodes", int, 1,
                      "Number of nodes in the cluster",
                      min_value=1, max_value=128),
        ConfigKeyInfo("database_name", str, "dev",
                      "Default database name"),
        ConfigKeyInfo("master_username", str, "admin",
                      "Master username"),
    ],
    "aurora": [
        ConfigKeyInfo("engine", str, "aurora-postgresql",
                      "Aurora engine type",
                      allowed_values=["aurora-postgresql", "aurora-mysql"]),
        ConfigKeyInfo("engine_version", str, "15.4",
                      "Engine version"),
        ConfigKeyInfo("database_name", str, "appdb",
                      "Default database name"),
        ConfigKeyInfo("master_username", str, "admin",
                      "Master username"),
        ConfigKeyInfo("min_capacity", float, 0.5,
                      "Minimum Aurora Serverless v2 ACU",
                      min_value=0.5, max_value=128),
        ConfigKeyInfo("max_capacity", float, 8,
                      "Maximum Aurora Serverless v2 ACU",
                      min_value=0.5, max_value=128),
    ],
    "emr": [
        ConfigKeyInfo("release_label", str, "emr-6.15.0",
                      "EMR release label"),
        ConfigKeyInfo("master_instance_type", str, "m5.xlarge",
                      "Master node instance type"),
        ConfigKeyInfo("core_instance_type", str, "m5.xlarge",
                      "Core node instance type"),
        ConfigKeyInfo("core_instance_count", int, 2,
                      "Number of core nodes",
                      min_value=1, max_value=256),
        ConfigKeyInfo("applications", list, ["Spark", "Hive"],
                      "Applications to install",
                      allowed_values=["Spark", "Hive", "HBase", "Presto", "Flink",
                                      "Pig", "Tez", "Ganglia", "Zeppelin", "Livy"]),
    ],
    "emr_serverless": [
        ConfigKeyInfo("release_label", str, "emr-6.15.0",
                      "EMR release label"),
        ConfigKeyInfo("type", str, "SPARK",
                      "Application type",
                      allowed_values=["SPARK", "HIVE"]),
        ConfigKeyInfo("architecture", str, "X86_64",
                      "CPU architecture",
                      allowed_values=["X86_64", "ARM64"]),
        ConfigKeyInfo("idle_timeout_minutes", int, 15,
                      "Auto-stop idle timeout in minutes",
                      min_value=1, max_value=10080),
        ConfigKeyInfo("initial_capacity_driver_cpu", str, "1vCPU",
                      "Driver initial CPU"),
        ConfigKeyInfo("initial_capacity_driver_memory", str, "2gb",
                      "Driver initial memory"),
        ConfigKeyInfo("initial_capacity_executor_cpu", str, "1vCPU",
                      "Executor initial CPU"),
        ConfigKeyInfo("initial_capacity_executor_memory", str, "2gb",
                      "Executor initial memory"),
        ConfigKeyInfo("initial_capacity_executor_count", int, 1,
                      "Initial executor count",
                      min_value=1, max_value=100),
        ConfigKeyInfo("max_cpu", str, "4vCPU",
                      "Maximum total CPU"),
        ConfigKeyInfo("max_memory", str, "8gb",
                      "Maximum total memory"),
        ConfigKeyInfo("max_disk", str, "20gb",
                      "Maximum total disk"),
    ],
    "sagemaker": [
        ConfigKeyInfo("instance_type", str, "ml.t2.medium",
                      "Endpoint instance type",
                      allowed_values=[
                          "ml.t2.medium", "ml.t2.large", "ml.t2.xlarge",
                          "ml.m5.large", "ml.m5.xlarge", "ml.m5.2xlarge",
                          "ml.c5.large", "ml.c5.xlarge",
                          "ml.g4dn.xlarge", "ml.p3.2xlarge",
                      ]),
        ConfigKeyInfo("initial_instance_count", int, 1,
                      "Number of endpoint instances",
                      min_value=1, max_value=20),
        ConfigKeyInfo("container_image", str, "",
                      "Custom container image URI (overrides framework)"),
        ConfigKeyInfo("framework", str, "sagemaker-scikit-learn",
                      "ML framework for pre-built image",
                      allowed_values=[
                          "sagemaker-scikit-learn", "pytorch-inference",
                          "tensorflow-inference", "huggingface-pytorch-inference",
                          "xgboost", "mxnet-inference",
                      ]),
        ConfigKeyInfo("image_tag", str, "1.2-1-cpu-py3",
                      "Pre-built image tag"),
        ConfigKeyInfo("model_data_url", str, "s3://placeholder-model-bucket/model.tar.gz",
                      "S3 path to model artifacts"),
    ],
    "sagemaker_notebook": [
        ConfigKeyInfo("instance_type", str, "ml.t2.medium",
                      "Notebook instance type",
                      allowed_values=[
                          "ml.t2.medium", "ml.t2.large", "ml.t2.xlarge",
                          "ml.t3.medium", "ml.t3.large", "ml.t3.xlarge",
                          "ml.m5.large", "ml.m5.xlarge",
                      ]),
        ConfigKeyInfo("volume_size", int, 5,
                      "EBS volume size in GB",
                      min_value=5, max_value=16384),
        ConfigKeyInfo("direct_internet_access", str, "Enabled",
                      "Direct internet access",
                      allowed_values=["Enabled", "Disabled"]),
    ],
    "quicksight": [
        ConfigKeyInfo("type", str, "ATHENA",
                      "Data source type",
                      allowed_values=["ATHENA", "S3", "REDSHIFT", "AURORA"]),
        ConfigKeyInfo("work_group", str, "primary",
                      "Athena workgroup name"),
    ],
    "glue_data_catalog": [
        ConfigKeyInfo("description", str, "Glue Data Catalog database",
                      "Catalog database description"),
        ConfigKeyInfo("tables", list, [],
                      "List of table definitions (name, location, columns, partition_keys)"),
    ],
    "iam": [
        ConfigKeyInfo("path", str, "/",
                      "IAM role path"),
        ConfigKeyInfo("max_session_duration", int, 3600,
                      "Max session duration in seconds",
                      min_value=3600, max_value=43200),
    ],
    # Services with no user-configurable keys
    "sns": [],
    "glue": [],
    "glue_databrew": [],
    "athena": [
        ConfigKeyInfo("named_queries", list, [],
                      "List of named query definitions (name, database, query)"),
    ],
    "lake_formation": [],
}


def get_supported_keys(service_type: str) -> list[ConfigKeyInfo]:
    """Return config keys the renderer for this type actually handles."""
    return SUPPORTED_CONFIG.get(service_type, [])


def get_supported_key_names(service_type: str) -> set[str]:
    """Return just the key names as a set for quick lookup."""
    return {k.key for k in get_supported_keys(service_type)}


def validate_config_patch(
    service_type: str, patch: dict[str, Any]
) -> tuple[dict[str, Any], list[str]]:
    """Validate a config patch against the registry.

    Returns (clean_patch, warnings).  Unknown keys are stripped with a warning.
    Type coercion and range checks are applied.
    """
    supported = {k.key: k for k in get_supported_keys(service_type)}
    clean: dict[str, Any] = {}
    warnings: list[str] = []

    for key, value in patch.items():
        info = supported.get(key)
        if info is None:
            warnings.append(
                f"'{key}' is not supported by the {service_type} renderer "
                f"and will be ignored"
            )
            continue

        # Type coercion
        try:
            if info.type is int and not isinstance(value, int):
                value = int(value)
            elif info.type is float and not isinstance(value, (int, float)):
                value = float(value)
            elif info.type is str and not isinstance(value, str):
                value = str(value)
            elif info.type is list and isinstance(value, str):
                value = [v.strip() for v in value.split(",")]
        except (ValueError, TypeError):
            warnings.append(
                f"'{key}' value '{value}' cannot be converted to {info.type.__name__}"
            )
            continue

        # Allowed values check
        if info.allowed_values is not None:
            if info.type is list:
                invalid = [v for v in value if v not in info.allowed_values]
                if invalid:
                    warnings.append(
                        f"'{key}' contains invalid values: {invalid}. "
                        f"Allowed: {info.allowed_values}"
                    )
                    continue
            elif value not in info.allowed_values:
                warnings.append(
                    f"'{key}' value '{value}' is not allowed. "
                    f"Options: {info.allowed_values}"
                )
                continue

        # Range check
        if info.min_value is not None and value < info.min_value:
            warnings.append(
                f"'{key}' value {value} is below minimum {info.min_value}"
            )
            continue
        if info.max_value is not None and value > info.max_value:
            warnings.append(
                f"'{key}' value {value} exceeds maximum {info.max_value}"
            )
            continue

        clean[key] = value

    return clean, warnings
