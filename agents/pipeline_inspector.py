"""Pipeline Inspector Agent — detects and auto-fixes runtime errors in deployed pipelines.

Watches the log stream from PipelineLogStreamer for ERROR-level events, classifies
them without an LLM (regex), then makes a single LLM call to diagnose the root cause
and generate a boto3 fix. Executes the fix via the existing execute_code() infra.

Flow:
  1. Error detection (regex, <1ms) — classifies into PERMISSION, CONFIG, CODE, NETWORK, etc.
  2. Context collection — gathers recent logs, service blueprint, IAM permissions, API ref
  3. Diagnosis + fix generation (1 LLM call, ~5-10s) — returns diagnosis + executable code
  4. Fix execution — runs generated boto3 code, reports success/failure
  5. Report — pushes inspector_event messages to the WebSocket queue

No changes to engine/, specs/, or schemas.py. All fixes are live boto3 operations,
not HCL modifications (that's what autofix_agent handles at deploy time).
"""
from __future__ import annotations

import json
import logging
import os
import re
import threading
import time
import queue as stdlib_queue
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

import yaml

logger = logging.getLogger(__name__)

SPECS_DIR = Path(__file__).resolve().parent.parent / "specs"
API_DIR = Path(__file__).resolve().parent.parent / "api"


# ---------------------------------------------------------------------------
# Error classification (regex, no LLM)
# ---------------------------------------------------------------------------

_ERROR_PATTERNS: dict[str, re.Pattern] = {
    "PERMISSION": re.compile(
        r"AccessDenied|not authorized|UnauthorizedAccess|"
        r"forbidden|iam.*policy|AssumeRolePolicy|"
        r"AccessControlListNotSupported|InvalidAccessKeyId|"
        r"AuthFailure|ExpiredToken|SignatureDoesNotMatch",
        re.I,
    ),
    "RESOURCE_NOT_FOUND": re.compile(
        r"ResourceNotFoundException|NoSuchBucket|NoSuchKey|"
        r"not found|does not exist|NoSuchEntity|"
        r"EntityNotFoundException|404 Not Found|"
        r"FunctionNotFound|TableNotFoundException",
        re.I,
    ),
    "CONFIG": re.compile(
        r"ValidationException|InvalidParameterValue|"
        r"InvalidParameter|MalformedPolicyDocument|"
        r"InvalidInputException|SerializationException|"
        r"incompatible|mutually exclusive|must be between|"
        r"Parameter validation failed|Unknown parameter|"
        r"must be one of|InvalidRequestException|"
        r"InvalidConfigurationException|missing required|"
        r"could not unzip|invalid value",
        re.I,
    ),
    "NETWORK": re.compile(
        r"timeout|ConnectionRefused|NetworkError|"
        r"ECONNREFUSED|ETIMEDOUT|UnknownHostException|"
        r"SocketTimeoutException|connection reset|"
        r"EndpointConnectionError|ConnectTimeoutError",
        re.I,
    ),
    "QUOTA": re.compile(
        r"LimitExceeded|TooManyRequests|Throttling|"
        r"Rate exceeded|ServiceQuotaExceeded|"
        r"ResourceLimitExceeded|ProvisionedThroughputExceeded",
        re.I,
    ),
    "RUNTIME": re.compile(
        r"RuntimeError|OutOfMemory|MemoryError|"
        r"StackOverflow|java\.lang\.OutOfMemoryError|"
        r"Container killed|OOMKilled|"
        r"Task timed out|Lambda\.Unknown",
        re.I,
    ),
}


def classify_runtime_error(message: str) -> str:
    """Classify an error log message into a category. No LLM, regex only."""
    for category, pattern in _ERROR_PATTERNS.items():
        if pattern.search(message):
            return category
    return "UNKNOWN"


def is_error_message(message: str) -> bool:
    """Check if a log message indicates an error."""
    low = message[:120].lower()
    return any(kw in low for kw in (
        "error", "exception", "traceback", "fatal",
        "failed", "failure", "denied", "unauthorized",
    ))


# ---------------------------------------------------------------------------
# Context collection
# ---------------------------------------------------------------------------

def _load_spec(service_type: str) -> dict | None:
    """Load the service spec YAML for context."""
    spec_path = SPECS_DIR / f"{service_type}.yaml"
    if spec_path.exists():
        try:
            return yaml.safe_load(spec_path.read_text())
        except Exception:
            pass
    return None


def _load_api_ref(service_type: str) -> str:
    """Load API reference for a service type.

    Returns the operations relevant to diagnosing/fixing errors — update, put,
    modify, create, describe operations (not list/get which are less useful for fixes).
    """
    from agents.developer_agent import load_api_reference
    ref = load_api_reference(service_type)
    if not ref:
        return ""
    ops = ref.get("operations", {})
    # Prioritize operations useful for fixing: update, put, modify, create, describe
    fix_keywords = ("update", "put", "modify", "create", "add", "attach", "describe", "get_function")
    prioritized = []
    others = []
    for op_name, details in ops.items():
        desc = details.get("description", "")[:100] if isinstance(details, dict) else ""
        params = ""
        if isinstance(details, dict) and details.get("parameters"):
            param_names = [p for p in details["parameters"]][:8]
            params = f" params: {', '.join(param_names)}"
        line = f"  - {op_name}: {desc}{params}"
        if any(kw in op_name.lower() for kw in fix_keywords):
            prioritized.append(line)
        else:
            others.append(line)
    # Show all fix-relevant ops, then up to 10 others
    return "\n".join(prioritized + others[:10])


def build_error_context(
    error_logs: list[dict],
    service_name: str,
    service_type: str,
    all_recent_logs: list[dict],
    blueprint: dict | None = None,
    pipeline_services: list[dict] | None = None,
) -> str:
    """Build a structured context string for the LLM."""
    parts = []

    # Error messages (cap at 10 most recent)
    parts.append("## ERROR LOGS")
    for log in error_logs[-10:]:
        parts.append(f"  [{log.get('time','')}] {log.get('message','')}")

    # Recent logs from the same service (cap at 10)
    svc_logs = [l for l in all_recent_logs if l.get("service_name") == service_name]
    if svc_logs:
        parts.append(f"\n## RECENT LOGS FROM {service_name} ({service_type})")
        for log in svc_logs[-10:]:
            parts.append(f"  [{log.get('time','')}] [{log.get('level','')}] {log.get('message','')}")

    # Blueprint info
    if blueprint:
        parts.append(f"\n## SERVICE BLUEPRINT")
        parts.append(f"  Name: {blueprint.get('service_name', service_name)}")
        parts.append(f"  Type: {blueprint.get('service_type', service_type)}")
        parts.append(f"  Resource Name: {blueprint.get('resource_name', '')}")
        if blueprint.get("iam_permissions"):
            parts.append(f"  IAM Permissions: {', '.join(blueprint['iam_permissions'][:15])}")
        if blueprint.get("required_configuration"):
            cfg = json.dumps(blueprint["required_configuration"], indent=2)
            parts.append(f"  Configuration:\n{cfg}")
        if blueprint.get("env_vars"):
            parts.append(f"  Env Vars: {json.dumps(blueprint['env_vars'])}")

    # Spec info
    spec = _load_spec(service_type)
    if spec:
        parts.append(f"\n## SERVICE SPEC ({service_type})")
        if spec.get("iam", {}).get("always"):
            parts.append(f"  Required IAM (always): {spec['iam']['always']}")

    # API reference for the failing service
    api_ref = _load_api_ref(service_type)
    if api_ref:
        parts.append(f"\n## API OPERATIONS — {service_type}")
        parts.append(api_ref)

    # Detect other service types mentioned in the error (e.g., Lambda calling EMR Serverless)
    error_text_full = " ".join(e.get("message", "") for e in error_logs)
    _mentioned_types = {
        "emr_serverless": r"emr.serverless|emr-serverless|StartJobRun",
        "s3": r"s3[:\.]|bucket|NoSuchBucket|NoSuchKey",
        "sqs": r"sqs[:\.]|SendMessage|queue",
        "dynamodb": r"dynamodb[:\.]|PutItem|GetItem|table",
        "stepfunctions": r"states[:\.]|StartExecution|state.machine",
        "glue": r"glue[:\.]|StartJobRun|crawler",
        "kinesis_streams": r"kinesis[:\.]|PutRecord|stream",
        "sns": r"sns[:\.]|Publish|topic",
        "redshift": r"redshift[:\.]",
        "athena": r"athena[:\.]|StartQueryExecution",
    }
    for related_type, pattern in _mentioned_types.items():
        if related_type == service_type:
            continue
        if re.search(pattern, error_text_full, re.I):
            related_ref = _load_api_ref(related_type)
            if related_ref:
                parts.append(f"\n## API OPERATIONS — {related_type} (referenced in error)")
                parts.append(related_ref)
            break  # one related service is enough to keep context small

    # Pipeline topology (what other services exist)
    if pipeline_services:
        parts.append(f"\n## PIPELINE SERVICES")
        for svc in pipeline_services:
            parts.append(f"  - {svc['name']} ({svc['type']})")

    # Remind the LLM of the service's deployed resource name (critical for fixes)
    if blueprint:
        parts.append(f"\n## FIX CONTEXT")
        parts.append(f"  Resource name for boto3 calls: {blueprint.get('resource_name', 'unknown')}")
        role_name = blueprint.get('resource_name', '') + '-role'
        parts.append(f"  IAM role name: {role_name}")

    return "\n".join(parts)


# ---------------------------------------------------------------------------
# System prompt
# ---------------------------------------------------------------------------

INSPECTOR_SYSTEM_PROMPT = """\
You are a senior AWS cloud engineer and pipeline troubleshooter. You diagnose \
runtime errors in deployed data pipelines and generate precise boto3 fixes.

## Context
This pipeline was generated by a spec-driven framework. Each service has:
- A **spec** (defaults, IAM rules, env var patterns) in specs/<type>.yaml
- A **blueprint** (computed config, IAM permissions, resource names) from the spec + integration graph
- An **API reference** listing available boto3 operations for the service type

You receive the error logs, the failing service's blueprint, and its API reference. \
Use these to diagnose the root cause and generate a self-contained boto3 fix.

## How to write fix_code
fix_code is a complete Python script executed in a subprocess with boto3 available \
and AWS credentials in the environment. It must:
- Import everything it needs (boto3, json, io, zipfile, urllib, time, etc.)
- Create its own boto3 clients
- Handle errors with try/except and print clear status messages
- Print a success/failure summary at the end

## Fix patterns by error type

### PERMISSION / IAM
The error tells you the exact missing action. The blueprint tells you the role name \
(resource_name + "-role"). Add the missing permission:
```python
import boto3, json
iam = boto3.client("iam")
iam.put_role_policy(
    RoleName="<resource_name>-role",
    PolicyName="inspector-fix",
    PolicyDocument=json.dumps({
        "Version": "2012-10-17",
        "Statement": [{"Effect": "Allow", "Action": ["<missing_action>"], "Resource": ["*"]}]
    })
)
```

### CONFIG / CODE errors
The fix depends on WHERE the code or config lives for the failing service type. \
This framework is spec-driven — every service has a known deployment pattern:

**Where code/scripts live per service type:**
| Service | Code location | How to fix |
|---------|--------------|------------|
| Lambda | Zip deployment package in AWS | Download zip via get_function()["Code"]["Location"], modify .py files in memory with zipfile, re-upload via update_function_code(ZipFile=bytes) |
| EMR Serverless | PySpark/Hive script at an S3 path (in the job's sparkSubmit.entryPoint or hive.script) | Read script from S3 via s3.get_object(), modify, write back via s3.put_object() |
| EMR | Spark steps with scripts at S3 paths | Same as EMR Serverless — read/modify/write the S3 script |
| Glue | ETL script at an S3 path (in the job's ScriptLocation) — get it via glue.get_job() | Read script from S3, modify, write back. Or update job config via glue.update_job() |
| Glue DataBrew | Recipe-based (JSON recipe) | Update recipe via databrew.update_recipe() |
| Step Functions | State machine definition JSON stored in AWS | Get via sfn.describe_state_machine(), modify definition JSON, update via sfn.update_state_machine() |
| Kinesis Analytics | SQL application code | Update via kinesisanalyticsv2.update_application() |

**Lambda code fix pattern:**
```python
import boto3, io, zipfile, urllib.request, time
fn, region = "<resource_name>", "<region>"
client = boto3.client("lambda", region_name=region)
info = client.get_function(FunctionName=fn)
with urllib.request.urlopen(info["Code"]["Location"]) as r:
    zip_bytes = r.read()
buf = io.BytesIO()
with zipfile.ZipFile(io.BytesIO(zip_bytes), "r") as zin:
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename.endswith(".py"):
                text = data.decode("utf-8")
                if "<bad_string>" in text:
                    text = text.replace("<bad_string>", "<good_string>")
                    data = text.encode("utf-8")
                    print(f"Fixed {item.filename}")
            zout.writestr(item, data)
client.update_function_code(FunctionName=fn, ZipFile=buf.getvalue())
print("Waiting for Lambda update to propagate...")
for _ in range(60):
    s = client.get_function_configuration(FunctionName=fn).get("LastUpdateStatus")
    if s == "Successful":
        print("Lambda update confirmed successful")
        break
    if s == "Failed":
        raise RuntimeError("Lambda update failed: " + client.get_function_configuration(FunctionName=fn).get("LastUpdateStatusReason", ""))
    time.sleep(1)
else:
    print("WARNING: Lambda still updating after 60s")
print("Fix applied")
```

**S3-based script fix pattern (EMR Serverless, EMR, Glue):**
```python
import boto3
s3 = boto3.client("s3", region_name="<region>")
bucket, key = "<script_bucket>", "<script_key>"
obj = s3.get_object(Bucket=bucket, Key=key)
script = obj["Body"].read().decode("utf-8")
script = script.replace("<bad_string>", "<good_string>")
s3.put_object(Bucket=bucket, Key=key, Body=script.encode("utf-8"))
print(f"Fixed s3://{bucket}/{key}")
```

**Step Functions definition fix pattern:**
```python
import boto3, json
sfn = boto3.client("stepfunctions", region_name="<region>")
arn = "<state_machine_arn>"  # from blueprint or describe
desc = sfn.describe_state_machine(stateMachineArn=arn)
defn = json.loads(desc["definition"])
# ... modify defn ...
sfn.update_state_machine(stateMachineArn=arn, definition=json.dumps(defn), roleArn=desc["roleArn"])
print("State machine updated")
```

**Service config update pattern (any service):**
Use the service's update/modify API from the API OPERATIONS section. Examples:
- Lambda: `lambda_client.update_function_configuration(FunctionName=fn, MemorySize=512, Timeout=300)`
- Glue: `glue_client.update_job(JobName=name, JobUpdate={"MaxCapacity": 2.0})`
- EMR Serverless: `emr_client.update_application(applicationId=id, maximumCapacity={...})`
- Kinesis: `kinesis_client.update_shard_count(StreamName=name, TargetShardCount=2)`

### RESOURCE_NOT_FOUND
Create the missing resource using boto3. Check the blueprint for expected resource names.

### NETWORK / TIMEOUT
Modify security groups or VPC configuration using ec2 client.

### QUOTA / THROTTLING
Set fixable=false. User must request a quota increase via AWS Console.

### RUNTIME (OOM, timeout, container killed)
Increase resources on the service using its config update API (see table above).

## Response Format
Respond with ONLY valid JSON (no markdown fences):
{
    "diagnosis": "Specific explanation of root cause",
    "root_cause_service": "service name",
    "category": "PERMISSION|CONFIG|RESOURCE_NOT_FOUND|NETWORK|QUOTA|RUNTIME|UNKNOWN",
    "fixable": true/false,
    "fix_description": "What the fix does (1-2 sentences)",
    "fix_code": "Complete self-contained Python script",
    "manual_action": "If not fixable, what the user should do"
}

## Rules
1. fix_code must be SELF-CONTAINED — all imports, all clients, all logic.
2. Use the resource_name from the blueprint for AWS resource identifiers.
3. For Lambda code fixes: download zip → modify in memory → re-upload. Never write to disk.
4. NEVER delete data, drop tables, remove resources, change passwords.
5. For QUOTA errors, always set fixable=false.
6. Keep fixes MINIMAL — fix the specific error only.
7. Refer to the API OPERATIONS in context for correct boto3 method names and parameters.
"""


# ---------------------------------------------------------------------------
# Inspector agent
# ---------------------------------------------------------------------------

@dataclass
class InspectorResult:
    """Result of an inspector analysis."""
    service_name: str
    service_type: str
    category: str
    diagnosis: str
    fixable: bool
    fix_description: str
    fix_code: str | None
    manual_action: str | None
    fix_executed: bool = False
    fix_success: bool = False
    fix_output: str = ""
    error_text: str = ""


class PipelineInspectorAgent:
    """Analyzes pipeline runtime errors and generates fixes."""

    def __init__(
        self,
        api_key: str | None = None,
        model: str = "claude-haiku-4-5-20251001",
    ):
        import anthropic
        key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        if not key:
            raise RuntimeError("ANTHROPIC_API_KEY not set — inspector cannot run")
        self._client = anthropic.Anthropic(
            api_key=key,
            timeout=30.0,  # 30 second timeout — inspector must be fast
        )
        self._model = model

    def diagnose(
        self,
        error_logs: list[dict],
        service_name: str,
        service_type: str,
        error_category: str,
        all_recent_logs: list[dict],
        blueprint: dict | None = None,
        pipeline_services: list[dict] | None = None,
        region: str = "us-east-1",
    ) -> InspectorResult:
        """Diagnose a runtime error and generate a fix."""
        context = build_error_context(
            error_logs, service_name, service_type,
            all_recent_logs, blueprint, pipeline_services,
        )

        user_msg = (
            f"## ERROR CLASSIFICATION\nCategory: {error_category}\n"
            f"Failing service: {service_name} (type: {service_type})\n"
            f"Region: {region}\n\n"
            f"{context}"
        )
        # Sanitize to ASCII-safe text — some log messages contain unicode
        # (e.g., ellipsis …, emoji) that can cause encoding errors
        user_msg = user_msg.encode("ascii", errors="replace").decode("ascii")

        try:
            resp = self._client.messages.create(
                model=self._model,
                max_tokens=4096,
                system=INSPECTOR_SYSTEM_PROMPT,
                messages=[{"role": "user", "content": user_msg}],
            )
            raw = resp.content[0].text.strip()
        except Exception as exc:
            logger.error("Inspector LLM call failed: %s", exc)
            return InspectorResult(
                service_name=service_name,
                service_type=service_type,
                category=error_category,
                diagnosis=f"Inspector failed to call LLM: {exc}",
                fixable=False,
                fix_description="",
                fix_code=None,
                manual_action="Check the API key and try again.",
            )

        return self._parse_response(raw, service_name, service_type, error_category)

    def _parse_response(
        self, raw: str, service_name: str, service_type: str, category: str,
    ) -> InspectorResult:
        """Parse the LLM JSON response into an InspectorResult."""
        # Strip markdown fences if present
        text = raw
        if text.startswith("```"):
            lines = text.split("\n")
            lines = lines[1:]  # remove opening fence
            if lines and lines[-1].strip() == "```":
                lines = lines[:-1]
            text = "\n".join(lines)

        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            logger.warning("Inspector response is not valid JSON: %s", text[:200])
            return InspectorResult(
                service_name=service_name,
                service_type=service_type,
                category=category,
                diagnosis=text[:500],
                fixable=False,
                fix_description="",
                fix_code=None,
                manual_action="Inspector could not produce a structured diagnosis.",
            )

        return InspectorResult(
            service_name=service_name,
            service_type=service_type,
            category=data.get("category", category),
            diagnosis=data.get("diagnosis", ""),
            fixable=data.get("fixable", False),
            fix_description=data.get("fix_description", ""),
            fix_code=data.get("fix_code") if data.get("fixable") else None,
            manual_action=data.get("manual_action"),
        )


# ---------------------------------------------------------------------------
# Error collector — debounce + cooldown logic
# ---------------------------------------------------------------------------

@dataclass
class ErrorCollector:
    """Collects ERROR-level log events with debounce and per-service cooldown."""
    debounce_sec: float = 5.0
    cooldown_sec: float = 30.0

    _pending: dict[str, list[dict]] = field(default_factory=lambda: defaultdict(list), init=False)
    _first_error_time: dict[str, float] = field(default_factory=dict, init=False)
    _cooldowns: dict[str, float] = field(default_factory=dict, init=False)
    _lock: threading.Lock = field(default_factory=threading.Lock, init=False)

    def add_error(self, service_name: str, log_event: dict) -> None:
        """Add an error event. Thread-safe."""
        with self._lock:
            now = time.time()
            if service_name in self._cooldowns:
                if now < self._cooldowns[service_name]:
                    return  # still in cooldown
                del self._cooldowns[service_name]

            self._pending[service_name].append(log_event)
            if service_name not in self._first_error_time:
                self._first_error_time[service_name] = now

    def get_ready_errors(self) -> list[tuple[str, list[dict]]]:
        """Return (service_name, error_logs) pairs that have finished debouncing."""
        ready = []
        now = time.time()
        with self._lock:
            for svc_name, first_time in list(self._first_error_time.items()):
                if now - first_time >= self.debounce_sec:
                    errors = self._pending.pop(svc_name, [])
                    del self._first_error_time[svc_name]
                    if errors:
                        ready.append((svc_name, errors))
        return ready

    def set_cooldown(self, service_name: str) -> None:
        """Start cooldown for a service after an inspector run."""
        with self._lock:
            self._cooldowns[service_name] = time.time() + self.cooldown_sec

    def clear_cooldown(self, service_name: str) -> None:
        """Remove cooldown for a service so it can be re-inspected immediately."""
        with self._lock:
            self._cooldowns.pop(service_name, None)

    def clear(self) -> None:
        """Reset all state."""
        with self._lock:
            self._pending.clear()
            self._first_error_time.clear()
            self._cooldowns.clear()


# ---------------------------------------------------------------------------
# Budget tracker — limits per-service inspector activity
# ---------------------------------------------------------------------------

# Limits
MAX_LLM_CALLS_PER_SERVICE = 30
MAX_INSPECTOR_DURATION_SEC = 600  # 10 minutes

@dataclass
class InspectorBudget:
    """Tracks LLM calls and elapsed time per service to enforce limits."""
    _llm_calls: dict[str, int] = field(default_factory=lambda: defaultdict(int), init=False)
    _start_times: dict[str, float] = field(default_factory=dict, init=False)
    _lock: threading.Lock = field(default_factory=threading.Lock, init=False)

    def start_tracking(self, service_name: str) -> None:
        """Start tracking a service (first error detected)."""
        with self._lock:
            if service_name not in self._start_times:
                self._start_times[service_name] = time.time()

    def record_llm_call(self, service_name: str) -> None:
        """Record one LLM call for a service."""
        with self._lock:
            self._llm_calls[service_name] += 1

    def can_continue(self, service_name: str) -> tuple[bool, str]:
        """Check if the inspector can make another attempt for this service.

        Returns (allowed, reason_if_not).
        """
        with self._lock:
            calls = self._llm_calls.get(service_name, 0)
            if calls >= MAX_LLM_CALLS_PER_SERVICE:
                return False, f"LLM call limit reached ({calls}/{MAX_LLM_CALLS_PER_SERVICE})"

            start = self._start_times.get(service_name)
            if start:
                elapsed = time.time() - start
                if elapsed >= MAX_INSPECTOR_DURATION_SEC:
                    mins = int(elapsed / 60)
                    return False, f"Time limit reached ({mins} min)"

        return True, ""

    def get_stats(self, service_name: str) -> dict:
        """Get current stats for a service."""
        with self._lock:
            calls = self._llm_calls.get(service_name, 0)
            start = self._start_times.get(service_name, time.time())
            elapsed = int(time.time() - start)
            return {"llm_calls": calls, "elapsed_sec": elapsed}

    def clear(self, service_name: str | None = None) -> None:
        """Clear tracking for one or all services."""
        with self._lock:
            if service_name:
                self._llm_calls.pop(service_name, None)
                self._start_times.pop(service_name, None)
            else:
                self._llm_calls.clear()
                self._start_times.clear()


# ---------------------------------------------------------------------------
# Inspector runner — integrates with PipelineLogStreamer
# ---------------------------------------------------------------------------

def run_inspector(
    agent: PipelineInspectorAgent,
    error_logs: list[dict],
    service_name: str,
    service_type: str,
    all_recent_logs: list[dict],
    output_queue: stdlib_queue.SimpleQueue,
    blueprint: dict | None = None,
    pipeline_services: list[dict] | None = None,
    region: str = "us-east-1",
    extra_env: dict[str, str] | None = None,
    blueprint_map: dict | None = None,
    budget: InspectorBudget | None = None,
    log_stream_ref: list | None = None,
    stop_event: threading.Event | None = None,
) -> InspectorResult:
    """Run the full inspector cycle: diagnose -> fix -> retrigger -> watch -> repeat.

    After a successful fix + retrigger, the inspector watches the log stream
    for new errors from the same service. If the error recurs, it re-investigates
    automatically — up to the budget limits (30 LLM calls or 10 minutes).

    Args:
        budget: shared budget tracker (created if None)
        log_stream_ref: mutable reference to the streamer's _recent_logs (for watching)
        stop_event: the streamer's stop event (to know when to stop)
    """
    if budget is None:
        budget = InspectorBudget()
    budget.start_tracking(service_name)

    attempt = 0
    current_errors = error_logs
    previous_fixes: list[str] = []  # track what we've already tried

    while True:
        attempt += 1

        # Check budget
        can_go, reason = budget.can_continue(service_name)
        if not can_go:
            stats = budget.get_stats(service_name)
            _push_event(output_queue, "inspector_budget_exhausted", {
                "service_name": service_name,
                "message": f"Inspector stopping for {service_name}: {reason}. "
                           f"({stats['llm_calls']} LLM calls, {stats['elapsed_sec']}s elapsed)",
                "stats": stats,
            })
            return InspectorResult(
                service_name=service_name, service_type=service_type,
                category="BUDGET_EXHAUSTED", diagnosis=reason,
                fixable=False, fix_description="", fix_code=None,
                manual_action=f"Inspector limit reached: {reason}. Manual investigation needed.",
            )

        # Check if streamer stopped
        if stop_event and stop_event.is_set():
            return InspectorResult(
                service_name=service_name, service_type=service_type,
                category="STOPPED", diagnosis="Monitoring stopped",
                fixable=False, fix_description="", fix_code=None, manual_action=None,
            )

        # Classify
        error_text = "\n".join(e.get("message", "") for e in current_errors)
        category = classify_runtime_error(error_text)

        error_summary = current_errors[-1].get("message", "")[:120] if current_errors else ""
        _push_event(output_queue, "inspector_start", {
            "service_name": service_name,
            "service_type": service_type,
            "category": category,
            "error_count": len(current_errors),
            "attempt": attempt,
            "message": f"[Attempt {attempt}] Error in {service_name} [{category}]: {error_summary}",
        })

        _push_event(output_queue, "inspector_diagnosing", {
            "service_name": service_name,
            "message": f"Analyzing root cause (attempt {attempt})...",
        })

        # Include previous fix attempts in context so the LLM doesn't repeat itself
        recent = list(log_stream_ref) if log_stream_ref else all_recent_logs
        extra_context_logs = current_errors
        if previous_fixes:
            # Add a synthetic log entry with previous fix history
            history_msg = "PREVIOUS FIX ATTEMPTS (do NOT repeat these):\n" + "\n".join(
                f"  Attempt {i+1}: {fix}" for i, fix in enumerate(previous_fixes)
            )
            extra_context_logs = current_errors + [{"message": history_msg, "time": "", "level": "INFO"}]

        # Diagnose (1 LLM call)
        budget.record_llm_call(service_name)
        result = agent.diagnose(
            error_logs=extra_context_logs,
            service_name=service_name,
            service_type=service_type,
            error_category=category,
            all_recent_logs=recent,
            blueprint=blueprint,
            pipeline_services=pipeline_services,
            region=region,
        )
        result.error_text = error_text[:500]

        stats = budget.get_stats(service_name)
        _push_event(output_queue, "inspector_diagnosis", {
            "service_name": service_name,
            "category": result.category,
            "diagnosis": result.diagnosis,
            "fixable": result.fixable,
            "fix_description": result.fix_description,
            "manual_action": result.manual_action,
            "attempt": attempt,
            "budget": stats,
        })

        # Not fixable — stop
        if not result.fixable or not result.fix_code:
            _push_event(output_queue, "inspector_manual", {
                "service_name": service_name,
                "category": result.category,
                "diagnosis": result.diagnosis,
                "manual_action": result.manual_action or "Manual investigation required.",
                "attempt": attempt,
            })
            return result

        # Execute fix
        _push_event(output_queue, "inspector_fixing", {
            "service_name": service_name,
            "message": f"[Attempt {attempt}] Applying fix: {result.fix_description}",
        })

        from agents.developer_agent import execute_code
        exec_result = execute_code(
            code=result.fix_code, region=region,
            extra_env=extra_env, timeout=120,
        )

        result.fix_executed = True
        result.fix_success = exec_result["exit_code"] == 0
        result.fix_output = exec_result["stdout"] or exec_result["stderr"]

        if not result.fix_success:
            _push_event(output_queue, "inspector_fix_failed", {
                "service_name": service_name,
                "message": f"Fix failed (attempt {attempt}): {result.fix_output[:500]}",
                "fix_code": result.fix_code,
            })
            previous_fixes.append(f"FAILED: {result.fix_description} — {result.fix_output[:200]}")
            # Loop back to retry with a different approach
            continue

        _push_event(output_queue, "inspector_fixed", {
            "service_name": service_name,
            "message": f"Fix applied (attempt {attempt}): {result.fix_description}",
            "output": result.fix_output[:1000],
        })
        previous_fixes.append(f"APPLIED: {result.fix_description}")

        # Re-trigger the pipeline
        _push_event(output_queue, "inspector_retrigger", {
            "service_name": service_name,
            "message": f"Re-triggering pipeline after attempt {attempt}...",
        })
        retrigger_pipeline(
            fixed_service_name=service_name,
            blueprint=blueprint,
            all_recent_logs=recent,
            output_queue=output_queue,
            region=region,
            extra_env=extra_env,
            blueprint_map=blueprint_map,
            pipeline_services=pipeline_services,
            error_logs=current_errors,
        )

        # Watch for new errors from this service after retrigger
        new_errors = _watch_for_errors(
            service_name=service_name,
            log_stream_ref=log_stream_ref,
            watch_duration_sec=45,
            stop_event=stop_event,
        )

        if not new_errors:
            # No new errors — the fix worked!
            _push_event(output_queue, "inspector_resolved", {
                "service_name": service_name,
                "message": f"No new errors from {service_name} after fix (attempt {attempt}). Pipeline running successfully.",
                "attempts": attempt,
                "budget": budget.get_stats(service_name),
            })
            return result

        # Errors recurred — loop back
        _push_event(output_queue, "inspector_error_recurred", {
            "service_name": service_name,
            "message": f"Error recurred in {service_name} after fix attempt {attempt}. Re-investigating...",
            "new_error_count": len(new_errors),
        })
        current_errors = new_errors


def _watch_for_errors(
    service_name: str,
    log_stream_ref: list | None,
    watch_duration_sec: int = 45,
    stop_event: threading.Event | None = None,
) -> list[dict]:
    """Watch the log stream for new errors from a specific service.

    Returns error log entries if any appear within watch_duration_sec,
    or empty list if the service runs clean.
    """
    if not log_stream_ref:
        # No live log stream reference — just wait and return empty
        time.sleep(watch_duration_sec)
        return []

    # Mark the current position in the log stream
    start_idx = len(log_stream_ref)
    deadline = time.time() + watch_duration_sec

    errors_found: list[dict] = []
    # Wait a bit before checking (let the retrigger fire and produce logs)
    time.sleep(min(15, watch_duration_sec))

    while time.time() < deadline:
        if stop_event and stop_event.is_set():
            return []

        # Check for new logs from this service since we started watching
        current_logs = log_stream_ref[start_idx:]
        for log_msg in current_logs:
            if log_msg.get("service_name") != service_name:
                continue
            level = log_msg.get("level", "")
            message = log_msg.get("message", "")
            if level == "ERROR" or is_error_message(message):
                errors_found.append(log_msg)

        if errors_found:
            # Wait a few more seconds to collect the full error (debounce)
            time.sleep(5)
            # Collect any additional errors
            for log_msg in log_stream_ref[start_idx + len(current_logs):]:
                if log_msg.get("service_name") != service_name:
                    continue
                level = log_msg.get("level", "")
                message = log_msg.get("message", "")
                if level == "ERROR" or is_error_message(message):
                    errors_found.append(log_msg)
            return errors_found

        time.sleep(3)

    return []


# ---------------------------------------------------------------------------
# Pipeline re-trigger after successful fix
# ---------------------------------------------------------------------------

# Source type -> code template to re-fire the trigger (deterministic, no LLM)
_RETRIGGER_PATTERNS: dict[str, str] = {
    "s3": """\
import boto3, time
s3 = boto3.client("s3", region_name="{region}")
bucket = "{source_resource}"
key = "{trigger_key}"
# Wait for any pending service updates to propagate before re-triggering
print("Waiting 10s for service updates to propagate...")
time.sleep(10)
print(f"Re-triggering: copying s3://{{bucket}}/{{key}} to itself...")
s3.copy_object(Bucket=bucket, Key=key, CopySource={{"Bucket": bucket, "Key": key}})
print(f"Re-triggered: S3 event fired for s3://{{bucket}}/{{key}}")
""",
    "sqs": """\
import boto3, json
sqs = boto3.client("sqs", region_name="{region}")
queue_url = "{source_resource}"
print(f"Re-triggering: sending message to {{queue_url}}...")
sqs.send_message(QueueUrl=queue_url, MessageBody=json.dumps({{"retrigger": True, "source": "inspector"}}))
print("Re-triggered: SQS message sent")
""",
    "eventbridge": """\
import boto3, json
eb = boto3.client("events", region_name="{region}")
print("Re-triggering: putting EventBridge event...")
eb.put_events(Entries=[{{
    "Source": "inspector.retrigger",
    "DetailType": "Pipeline Retrigger",
    "Detail": json.dumps({{"source": "inspector", "reason": "post-fix retrigger"}}),
}}])
print("Re-triggered: EventBridge event fired")
""",
    "cloudwatch": """\
import boto3, json
eb = boto3.client("events", region_name="{region}")
print("Re-triggering: putting EventBridge event...")
eb.put_events(Entries=[{{
    "Source": "inspector.retrigger",
    "DetailType": "Pipeline Retrigger",
    "Detail": json.dumps({{"source": "inspector", "reason": "post-fix retrigger"}}),
}}])
print("Re-triggered: EventBridge event fired")
""",
    "sns": """\
import boto3, json
sns = boto3.client("sns", region_name="{region}")
topic_arn = "{source_resource}"
print(f"Re-triggering: publishing to {{topic_arn}}...")
sns.publish(TopicArn=topic_arn, Message=json.dumps({{"retrigger": True, "source": "inspector"}}))
print("Re-triggered: SNS message published")
""",
    "kinesis_streams": """\
import boto3, json
kinesis = boto3.client("kinesis", region_name="{region}")
stream = "{source_resource}"
print(f"Re-triggering: putting record to {{stream}}...")
kinesis.put_record(StreamName=stream, Data=json.dumps({{"retrigger": True}}).encode(), PartitionKey="inspector")
print("Re-triggered: Kinesis record sent")
""",
    # Lambda as trigger source: wait for update then invoke
    "lambda": """\
import boto3, json, time
client = boto3.client("lambda", region_name="{region}")
fn = "{source_resource}"
# Wait for any pending Lambda update to finish
print(f"Waiting for {{fn}} update to complete...")
for _ in range(30):
    cfg = client.get_function_configuration(FunctionName=fn)
    status = cfg.get("LastUpdateStatus", "Successful")
    if status == "Successful":
        break
    if status == "Failed":
        print(f"WARNING: Lambda update failed: {{cfg.get('LastUpdateStatusReason')}}")
        break
    time.sleep(1)
print(f"Re-triggering: invoking Lambda {{fn}}...")
resp = client.invoke(FunctionName=fn, InvocationType="Event", Payload=json.dumps({{"retrigger": True, "source": "inspector"}}))
print(f"Re-triggered: Lambda invoked (status {{resp['StatusCode']}})")
""",
    # Step Functions: start a new execution
    "stepfunctions": """\
import boto3, json
sfn = boto3.client("stepfunctions", region_name="{region}")
arn = "{source_resource}"
print(f"Re-triggering: starting Step Functions execution...")
resp = sfn.start_execution(stateMachineArn=arn, input=json.dumps({{"retrigger": True, "source": "inspector"}}))
print(f"Re-triggered: execution {{resp['executionArn']}}")
""",
}


def _extract_s3_key_from_logs(logs: list[dict]) -> str | None:
    """Extract S3 object key from log messages.

    Looks for patterns like:
      - "Object created in bucket-name/path/to/file.csv"
      - "'key': 'path/to/file.csv'"
      - "s3://bucket/path/to/file.csv"
    """
    # Ordered: search error-adjacent logs first, then all logs
    error_times = set()
    for log in logs:
        if log.get("level") == "ERROR":
            error_times.add(log.get("time", "")[:8])  # HH:MM:SS

    def _try_extract(msg: str) -> str | None:
        # "Object created in bucket/path/to/key"
        m = re.search(r"Object created in [^\s/]+/(.+?)(?:\s|$)", msg)
        if m:
            return m.group(1).strip()
        # "s3://bucket/path/to/key"
        m = re.search(r"s3://[^/]+/([^\s'\"]+)", msg)
        if m:
            return m.group(1).strip()
        # "'key': 'path/to/key'" or "key=path/to/key"
        m = re.search(r"['\"]?key['\"]?\s*[:=]\s*['\"]?([^'\"}\s,]+)", msg, re.I)
        if m and "/" in m.group(1):  # only if it looks like a path
            return m.group(1).strip()
        return None

    # Pass 1: error-adjacent logs
    for log in logs:
        msg = log.get("message", "")
        log_time = log.get("time", "")[:8] if log.get("time") else ""
        near_error = log_time in error_times if log_time else False
        if near_error or log.get("level") == "ERROR":
            key = _try_extract(msg)
            if key:
                return key

    # Pass 2: any log with "Object created"
    for log in logs:
        key = _try_extract(log.get("message", ""))
        if key:
            return key

    return None


def _find_latest_s3_key(bucket: str, region: str, extra_env: dict | None = None) -> str:
    """List the most recently modified object in an S3 bucket as a fallback."""
    try:
        import boto3, os
        env = os.environ.copy()
        if extra_env:
            env.update(extra_env)
        session = boto3.Session(
            aws_access_key_id=env.get("AWS_ACCESS_KEY_ID"),
            aws_secret_access_key=env.get("AWS_SECRET_ACCESS_KEY"),
            region_name=region,
        )
        s3 = session.client("s3")
        resp = s3.list_objects_v2(Bucket=bucket, MaxKeys=10)
        objects = resp.get("Contents", [])
        if objects:
            # Sort by last modified, pick the most recent
            objects.sort(key=lambda o: o.get("LastModified", ""), reverse=True)
            return objects[0]["Key"]
    except Exception as exc:
        logger.warning("Failed to list S3 bucket %s: %s", bucket, exc)
    return ""


def _find_service_type(name: str, pipeline_services: list[dict] | None) -> str:
    """Look up service type by name from the pipeline services list."""
    if pipeline_services:
        for svc in pipeline_services:
            if svc.get("name") == name:
                return svc.get("type", "")
    return ""


def _find_retrigger_root(
    service_name: str,
    blueprint_map: dict | None,
    pipeline_services: list[dict] | None,
    visited: set | None = None,
) -> tuple[str, str, str] | None:
    """Walk the integration graph backward to find a triggerable root.

    Returns (source_name, source_type, source_resource_name) for the first
    ancestor that has a re-trigger pattern, or None.

    E.g., EMR Serverless <- Lambda <- S3  =>  returns (s3_1, "s3", "bucket-name")
    because S3 has a re-trigger pattern (copy object to self).
    """
    if visited is None:
        visited = set()
    if service_name in visited:
        return None  # cycle guard
    visited.add(service_name)

    if not blueprint_map:
        return None

    bp = blueprint_map.get(service_name)
    if not bp:
        return None

    for integ in bp.get("integrations_as_target", []):
        source_name = integ.get("source", "")
        source_type = _find_service_type(source_name, pipeline_services)

        if not source_type:
            continue

        # If this source type has a direct retrigger pattern, use it
        if source_type in _RETRIGGER_PATTERNS:
            source_bp = blueprint_map.get(source_name, {})
            source_resource = source_bp.get("resource_name", source_name)
            return (source_name, source_type, source_resource)

        # Otherwise, walk further up the chain
        ancestor = _find_retrigger_root(source_name, blueprint_map, pipeline_services, visited)
        if ancestor:
            return ancestor

    return None


def retrigger_pipeline(
    fixed_service_name: str,
    blueprint: dict | None,
    all_recent_logs: list[dict],
    output_queue: stdlib_queue.SimpleQueue,
    region: str = "us-east-1",
    extra_env: dict[str, str] | None = None,
    blueprint_map: dict | None = None,
    pipeline_services: list[dict] | None = None,
    error_logs: list[dict] | None = None,
) -> bool:
    """After a successful fix, re-trigger the pipeline to resume execution.

    Walks the integration graph backward from the fixed service to find the
    nearest ancestor with a known re-trigger pattern (S3 copy, SQS send,
    Lambda invoke, etc.). If no trigger is found, falls back to direct
    invocation for Lambda services.
    """
    if not blueprint:
        return False

    # Walk backward through the integration chain to find a triggerable root
    root = _find_retrigger_root(
        fixed_service_name, blueprint_map, pipeline_services,
    )

    if not root:
        # No triggerable ancestor — try direct invoke if the fixed service is Lambda
        if blueprint.get("service_type") == "lambda":
            resource_name = blueprint.get("resource_name", fixed_service_name)
            _push_event(output_queue, "inspector_retrigger", {
                "service_name": fixed_service_name,
                "message": f"Re-triggering {fixed_service_name} via direct invocation...",
            })
            code = _RETRIGGER_PATTERNS["lambda"].format(
                region=region, source_resource=resource_name,
            )
            return _execute_retrigger(code, region, extra_env, output_queue, fixed_service_name)
        return False

    source_name, source_type, source_resource = root
    template = _RETRIGGER_PATTERNS[source_type]

    # For S3 triggers, extract the exact key — search error context first
    trigger_key = ""
    if source_type == "s3":
        if error_logs:
            trigger_key = _extract_s3_key_from_logs(error_logs) or ""
        if not trigger_key:
            trigger_key = _extract_s3_key_from_logs(all_recent_logs) or ""
        if not trigger_key:
            # Last resort: list the bucket and use the most recent object
            trigger_key = _find_latest_s3_key(source_resource, region, extra_env)
        if not trigger_key:
            _push_event(output_queue, "inspector_retrigger_failed", {
                "service_name": fixed_service_name,
                "message": "Could not determine which S3 key triggered the pipeline. Upload a file to the S3 bucket to retry.",
            })
            return False

    chain_desc = f"{source_type}:{source_name}"
    if source_name != fixed_service_name:
        chain_desc += f" (upstream of {fixed_service_name})"

    key_info = f" (key: {trigger_key})" if trigger_key else ""
    _push_event(output_queue, "inspector_retrigger", {
        "service_name": fixed_service_name,
        "trigger_source": chain_desc,
        "message": f"Re-triggering pipeline via {chain_desc}{key_info}...",
    })

    code = template.format(
        region=region,
        source_resource=source_resource,
        trigger_key=trigger_key,
    )

    return _execute_retrigger(code, region, extra_env, output_queue, fixed_service_name)


def _execute_retrigger(
    code: str, region: str, extra_env: dict | None,
    output_queue: stdlib_queue.SimpleQueue, service_name: str,
) -> bool:
    """Execute re-trigger code and report result."""
    from agents.developer_agent import execute_code
    result = execute_code(code=code, region=region, extra_env=extra_env, timeout=30)

    output = result["stdout"] or result["stderr"]
    if result["exit_code"] == 0:
        _push_event(output_queue, "inspector_retrigger_ok", {
            "service_name": service_name,
            "message": f"Pipeline re-triggered successfully",
            "output": output[:800],
        })
        return True
    else:
        _push_event(output_queue, "inspector_retrigger_failed", {
            "service_name": service_name,
            "message": f"Re-trigger failed: {output[:300]}",
        })
        return False


def _push_event(q: stdlib_queue.SimpleQueue, event_type: str, data: dict) -> None:
    """Push an inspector event to the output queue."""
    q.put_nowait({
        "type": "inspector_event",
        "event": event_type,
        "time": datetime.now().strftime("%H:%M:%S"),
        **data,
    })
