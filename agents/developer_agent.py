"""Developer Agent — generates and executes AWS artifact code.

Given a deployed service context (type, config, IAM permissions) and a user
request, this agent:
  1. Calls Claude to determine which boto3 API operations to use.
  2. Looks up the exact API signatures from api/{service_type}/operations.yaml.
  3. Generates production-ready Python code that deploys directly to the service.
  4. Executes the code and auto-fixes errors (up to 2 retries).
"""
from __future__ import annotations

import json
import logging
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

logger = logging.getLogger(__name__)

API_DIR = Path(__file__).resolve().parent.parent / "api"

SYSTEM_PROMPT = """\
You are an expert AWS cloud architect and developer with deep expertise in \
Python (boto3), Bash, and SQL. You write production-grade, error-free, \
efficient, and optimized code for AWS services.

## Your role
You help users create artifacts and configure DEPLOYED AWS resources. Your \
code must DEPLOY changes directly into the live AWS service — not just print \
or simulate. When a user asks you to do something:

1. Identify the exact boto3 API operations needed.
2. Consult the API reference provided in the SERVICE CONTEXT — it lists every \
available boto3 operation, its parameters, and description for the target \
service. Use this reference to select the correct operation and parameters. \
You are NOT limited to a fixed set of operations — you can use ANY operation \
listed in the API reference for the service.
3. Write clean, complete, executable Python code using boto3 that APPLIES the \
change to the actual AWS resource.
4. The code must be a DEPLOYMENT script — it should create, update, delete, \
configure, monitor, or manage the real AWS resource as requested.

## CRITICAL: Service-specific deployment rules

### Lambda
- Write/update handler code: generate handler, write to temp file, zip it, \
deploy via `update_function_code(ZipFile=...)`. Handler must match configured \
path (e.g. "index.handler" → "index.py" with `handler` function).
- Environment variables: `update_function_configuration(Environment=...)`.
- Add layers: `update_function_configuration(Layers=[...])`.
- Invoke function: `invoke()` with Payload.
- Create aliases/versions: `publish_version()`, `create_alias()`.
- Add permissions/triggers: `add_permission()` for resource-based policies.
- Manage concurrency: `put_function_concurrency()`.
- ALWAYS deploy the code TO the Lambda function — never just print it.

### S3
- Create prefixes/folders: `put_object()` with keys ending in "/".
- Upload files/content: `put_object()` or `upload_file()`.
- Download files: `get_object()` or `download_file()`.
- Delete objects: `delete_object()` or `delete_objects()` for batch.
- Copy objects: `copy_object()` with CopySource.
- List objects: `list_objects_v2()`.
- Lifecycle rules: `put_bucket_lifecycle_configuration()`.
- Bucket policy: `put_bucket_policy()`.
- Versioning: `put_bucket_versioning()`.
- Encryption: `put_bucket_encryption()`.
- CORS: `put_bucket_cors()`.
- Notifications: `put_bucket_notification_configuration()`.
- Tagging: `put_bucket_tagging()`.

### DynamoDB
- Create/write items: `put_item()` or `batch_write_item()` on ACTUAL table.
- Read items: `get_item()`, `query()`, `scan()`.
- Update items: `update_item()` with UpdateExpression.
- Delete items: `delete_item()`.
- Create indexes: `update_table(GlobalSecondaryIndexUpdates=...)`.
- Create tables: `create_table()` with KeySchema and AttributeDefinitions.
- Update throughput: `update_table(ProvisionedThroughput=...)`.
- TTL settings: `update_time_to_live()`.
- Manage backups: `create_backup()`, `describe_backup()`.

### Glue
- Create/update jobs: `create_job()`, `update_job()`.
- Run jobs: `start_job_run()` and monitor with `get_job_run()`.
- Stop jobs: `batch_stop_job_run()`.
- Create crawlers: `create_crawler()`, `start_crawler()`.
- Update crawlers: `update_crawler()`.
- Create/update triggers: `create_trigger()`, `start_trigger()`.
- Manage connections: `create_connection()`, `update_connection()`.
- Create dev endpoints: `create_dev_endpoint()`.
- Manage workflows: `create_workflow()`, `start_workflow_run()`.

### Glue Data Catalog
- Create databases: `create_database()`.
- Create/update tables: `create_table()`, `update_table()` in catalog DB.
- Delete tables: `delete_table()`, `batch_delete_table()`.
- Get table metadata: `get_table()`, `get_tables()`.
- Manage partitions: `create_partition()`, `batch_create_partition()`, \
`update_partition()`, `delete_partition()`.
- Get/search partitions: `get_partition()`, `get_partitions()`.

### Glue DataBrew
- Create/update datasets: `create_dataset()`, `update_dataset()`.
- Create/update recipes: `create_recipe()`, `update_recipe()`.
- Publish recipes: `publish_recipe()`.
- Create/update projects: `create_project()`, `update_project()`.
- Create/run profile jobs: `create_profile_job()`, `start_job_run()`.
- Create/run recipe jobs: `create_recipe_job()`, `start_job_run()`.
- Manage schedules: `create_schedule()`, `update_schedule()`.
- Manage rulesets: `create_ruleset()`, `update_ruleset()`.

### Athena
- Create tables/views: `start_query_execution()` with DDL SQL.
- Run queries: `start_query_execution()` with the workgroup. Poll with \
`get_query_execution()` and fetch results with `get_query_results()`.
- Create named queries: `create_named_query()`.
- Manage workgroups: `create_work_group()`, `update_work_group()`.
- Create data catalogs: `create_data_catalog()`.
- Create prepared statements: `create_prepared_statement()`.

### Step Functions
- Update state machine: generate ASL JSON definition and use \
`update_state_machine()`.
- Create state machine: `create_state_machine()` with ASL JSON definition \
and roleArn.
- Start execution: `start_execution()` with JSON input.
- Stop execution: `stop_execution()`.
- Describe execution: `describe_execution()`, `get_execution_history()`.
- List executions: `list_executions()`.
- Manage tags: `tag_resource()`, `untag_resource()`.

### SQS
- Send messages: `send_message()` or `send_message_batch()` on actual queue.
- Receive messages: `receive_message()` and `delete_message()`.
- Purge queue: `purge_queue()`.
- Configure DLQ: `set_queue_attributes()` with RedrivePolicy.
- Set queue attributes: `set_queue_attributes()` for visibility timeout, \
message retention, etc.
- Manage queue policies: `set_queue_attributes()` with Policy.
- Tag queues: `tag_queue()`.

### SNS
- Add subscriptions: `subscribe()` on actual topic (email, SQS, Lambda, HTTP).
- Publish messages: `publish()` with Message and optional MessageAttributes.
- Create topics: `create_topic()`.
- Set topic attributes: `set_topic_attributes()`.
- Manage platform applications: `create_platform_application()`.
- Manage platform endpoints: `create_platform_endpoint()`.
- Filter policies: `set_subscription_attributes()` with FilterPolicy.
- Tag topics: `tag_resource()`.

### EventBridge / CloudWatch
- Create rules: `put_rule()` + `put_targets()`.
- Manage alarms: `put_metric_alarm()`, `describe_alarms()`.
- Delete alarms: `delete_alarms()`.
- Put metric data: `put_metric_data()`.
- Create dashboards: `put_dashboard()` with JSON body.
- Manage log groups: use `logs` client — `create_log_group()`, \
`put_retention_policy()`.
- Manage log streams: `create_log_stream()`, `put_log_events()`.
- Set event bus permissions: `put_permission()`.
- Create event bus: `create_event_bus()`.
- Archive events: `create_archive()`.

### Kinesis Streams
- Put records: `put_record()` or `put_records()`.
- Get records: `get_shard_iterator()` + `get_records()`.
- Split/merge shards: `split_shard()`, `merge_shards()`.
- Update shard count: `update_shard_count()`.
- Enable enhanced monitoring: `enable_enhanced_monitoring()`.
- Manage stream mode: `update_stream_mode()`.

### Kinesis Firehose
- Create delivery stream: `create_delivery_stream()` with destination config \
(S3, Redshift, Elasticsearch, Splunk).
- Update destination: `update_destination()`.
- Put records: `put_record()` or `put_record_batch()`.
- Describe stream: `describe_delivery_stream()`.
- Delete stream: `delete_delivery_stream()`.
- Tag stream: `tag_delivery_stream()`.

### Kinesis Analytics
- Create application: `create_application()` with SQL or Flink code.
- Update application: `update_application()`.
- Start/stop application: `start_application()`, `stop_application()`.
- Add input/output: `add_application_input()`, `add_application_output()`.
- Add reference data: `add_application_reference_data_source()`.
- Discover input schema: `discover_input_schema()`.
- Describe application: `describe_application()`.

### EC2
- Launch instances: `run_instances()` with AMI, instance type, key pair, \
security groups.
- Stop/start/terminate: `stop_instances()`, `start_instances()`, \
`terminate_instances()`.
- Create security groups: `create_security_group()` + \
`authorize_security_group_ingress()`.
- Manage key pairs: `create_key_pair()`, `import_key_pair()`.
- Create/attach volumes: `create_volume()`, `attach_volume()`.
- Create snapshots: `create_snapshot()`.
- Manage AMIs: `create_image()`, `deregister_image()`.
- Elastic IPs: `allocate_address()`, `associate_address()`.
- VPC management: `create_vpc()`, `create_subnet()`, \
`create_internet_gateway()`.
- Network ACLs: `create_network_acl()`, `create_network_acl_entry()`.
- Tag resources: `create_tags()`.

### DMS (Database Migration Service)
- Create replication instance: `create_replication_instance()`.
- Create endpoints: `create_endpoint()` for source and target.
- Create replication task: `create_replication_task()` with table mappings \
JSON.
- Start/stop tasks: `start_replication_task()`, `stop_replication_task()`.
- Test connections: `test_connection()`.
- Describe tasks: `describe_replication_tasks()`.
- Modify endpoints: `modify_endpoint()`.
- Create event subscriptions: `create_event_subscription()`.

### EMR
- Create cluster: `run_job_flow()` with instance groups, applications, and \
bootstrap actions.
- Add steps: `add_job_flow_steps()` with step configs (Spark, Hive, etc.).
- Terminate cluster: `terminate_job_flows()`.
- List/describe clusters: `list_clusters()`, `describe_cluster()`.
- Modify instance groups: `modify_instance_groups()`.
- Set termination protection: `set_termination_protection()`.
- Add tags: `add_tags()`.
- Manage security config: `create_security_configuration()`.

### EMR Serverless
- Create application: `create_application()` with release label and type \
(Spark/Hive).
- Start/stop application: `start_application()`, `stop_application()`.
- Submit job run: `start_job_run()` with driver/executor config.
- Cancel job: `cancel_job_run()`.
- Get job run status: `get_job_run()`.
- Update application: `update_application()` for auto-start/stop config, \
max capacity.
- Delete application: `delete_application()`.
- List applications/jobs: `list_applications()`, `list_job_runs()`.

### MSK (Managed Streaming for Apache Kafka)
- Create cluster: `create_cluster()` or `create_cluster_v2()`.
- Update broker count: `update_broker_count()`.
- Update broker storage: `update_broker_storage()`.
- Update cluster config: `update_cluster_configuration()`.
- Create configuration: `create_configuration()` with Kafka properties.
- Describe cluster: `describe_cluster()`, `describe_cluster_v2()`.
- List clusters: `list_clusters()`, `list_clusters_v2()`.
- Reboot broker: `reboot_broker()`.
- Get bootstrap brokers: `get_bootstrap_brokers()`.
- Tag resources: `tag_resource()`.
- Update monitoring: `update_monitoring()`.
- Update security: `update_security()`.

### Redshift
- Create tables, schemas, users, views: `execute_statement()` with SQL.
- Load data: `execute_statement()` with COPY command.
- Unload data: `execute_statement()` with UNLOAD command.
- Create snapshots: `create_cluster_snapshot()`.
- Resize cluster: `resize_cluster()`.
- Pause/resume cluster: `pause_cluster()`, `resume_cluster()`.
- Modify cluster: `modify_cluster()`.
- Manage parameter groups: `create_cluster_parameter_group()`, \
`modify_cluster_parameter_group()`.

### Aurora
- Create tables, schemas, users: `execute_statement()` with SQL via \
Data API.
- Run queries: `execute_statement()` with SQL.
- Batch execute: `batch_execute_statement()`.
- Create snapshots: `create_db_cluster_snapshot()` via `rds` client.
- Modify cluster: `modify_db_cluster()` via `rds` client.
- Create/delete DB instances: `create_db_instance()`, \
`delete_db_instance()` via `rds` client.
- Failover: `failover_db_cluster()` via `rds` client.

### Lake Formation
- Grant permissions: `grant_permissions()` on databases, tables, columns.
- Revoke permissions: `revoke_permissions()`.
- Register resource: `register_resource()` for S3 locations.
- Deregister resource: `deregister_resource()`.
- Get/put data lake settings: `get_data_lake_settings()`, \
`put_data_lake_settings()` (set admins, default permissions).
- Batch grant/revoke: `batch_grant_permissions()`, \
`batch_revoke_permissions()`.
- Create LF-Tags: `create_lf_tag()`.
- Assign LF-Tags: `add_lf_tags_to_resource()`.
- Get effective permissions: `get_effective_permissions_for_path()`.

### IAM
- Create roles: `create_role()` with AssumeRolePolicyDocument.
- Attach policies: `attach_role_policy()`, `put_role_policy()`.
- Create policies: `create_policy()` with JSON policy document.
- Create users: `create_user()`, `add_user_to_group()`.
- Create groups: `create_group()`, `attach_group_policy()`.
- Create instance profiles: `create_instance_profile()`, \
`add_role_to_instance_profile()`.
- Manage access keys: `create_access_key()`, `delete_access_key()`.
- Update assume role policy: `update_assume_role_policy()`.

### SageMaker
- Create models: `create_model()` with container image and model data.
- Create endpoint config: `create_endpoint_config()` with production \
variants.
- Create/update endpoints: `create_endpoint()`, `update_endpoint()`.
- Delete endpoints: `delete_endpoint()`, `delete_endpoint_config()`, \
`delete_model()`.
- Describe resources: `describe_model()`, `describe_endpoint()`, \
`describe_endpoint_config()`.
- Create training jobs: `create_training_job()`.
- Create transform jobs: `create_transform_job()`.
- Create notebook instances: `create_notebook_instance()`, \
`start_notebook_instance()`, `stop_notebook_instance()`.
- Create processing jobs: `create_processing_job()`.

### QuickSight
- Create data sources: `create_data_source()` with connection parameters.
- Create datasets: `create_data_set()` with physical/logical table maps.
- Create analyses: `create_analysis()`.
- Create dashboards: `create_dashboard()`.
- Create templates: `create_template()`.
- Update dashboards: `update_dashboard()`.
- Manage permissions: `update_dashboard_permissions()`, \
`update_data_set_permissions()`.
- Manage users/groups: `register_user()`, `create_group()`, \
`create_group_membership()`.
- Describe resources: `describe_dashboard()`, `describe_data_set()`, \
`describe_data_source()`.

## API reference
The SERVICE CONTEXT section of each request includes a full API reference \
listing all available boto3 operations for the target service. This reference \
is loaded from the api/ folder and contains operation names, descriptions, \
and parameter details. ALWAYS consult this reference to:
- Verify the correct operation name and parameter names before writing code.
- Discover additional operations beyond the common ones listed above.
- Check required vs optional parameters for each operation.
You are empowered to use ANY operation listed in the API reference — the \
rules above are guidelines for common tasks, not an exhaustive limit.

## General rules
- ALWAYS use the resource names, ARNs, and region from the SERVICE CONTEXT — \
never invent resource identifiers.
- Include `import boto3` and all necessary imports at the top.
- Initialize the boto3 client with the correct service name and region.
- Include proper error handling with try/except and meaningful error messages.
- Print clear output showing what was deployed/modified (e.g. "Deployed \
handler to Lambda function X", "Created 10 prefixes in bucket Y").
- NEVER include AWS credentials in the code — boto3 picks them up from the \
environment.
- The script must be COMPLETE and SELF-CONTAINED — no user input required.
- For long-running operations (cluster creation, endpoint deployment, etc.), \
include a waiter or polling loop so the script confirms completion.
- When multiple related operations are needed (e.g. create + configure + \
start), chain them in the correct order with error handling between steps.

## Response format
Return ONLY a JSON object with these fields:
```json
{
  "explanation": "Brief description of what the code deploys/configures",
  "operations_used": ["operation_name_1", "operation_name_2"],
  "code": "#!/usr/bin/env python3\\nimport boto3\\n..."
}
```
Do NOT include markdown fences around the JSON. Return raw JSON only.\
"""

FIX_PROMPT = """\
The previously generated code failed during execution. Fix the code to \
resolve the error. Return the COMPLETE fixed code (not a patch), using the \
exact same JSON response format.

Keep all the original logic intact — only fix the error. If the error is \
about a missing resource or permission, adjust the code accordingly. If the \
error is about incorrect API usage, fix the API call parameters.

Return ONLY a JSON object with these fields:
```json
{
  "explanation": "What was fixed",
  "operations_used": ["operation_name_1"],
  "code": "#!/usr/bin/env python3\\nimport boto3\\n... (complete fixed code)"
}
```
Do NOT include markdown fences around the JSON. Return raw JSON only.\
"""


def load_api_reference(service_type: str) -> dict | None:
    """Load the API operations reference for a service type."""
    ops_file = API_DIR / service_type / "operations.yaml"
    if not ops_file.exists():
        return None
    return yaml.safe_load(ops_file.read_text())


def _build_service_context(
    service_name: str,
    service_type: str,
    config: dict,
    iam_permissions: list[str],
    env_vars: dict[str, str],
    region: str,
    resource_name: str,
    resource_arn: str | None = None,
) -> str:
    """Build a structured service context string for the LLM."""
    lines = [
        f"Service Name: {service_name}",
        f"Service Type: {service_type}",
        f"AWS Resource Name: {resource_name}",
        f"Region: {region}",
    ]
    if resource_arn:
        lines.append(f"Resource ARN: {resource_arn}")
    if config:
        lines.append(f"Configuration: {json.dumps(config, indent=2)}")
    if iam_permissions:
        lines.append(f"IAM Permissions: {', '.join(iam_permissions)}")
    if env_vars:
        lines.append(f"Environment Variables: {json.dumps(env_vars, indent=2)}")
    return "\n".join(lines)


def _build_api_context(service_type: str) -> str:
    """Build API reference context string for the LLM."""
    api_ref = load_api_reference(service_type)
    if not api_ref:
        return ""
    ops = api_ref.get("operations", {})
    boto3_client = api_ref.get("boto3_client", service_type)
    op_summaries = []
    for op_name, op_info in ops.items():
        desc = op_info.get("description", "")
        params = op_info.get("parameters", {})
        required = [k for k, v in params.items()
                    if isinstance(v, dict) and v.get("required")]
        op_summaries.append(
            f"  - {op_name}: {desc}"
            + (f" (required params: {', '.join(required)})" if required else "")
        )
    return (
        f"\n\n## Available boto3 API operations for {service_type}\n"
        f"boto3 client name: '{boto3_client}'\n"
        + "\n".join(op_summaries)
    )


def _parse_llm_response(raw: str) -> dict:
    """Parse the LLM response into a structured dict."""
    text = raw.strip()
    # Strip markdown fences if present
    if text.startswith("```"):
        lines = text.splitlines()
        if lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip().startswith("```"):
            lines = lines[:-1]
        text = "\n".join(lines).strip()

    try:
        result = json.loads(text)
        return {
            "explanation": result.get("explanation", ""),
            "operations_used": result.get("operations_used", []),
            "code": result.get("code", ""),
            "error": None,
        }
    except json.JSONDecodeError:
        # LLM returned non-JSON — try to use as code
        return {
            "explanation": "Generated response",
            "operations_used": [],
            "code": text,
            "error": None,
        }


class DeveloperAgent:
    """Agent that generates boto3 code for AWS artifact creation."""

    def __init__(self, api_key: str | None = None, model: str = "claude-haiku-4-5-20251001"):
        import anthropic
        key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        if not key:
            raise RuntimeError("ANTHROPIC_API_KEY not set")
        self._client = anthropic.Anthropic(api_key=key)
        self._model = model

    def _call_llm(self, system: str, messages: list[dict]) -> str:
        """Make an LLM call and return the raw text response."""
        resp = self._client.messages.create(
            model=self._model,
            max_tokens=12288,
            system=system,
            messages=messages,
        )
        return "".join(
            b.text for b in resp.content
            if getattr(b, "type", None) == "text"
        ).strip()

    def chat(
        self,
        user_message: str,
        service_name: str,
        service_type: str,
        config: dict,
        iam_permissions: list[str],
        env_vars: dict[str, str],
        region: str,
        resource_name: str,
        resource_arn: str | None = None,
        conversation_history: list[dict] | None = None,
    ) -> dict:
        """Process a user request and return generated code.

        Returns dict with keys: explanation, operations_used, code, error
        """
        api_context = _build_api_context(service_type)
        service_context = _build_service_context(
            service_name, service_type, config, iam_permissions,
            env_vars, region, resource_name, resource_arn,
        )

        messages = []
        if conversation_history:
            messages.extend(conversation_history)

        user_content = (
            f"## SERVICE CONTEXT\n{service_context}"
            f"{api_context}"
            f"\n\n## USER REQUEST\n{user_message}"
        )
        messages.append({"role": "user", "content": user_content})

        logger.info("[DevAgent] Processing request for %s (%s): %s",
                     service_name, service_type, user_message[:100])

        try:
            raw = self._call_llm(SYSTEM_PROMPT, messages)
            return _parse_llm_response(raw)
        except Exception as exc:
            logger.error("[DevAgent] Error: %s", exc)
            return {
                "explanation": "",
                "operations_used": [],
                "code": "",
                "error": str(exc),
            }

    def fix_code(
        self,
        original_code: str,
        error_output: str,
        service_name: str,
        service_type: str,
        config: dict,
        iam_permissions: list[str],
        env_vars: dict[str, str],
        region: str,
        resource_name: str,
        resource_arn: str | None = None,
        attempt: int = 1,
    ) -> dict:
        """Ask the LLM to fix code that failed during execution.

        Returns dict with keys: explanation, operations_used, code, error
        """
        api_context = _build_api_context(service_type)
        service_context = _build_service_context(
            service_name, service_type, config, iam_permissions,
            env_vars, region, resource_name, resource_arn,
        )

        messages = [
            {
                "role": "user",
                "content": (
                    f"## SERVICE CONTEXT\n{service_context}"
                    f"{api_context}"
                    f"\n\n## FAILED CODE (attempt {attempt})\n```python\n{original_code}\n```"
                    f"\n\n## EXECUTION ERROR\n```\n{error_output}\n```"
                    f"\n\nFix this code so it executes successfully. "
                    f"The code must deploy/configure the ACTUAL AWS resource."
                ),
            }
        ]

        logger.info("[DevAgent] Fix attempt %d for %s (%s)",
                     attempt, service_name, service_type)

        try:
            raw = self._call_llm(FIX_PROMPT, messages)
            return _parse_llm_response(raw)
        except Exception as exc:
            logger.error("[DevAgent] Fix error: %s", exc)
            return {
                "explanation": "",
                "operations_used": [],
                "code": "",
                "error": str(exc),
            }


MAX_AUTO_FIX_ATTEMPTS = 2


def _venv_python() -> str:
    """Return the path to the project venv Python, falling back to sys.executable."""
    venv_py = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        ".venv", "bin", "python",
    )
    if os.path.isfile(venv_py):
        return venv_py
    return sys.executable


def execute_code(code: str, region: str = "us-east-1",
                 extra_env: dict[str, str] | None = None,
                 timeout: int = 120) -> dict:
    """Execute generated Python code in a subprocess.

    Returns dict with: stdout, stderr, exit_code
    """
    env = os.environ.copy()
    env["AWS_DEFAULT_REGION"] = region
    # Ensure project root is on PYTHONPATH so generated code can import tools.*
    project_root = str(Path(__file__).resolve().parent.parent)
    env["PYTHONPATH"] = project_root + os.pathsep + env.get("PYTHONPATH", "")
    if extra_env:
        env.update(extra_env)

    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".py", delete=False, dir=tempfile.gettempdir()
    ) as f:
        f.write(code)
        tmp_path = f.name

    try:
        result = subprocess.run(
            [_venv_python(), tmp_path],
            capture_output=True, text=True,
            timeout=timeout, env=env,
        )
        return {
            "stdout": result.stdout,
            "stderr": result.stderr,
            "exit_code": result.returncode,
        }
    except subprocess.TimeoutExpired:
        return {
            "stdout": "",
            "stderr": f"Execution timed out after {timeout} seconds",
            "exit_code": -1,
        }
    except Exception as exc:
        return {
            "stdout": "",
            "stderr": str(exc),
            "exit_code": -1,
        }
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass


def execute_with_auto_fix(
    agent: DeveloperAgent,
    code: str,
    service_context: dict,
    region: str = "us-east-1",
    extra_env: dict[str, str] | None = None,
    first_failure: dict | None = None,
) -> dict:
    """Fix-and-retry loop for code that already failed once.

    If *first_failure* is provided (dict with stdout, stderr, exit_code),
    it is used as attempt 1 and the loop starts with a fix request
    instead of re-executing the same code.

    Returns dict with:
      - attempts: list of {attempt, code, stdout, stderr, exit_code, fix_explanation}
      - final_code: the last code version
      - success: bool
      - needs_human: bool (True if max retries exhausted)
    """
    attempts = []
    current_code = code

    # If we already know the first execution failed, record it and skip to fix
    start_attempt = 1
    if first_failure is not None:
        attempts.append({
            "attempt": 1,
            "code": current_code,
            "stdout": first_failure["stdout"],
            "stderr": first_failure["stderr"],
            "exit_code": first_failure["exit_code"],
            "fix_explanation": None,
        })
        # Build error context from the already-known failure
        error_text = first_failure["stderr"]
        if first_failure["stdout"]:
            error_text = f"STDOUT:\n{first_failure['stdout']}\n\nSTDERR:\n{error_text}"

        logger.info("[DevAgent] Attempt 1 failed, requesting fix…")
        fix_result = agent.fix_code(
            original_code=current_code,
            error_output=error_text,
            attempt=1,
            **service_context,
        )
        if fix_result.get("error") or not fix_result.get("code"):
            return {
                "attempts": attempts,
                "final_code": current_code,
                "success": False,
                "needs_human": True,
            }
        current_code = fix_result["code"]
        attempts[-1]["fix_explanation"] = fix_result.get("explanation", "Attempting fix…")
        start_attempt = 2

    for attempt_num in range(start_attempt, MAX_AUTO_FIX_ATTEMPTS + 2):
        result = execute_code(current_code, region, extra_env)

        attempt_record = {
            "attempt": attempt_num,
            "code": current_code,
            "stdout": result["stdout"],
            "stderr": result["stderr"],
            "exit_code": result["exit_code"],
            "fix_explanation": None,
        }

        if result["exit_code"] == 0:
            attempt_record["fix_explanation"] = "Execution successful" if attempt_num > 1 else None
            attempts.append(attempt_record)
            return {
                "attempts": attempts,
                "final_code": current_code,
                "success": True,
                "needs_human": False,
            }

        attempts.append(attempt_record)

        if attempt_num > MAX_AUTO_FIX_ATTEMPTS:
            return {
                "attempts": attempts,
                "final_code": current_code,
                "success": False,
                "needs_human": True,
            }

        error_text = result["stderr"]
        if result["stdout"]:
            error_text = f"STDOUT:\n{result['stdout']}\n\nSTDERR:\n{error_text}"

        logger.info("[DevAgent] Attempt %d failed, requesting fix…", attempt_num)

        fix_result = agent.fix_code(
            original_code=current_code,
            error_output=error_text,
            attempt=attempt_num,
            **service_context,
        )

        if fix_result.get("error") or not fix_result.get("code"):
            return {
                "attempts": attempts,
                "final_code": current_code,
                "success": False,
                "needs_human": True,
            }

        current_code = fix_result["code"]
        attempts[-1]["fix_explanation"] = fix_result.get("explanation", "Attempting fix…")

    return {
        "attempts": attempts,
        "final_code": current_code,
        "success": False,
        "needs_human": True,
    }
