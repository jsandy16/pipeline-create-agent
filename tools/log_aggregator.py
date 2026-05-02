"""Pipeline Run Log Aggregator — streams CloudWatch Logs from deployed pipeline services.

Discovers CloudWatch Log Groups from terraform.tfstate, polls FilterLogEvents
across all groups in parallel, merges chronologically, and pushes events into
a SimpleQueue for WebSocket streaming.

No LLM calls. Uses boto3 only.
Requires: logs:FilterLogEvents, logs:DescribeLogGroups IAM permissions.
"""
from __future__ import annotations

import json
import logging
import os
import queue as stdlib_queue
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Log group name patterns per service type
# ---------------------------------------------------------------------------

_LOG_GROUP_PATTERNS: dict[str, str] = {
    # Compute — native CW Logs
    "lambda":            "/aws/lambda/{resource_name}",
    "stepfunctions":     "/aws/vendedlogs/states/{resource_name}",
    "emr":               "/aws/emr/{resource_name}",
    "emr_serverless":    "/aws/emr-serverless/{resource_name}",
    "sagemaker":         "/aws/sagemaker/Endpoints/{resource_name}",
    # Analytics / ETL
    "glue":              "/aws-glue/jobs/{resource_name}",
    "glue_databrew":     "/aws-glue-databrew/jobs/{resource_name}",
    "athena":            "/aws/athena/{resource_name}",
    "kinesis_firehose":  "/aws/kinesisfirehose/{resource_name}",
    "kinesis_analytics": "/aws/kinesis-analytics/{resource_name}",
    # Databases
    "aurora":            "/aws/rds/cluster/{resource_name}/postgresql",
    "redshift":          "/aws/redshift/cluster/{resource_name}",
    # Streaming
    "msk":               "/aws/msk/{resource_name}",
    # Migration
    "dms":               "dms-tasks-{resource_name}",
}

# Terraform resource type -> attribute that holds the "name" used in log group
_TF_NAME_ATTR: dict[str, str] = {
    "aws_lambda_function":                  "function_name",
    "aws_sfn_state_machine":                "name",
    "aws_emr_cluster":                      "name",
    "aws_emr_serverless_application":       "name",
    "aws_sagemaker_endpoint":               "name",
    "aws_glue_crawler":                     "name",
    "aws_databrew_project":                 "name",
    "aws_athena_workgroup":                 "name",
    "aws_kinesis_firehose_delivery_stream": "name",
    "aws_kinesisanalyticsv2_application":   "name",
    "aws_rds_cluster":                      "cluster_identifier",
    "aws_redshift_cluster":                 "cluster_identifier",
    "aws_msk_cluster":                      "cluster_name",
    "aws_dms_replication_instance":         "replication_instance_id",
}

# Service type -> terraform resource type (for state lookup)
_SERVICE_TO_TF: dict[str, str] = {
    "lambda":            "aws_lambda_function",
    "stepfunctions":     "aws_sfn_state_machine",
    "emr":               "aws_emr_cluster",
    "emr_serverless":    "aws_emr_serverless_application",
    "sagemaker":         "aws_sagemaker_endpoint",
    "glue":              "aws_glue_crawler",
    "glue_databrew":     "aws_databrew_project",
    "athena":            "aws_athena_workgroup",
    "kinesis_firehose":  "aws_kinesis_firehose_delivery_stream",
    "kinesis_analytics": "aws_kinesisanalyticsv2_application",
    "aurora":            "aws_rds_cluster",
    "redshift":          "aws_redshift_cluster",
    "msk":               "aws_msk_cluster",
    "dms":               "aws_dms_replication_instance",
}

# Services that don't have CW Logs but can be monitored via CloudTrail
_CLOUDTRAIL_SERVICES: set[str] = {
    "s3", "sqs", "sns", "dynamodb", "eventbridge", "cloudwatch",
    "kinesis_streams",
}


@dataclass
class LogGroupInfo:
    """Metadata for one CloudWatch Log Group being monitored."""
    service_name: str
    service_type: str
    log_group_name: str
    resource_name: str
    exists: bool = False


@dataclass
class CloudTrailSource:
    """A service monitored via CloudTrail events (no native CW Logs)."""
    service_name: str
    service_type: str
    resource_arn: str
    resource_name: str


@dataclass
class LogEvent:
    """A single log event from CloudWatch."""
    timestamp_ms: int
    service_name: str
    service_type: str
    log_group: str
    log_stream: str
    message: str

    def to_ws_message(self) -> dict[str, Any]:
        """Format as a WebSocket message."""
        ts = datetime.fromtimestamp(self.timestamp_ms / 1000)
        level = _infer_level(self.message)
        return {
            "type": "run_log",
            "service_name": self.service_name,
            "service_type": self.service_type,
            "log_group": self.log_group,
            "log_stream": self.log_stream,
            "level": level,
            "time": ts.strftime("%H:%M:%S.") + f"{ts.microsecond // 1000:03d}",
            "message": self.message.rstrip("\n"),
            "timestamp_ms": self.timestamp_ms,
        }


def _infer_level(message: str) -> str:
    """Best-effort log level inference from message text."""
    low = message[:80].lower()
    if "error" in low or "exception" in low or "traceback" in low:
        return "ERROR"
    if "warn" in low:
        return "WARNING"
    if "debug" in low:
        return "DEBUG"
    return "INFO"


# ---------------------------------------------------------------------------
# Discovery: terraform.tfstate -> log group names
# ---------------------------------------------------------------------------

def _resource_name_from_state(state: dict, service_type: str) -> str | None:
    """Extract the deployed resource name from terraform state for a service type."""
    tf_type = _SERVICE_TO_TF.get(service_type)
    if not tf_type:
        return None

    name_attr = _TF_NAME_ATTR.get(tf_type, "name")

    for res in state.get("resources", []):
        if res.get("type") == tf_type and res.get("mode") != "data":
            for inst in res.get("instances", []):
                attrs = inst.get("attributes", {})
                name = attrs.get(name_attr) or attrs.get("id")
                if name:
                    return str(name)
    return None


# Map service_type -> (terraform resource type, arn attribute) for CloudTrail sources
_CLOUDTRAIL_TF_MAP: dict[str, tuple[str, str]] = {
    "s3":              ("aws_s3_bucket",              "arn"),
    "sqs":             ("aws_sqs_queue",              "arn"),
    "sns":             ("aws_sns_topic",              "arn"),
    "dynamodb":        ("aws_dynamodb_table",         "arn"),
    "eventbridge":     ("aws_cloudwatch_event_rule",  "arn"),
    "cloudwatch":      ("aws_cloudwatch_event_rule",  "arn"),
    "kinesis_streams": ("aws_kinesis_stream",         "arn"),
}


def _resource_arn_from_state(state: dict, service_type: str) -> tuple[str, str] | None:
    """Extract (resource_name, arn) for a CloudTrail-monitored service from tfstate."""
    entry = _CLOUDTRAIL_TF_MAP.get(service_type)
    if not entry:
        return None

    tf_type, arn_attr = entry
    for res in state.get("resources", []):
        if res.get("type") == tf_type and res.get("mode") != "data":
            for inst in res.get("instances", []):
                attrs = inst.get("attributes", {})
                arn = attrs.get(arn_attr, "")
                name = attrs.get("id") or attrs.get("name", "")
                if arn:
                    return (str(name), str(arn))
    return None


def discover_log_groups(
    state_file: Path,
    services: list[dict[str, str]],
    boto_session: boto3.Session | None = None,
) -> tuple[list[LogGroupInfo], list[str], list[CloudTrailSource]]:
    """Discover CloudWatch Log Groups and CloudTrail sources for deployed services.

    Args:
        state_file: Path to terraform.tfstate
        services: List of {"name": ..., "type": ...} dicts from the pipeline
        boto_session: Optional boto3 session (uses default if None)

    Returns:
        (monitored_groups, services_without_logs, cloudtrail_sources)
    """
    if not state_file.exists():
        raise FileNotFoundError(f"State file not found: {state_file}")

    state = json.loads(state_file.read_text())
    session = boto_session or boto3.Session()
    client = session.client("logs")

    groups: list[LogGroupInfo] = []
    ct_sources: list[CloudTrailSource] = []
    no_logs: list[str] = []

    for svc in services:
        svc_name = svc["name"]
        svc_type = svc["type"]
        pattern = _LOG_GROUP_PATTERNS.get(svc_type)

        if pattern:
            # CloudWatch Logs path
            resource_name = _resource_name_from_state(state, svc_type)
            if not resource_name:
                no_logs.append(svc_name)
                logger.warning("Could not find resource name in state for %s (%s)",
                              svc_name, svc_type)
                continue

            log_group_name = pattern.format(resource_name=resource_name)

            # Check if log group exists in AWS
            exists = False
            try:
                resp = client.describe_log_groups(logGroupNamePrefix=log_group_name, limit=1)
                for lg in resp.get("logGroups", []):
                    if lg.get("logGroupName") == log_group_name:
                        exists = True
                        break
            except ClientError as e:
                logger.warning("Error checking log group %s: %s", log_group_name, e)

            groups.append(LogGroupInfo(
                service_name=svc_name,
                service_type=svc_type,
                log_group_name=log_group_name,
                resource_name=resource_name,
                exists=exists,
            ))

        elif svc_type in _CLOUDTRAIL_SERVICES:
            # CloudTrail fallback path
            result = _resource_arn_from_state(state, svc_type)
            if result:
                res_name, arn = result
                ct_sources.append(CloudTrailSource(
                    service_name=svc_name,
                    service_type=svc_type,
                    resource_arn=arn,
                    resource_name=res_name,
                ))
            else:
                no_logs.append(svc_name)
        else:
            no_logs.append(svc_name)

    return groups, no_logs, ct_sources


def discover_log_groups_from_state(
    state_file: Path,
    services: list[dict[str, str]],
) -> tuple[list[LogGroupInfo], list[str]]:
    """Lightweight discovery without AWS validation (no boto3 calls).

    Returns all potential log groups based on state + known patterns.
    Sets exists=True optimistically (polling will handle missing groups gracefully).
    """
    if not state_file.exists():
        raise FileNotFoundError(f"State file not found: {state_file}")

    state = json.loads(state_file.read_text())
    groups: list[LogGroupInfo] = []
    no_logs: list[str] = []

    for svc in services:
        svc_name = svc["name"]
        svc_type = svc["type"]
        pattern = _LOG_GROUP_PATTERNS.get(svc_type)

        if not pattern:
            no_logs.append(svc_name)
            continue

        resource_name = _resource_name_from_state(state, svc_type)
        if not resource_name:
            no_logs.append(svc_name)
            continue

        log_group_name = pattern.format(resource_name=resource_name)
        groups.append(LogGroupInfo(
            service_name=svc_name,
            service_type=svc_type,
            log_group_name=log_group_name,
            resource_name=resource_name,
            exists=True,
        ))

    return groups, no_logs


# ---------------------------------------------------------------------------
# Polling: fetch new log events from CloudWatch
# ---------------------------------------------------------------------------

def poll_logs(
    log_groups: list[LogGroupInfo],
    since_ms: int,
    client,
    limit_per_group: int = 100,
) -> list[LogEvent]:
    """Fetch new log events from all monitored log groups since a timestamp.

    Parallelizes requests across groups with a thread pool.
    Returns events sorted chronologically.
    """
    events: list[LogEvent] = []

    def _fetch_one(group: LogGroupInfo) -> list[LogEvent]:
        if not group.exists:
            return []
        try:
            resp = client.filter_log_events(
                logGroupName=group.log_group_name,
                startTime=since_ms,
                limit=limit_per_group,
                interleaved=True,
            )
            return [
                LogEvent(
                    timestamp_ms=evt["timestamp"],
                    service_name=group.service_name,
                    service_type=group.service_type,
                    log_group=group.log_group_name,
                    log_stream=evt.get("logStreamName", ""),
                    message=evt.get("message", ""),
                )
                for evt in resp.get("events", [])
            ]
        except ClientError as e:
            code = e.response.get("Error", {}).get("Code", "")
            if code == "ResourceNotFoundException":
                group.exists = False
                logger.debug("Log group not found (yet): %s", group.log_group_name)
            else:
                logger.warning("Error polling %s: %s", group.log_group_name, e)
            return []

    with ThreadPoolExecutor(max_workers=min(len(log_groups), 8)) as pool:
        futures = {pool.submit(_fetch_one, g): g for g in log_groups}
        for future in as_completed(futures):
            try:
                events.extend(future.result())
            except Exception as exc:
                logger.warning("Poll thread error: %s", exc)

    events.sort(key=lambda e: e.timestamp_ms)
    return events


def poll_cloudtrail(
    ct_sources: list[CloudTrailSource],
    since_ms: int,
    ct_client,
    limit: int = 50,
) -> list[LogEvent]:
    """Fetch recent CloudTrail events for services without native CW Logs.

    Uses LookupEvents filtered by resource ARN. CloudTrail has ~5-15 min
    delivery delay, so these events appear later than CW Logs.
    """
    if not ct_sources:
        return []

    events: list[LogEvent] = []
    # CloudTrail requires StartTime < EndTime, both timezone-aware.
    # Clamp start_time to at most 60 seconds ago to avoid future timestamps.
    from datetime import timezone
    now_utc = datetime.now(timezone.utc)
    start_time = datetime.fromtimestamp(since_ms / 1000, tz=timezone.utc)
    if start_time >= now_utc:
        start_time = now_utc.replace(microsecond=0)  # clamp to now
    end_time = now_utc

    def _fetch_ct(source: CloudTrailSource) -> list[LogEvent]:
        try:
            resp = ct_client.lookup_events(
                LookupAttributes=[{
                    "AttributeKey": "ResourceName",
                    "AttributeValue": source.resource_name,
                }],
                StartTime=start_time,
                EndTime=end_time,
                MaxResults=min(limit, 50),
            )
            result = []
            for evt in resp.get("Events", []):
                ts_ms = int(evt["EventTime"].timestamp() * 1000)
                if ts_ms < since_ms:
                    continue
                event_name = evt.get("EventName", "unknown")
                username = evt.get("Username", "")
                msg = f"[CloudTrail] {event_name}"
                if username:
                    msg += f" by {username}"
                # Add resource details from the event
                resources = evt.get("Resources", [])
                for r in resources:
                    if r.get("ResourceName") == source.resource_name:
                        msg += f" on {r.get('ResourceType', source.service_type)}:{source.resource_name}"
                        break
                result.append(LogEvent(
                    timestamp_ms=ts_ms,
                    service_name=source.service_name,
                    service_type=source.service_type,
                    log_group=f"cloudtrail:{source.service_type}",
                    log_stream="",
                    message=msg,
                ))
            return result
        except ClientError as e:
            logger.warning("CloudTrail lookup error for %s: %s", source.service_name, e)
            return []

    with ThreadPoolExecutor(max_workers=min(len(ct_sources), 4)) as pool:
        futures = {pool.submit(_fetch_ct, s): s for s in ct_sources}
        for future in as_completed(futures):
            try:
                events.extend(future.result())
            except Exception as exc:
                logger.warning("CloudTrail poll error: %s", exc)

    events.sort(key=lambda e: e.timestamp_ms)
    return events


# ---------------------------------------------------------------------------
# Streaming loop: long-running poller that pushes to a queue
# ---------------------------------------------------------------------------

@dataclass
class PipelineLogStreamer:
    """Long-running log streamer for a deployed pipeline.

    Start with .start(), stop with .stop().
    Events are pushed to the provided SimpleQueue as WebSocket-ready dicts.

    If inspector_agent is set and auto_fix_enabled is True, error-level events
    are collected and, after debouncing, the inspector is triggered to diagnose
    and fix the error automatically.
    """
    log_groups: list[LogGroupInfo]
    output_queue: stdlib_queue.SimpleQueue
    poll_interval: float = 3.0
    boto_session: boto3.Session | None = None
    ct_sources: list[CloudTrailSource] = field(default_factory=list)

    # Inspector integration (optional — set these to enable auto-fix)
    inspector_agent: Any = None    # PipelineInspectorAgent or None
    inspector_context: dict = field(default_factory=dict)
    # inspector_context keys: blueprint_map, pipeline_services, region, extra_env
    auto_fix_enabled: bool = False

    _stop_event: threading.Event = field(default_factory=threading.Event, init=False)
    _thread: threading.Thread | None = field(default=None, init=False)
    _high_water: int = field(default=0, init=False)
    _ct_high_water: int = field(default=0, init=False)
    _recent_logs: list = field(default_factory=list, init=False)  # last ~100 log events
    _error_collector: Any = None  # ErrorCollector, created on start
    _inspector_budget: Any = None  # InspectorBudget, created on start

    def set_auto_fix(self, enabled: bool) -> None:
        """Toggle auto-fix on/off at runtime.

        When toggled ON, scans recent logs for existing errors so we don't
        miss errors that arrived before auto-fix was enabled.
        """
        self.auto_fix_enabled = enabled
        if enabled and self._error_collector and self.inspector_agent:
            # Scan recent logs for errors that already happened
            from agents.pipeline_inspector import is_error_message
            for log_msg in self._recent_logs:
                level = log_msg.get("level", "")
                message = log_msg.get("message", "")
                svc_name = log_msg.get("service_name", "")
                if svc_name and (level == "ERROR" or is_error_message(message)):
                    self._error_collector.add_error(svc_name, log_msg)

    def start(self) -> None:
        """Start polling in a background thread."""
        if self._thread and self._thread.is_alive():
            return
        # Start from "now" minus 60 seconds to catch very recent events
        self._high_water = int((time.time() - 60) * 1000)
        # CloudTrail has 5-15 min delay, start further back
        self._ct_high_water = int((time.time() - 900) * 1000)
        self._recent_logs = []
        # Initialize error collector for inspector
        if self.inspector_agent:
            from agents.pipeline_inspector import ErrorCollector, InspectorBudget
            self._error_collector = ErrorCollector()
            self._inspector_budget = InspectorBudget()
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        """Signal the polling loop to stop."""
        self._stop_event.set()

    def is_running(self) -> bool:
        return self._thread is not None and self._thread.is_alive()

    def _check_error(self, ws_msg: dict) -> None:
        """Check a log message for errors and feed to the error collector."""
        if not self.auto_fix_enabled or not self._error_collector:
            return
        if not self.inspector_agent:
            return

        level = ws_msg.get("level", "")
        message = ws_msg.get("message", "")
        svc_name = ws_msg.get("service_name", "")

        if not svc_name:
            return

        from agents.pipeline_inspector import is_error_message
        if level == "ERROR" or is_error_message(message):
            self._error_collector.add_error(svc_name, ws_msg)

    def _trigger_inspector(self) -> None:
        """Check for debounced errors and trigger inspector in background."""
        if not self.auto_fix_enabled or not self._error_collector:
            return
        if not self.inspector_agent:
            return

        ready = self._error_collector.get_ready_errors()
        for svc_name, error_logs in ready:
            # Find the service type from log groups or CT sources
            svc_type = self._lookup_service_type(svc_name)
            if not svc_type:
                continue

            # Set cooldown immediately to prevent re-triggering
            self._error_collector.set_cooldown(svc_name)

            # Run inspector in a separate thread (non-blocking)
            ctx = self.inspector_context
            t = threading.Thread(
                target=self._run_inspector,
                args=(svc_name, svc_type, error_logs, ctx),
                daemon=True,
            )
            t.start()

    def _lookup_service_type(self, service_name: str) -> str | None:
        """Find service_type for a service_name from monitored groups/sources."""
        for g in self.log_groups:
            if g.service_name == service_name:
                return g.service_type
        for s in self.ct_sources:
            if s.service_name == service_name:
                return s.service_type
        return None

    def _run_inspector(
        self, svc_name: str, svc_type: str,
        error_logs: list[dict], ctx: dict,
    ) -> None:
        """Run inspector in background thread. Includes watch-retry loop."""
        from agents.pipeline_inspector import run_inspector
        try:
            blueprint_map = ctx.get("blueprint_map", {})
            run_inspector(
                agent=self.inspector_agent,
                error_logs=error_logs,
                service_name=svc_name,
                service_type=svc_type,
                all_recent_logs=list(self._recent_logs),
                output_queue=self.output_queue,
                blueprint=blueprint_map.get(svc_name),
                pipeline_services=ctx.get("pipeline_services"),
                region=ctx.get("region", "us-east-1"),
                extra_env=ctx.get("extra_env"),
                blueprint_map=blueprint_map,
                budget=self._inspector_budget,
                log_stream_ref=self._recent_logs,
                stop_event=self._stop_event,
            )
            # After inspector finishes (success or budget exhausted),
            # clear cooldown so new different errors can be picked up
            if self._error_collector:
                self._error_collector.clear_cooldown(svc_name)
        except Exception as exc:
            logger.error("Inspector failed for %s: %s", svc_name, exc)
            self.output_queue.put_nowait({
                "type": "inspector_event",
                "event": "inspector_error",
                "service_name": svc_name,
                "message": f"Inspector error: {exc}",
            })

    def _run(self) -> None:
        session = self.boto_session or boto3.Session()
        cw_client = session.client("logs")
        ct_client = session.client("cloudtrail") if self.ct_sources else None

        total = len(self.log_groups) + len(self.ct_sources)
        parts = []
        if self.log_groups:
            parts.append(f"{len(self.log_groups)} CloudWatch log group(s)")
        if self.ct_sources:
            parts.append(f"{len(self.ct_sources)} CloudTrail source(s)")

        self.output_queue.put_nowait({
            "type": "run_log_status",
            "status": "polling",
            "message": f"Monitoring {' + '.join(parts)}…",
            "log_groups": [
                {"service_name": g.service_name, "service_type": g.service_type,
                 "log_group": g.log_group_name, "exists": g.exists}
                for g in self.log_groups
            ],
        })

        # Track CloudTrail poll cycle (poll CT less frequently — every 3rd cycle)
        _ct_cycle = 0

        while not self._stop_event.is_set():
            try:
                # Re-check existence for groups that were previously missing
                for g in self.log_groups:
                    if not g.exists:
                        try:
                            resp = cw_client.describe_log_groups(
                                logGroupNamePrefix=g.log_group_name, limit=1)
                            for lg in resp.get("logGroups", []):
                                if lg.get("logGroupName") == g.log_group_name:
                                    g.exists = True
                                    self.output_queue.put_nowait({
                                        "type": "run_log_status",
                                        "status": "group_found",
                                        "message": f"Log group now active: {g.log_group_name}",
                                        "service_name": g.service_name,
                                    })
                                    break
                        except ClientError:
                            pass

                # Poll CloudWatch Logs
                events = poll_logs(self.log_groups, self._high_water, cw_client)

                if events:
                    for evt in events:
                        ws_msg = evt.to_ws_message()
                        self.output_queue.put_nowait(ws_msg)
                        # Track recent logs for inspector context
                        self._recent_logs.append(ws_msg)
                        if len(self._recent_logs) > 200:
                            self._recent_logs = self._recent_logs[-100:]
                        # Feed errors to collector if auto-fix is enabled
                        self._check_error(ws_msg)
                    self._high_water = events[-1].timestamp_ms + 1

                # Poll CloudTrail every 3rd cycle (~9 seconds) to reduce API calls
                _ct_cycle += 1
                if ct_client and self.ct_sources and _ct_cycle % 3 == 0:
                    ct_events = poll_cloudtrail(
                        self.ct_sources, self._ct_high_water, ct_client)
                    if ct_events:
                        for evt in ct_events:
                            ws_msg = evt.to_ws_message()
                            self.output_queue.put_nowait(ws_msg)
                            self._recent_logs.append(ws_msg)
                            self._check_error(ws_msg)
                        self._ct_high_water = ct_events[-1].timestamp_ms + 1

                # Check if any debounced errors are ready for inspection
                self._trigger_inspector()

            except Exception as exc:
                logger.error("Poll loop error: %s", exc)
                self.output_queue.put_nowait({
                    "type": "run_log_status",
                    "status": "error",
                    "message": f"Polling error: {exc}",
                })

            # Sleep in small increments so stop is responsive
            for _ in range(int(self.poll_interval * 10)):
                if self._stop_event.is_set():
                    break
                time.sleep(0.1)

        self.output_queue.put_nowait({
            "type": "run_log_status",
            "status": "stopped",
            "message": "Log monitoring stopped.",
        })


# ---------------------------------------------------------------------------
# Convenience: create a boto3 session from admin config
# ---------------------------------------------------------------------------

def make_boto_session(
    access_key: str | None = None,
    secret_key: str | None = None,
    region: str = "us-east-1",
) -> boto3.Session:
    """Create a boto3 session, using explicit keys or falling back to env/profile."""
    if access_key and secret_key:
        return boto3.Session(
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            region_name=region,
        )
    return boto3.Session(region_name=region)
