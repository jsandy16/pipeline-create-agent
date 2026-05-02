"""Web application — Architecture diagram → Terraform HCL generator.

Start:
    uvicorn app:app --reload --port 8000

Then open http://localhost:8000 in a browser.
"""
from __future__ import annotations

import asyncio
import csv
import io
import json
import logging
import queue as stdlib_queue
import re
import urllib.parse
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any

import uvicorn
import yaml
from fastapi import FastAPI, File, Form, Request, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, JSONResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles

# Importing main loads .env via load_dotenv() at module level
from main import _diagram_to_yaml
from schemas import PipelineRequest
from engine.pipeline_builder import build_pipeline
from engine.spec_index import FeatureIndex, ConfigResolution
from engine.config_registry import get_supported_keys, validate_config_patch

UPLOAD_DIR = Path("input_architecture_dgm")
UPLOAD_DIR.mkdir(exist_ok=True)

TEMPLATE_PATH = Path(__file__).parent / "templates" / "index.html"

app = FastAPI(title="AWS Pipeline Engine")
app.mount("/static", StaticFiles(directory=Path(__file__).parent / "templates" / "static"), name="static")

logging.getLogger().setLevel(logging.INFO)

# ─── Feature index for config chat (built once at startup) ───────────────────
_feature_index = FeatureIndex()

# job_id → { status, result_info, log_q, task }
_jobs: dict[str, dict] = {}

# deploy_id → { status, plan_text, log_q, task, work_dir }
_deploys: dict[str, dict] = {}

# preview_id → { status, log_q, streamer, job_id }
_previews: dict[str, dict] = {}

SUPPORTED_EXTENSIONS = frozenset({".png", ".jpg", ".jpeg", ".gif", ".webp"})

# ─── Pipeline matrix resource map ─────────────────────────────────────────────
# Maps service_type → (terraform_resource_type, arn_attribute)
_TF_RESOURCE_MAP: dict[str, tuple[str, str]] = {
    "s3":                ("aws_s3_bucket",                       "arn"),
    "lambda":            ("aws_lambda_function",                  "arn"),
    "sqs":               ("aws_sqs_queue",                        "arn"),
    "sns":               ("aws_sns_topic",                        "arn"),
    "dynamodb":          ("aws_dynamodb_table",                   "arn"),
    "kinesis_streams":   ("aws_kinesis_stream",                   "arn"),
    "kinesis_firehose":  ("aws_kinesis_firehose_delivery_stream", "arn"),
    "kinesis_analytics": ("aws_kinesisanalyticsv2_application",   "arn"),
    "stepfunctions":     ("aws_sfn_state_machine",                "arn"),
    "glue":              ("aws_glue_job",                         "arn"),
    "athena":            ("aws_athena_workgroup",                 "arn"),
    "cloudwatch":        ("aws_cloudwatch_event_rule",            "arn"),
    "eventbridge":       ("aws_cloudwatch_event_rule",            "arn"),
    "ec2":               ("aws_instance",                         "arn"),
    "msk":               ("aws_msk_cluster",                      "arn"),
    "redshift":          ("aws_redshift_cluster",                 "arn"),
    "aurora":            ("aws_rds_cluster",                      "arn"),
    "dms":               ("aws_dms_replication_instance",         "replication_instance_arn"),
    "emr":               ("aws_emr_cluster",                      "arn"),
    "lake_formation":    ("aws_lakeformation_data_lake_settings", "id"),
    "glue_data_catalog": ("aws_glue_catalog_database",           "arn"),
    "glue_databrew":     ("aws_databrew_project",                "arn"),
    "iam":               ("aws_iam_role",                         "arn"),
}


# ─── Progress tracker ──────────────────────────────────────────────────────────

class _ProgressTracker:
    """Infers pipeline progress % by parsing engine log messages."""

    def __init__(self, total_services: int) -> None:
        self.total = max(total_services, 1)
        self.blueprints_done = 0
        self.lint_done = False
        self.write_done = False

    def update(self, _logger_name: str, message: str) -> tuple[int, str] | None:
        low = message.lower()
        changed = False

        if "blueprint built" in low:
            self.blueprints_done = min(self.blueprints_done + 1, self.total)
            changed = True
        elif "lint:" in low:
            self.lint_done = True
            changed = True
        elif "wrote output/" in low:
            self.write_done = True
            changed = True

        return self._calc() if changed else None

    def _calc(self) -> tuple[int, str]:
        # 10% for T0, 10–85% blueprints, 85–95% lint, 95–100% write
        bp_pct   = (self.blueprints_done / self.total) * 75
        lint_pct = 10 if self.lint_done else 0
        write_pct = 5 if self.write_done else 0
        total = int(10 + bp_pct + lint_pct + write_pct)

        if self.write_done:
            stage = "Writing output files"
        elif self.lint_done:
            stage = "Lint passed — writing output"
        elif self.blueprints_done >= self.total:
            stage = "Running linter"
        elif self.blueprints_done > 0:
            stage = f"Building blueprints ({self.blueprints_done}/{self.total})"
        else:
            stage = "Starting blueprint computation…"

        return min(total, 95), stage


# ─── Service event parser ──────────────────────────────────────────────────────

_SVC_BUILT_RE = re.compile(r"^\[([^\]]+)\]\s+blueprint built:")


def _parse_service_event(msg: str) -> dict | None:
    m = _SVC_BUILT_RE.match(msg)
    if m:
        return {"type": "service_update", "name": m.group(1), "status": "done", "agent": "✓"}
    return None


# ─── Custom log handler ────────────────────────────────────────────────────────

class _JobLogHandler(logging.Handler):
    """Forwards log events onto a SimpleQueue, parsing progress and service events."""

    def __init__(self, q: stdlib_queue.SimpleQueue, tracker: _ProgressTracker) -> None:
        super().__init__()
        self._q = q
        self._tracker = tracker

    def emit(self, record: logging.LogRecord) -> None:
        try:
            msg = record.getMessage()
            self._q.put_nowait({
                "type": "log",
                "level": record.levelname,
                "time": datetime.fromtimestamp(record.created).strftime("%H:%M:%S"),
                "logger": record.name,
                "message": msg,
            })
            result = self._tracker.update(record.name, msg)
            if result:
                pct, stage = result
                self._q.put_nowait({"type": "progress", "pct": pct, "stage": stage})
            svc_event = _parse_service_event(msg)
            if svc_event:
                self._q.put_nowait(svc_event)
        except Exception:  # noqa: BLE001
            pass


# ─── Background job runner ─────────────────────────────────────────────────────

def _run_diagram_reader(image_path: Path, model: str, api_key: str | None = None) -> str:
    """Call DiagramReaderAgent with an optional admin-provided API key."""
    from agents.diagram_reader import DiagramReaderAgent
    agent = DiagramReaderAgent(api_key=api_key, model=model)
    yaml_text = agent.run(image_path)
    out = image_path.with_suffix(".generated.yaml")
    out.write_text(yaml_text)
    logging.getLogger("pipeline").info("Generated YAML: %s", out)
    return yaml_text


async def _execute_job(job_id: str, diagram_path: Path) -> None:
    job = _jobs[job_id]
    q: stdlib_queue.SimpleQueue = job["log_q"]

    def _qlog(level: str, msg: str) -> None:
        q.put_nowait({
            "type": "log", "level": level,
            "time": datetime.now().strftime("%H:%M:%S"),
            "logger": "pipeline", "message": msg,
        })

    tracker = _ProgressTracker(total_services=1)
    handler = _JobLogHandler(q, tracker)
    handler.setLevel(logging.INFO)
    root = logging.getLogger()
    root.addHandler(handler)

    try:
        # ── T0: diagram → YAML ────────────────────────────────────────────
        _qlog("INFO", f"Reading architecture diagram: {diagram_path.name}")

        try:
            yaml_text = await asyncio.to_thread(
                _run_diagram_reader, diagram_path, "claude-sonnet-4-5",
                _admin_config.get("anthropic_api_key"),
            )
        except Exception as exc:
            _qlog("ERROR", f"Diagram reading failed: {exc}")
            q.put_nowait({"type": "done", "exit_code": 1, "result": None})
            job["status"] = "error"
            return

        raw_yaml = yaml.safe_load(yaml_text)
        # Apply project/cost-center overrides from the UI if provided
        bu = job.get("business_unit")
        cc = job.get("cost_center")
        if bu:
            raw_yaml["business_unit"] = bu
        if cc:
            raw_yaml["cost_center"] = cc
        request = PipelineRequest.model_validate(raw_yaml)

        _qlog("INFO", (
            f"Extracted pipeline '{request.pipeline_name}' — "
            f"{len(request.services)} service(s), "
            f"{len(request.integrations)} integration(s)."
        ))

        # Re-initialise tracker with accurate service count
        tracker.__init__(total_services=len(request.services))

        # Emit service list so the UI can show cards in pending state
        q.put_nowait({
            "type": "services_init",
            "services": [{"name": s.name, "type": s.type} for s in request.services],
            "integrations": [
                {"source": i.source, "target": i.target, "event": i.event}
                for i in request.integrations
            ],
        })
        q.put_nowait({"type": "progress", "pct": 10,
                      "stage": f"T0 done — {len(request.services)} services queued"})

        # ── Build pipeline ────────────────────────────────────────────────
        # Use a stable (non-timestamped) path so terraform.tfstate persists
        # across runs.  Re-deploying the same pipeline after a code change
        # will produce a diff-only apply instead of AlreadyExists errors.
        out_dir = Path("output") / request.pipeline_name

        result = await asyncio.to_thread(build_pipeline, request, out_dir, False)

        # Save pipeline YAML for historical pipeline viewer
        if result.main_tf_path and yaml_text:
            try:
                (out_dir / "pipeline.yaml").write_text(yaml_text)
            except Exception:
                pass

        hard_errors = [e for e in result.lint_errors if e.severity == "error"]
        warnings    = [e for e in result.lint_errors if e.severity == "warning"]
        exit_code   = 1 if hard_errors else 0

        if hard_errors:
            for err in hard_errors:
                _qlog("ERROR", err.format())

        result_info = {
            "pipeline_name": result.pipeline_name,
            "main_tf_path":  str(result.main_tf_path) if result.main_tf_path else None,
            "services":      len(result.blueprints),
            "lint_errors":   len(hard_errors),
            "lint_warnings": len(warnings),
            "region":        request.region,
        }

        job["status"] = "done" if exit_code == 0 else "error"
        job["result_info"] = result_info

        # Generate pipeline details (always, even with lint warnings)
        try:
            job["details"] = _generate_details(result, request)
        except Exception as exc:
            job["details"] = {"text": f"Details unavailable: {exc}", "services": [], "integrations": []}

        # Generate pipeline matrix for CSV download
        try:
            job["matrix"] = _generate_matrix(result, request)
        except Exception as exc:
            job["matrix"] = []

        q.put_nowait({"type": "progress", "pct": 100,
                      "stage": "Complete" if exit_code == 0 else "Finished with errors"})
        q.put_nowait({"type": "done", "exit_code": exit_code, "result": result_info})

    except asyncio.CancelledError:
        _qlog("WARNING", "Pipeline cancelled by user.")
        q.put_nowait({"type": "progress", "pct": 0, "stage": "Cancelled"})
        q.put_nowait({"type": "done", "exit_code": 2, "result": None, "cancelled": True})
        job["status"] = "cancelled"

    except Exception as exc:
        _qlog("ERROR", f"Unexpected error: {exc}")
        q.put_nowait({"type": "done", "exit_code": 1, "result": None})
        job["status"] = "error"

    finally:
        root.removeHandler(handler)


# ─── Pipeline details generator ───────────────────────────────────────────────

_MECHANISM: dict[tuple[str, str], str] = {
    ("s3",             "lambda"):          "S3 Event Notification → Lambda invoke",
    ("s3",             "sqs"):             "S3 Event Notification → SQS",
    ("sqs",            "lambda"):          "SQS Event Source Mapping (polling)",
    ("lambda",         "sqs"):             "sqs:SendMessage",
    ("lambda",         "sns"):             "sns:Publish",
    ("lambda",         "stepfunctions"):   "states:StartExecution",
    ("lambda",         "dynamodb"):        "dynamodb:PutItem / GetItem / UpdateItem",
    ("lambda",         "s3"):              "s3:PutObject",
    ("lambda",         "lambda"):          "lambda:InvokeFunction",
    ("lambda",         "glue"):            "glue:StartJobRun",
    ("lambda",         "kinesis_streams"): "kinesis:PutRecord",
    ("stepfunctions",  "lambda"):          "lambda:InvokeFunction (sync task)",
    ("stepfunctions",  "glue"):            "glue:StartJobRun.sync",
    ("stepfunctions",  "dynamodb"):        "dynamodb:PutItem (SDK integration)",
    ("stepfunctions",  "s3"):              "s3:PutObject / GetObject",
    ("cloudwatch",     "sqs"):             "EventBridge target → SQS",
    ("cloudwatch",     "lambda"):          "EventBridge target → Lambda invoke",
    ("eventbridge",    "sqs"):             "EventBridge target → SQS",
    ("eventbridge",    "lambda"):          "EventBridge target → Lambda invoke",
    ("sns",            "sqs"):             "SNS subscription (protocol: sqs)",
    ("sns",            "lambda"):          "SNS subscription (protocol: lambda)",
    ("kinesis_streams", "lambda"):         "Kinesis Event Source Mapping",
    ("kinesis_streams", "kinesis_firehose"): "Firehose reads from Kinesis stream",
    ("kinesis_firehose", "s3"):            "Firehose buffered delivery → S3",
    ("kinesis_firehose", "redshift"):      "Firehose COPY → Redshift",
    ("glue",           "s3"):              "Glue crawler reads S3 path",
    ("emr",            "s3"):              "s3:GetObject / PutObject",
    ("dms",            "s3"):              "DMS full-load / CDC → S3",
    ("dms",            "redshift"):        "DMS full-load / CDC → Redshift",
}

_CATEGORY: dict[str, str] = {
    "s3":                "Storage",
    "dynamodb":          "Storage",
    "redshift":          "Storage",
    "aurora":            "Storage",
    "lake_formation":    "Governance",
    "glue_data_catalog": "Governance",
    "iam":               "Governance",
    "sqs":               "Messaging",
    "sns":               "Messaging",
    "kinesis_streams":   "Streaming",
    "kinesis_firehose":  "Streaming",
    "msk":               "Streaming",
    "lambda":            "Compute",
    "ec2":               "Compute",
    "stepfunctions":     "Orchestration",
    "glue":              "Analytics",
    "athena":            "Analytics",
    "emr":               "Analytics",
    "kinesis_analytics": "Analytics",
    "glue_databrew":     "Analytics",
    "cloudwatch":        "Scheduler",
    "eventbridge":       "Scheduler",
    "dms":               "Migration",
}

_CAT_ICON: dict[str, str] = {
    "Storage":      "💾",
    "Messaging":    "📬",
    "Streaming":    "🌊",
    "Compute":      "⚡",
    "Orchestration":"🔄",
    "Analytics":    "🔍",
    "Scheduler":    "⏰",
    "Governance":   "🔐",
    "Migration":    "🔀",
}


def _generate_details(result, request: PipelineRequest) -> dict:
    """Derive full pipeline details from blueprint data — zero LLM calls."""
    from collections import defaultdict, deque

    blueprints   = result.blueprints
    svc_map      = {s.name: s for s in request.services}
    integrations = request.integrations

    out_edges: dict[str, list] = defaultdict(list)
    in_edges:  dict[str, list] = defaultdict(list)
    for i in integrations:
        out_edges[i.source].append(i)
        in_edges[i.target].append(i)

    # ── Topological layer assignment (longest-path) ──────────────────────────
    layer: dict[str, int] = {s.name: 0 for s in request.services}
    in_deg = defaultdict(int)
    for i in integrations:
        in_deg[i.target] += 1
    queue: deque = deque(s.name for s in request.services if in_deg[s.name] == 0)
    visited: set = set()
    while queue:
        n = queue.popleft()
        if n in visited:
            continue
        visited.add(n)
        for e in out_edges[n]:
            new_l = layer[n] + 1
            if new_l > layer.get(e.target, 0):
                layer[e.target] = new_l
            queue.append(e.target)

    max_layer = max(layer.values()) if layer else 0

    def _mechanism(src_type: str, tgt_type: str, event: str) -> str:
        return _MECHANISM.get((src_type, tgt_type), event or "direct integration")

    def _cat(svc_type: str) -> str:
        return _CATEGORY.get(svc_type, "Other")

    # ── Group services by category ───────────────────────────────────────────
    by_cat: dict[str, list] = defaultdict(list)
    for s in request.services:
        by_cat[_cat(s.type)].append(s.name)

    # ── Build text report ────────────────────────────────────────────────────
    DIV = "=" * 48
    lines: list[str] = []

    def section(title: str) -> None:
        lines.extend(["", DIV, title, DIV, ""])

    # ── Data flow (topological walk) ─────────────────────────────────────────
    section("📊  DATA FLOW")
    seen_flow: set = set()

    def walk(name: str, indent: int = 0) -> None:
        if name in seen_flow:
            return
        seen_flow.add(name)
        svc = svc_map.get(name)
        if not svc:
            return
        bp  = blueprints.get(name)
        pad = "  " * indent
        pfx = "└── " if indent > 0 else ""
        cat = _cat(svc.type)
        lines.append(f"{pad}{pfx}{_CAT_ICON.get(cat,'☁️')} [{svc.type.upper()}]  {name}")

        if bp:
            key_perms = [p for p in bp.iam_permissions
                         if not p.startswith("logs:") and not p.startswith("ec2:")]
            if key_perms:
                lines.append(f"{pad}    IAM:  {', '.join(key_perms[:4])}")
            for k in list(bp.env_vars)[:3]:
                lines.append(f"{pad}    ENV:  {k}")

        incoming_types = [svc_map[e.source].type for e in in_edges[name] if e.source in svc_map]
        if incoming_types:
            lines.append(f"{pad}    ← receives from:  {', '.join(set(incoming_types))}")

        for e in out_edges[name]:
            tgt = svc_map.get(e.target)
            if not tgt:
                continue
            mech = _mechanism(svc.type, tgt.type, e.event)
            lines.append(f"{pad}    ↓  ({mech})")
            walk(e.target, indent + 1)

    sources = [s.name for s in request.services if not in_edges[s.name]]
    # Schedulers last so main flow reads top-to-bottom
    main_sources = [s for s in sources if svc_map[s].type not in ("cloudwatch", "eventbridge")]
    sched_sources = [s for s in sources if svc_map[s].type in ("cloudwatch", "eventbridge")]
    for s in main_sources:
        walk(s)
        lines.append("")
    if sched_sources:
        section("⏰  SCHEDULER FLOWS")
        for s in sched_sources:
            walk(s)
            lines.append("")

    # ── Category groups ──────────────────────────────────────────────────────
    for cat, names in sorted(by_cat.items()):
        if cat in ("Scheduler",):   # already shown above
            continue
        icon = _CAT_ICON.get(cat, "☁️")
        section(f"{icon}  {cat.upper()} SERVICES")
        for name in names:
            svc = svc_map[name]
            bp  = blueprints.get(name)
            lines.append(f"  {name}  ({svc.type})")
            if bp and bp.required_configuration:
                for k, v in list(bp.required_configuration.items())[:4]:
                    lines.append(f"    {k}: {v}")
            lines.append("")

    # ── Access patterns ──────────────────────────────────────────────────────
    section("🔐  ACCESS PATTERNS")
    seen_pat: set = set()
    for i in integrations:
        src = svc_map.get(i.source)
        tgt = svc_map.get(i.target)
        if not src or not tgt:
            continue
        key = (src.type, tgt.type)
        if key in seen_pat:
            continue
        seen_pat.add(key)
        mech = _mechanism(src.type, tgt.type, i.event)
        bp_tgt = blueprints.get(i.target)
        relevant = [p for p in (bp_tgt.iam_permissions if bp_tgt else [])
                    if not p.startswith("logs:") and not p.startswith("ec2:")]
        lines.append(f"  {src.type.upper()}  →  {tgt.type.upper()}")
        lines.append(f"    Mechanism:   {mech}")
        if relevant:
            lines.append(f"    Permissions: {', '.join(relevant[:5])}")
        lines.append("")

    # ── Pipeline summary ─────────────────────────────────────────────────────
    section("🔄  PIPELINE SUMMARY")
    lines.append(f"  Pipeline:    {result.pipeline_name}")
    lines.append(f"  Services:    {len(request.services)}")
    lines.append(f"  Connections: {len(integrations)}")
    lines.append(f"  Depth:       {max_layer + 1} layers")
    lines.append("")
    # ASCII chain — main path
    def main_path(start: str, visited_p: set | None = None) -> list[str]:
        if visited_p is None:
            visited_p = set()
        if start in visited_p:
            return []
        visited_p.add(start)
        path = [start]
        for e in out_edges[start]:
            if e.target not in visited_p:
                path.extend(main_path(e.target, visited_p))
                break
        return path

    for src in main_sources:
        path = main_path(src)
        short = [f"{svc_map[n].type}({n})" if n in svc_map else n for n in path[:7]]
        chain = "  →  ".join(short)
        if len(path) > 7:
            chain += f"  → ... ({len(path)} total)"
        lines.append(f"  {chain}")
    if sched_sources:
        for src in sched_sources:
            path = main_path(src)
            short = [f"{svc_map[n].type}({n})" for n in path[:4] if n in svc_map]
            lines.append(f"  ⏰ {' → '.join(short)}")
    lines.append("")

    text = "\n".join(lines)

    # ── Structured data for the flow diagram ─────────────────────────────────
    svc_data = [
        {"name": s.name, "type": s.type, "category": _cat(s.type), "layer": layer.get(s.name, 0)}
        for s in request.services
    ]
    int_data = [
        {"source": i.source, "target": i.target,
         "event": i.event, "mechanism": _mechanism(svc_map[i.source].type, svc_map[i.target].type, i.event)}
        for i in integrations if i.source in svc_map and i.target in svc_map
    ]

    return {"text": text, "services": svc_data, "integrations": int_data,
            "pipeline_name": result.pipeline_name}


# ─── Pipeline matrix generator ───────────────────────────────────────────────

def _generate_matrix(result, request: PipelineRequest) -> list[dict]:
    """Build a flat list of every AWS resource the pipeline will create.

    Includes primary resources (S3 bucket, Lambda function, …) plus the IAM
    role and policy created for every principal service.  ARN values use
    Terraform interpolation references — they are only resolved after apply.
    """
    from engine.naming import suffixed_name

    rows: list[dict] = []
    blueprints = result.blueprints
    svc_map = {s.name: s for s in request.services}

    for svc_name, bp in blueprints.items():
        svc = svc_map.get(svc_name)
        if not svc:
            continue
        stype = svc.type
        tf_res, arn_attr = _TF_RESOURCE_MAP.get(stype, (f"aws_{stype}", "arn"))
        display = stype.replace("_", " ").title()

        rows.append({
            "Component Type": display,
            "AWS Resource Type": tf_res,
            "AWS Name": bp.resource_name,
            "Terraform ARN Reference": f"${{{tf_res}.{bp.resource_label}.{arn_attr}}}",
            "Category": "Primary Resource",
        })

        if bp.is_principal:
            role_label  = f"{bp.resource_label}_role"
            role_name   = suffixed_name(bp.resource_name, "-role", 64)
            policy_label = f"{bp.resource_label}_policy"
            policy_name  = suffixed_name(bp.resource_name, "-policy", 128)

            rows.append({
                "Component Type": "IAM Role",
                "AWS Resource Type": "aws_iam_role",
                "AWS Name": role_name,
                "Terraform ARN Reference": f"${{aws_iam_role.{role_label}.arn}}",
                "Category": "IAM",
            })
            rows.append({
                "Component Type": "IAM Policy",
                "AWS Resource Type": "aws_iam_policy",
                "AWS Name": policy_name,
                "Terraform ARN Reference": f"${{aws_iam_policy.{policy_label}.arn}}",
                "Category": "IAM",
            })

    return rows


# ─── Routes ───────────────────────────────────────────────────────────────────

@app.get("/", response_class=HTMLResponse)
async def index() -> HTMLResponse:
    return HTMLResponse(TEMPLATE_PATH.read_text())


# ─── Pipeline Architect: run from PipelineRequest directly ────────────────────

async def _execute_job_from_request(job_id: str, request: PipelineRequest) -> None:
    """Like _execute_job but takes a PipelineRequest directly (no diagram reading)."""
    job = _jobs[job_id]
    q = job["log_q"]

    def _qlog(level, msg):
        q.put_nowait({
            "type": "log", "level": level,
            "time": datetime.now().strftime("%H:%M:%S"),
            "logger": "pipeline", "message": msg,
        })

    tracker = _ProgressTracker(total_services=len(request.services))
    handler = _JobLogHandler(q, tracker)
    handler.setLevel(logging.INFO)
    root = logging.getLogger()
    root.addHandler(handler)

    try:
        _qlog("INFO", f"Pipeline Architect: '{request.pipeline_name}' — {len(request.services)} service(s), {len(request.integrations)} integration(s).")
        tracker.__init__(total_services=len(request.services))

        q.put_nowait({
            "type": "services_init",
            "services": [{"name": s.name, "type": s.type} for s in request.services],
            "integrations": [{"source": i.source, "target": i.target, "event": i.event} for i in request.integrations],
        })
        q.put_nowait({"type": "progress", "pct": 10,
                      "stage": f"{len(request.services)} services queued"})

        out_dir = Path("output") / request.pipeline_name
        result = await asyncio.to_thread(build_pipeline, request, out_dir, False)

        # Save pipeline YAML for historical viewer
        if result.main_tf_path:
            try:
                yaml_text = yaml.dump(request.model_dump(), allow_unicode=True)
                (out_dir / "pipeline.yaml").write_text(yaml_text)
            except Exception:
                pass

        hard_errors = [e for e in result.lint_errors if e.severity == "error"]
        warnings    = [e for e in result.lint_errors if e.severity == "warning"]
        exit_code   = 1 if hard_errors else 0

        if hard_errors:
            for err in hard_errors:
                _qlog("ERROR", err.format())

        # Surface config validation errors (pre-render, before terraform)
        v_errors   = [e for e in result.validation_errors if e.severity == "error"]
        v_warnings = [e for e in result.validation_errors if e.severity == "warning"]
        if v_errors:
            _qlog("WARNING", f"⚠️  {len(v_errors)} config validation error(s) — "
                             "terraform apply may fail:")
            for ve in v_errors:
                _qlog("WARNING", f"  • [{ve.rule}] {ve.service_name}: {ve.message}")
        if v_warnings:
            _qlog("INFO", f"ℹ️  {len(v_warnings)} pre-deploy warning(s):")
            for vw in v_warnings:
                _qlog("INFO", f"  • [{vw.rule}] {vw.service_name}: {vw.message}")

        result_info = {
            "pipeline_name":   result.pipeline_name,
            "main_tf_path":    str(result.main_tf_path) if result.main_tf_path else None,
            "services":        len(result.blueprints),
            "lint_errors":     len(hard_errors),
            "lint_warnings":   len(warnings),
            "config_errors":   len(v_errors),
            "config_warnings": len(v_warnings),
            "region":          request.region,
        }

        job["status"] = "done" if exit_code == 0 else "error"
        job["result_info"] = result_info

        try:
            job["details"] = _generate_details(result, request)
        except Exception as exc:
            job["details"] = {"text": f"Details unavailable: {exc}", "services": [], "integrations": []}

        try:
            job["matrix"] = _generate_matrix(result, request)
        except Exception:
            job["matrix"] = []

        q.put_nowait({"type": "progress", "pct": 100,
                      "stage": "Complete" if exit_code == 0 else "Finished with errors"})
        q.put_nowait({"type": "done", "exit_code": exit_code, "result": result_info})

    except asyncio.CancelledError:
        _qlog("WARNING", "Pipeline cancelled by user.")
        q.put_nowait({"type": "progress", "pct": 0, "stage": "Cancelled"})
        q.put_nowait({"type": "done", "exit_code": 2, "result": None, "cancelled": True})
        job["status"] = "cancelled"

    except Exception as exc:
        _qlog("ERROR", f"Unexpected error: {exc}")
        q.put_nowait({"type": "done", "exit_code": 1, "result": None})
        job["status"] = "error"

    finally:
        root.removeHandler(handler)


@app.post("/run-from-diagram")
async def run_from_diagram_endpoint(req: Request) -> JSONResponse:
    """Accept a PipelineRequest JSON (from the Pipeline Architect canvas) and run the engine."""
    try:
        body = await req.json()
    except Exception:
        return JSONResponse(status_code=400, content={"detail": "Invalid JSON body"})

    # Allow UI to supply project/cost-center that override YAML defaults
    if "business_unit" in body and body["business_unit"]:
        body.setdefault("business_unit", body["business_unit"])
    if "cost_center" in body and body["cost_center"]:
        body.setdefault("cost_center", body["cost_center"])

    try:
        request = PipelineRequest.model_validate(body)
    except Exception as exc:
        return JSONResponse(status_code=422, content={"detail": f"Invalid pipeline spec: {exc}"})

    job_id = uuid.uuid4().hex
    log_q: stdlib_queue.SimpleQueue = stdlib_queue.SimpleQueue()
    _jobs[job_id] = {
        "status": "running", "result_info": None,
        "log_q": log_q, "task": None,
        "details": None, "matrix": [], "plan_text": "",
    }
    task = asyncio.create_task(_execute_job_from_request(job_id, request))
    _jobs[job_id]["task"] = task
    return JSONResponse({"job_id": job_id})


@app.post("/run")
async def run_pipeline(
    file: UploadFile = File(...),
    hint: str = Form(default=""),
    business_unit: str = Form(default=""),
    cost_center: str = Form(default=""),
) -> JSONResponse:
    """Accept a diagram upload and start the pipeline. Returns job_id."""
    ext = Path(file.filename or "").suffix.lower()
    if ext not in SUPPORTED_EXTENSIONS:
        return JSONResponse(
            status_code=400,
            content={"detail": f"Unsupported file type '{ext}'. Use PNG, JPEG, WebP or GIF."},
        )

    job_id    = uuid.uuid4().hex
    save_path = UPLOAD_DIR / f"{job_id}{ext}"
    save_path.write_bytes(await file.read())

    log_q: stdlib_queue.SimpleQueue = stdlib_queue.SimpleQueue()
    _jobs[job_id] = {
        "status": "running", "result_info": None,
        "log_q": log_q, "task": None,
        "business_unit": business_unit.strip() or None,
        "cost_center": cost_center.strip() or None,
    }

    task = asyncio.create_task(_execute_job(job_id, save_path))
    _jobs[job_id]["task"] = task

    return JSONResponse({"job_id": job_id})


@app.get("/details/{job_id}")
async def get_pipeline_details(job_id: str) -> JSONResponse:
    """Return the generated pipeline details for a completed job."""
    job = _jobs.get(job_id)
    if not job:
        return JSONResponse(status_code=404, content={"detail": "Job not found"})
    details = job.get("details")
    if not details:
        return JSONResponse(status_code=404, content={"detail": "Details not yet available"})
    return JSONResponse(details)


@app.delete("/cancel/{job_id}")
async def cancel_job(job_id: str) -> JSONResponse:
    job = _jobs.get(job_id)
    if not job:
        return JSONResponse(status_code=404, content={"detail": "Job not found"})
    task: asyncio.Task | None = job.get("task")
    if task and not task.done():
        task.cancel()
        return JSONResponse({"cancelled": True})
    return JSONResponse({"cancelled": False, "detail": "Job already finished"})


@app.websocket("/ws/{job_id}")
async def websocket_logs(websocket: WebSocket, job_id: str) -> None:
    """Stream log events and final result for a running job."""
    await websocket.accept()

    job = _jobs.get(job_id)
    if not job:
        await websocket.send_json({"type": "error", "message": f"Unknown job: {job_id}"})
        await websocket.close()
        return

    q: stdlib_queue.SimpleQueue = job["log_q"]

    try:
        while True:
            sent = 0
            while True:
                try:
                    msg = q.get_nowait()
                    await websocket.send_json(msg)
                    sent += 1
                    if msg.get("type") == "done":
                        await websocket.close()
                        return
                except stdlib_queue.Empty:
                    break

            if job["status"] in ("done", "error") and sent == 0:
                await websocket.send_json({
                    "type": "done",
                    "exit_code": 0 if job["status"] == "done" else 1,
                    "result": job.get("result_info"),
                })
                await websocket.close()
                return

            await asyncio.sleep(0.15)

    except WebSocketDisconnect:
        pass


# ─── Deploy routes ────────────────────────────────────────────────────────────

@app.post("/deploy/plan/{job_id}")
async def deploy_plan(job_id: str) -> JSONResponse:
    """Run terraform init + plan for a completed pipeline job. Returns plan text."""
    job = _jobs.get(job_id)
    if not job:
        return JSONResponse(status_code=404, content={"detail": "Job not found"})
    result_info = job.get("result_info")
    if not result_info or not result_info.get("main_tf_path"):
        return JSONResponse(status_code=400, content={"detail": "Pipeline not yet complete or has errors"})

    work_dir = Path(result_info["main_tf_path"]).resolve().parent

    from tools.terraform_cli import init_for_deploy, plan as tf_plan

    def _run_plan() -> dict:
        from tools.terraform_fix import attempt_autofix, classify_errors
        from tools.autofix_agent import classify_all_errors, propose_fix

        init_res = init_for_deploy(work_dir)
        if not init_res.ok:
            return {"ok": False, "error": f"terraform init failed:\n{init_res.stderr}"}

        # First plan attempt
        plan_res = tf_plan(work_dir)
        if plan_res.ok:
            return {"ok": True, "plan": plan_res.stdout}

        # Plan failed — classify errors
        errors = plan_res.stderr + "\n" + plan_res.stdout
        categories = classify_all_errors(errors)

        # Try the existing minor-error auto-fix first (name length, invalid chars)
        from tools.terraform_fix import classify_errors as classify_minor
        minor_severity = classify_minor(errors)

        if minor_severity == "minor":
            fix_result = attempt_autofix(
                work_dir, errors,
                api_key=_admin_config.get("anthropic_api_key"),
            )
            if fix_result["action"] == "fixed":
                # Already initialised from earlier — no need to re-init
                # unless provider requirements changed (they don't for minor fixes).
                plan_res2 = tf_plan(work_dir)
                if plan_res2.ok:
                    return {"ok": True, "plan": plan_res2.stdout,
                            "autofix_applied": True,
                            "autofix_note": "Minor errors were automatically fixed before planning."}
                # Minor fix didn't solve it — fall through to smart autofix
                errors = plan_res2.stderr + "\n" + plan_res2.stdout
                categories = classify_all_errors(errors)

        # Smart auto-fix: analyse with LLM and propose a fix for user confirmation
        proposal = propose_fix(
            errors, work_dir, categories,
            api_key=_admin_config.get("anthropic_api_key"),
        )

        # Store proposal in job for the confirm route
        job["autofix_proposal"] = proposal.to_dict()
        job["autofix_work_dir"] = str(work_dir)

        if proposal.fixable:
            return {
                "ok": False,
                "error": errors,
                "autofix_available": True,
                "autofix_proposal": proposal.to_dict(),
            }
        else:
            return {
                "ok": False,
                "error": errors,
                "human_review": True,
                "autofix_proposal": proposal.to_dict(),
            }

    result = await asyncio.to_thread(_run_plan)
    if not result["ok"]:
        resp_content: dict[str, Any] = {
            "detail": result["error"],
            "human_review": result.get("human_review", False),
        }
        if result.get("autofix_available"):
            resp_content["autofix_available"] = True
            resp_content["autofix_proposal"] = result["autofix_proposal"]
            return JSONResponse(status_code=422, content=resp_content)
        if result.get("autofix_proposal"):
            resp_content["autofix_proposal"] = result["autofix_proposal"]
        status = 422 if result.get("human_review") else 500
        return JSONResponse(status_code=status, content=resp_content)
    resp: dict[str, Any] = {"plan": result["plan"]}
    if result.get("autofix_applied"):
        resp["autofix_note"] = result["autofix_note"]
    # Cache plan text for download
    if job:
        job["plan_text"] = result["plan"]
    return JSONResponse(resp)


@app.post("/deploy/apply/{job_id}")
async def deploy_apply(job_id: str) -> JSONResponse:
    """Start terraform apply for a job that has already been planned. Returns deploy_id."""
    job = _jobs.get(job_id)
    if not job:
        return JSONResponse(status_code=404, content={"detail": "Job not found"})
    result_info = job.get("result_info")
    if not result_info or not result_info.get("main_tf_path"):
        return JSONResponse(status_code=400, content={"detail": "Pipeline not complete"})

    work_dir = Path(result_info["main_tf_path"]).resolve().parent
    plan_file = work_dir / "tfplan"
    if not plan_file.exists():
        return JSONResponse(status_code=400, content={"detail": "No plan file — run /deploy/plan first"})

    deploy_id = uuid.uuid4().hex
    log_q: stdlib_queue.SimpleQueue = stdlib_queue.SimpleQueue()
    _deploys[deploy_id] = {"status": "running", "log_q": log_q, "task": None, "work_dir": str(work_dir)}

    async def _run_apply() -> None:
        from tools.terraform_cli import apply_streaming, get_output
        deploy = _deploys[deploy_id]
        q = deploy["log_q"]

        def _qlog(level: str, msg: str) -> None:
            q.put_nowait({"type": "log", "level": level,
                          "time": datetime.now().strftime("%H:%M:%S"), "message": msg})

        try:
            _qlog("INFO", "Starting terraform apply…")
            exit_code = 0
            for line in apply_streaming(work_dir):
                if line.startswith("__EXIT_CODE_"):
                    exit_code = int(line.removeprefix("__EXIT_CODE_").removesuffix("__"))
                elif line.strip():
                    _qlog("INFO", line)

            if exit_code == 0:
                _qlog("SUCCESS", "✓ Deployment complete!")
                out_res = get_output(work_dir)
                if out_res.ok and out_res.stdout.strip():
                    _qlog("INFO", "--- Outputs ---")
                    for ln in out_res.stdout.strip().splitlines():
                        _qlog("INFO", ln)
                deploy["status"] = "done"
                q.put_nowait({"type": "done", "exit_code": 0})
            else:
                _qlog("ERROR", "✗ terraform apply failed.")
                deploy["status"] = "error"
                q.put_nowait({"type": "done", "exit_code": 1})
        except Exception as exc:
            _qlog("ERROR", f"Unexpected error: {exc}")
            deploy["status"] = "error"
            q.put_nowait({"type": "done", "exit_code": 1})

    task = asyncio.create_task(_run_apply())
    _deploys[deploy_id]["task"] = task
    return JSONResponse({"deploy_id": deploy_id})


@app.websocket("/ws/deploy/{deploy_id}")
async def websocket_deploy(websocket: WebSocket, deploy_id: str) -> None:
    """Stream terraform apply log lines for a running deployment."""
    await websocket.accept()
    deploy = _deploys.get(deploy_id)
    if not deploy:
        await websocket.send_json({"type": "error", "message": f"Unknown deploy: {deploy_id}"})
        await websocket.close()
        return

    q: stdlib_queue.SimpleQueue = deploy["log_q"]
    try:
        while True:
            sent = 0
            while True:
                try:
                    msg = q.get_nowait()
                    await websocket.send_json(msg)
                    sent += 1
                    if msg.get("type") == "done":
                        await websocket.close()
                        return
                except stdlib_queue.Empty:
                    break
            if deploy["status"] in ("done", "error") and sent == 0:
                await websocket.send_json({"type": "done",
                                           "exit_code": 0 if deploy["status"] == "done" else 1})
                await websocket.close()
                return
            await asyncio.sleep(0.15)
    except WebSocketDisconnect:
        pass


# ─── Auto-fix confirm/apply routes ───────────────────────────────────────────

@app.post("/deploy/autofix/confirm/{job_id}")
async def deploy_autofix_confirm(job_id: str) -> JSONResponse:
    """Apply a previously proposed auto-fix. User has reviewed and confirmed."""
    job = _jobs.get(job_id)
    if not job:
        return JSONResponse(status_code=404, content={"detail": "Job not found"})

    proposal_dict = job.get("autofix_proposal")
    if not proposal_dict:
        return JSONResponse(status_code=400, content={"detail": "No autofix proposal available"})

    work_dir = Path(job.get("autofix_work_dir", ""))
    if not work_dir.exists():
        return JSONResponse(status_code=400, content={"detail": "Work directory not found"})

    from tools.autofix_agent import AutofixProposal, apply_proposal

    proposal = AutofixProposal(**proposal_dict)

    if not proposal.fixable:
        return JSONResponse(status_code=400, content={
            "detail": "This proposal is not auto-fixable.",
            "user_action_required": proposal.user_action_required,
        })

    def _apply() -> dict:
        success, msg = apply_proposal(proposal, work_dir)
        if not success:
            return {"ok": False, "message": msg}

        if proposal.requires_regeneration:
            return {
                "ok": True,
                "message": msg,
                "requires_regeneration": True,
            }

        # HCL-only fix: re-run plan to verify
        from tools.terraform_cli import init_for_deploy, plan as tf_plan
        init_res = init_for_deploy(work_dir)
        if not init_res.ok:
            return {"ok": False, "message": f"terraform init failed after fix:\n{init_res.stderr}"}
        plan_res = tf_plan(work_dir)
        if plan_res.ok:
            return {"ok": True, "message": msg, "plan": plan_res.stdout,
                    "requires_regeneration": False}
        return {"ok": False, "message": f"Fix applied but plan still fails:\n{plan_res.stderr}\n{plan_res.stdout}"}

    result = await asyncio.to_thread(_apply)

    if not result["ok"]:
        return JSONResponse(status_code=422, content={"detail": result["message"]})

    resp: dict[str, Any] = {
        "message": result["message"],
        "requires_regeneration": result.get("requires_regeneration", False),
    }
    if result.get("plan"):
        resp["plan"] = result["plan"]
        job["plan_text"] = result["plan"]
    # Clear the proposal
    job.pop("autofix_proposal", None)
    return JSONResponse(resp)


@app.post("/deploy/autofix/regenerate/{job_id}")
async def deploy_autofix_regenerate(job_id: str) -> JSONResponse:
    """Regenerate the pipeline from the (now fixed) pipeline YAML.

    Called when an autofix modified pipeline.yaml or specs and requires
    a full rebuild. Returns a new job_id for the regenerated pipeline.
    """
    job = _jobs.get(job_id)
    if not job:
        return JSONResponse(status_code=404, content={"detail": "Job not found"})

    work_dir_str = job.get("autofix_work_dir", "")
    work_dir = Path(work_dir_str)
    yaml_path = work_dir / "pipeline.yaml"

    if not yaml_path.exists():
        return JSONResponse(status_code=400, content={"detail": "No pipeline.yaml found for regeneration"})

    try:
        raw = yaml.safe_load(yaml_path.read_text())
        request = PipelineRequest.model_validate(raw)
    except Exception as e:
        return JSONResponse(status_code=400, content={"detail": f"Invalid pipeline YAML: {e}"})

    # Create a new job for the regenerated pipeline
    new_job_id = uuid.uuid4().hex
    log_q: stdlib_queue.SimpleQueue = stdlib_queue.SimpleQueue()
    new_job = {
        "status": "running",
        "log_q": log_q,
        "task": None,
        "regenerated_from": job_id,
    }
    _jobs[new_job_id] = new_job

    # Run the pipeline generation in background
    task = asyncio.create_task(_execute_job_from_request(new_job_id, request))
    new_job["task"] = task

    return JSONResponse({
        "new_job_id": new_job_id,
        "message": "Pipeline regeneration started with the fixed configuration.",
    })


# ─── Destroy routes ───────────────────────────────────────────────────────────

# destroy_id → { status, log_q, task, work_dir }
_destroys: dict[str, dict] = {}

# ─── Admin config (in-memory, session-scoped) ─────────────────────────────────
# Keys entered via the Admin panel override .env credentials for this session.
_admin_config: dict[str, str] = {}


@app.post("/deploy/destroy/{job_id}")
async def deploy_destroy(job_id: str) -> JSONResponse:
    """Start terraform destroy for a successfully deployed job. Returns destroy_id."""
    job = _jobs.get(job_id)
    if not job:
        return JSONResponse(status_code=404, content={"detail": "Job not found"})
    result_info = job.get("result_info")
    if not result_info or not result_info.get("main_tf_path"):
        return JSONResponse(status_code=400, content={"detail": "Pipeline not complete"})

    work_dir = Path(result_info["main_tf_path"]).resolve().parent
    if not (work_dir / ".terraform").exists():
        return JSONResponse(status_code=400, content={"detail": "No terraform state — deploy first"})

    destroy_id = uuid.uuid4().hex
    log_q: stdlib_queue.SimpleQueue = stdlib_queue.SimpleQueue()
    _destroys[destroy_id] = {"status": "running", "log_q": log_q, "task": None, "work_dir": str(work_dir)}

    async def _run_destroy() -> None:
        from tools.terraform_cli import destroy_streaming
        d = _destroys[destroy_id]
        q = d["log_q"]

        def _qlog(level: str, msg: str) -> None:
            q.put_nowait({"type": "log", "level": level,
                          "time": datetime.now().strftime("%H:%M:%S"), "message": msg})

        try:
            _qlog("WARNING", "⚠️  Starting terraform destroy — deleting all pipeline resources…")
            exit_code = 0
            for line in destroy_streaming(work_dir):
                if line.startswith("__EXIT_CODE_"):
                    exit_code = int(line.removeprefix("__EXIT_CODE_").removesuffix("__"))
                elif line.strip():
                    _qlog("INFO", line)

            if exit_code == 0:
                _qlog("SUCCESS", "✓ All resources destroyed.")
                d["status"] = "done"
                q.put_nowait({"type": "done", "exit_code": 0})
            else:
                _qlog("ERROR", "✗ terraform destroy failed.")
                d["status"] = "error"
                q.put_nowait({"type": "done", "exit_code": 1})
        except Exception as exc:
            _qlog("ERROR", f"Unexpected error: {exc}")
            d["status"] = "error"
            q.put_nowait({"type": "done", "exit_code": 1})

    task = asyncio.create_task(_run_destroy())
    _destroys[destroy_id]["task"] = task
    return JSONResponse({"destroy_id": destroy_id})


@app.websocket("/ws/destroy/{destroy_id}")
async def websocket_destroy(websocket: WebSocket, destroy_id: str) -> None:
    """Stream terraform destroy log lines."""
    await websocket.accept()
    d = _destroys.get(destroy_id)
    if not d:
        await websocket.send_json({"type": "error", "message": f"Unknown destroy: {destroy_id}"})
        await websocket.close()
        return

    q: stdlib_queue.SimpleQueue = d["log_q"]
    try:
        while True:
            sent = 0
            while True:
                try:
                    msg = q.get_nowait()
                    await websocket.send_json(msg)
                    sent += 1
                    if msg.get("type") == "done":
                        await websocket.close()
                        return
                except stdlib_queue.Empty:
                    break
            if d["status"] in ("done", "error") and sent == 0:
                await websocket.send_json({"type": "done",
                                           "exit_code": 0 if d["status"] == "done" else 1})
                await websocket.close()
                return
            await asyncio.sleep(0.15)
    except WebSocketDisconnect:
        pass


# ─── Download endpoints ───────────────────────────────────────────────────────

@app.get("/matrix/{job_id}")
async def download_matrix(job_id: str):
    """Return pipeline matrix as a downloadable CSV file."""
    job = _jobs.get(job_id)
    if not job:
        return JSONResponse(status_code=404, content={"detail": "Job not found"})
    rows = job.get("matrix")
    if not rows:
        return JSONResponse(status_code=404, content={"detail": "Matrix not yet available"})

    buf = io.StringIO()
    cols = ["Component Type", "AWS Resource Type", "AWS Name", "Terraform ARN Reference", "Category"]
    writer = csv.DictWriter(buf, fieldnames=cols)
    writer.writeheader()
    writer.writerows(rows)
    buf.seek(0)

    pipeline_name = job.get("result_info", {}).get("pipeline_name", "pipeline")
    filename = f"{pipeline_name}_matrix.csv"
    return StreamingResponse(
        iter([buf.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@app.get("/plan/{job_id}")
async def download_plan(job_id: str):
    """Return cached terraform plan text as a downloadable file."""
    job = _jobs.get(job_id)
    if not job:
        return JSONResponse(status_code=404, content={"detail": "Job not found"})
    plan_text = job.get("plan_text")
    if not plan_text:
        return JSONResponse(status_code=404, content={"detail": "Plan not available — run Deploy first"})

    pipeline_name = job.get("result_info", {}).get("pipeline_name", "pipeline")
    filename = f"{pipeline_name}_tfplan.txt"
    return StreamingResponse(
        iter([plan_text]),
        media_type="text/plain",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


# ─── Admin routes ─────────────────────────────────────────────────────────────

@app.post("/admin/api-key")
async def admin_set_api_key(request: Request) -> JSONResponse:
    """Store Anthropic API key for this session."""
    body = await request.json()
    key = (body.get("api_key") or "").strip()
    if not key:
        return JSONResponse(status_code=400, content={"detail": "api_key required"})
    _admin_config["anthropic_api_key"] = key
    masked = key[:8] + "…" + key[-4:] if len(key) > 12 else "***"
    return JSONResponse({"ok": True, "masked": masked})


@app.get("/admin/api-key/status")
async def admin_api_key_status() -> JSONResponse:
    key = _admin_config.get("anthropic_api_key", "")
    if key:
        masked = key[:8] + "…" + key[-4:] if len(key) > 12 else "***"
        return JSONResponse({"configured": True, "masked": masked})
    return JSONResponse({"configured": False})


@app.post("/admin/aws-keys")
async def admin_set_aws_keys(request: Request) -> JSONResponse:
    """Store AWS credentials for this session and inject into Terraform calls."""
    body = await request.json()
    access_key = (body.get("access_key_id") or "").strip()
    secret_key = (body.get("secret_access_key") or "").strip()
    region = (body.get("region") or "us-east-1").strip()
    if not access_key or not secret_key:
        return JSONResponse(status_code=400, content={"detail": "access_key_id and secret_access_key required"})
    _admin_config["aws_access_key_id"] = access_key
    _admin_config["aws_secret_access_key"] = secret_key
    _admin_config["aws_region"] = region
    from tools import terraform_cli as _tf_cli
    _tf_cli.set_extra_env({
        "AWS_ACCESS_KEY_ID": access_key,
        "AWS_SECRET_ACCESS_KEY": secret_key,
        "AWS_DEFAULT_REGION": region,
    })
    return JSONResponse({"ok": True, "region": region,
                         "masked_key": access_key[:4] + "…" + access_key[-4:]})


@app.get("/admin/aws-keys/status")
async def admin_aws_keys_status() -> JSONResponse:
    key = _admin_config.get("aws_access_key_id", "")
    if key:
        return JSONResponse({
            "configured": True,
            "masked_key": key[:4] + "…" + key[-4:],
            "region": _admin_config.get("aws_region", "us-east-1"),
        })
    return JSONResponse({"configured": False})


@app.get("/admin/pipelines")
async def admin_list_pipelines() -> JSONResponse:
    """List all historical pipeline runs from the output/ directory."""
    output_dir = Path("output")
    pipelines = []
    if output_dir.exists():
        for d in sorted(output_dir.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True):
            if not d.is_dir():
                continue
            yaml_file = d / "pipeline.yaml"
            tf_file = d / "main.tf"
            if not yaml_file.exists() and not tf_file.exists():
                continue
            ref = yaml_file if yaml_file.exists() else tf_file
            mtime = ref.stat().st_mtime
            has_state = (d / "terraform.tfstate").exists()
            # Count services if YAML available
            svc_count = 0
            if yaml_file.exists():
                try:
                    raw = yaml.safe_load(yaml_file.read_text())
                    svc_count = len(raw.get("services", []))
                except Exception:
                    pass
            pipelines.append({
                "name": d.name,
                "created": datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M"),
                "services": svc_count,
                "has_state": has_state,
            })
    return JSONResponse({"pipelines": pipelines})


@app.get("/admin/pipeline/{name}")
async def admin_get_pipeline(name: str) -> JSONResponse:
    """Return services + integrations for a historical pipeline (for diagram rendering).

    Resolution order:
      1. output/<name>/pipeline.yaml  — saved by the engine on each successful run
      2. input_architecture_dgm/*.generated.yaml  — fallback for runs made before
         pipeline.yaml saving was added; picks the most-recent matching file.
    """
    # 1. Preferred: saved alongside terraform output
    preferred = Path("output") / name / "pipeline.yaml"
    if preferred.exists():
        src = preferred
    else:
        # 2. Scan upload dir for generated YAMLs whose pipeline_name matches
        candidates = []
        for f in UPLOAD_DIR.glob("*.generated.yaml"):
            try:
                raw = yaml.safe_load(f.read_text())
                if isinstance(raw, dict) and raw.get("pipeline_name") == name:
                    candidates.append((f.stat().st_mtime, f))
            except Exception:
                continue
        if not candidates:
            return JSONResponse(status_code=404, content={
                "detail": f"No YAML found for '{name}'. Re-run the pipeline to save it."
            })
        src = max(candidates, key=lambda t: t[0])[1]

    try:
        raw = yaml.safe_load(src.read_text())
        req = PipelineRequest.model_validate(raw)
        return JSONResponse({
            "name": req.pipeline_name,
            "services": [{"name": s.name, "type": s.type} for s in req.services],
            "integrations": [
                {"source": i.source, "target": i.target, "event": i.event}
                for i in req.integrations
            ],
        })
    except Exception as exc:
        return JSONResponse(status_code=500, content={"detail": str(exc)})


@app.post("/admin/pipeline/{name}/destroy")
async def admin_destroy_pipeline(name: str) -> JSONResponse:
    """Start terraform destroy for a historical pipeline by name. Returns destroy_id."""
    # Sanitise name to prevent path traversal
    safe_name = Path(name).name
    work_dir = Path("output") / safe_name
    if not work_dir.is_dir():
        return JSONResponse(status_code=404, content={"detail": f"Pipeline '{safe_name}' not found"})
    if not (work_dir / "terraform.tfstate").exists():
        return JSONResponse(status_code=400, content={
            "detail": "No terraform state found — pipeline may not be deployed."
        })

    destroy_id = uuid.uuid4().hex
    log_q: stdlib_queue.SimpleQueue = stdlib_queue.SimpleQueue()
    _destroys[destroy_id] = {
        "status": "running", "log_q": log_q, "task": None, "work_dir": str(work_dir)
    }

    async def _run_hist_destroy() -> None:
        from tools.terraform_cli import destroy_streaming
        d = _destroys[destroy_id]
        q = d["log_q"]

        def _qlog(level: str, msg: str) -> None:
            q.put_nowait({"type": "log", "level": level,
                          "time": datetime.now().strftime("%H:%M:%S"), "message": msg})

        try:
            _qlog("WARNING", f"⚠️  Destroying resources for pipeline '{safe_name}'…")
            exit_code = 0
            for line in destroy_streaming(work_dir):
                if line.startswith("__EXIT_CODE_"):
                    exit_code = int(line.removeprefix("__EXIT_CODE_").removesuffix("__"))
                elif line.strip():
                    _qlog("INFO", line)
            if exit_code == 0:
                _qlog("SUCCESS", "✓ All resources destroyed.")
                d["status"] = "done"
                q.put_nowait({"type": "done", "exit_code": 0})
            else:
                _qlog("ERROR", "✗ terraform destroy failed.")
                d["status"] = "error"
                q.put_nowait({"type": "done", "exit_code": 1})
        except Exception as exc:
            _qlog("ERROR", f"Unexpected error: {exc}")
            d["status"] = "error"
            q.put_nowait({"type": "done", "exit_code": 1})

    task = asyncio.create_task(_run_hist_destroy())
    _destroys[destroy_id]["task"] = task
    return JSONResponse({"destroy_id": destroy_id, "pipeline_name": safe_name})


@app.delete("/admin/pipeline/{name}")
async def admin_delete_pipeline(name: str) -> JSONResponse:
    """Delete a historical pipeline's output directory (Terraform files + state)."""
    import shutil
    safe_name = Path(name).name
    work_dir = Path("output") / safe_name
    if not work_dir.is_dir():
        return JSONResponse(status_code=404, content={"detail": f"Pipeline '{safe_name}' not found"})
    try:
        shutil.rmtree(work_dir)
        return JSONResponse({"deleted": safe_name})
    except Exception as exc:
        return JSONResponse(status_code=500, content={"detail": str(exc)})


@app.get("/pipeline-builder/load/{name}")
async def pipeline_builder_load(name: str) -> JSONResponse:
    """Load a historical pipeline into a new Pipeline Builder chat session for modification.

    Creates a new chat_id, stores the pipeline YAML, and returns the same payload
    as /pipeline-builder/chat so the UI can open the modal in refinement mode.
    """
    safe_name = Path(name).name
    yaml_path = Path("output") / safe_name / "pipeline.yaml"
    if not yaml_path.exists():
        return JSONResponse(status_code=404, content={
            "detail": f"No pipeline.yaml found for '{safe_name}'."
        })
    try:
        yaml_text = yaml_path.read_text()
        parsed = yaml.safe_load(yaml_text)
        pipeline_req = PipelineRequest.model_validate(parsed)
    except Exception as exc:
        return JSONResponse(status_code=422, content={"detail": f"Invalid pipeline YAML: {exc}"})

    chat_id = uuid.uuid4().hex
    _builder_chats[chat_id] = [{
        "role": "user",
        "content": f"[Loaded historical pipeline: {safe_name}]",
    }, {
        "role": "assistant",
        "content": yaml_text,
    }]
    _builder_yaml[chat_id] = yaml_text

    return JSONResponse({
        "chat_id": chat_id,
        "yaml": yaml_text,
        "pipeline_name": pipeline_req.pipeline_name,
        "services": [{"name": s.name, "type": s.type} for s in pipeline_req.services],
        "integrations": [
            {"source": i.source, "target": i.target, "event": i.event}
            for i in pipeline_req.integrations
        ],
        "warnings": [],
    })


# ─── Deployed resources endpoint ──────────────────────────────────────────────

# Maps terraform resource type → (component label, AWS type label, name_attr, arn_attr, has_arn)
_RES_META: dict[str, tuple[str, str, str, str]] = {
    "aws_s3_bucket":                                    ("S3 Bucket",               "AWS S3 Bucket",                    "id",            "arn"),
    "aws_s3_bucket_versioning":                         ("S3 Bucket Versioning",     "AWS S3 Bucket Versioning",         "id",            ""),
    "aws_s3_bucket_server_side_encryption_configuration":("S3 Bucket Encryption",    "AWS S3 SSE Configuration",         "id",            ""),
    "aws_s3_bucket_notification":                       ("S3 Bucket Notification",   "AWS S3 Notification",              "id",            ""),
    "aws_lambda_function":                              ("Lambda Function",           "AWS Lambda",                       "function_name", "arn"),
    "aws_lambda_permission":                            ("Lambda Permission",         "AWS Lambda Permission",            "statement_id",  ""),
    "aws_lambda_event_source_mapping":                  ("Lambda Event Source",       "AWS Lambda Event Source Mapping",  "id",            ""),
    "aws_iam_role":                                     ("IAM Role",                 "AWS IAM Role",                     "name",          "arn"),
    "aws_iam_role_policy":                              ("IAM Policy (Inline)",       "AWS IAM Role Policy",              "name",          ""),
    "aws_iam_instance_profile":                         ("IAM Instance Profile",      "AWS IAM Instance Profile",         "name",          "arn"),
    "aws_sqs_queue":                                    ("SQS Queue",                "AWS SQS Queue",                    "name",          "arn"),
    "aws_sqs_queue_policy":                             ("SQS Queue Policy",          "AWS SQS Queue Policy",             "id",            ""),
    "aws_sns_topic":                                    ("SNS Topic",                "AWS SNS Topic",                    "name",          "arn"),
    "aws_sns_topic_subscription":                       ("SNS Subscription",          "AWS SNS Subscription",             "id",            "arn"),
    "aws_dynamodb_table":                               ("DynamoDB Table",            "AWS DynamoDB Table",               "name",          "arn"),
    "aws_cloudwatch_log_group":                         ("CloudWatch Log Group",      "Amazon CloudWatch Logs",           "name",          "arn"),
    "aws_cloudwatch_event_rule":                        ("EventBridge Rule",          "AWS EventBridge Rule",             "name",          "arn"),
    "aws_cloudwatch_event_target":                      ("EventBridge Target",        "AWS EventBridge Target",           "target_id",     ""),
    "aws_sfn_state_machine":                            ("Step Functions",            "AWS Step Functions",               "name",          "arn"),
    "aws_kinesis_stream":                               ("Kinesis Stream",            "AWS Kinesis Data Streams",         "name",          "arn"),
    "aws_kinesis_firehose_delivery_stream":             ("Kinesis Firehose",          "AWS Kinesis Firehose",             "name",          "arn"),
    "aws_kinesisanalyticsv2_application":               ("Kinesis Analytics",         "AWS Kinesis Analytics v2",         "name",          "arn"),
    "aws_glue_catalog_database":                        ("Glue Database",             "AWS Glue Data Catalog",            "name",          "arn"),
    "aws_glue_crawler":                                 ("Glue Crawler",              "AWS Glue Crawler",                 "name",          "arn"),
    "aws_athena_workgroup":                             ("Athena Workgroup",          "AWS Athena",                       "name",          "arn"),
    "aws_msk_cluster":                                  ("MSK Cluster",               "AWS MSK (Kafka)",                  "cluster_name",  "arn"),
    "aws_security_group":                               ("Security Group",            "AWS EC2 Security Group",           "name",          "arn"),
    "aws_instance":                                     ("EC2 Instance",              "AWS EC2",                          "id",            "arn"),
}


def _console_url(res_type: str, attrs: dict, region: str) -> str:
    """Build an AWS Console deep-link URL for a deployed resource."""
    try:
        base = f"https://{region}.console.aws.amazon.com"
        if res_type == "aws_s3_bucket":
            return f"https://s3.console.aws.amazon.com/s3/buckets/{attrs.get('id','')}?region={region}"
        if res_type == "aws_lambda_function":
            fn = attrs.get("function_name") or attrs.get("id", "")
            return f"{base}/lambda/home?region={region}#/functions/{fn}"
        if res_type in ("aws_iam_role", "aws_iam_instance_profile"):
            return f"https://us-east-1.console.aws.amazon.com/iam/home#/roles/{attrs.get('name','')}"
        if res_type == "aws_sqs_queue":
            url = attrs.get("url") or attrs.get("id", "")
            return f"{base}/sqs/v3/home?region={region}#/queues/{urllib.parse.quote(url, safe='')}"
        if res_type == "aws_sns_topic":
            return f"{base}/sns/v3/home?region={region}#/topic/{attrs.get('arn','')}"
        if res_type == "aws_dynamodb_table":
            return f"{base}/dynamodbv2/home?region={region}#table?name={attrs.get('name','')}"
        if res_type == "aws_cloudwatch_log_group":
            lg = urllib.parse.quote(attrs.get("name",""), safe="")
            return f"{base}/cloudwatch/home?region={region}#logsV2:log-groups/log-group/{lg}"
        if res_type == "aws_cloudwatch_event_rule":
            return f"{base}/events/home?region={region}#/rules/{attrs.get('name','')}"
        if res_type == "aws_sfn_state_machine":
            return f"{base}/states/home?region={region}#/statemachines/view/{urllib.parse.quote(attrs.get('arn',''), safe='')}"
        if res_type == "aws_kinesis_stream":
            return f"{base}/kinesis/home?region={region}#/streams/details/{attrs.get('name','')}/monitoring"
        if res_type == "aws_instance":
            return f"{base}/ec2/v2/home?region={region}#Instances:instanceId={attrs.get('id','')}"
        if res_type == "aws_msk_cluster":
            return f"{base}/msk/home?region={region}#/clusters"
    except Exception:
        pass
    return ""


@app.get("/deploy/resources/{job_id}")
async def get_deployed_resources(job_id: str) -> JSONResponse:
    """Read terraform.tfstate after a successful apply and return deployed resource table."""
    job = _jobs.get(job_id)
    if not job:
        return JSONResponse(status_code=404, content={"detail": "Job not found"})
    result_info = job.get("result_info")
    if not result_info or not result_info.get("main_tf_path"):
        return JSONResponse(status_code=400, content={"detail": "Pipeline not complete"})

    work_dir = Path(result_info["main_tf_path"]).resolve().parent
    state_file = work_dir / "terraform.tfstate"
    if not state_file.exists():
        return JSONResponse(status_code=404, content={"detail": "No state file — deploy first"})

    try:
        state = json.loads(state_file.read_text())
    except Exception as e:
        return JSONResponse(status_code=500, content={"detail": f"Cannot read state: {e}"})

    region = result_info.get("region", "us-east-1")
    rows = []
    idx = 1

    for res in state.get("resources", []):
        rtype = res.get("type", "")
        if res.get("mode") == "data":
            continue  # skip data sources (archive_file, aws_ami, etc.)
        meta = _RES_META.get(rtype)
        if not meta:
            continue

        component, type_label, name_attr, arn_attr = meta

        for inst in res.get("instances", []):
            attrs = inst.get("attributes", {})
            name = str(attrs.get(name_attr) or attrs.get("id") or res.get("name", ""))
            arn  = str(attrs.get(arn_attr, "")) if arn_attr else ""
            url  = _console_url(rtype, attrs, region) if arn else ""
            rows.append({
                "idx": idx, "component": component, "type": type_label,
                "name": name, "arn": arn, "url": url,
            })
            idx += 1

    return JSONResponse({"resources": rows, "region": region})


# ─── Service config endpoint (for service detail popup) ─────────────────────

@app.get("/pipeline/{job_id}/service/{service_name}/config")
async def get_service_config(job_id: str, service_name: str) -> JSONResponse:
    """Return full configuration for a deployed service (blueprint + tfstate)."""
    job = _jobs.get(job_id)
    if not job:
        return JSONResponse(status_code=404, content={"detail": "Job not found"})
    details = job.get("details")
    if not details:
        return JSONResponse(status_code=404, content={"detail": "Pipeline details not available"})

    result_info = job.get("result_info", {})
    region = result_info.get("region", "us-east-1")

    # Find the service in pipeline request via stored YAML
    pipeline_name = result_info.get("pipeline_name", "")
    yaml_path = Path("output") / pipeline_name / "pipeline.yaml"

    svc_data = None
    bp_data = None

    # Try to rebuild blueprint for this service
    if yaml_path.exists():
        try:
            raw = yaml.safe_load(yaml_path.read_text())
            request = PipelineRequest.model_validate(raw)
            from engine.spec_builder import build_blueprint
            svc_map = {s.name: s for s in request.services}
            svc = svc_map.get(service_name)
            if svc:
                svc_data = {"name": svc.name, "type": svc.type, "config": svc.config}
                bp = build_blueprint(svc, request)
                # Resolve env_vars: replace Terraform references with actual AWS resource names
                # e.g. "aws_s3_bucket.label_xyz.id" → "my-actual-bucket-name"
                resolved_env = {}
                if bp.env_vars:
                    # Build a lookup: resource_label → resource_name for all services
                    label_to_name = {}
                    for other_svc in request.services:
                        other_bp = build_blueprint(other_svc, request)
                        label_to_name[other_bp.resource_label] = other_bp.resource_name
                    for var_name, tf_ref in bp.env_vars.items():
                        # tf_ref looks like "aws_s3_bucket.label_xyz.id" or ".arn" etc.
                        parts = tf_ref.split(".")
                        if len(parts) >= 2:
                            ref_label = parts[1]  # the resource label
                            resolved_env[var_name] = label_to_name.get(ref_label, tf_ref)
                        else:
                            resolved_env[var_name] = tf_ref
                bp_data = {
                    "service_name": bp.service_name,
                    "service_type": bp.service_type,
                    "resource_label": bp.resource_label,
                    "resource_name": bp.resource_name,
                    "is_principal": bp.is_principal,
                    "required_configuration": bp.required_configuration,
                    "iam_permissions": bp.iam_permissions,
                    "env_vars": resolved_env,
                    "vpc_required": bp.vpc_required,
                    "tags": bp.tags,
                    "integrations_as_source": [
                        {"source": i.source, "target": i.target, "event": i.event}
                        for i in bp.integrations_as_source
                    ],
                    "integrations_as_target": [
                        {"source": i.source, "target": i.target, "event": i.event}
                        for i in bp.integrations_as_target
                    ],
                }
        except Exception as exc:
            logging.getLogger(__name__).warning(
                "Could not rebuild blueprint for %s: %s", service_name, exc)

    if not svc_data:
        return JSONResponse(status_code=404, content={"detail": f"Service '{service_name}' not found"})

    # Try to get live resource details from tfstate
    live_attrs = {}
    tf_path = Path(result_info.get("main_tf_path", "")) if result_info.get("main_tf_path") else None
    if tf_path:
        state_file = tf_path.resolve().parent / "terraform.tfstate"
        if state_file.exists():
            try:
                state = json.loads(state_file.read_text())
                svc_type = svc_data["type"]
                tf_res_type = _TF_RESOURCE_MAP.get(svc_type, (f"aws_{svc_type}", "arn"))[0]
                for res in state.get("resources", []):
                    if res.get("type") == tf_res_type and res.get("mode") != "data":
                        for inst in res.get("instances", []):
                            attrs = inst.get("attributes", {})
                            rl = bp_data["resource_label"] if bp_data else ""
                            if res.get("name", "") == rl or not live_attrs:
                                live_attrs = attrs
            except Exception:
                pass

    # Check available API operations
    from agents.developer_agent import load_api_reference
    api_ref = load_api_reference(svc_data["type"])
    has_api = api_ref is not None

    return JSONResponse({
        "service": svc_data,
        "blueprint": bp_data,
        "live_attrs": live_attrs,
        "region": region,
        "has_developer_api": has_api,
    })


# ─── Developer Agent routes ─────────────────────────────────────────────────

# In-memory conversation store: chat_id → list of {role, content} messages
_dev_agent_chats: dict[str, list[dict]] = {}


@app.post("/developer-agent/chat")
async def developer_agent_chat(request: Request) -> JSONResponse:
    """Chat with the Developer Agent to generate AWS artifact code."""
    body = await request.json()
    message = (body.get("message") or "").strip()
    service_name = body.get("service_name", "")
    service_type = body.get("service_type", "")
    config = body.get("config", {})
    iam_permissions = body.get("iam_permissions", [])
    env_vars = body.get("env_vars", {})
    region = body.get("region", "us-east-1")
    resource_name = body.get("resource_name", "")
    resource_arn = body.get("resource_arn", "")
    chat_id = body.get("chat_id", "")

    if not message:
        return JSONResponse(status_code=400, content={"detail": "message is required"})

    # Get or create conversation history
    history = _dev_agent_chats.get(chat_id, []) if chat_id else []

    from agents.developer_agent import DeveloperAgent

    try:
        agent = DeveloperAgent(
            api_key=_admin_config.get("anthropic_api_key"),
            model="claude-haiku-4-5-20251001",
        )
    except RuntimeError as exc:
        return JSONResponse(status_code=400, content={"detail": str(exc)})

    result = await asyncio.to_thread(
        agent.chat,
        user_message=message,
        service_name=service_name,
        service_type=service_type,
        config=config,
        iam_permissions=iam_permissions,
        env_vars=env_vars,
        region=region,
        resource_name=resource_name,
        resource_arn=resource_arn,
        conversation_history=history,
    )

    if result.get("error"):
        return JSONResponse(status_code=500, content={"detail": result["error"]})

    # Update conversation history
    if not chat_id:
        chat_id = uuid.uuid4().hex
    if chat_id not in _dev_agent_chats:
        _dev_agent_chats[chat_id] = []
    _dev_agent_chats[chat_id].append({"role": "user", "content": message})
    _dev_agent_chats[chat_id].append({"role": "assistant", "content": result.get("code", "")})

    # Keep history bounded
    if len(_dev_agent_chats[chat_id]) > 20:
        _dev_agent_chats[chat_id] = _dev_agent_chats[chat_id][-20:]

    return JSONResponse({
        "chat_id": chat_id,
        "explanation": result.get("explanation", ""),
        "operations_used": result.get("operations_used", []),
        "code": result.get("code", ""),
    })


@app.post("/developer-agent/execute")
async def developer_agent_execute(request: Request) -> JSONResponse:
    """Execute generated boto3 code with optional auto-fix feedback loop.

    First runs the code directly. If it succeeds, returns immediately.
    If it fails, attempts auto-fix via the Developer Agent (up to 2 retries).
    If the agent can't be created (no API key), returns the plain failure.
    """
    body = await request.json()
    code = (body.get("code") or "").strip()
    region = body.get("region", "us-east-1")

    if not code:
        return JSONResponse(status_code=400, content={"detail": "code is required"})

    # Build extra env from admin AWS keys
    extra_env = {}
    if _admin_config.get("aws_access_key_id"):
        extra_env["AWS_ACCESS_KEY_ID"] = _admin_config["aws_access_key_id"]
        extra_env["AWS_SECRET_ACCESS_KEY"] = _admin_config["aws_secret_access_key"]
        extra_env["AWS_DEFAULT_REGION"] = _admin_config.get("aws_region", region)

    from agents.developer_agent import execute_code

    try:
        # Step 1: Try executing the code directly (no agent needed)
        first_result = await asyncio.to_thread(
            execute_code, code, region, extra_env,
        )

        if first_result["exit_code"] == 0:
            # Success on first try — return immediately
            return JSONResponse({
                "attempts": [{
                    "attempt": 1,
                    "code": code,
                    "stdout": first_result["stdout"],
                    "stderr": first_result["stderr"],
                    "exit_code": 0,
                    "fix_explanation": None,
                }],
                "final_code": code,
                "success": True,
                "needs_human": False,
            })

        # Step 2: Code failed — try auto-fix if we can create the agent
        from agents.developer_agent import DeveloperAgent, execute_with_auto_fix

        service_context = {
            "service_name": body.get("service_name", ""),
            "service_type": body.get("service_type", ""),
            "config": body.get("config", {}),
            "iam_permissions": body.get("iam_permissions", []),
            "env_vars": body.get("env_vars", {}),
            "region": region,
            "resource_name": body.get("resource_name", ""),
            "resource_arn": body.get("resource_arn", ""),
        }

        try:
            agent = DeveloperAgent(
                api_key=_admin_config.get("anthropic_api_key"),
                model="claude-haiku-4-5-20251001",
            )
        except Exception:
            # Can't create agent — return the plain failure (old behaviour)
            return JSONResponse({
                "attempts": [{
                    "attempt": 1,
                    "code": code,
                    "stdout": first_result["stdout"],
                    "stderr": first_result["stderr"],
                    "exit_code": first_result["exit_code"],
                    "fix_explanation": None,
                }],
                "final_code": code,
                "success": False,
                "needs_human": True,
            })

        result = await asyncio.to_thread(
            execute_with_auto_fix,
            agent=agent,
            code=code,
            service_context=service_context,
            region=region,
            extra_env=extra_env,
            first_failure=first_result,
        )

        return JSONResponse({
            "attempts": result["attempts"],
            "final_code": result["final_code"],
            "success": result["success"],
            "needs_human": result["needs_human"],
        })

    except Exception as exc:
        logger.error("[DevAgent Execute] Unhandled error: %s", exc)
        return JSONResponse({
            "attempts": [{
                "attempt": 1,
                "code": code,
                "stdout": "",
                "stderr": str(exc),
                "exit_code": -1,
                "fix_explanation": None,
            }],
            "final_code": code,
            "success": False,
            "needs_human": True,
        })


# ─── Developer Agent API reference endpoint ──────────────────────────────────

@app.get("/api-reference/{service_type}")
async def get_api_reference(service_type: str) -> JSONResponse:
    """Return available API operations for a service type."""
    from agents.developer_agent import load_api_reference
    ref = load_api_reference(service_type)
    if not ref:
        return JSONResponse(status_code=404, content={"detail": f"No API reference for '{service_type}'"})
    return JSONResponse(ref)


# ─── Pipeline Run Preview (log aggregator) ────────────────────────────────────

async def _start_preview_from_dir(work_dir: Path, region: str = "us-east-1") -> JSONResponse:
    """Shared helper: discover log groups in a work_dir and start a preview streamer."""
    state_file = work_dir / "terraform.tfstate"
    if not state_file.exists():
        return JSONResponse(status_code=400, content={
            "detail": "No terraform state — deploy the pipeline first"})

    yaml_path = work_dir / "pipeline.yaml"
    if not yaml_path.exists():
        return JSONResponse(status_code=400, content={
            "detail": "No pipeline.yaml found"})

    try:
        raw = yaml.safe_load(yaml_path.read_text())
        request = PipelineRequest.model_validate(raw)
    except Exception as exc:
        return JSONResponse(status_code=400, content={
            "detail": f"Invalid pipeline YAML: {exc}"})

    services = [{"name": s.name, "type": s.type} for s in request.services]

    from tools.log_aggregator import (
        discover_log_groups, make_boto_session, PipelineLogStreamer,
    )

    session = make_boto_session(
        access_key=_admin_config.get("aws_access_key_id"),
        secret_key=_admin_config.get("aws_secret_access_key"),
        region=region,
    )

    try:
        log_groups, no_logs, ct_sources = await asyncio.to_thread(
            discover_log_groups, state_file, services, session,
        )
    except Exception as exc:
        return JSONResponse(status_code=500, content={
            "detail": f"Failed to discover log groups: {exc}"})

    if not log_groups and not ct_sources:
        return JSONResponse(status_code=404, content={
            "detail": "No monitorable log groups found for this pipeline's services",
            "services_without_logs": no_logs,
        })

    preview_id = uuid.uuid4().hex
    log_q: stdlib_queue.SimpleQueue = stdlib_queue.SimpleQueue()

    # Build inspector agent and context (if API key available)
    inspector_agent = None
    inspector_context: dict = {}
    has_inspector = False
    try:
        from agents.pipeline_inspector import PipelineInspectorAgent
        inspector_agent = PipelineInspectorAgent(
            api_key=_admin_config.get("anthropic_api_key"),
        )

        # Build blueprint map for all services
        from engine.spec_builder import build_blueprint
        blueprint_map = {}
        svc_map = {s.name: s for s in request.services}
        for svc in request.services:
            try:
                bp = build_blueprint(svc, request)
                blueprint_map[svc.name] = {
                    "service_name": bp.service_name,
                    "service_type": bp.service_type,
                    "resource_name": bp.resource_name,
                    "resource_label": bp.resource_label,
                    "is_principal": bp.is_principal,
                    "required_configuration": bp.required_configuration,
                    "iam_permissions": bp.iam_permissions,
                    "env_vars": bp.env_vars,
                    "vpc_required": bp.vpc_required,
                    "integrations_as_target": [
                        {"source": i.source, "target": i.target, "event": i.event}
                        for i in bp.integrations_as_target
                    ],
                    "integrations_as_source": [
                        {"source": i.source, "target": i.target, "event": i.event}
                        for i in bp.integrations_as_source
                    ],
                }
            except Exception:
                pass

        # Build extra env for code execution
        extra_env = {}
        if _admin_config.get("aws_access_key_id"):
            extra_env["AWS_ACCESS_KEY_ID"] = _admin_config["aws_access_key_id"]
            extra_env["AWS_SECRET_ACCESS_KEY"] = _admin_config["aws_secret_access_key"]
            extra_env["AWS_DEFAULT_REGION"] = _admin_config.get("aws_region", region)

        inspector_context = {
            "blueprint_map": blueprint_map,
            "pipeline_services": services,
            "region": region,
            "extra_env": extra_env or None,
        }
        has_inspector = True
    except Exception as exc:
        logging.getLogger(__name__).info(
            "Inspector not available (API key may be missing): %s", exc)

    streamer = PipelineLogStreamer(
        log_groups=log_groups,
        output_queue=log_q,
        poll_interval=3.0,
        boto_session=session,
        ct_sources=ct_sources,
        inspector_agent=inspector_agent,
        inspector_context=inspector_context,
        auto_fix_enabled=False,  # off by default, user toggles on
    )
    streamer.start()

    _previews[preview_id] = {
        "status": "running",
        "log_q": log_q,
        "streamer": streamer,
    }

    return JSONResponse({
        "preview_id": preview_id,
        "has_inspector": has_inspector,
        "monitored": [
            {"service_name": g.service_name, "service_type": g.service_type,
             "log_group": g.log_group_name, "exists": g.exists}
            for g in log_groups
        ],
        "cloudtrail_monitored": [
            {"service_name": s.service_name, "service_type": s.service_type,
             "source": "cloudtrail"}
            for s in ct_sources
        ],
        "services_without_logs": no_logs,
    })


@app.post("/pipeline/run-preview/{job_id}/start")
async def start_run_preview(job_id: str) -> JSONResponse:
    """Start monitoring CloudWatch Logs for a deployed pipeline (by job_id)."""
    job = _jobs.get(job_id)
    if not job:
        return JSONResponse(status_code=404, content={"detail": "Job not found"})
    result_info = job.get("result_info")
    if not result_info or not result_info.get("main_tf_path"):
        return JSONResponse(status_code=400, content={"detail": "Pipeline not complete"})

    work_dir = Path(result_info["main_tf_path"]).resolve().parent
    region = result_info.get("region", "us-east-1")
    return await _start_preview_from_dir(work_dir, region)


@app.post("/pipeline/run-preview/by-name/{pipeline_name}/start")
async def start_run_preview_by_name(pipeline_name: str) -> JSONResponse:
    """Start monitoring CloudWatch Logs for a historical pipeline (by name).

    Looks up output/{pipeline_name}/ directly — no in-memory job_id required.
    This enables monitoring for pipelines deployed in previous sessions.
    """
    work_dir = Path("output") / pipeline_name
    if not work_dir.is_dir():
        return JSONResponse(status_code=404, content={
            "detail": f"Pipeline '{pipeline_name}' not found in output/"})

    # Try to read region from pipeline.yaml, fall back to admin config or us-east-1
    region = _admin_config.get("aws_region", "us-east-1")
    yaml_path = work_dir / "pipeline.yaml"
    if yaml_path.exists():
        try:
            raw = yaml.safe_load(yaml_path.read_text())
            region = raw.get("region", region)
        except Exception:
            pass

    return await _start_preview_from_dir(work_dir, region)


@app.delete("/pipeline/run-preview/{preview_id}/stop")
async def stop_run_preview(preview_id: str) -> JSONResponse:
    """Stop monitoring CloudWatch Logs for a running preview."""
    preview = _previews.get(preview_id)
    if not preview:
        return JSONResponse(status_code=404, content={"detail": "Preview not found"})

    streamer = preview.get("streamer")
    if streamer and streamer.is_running():
        streamer.stop()
        preview["status"] = "stopped"
        return JSONResponse({"stopped": True})
    return JSONResponse({"stopped": False, "detail": "Preview already stopped"})


@app.post("/pipeline/run-preview/{preview_id}/auto-fix")
async def toggle_auto_fix(preview_id: str, request: Request) -> JSONResponse:
    """Toggle auto-fix on/off for a running preview."""
    preview = _previews.get(preview_id)
    if not preview:
        return JSONResponse(status_code=404, content={"detail": "Preview not found"})

    streamer = preview.get("streamer")
    if not streamer:
        return JSONResponse(status_code=400, content={"detail": "No streamer"})

    if not streamer.inspector_agent:
        return JSONResponse(status_code=400, content={
            "detail": "Inspector not available — configure Anthropic API key first"})

    body = await request.json()
    enabled = bool(body.get("enabled", False))
    streamer.set_auto_fix(enabled)
    return JSONResponse({"auto_fix_enabled": enabled})


@app.websocket("/ws/pipeline-run/{preview_id}")
async def websocket_pipeline_run(websocket: WebSocket, preview_id: str) -> None:
    """Stream pipeline runtime log events from CloudWatch."""
    await websocket.accept()

    preview = _previews.get(preview_id)
    if not preview:
        await websocket.send_json({
            "type": "error", "message": f"Unknown preview: {preview_id}"})
        await websocket.close()
        return

    q: stdlib_queue.SimpleQueue = preview["log_q"]

    try:
        while True:
            sent = 0
            while True:
                try:
                    msg = q.get_nowait()
                    await websocket.send_json(msg)
                    sent += 1
                    # If streamer was stopped and sent the final status message
                    if (msg.get("type") == "run_log_status"
                            and msg.get("status") == "stopped"):
                        await websocket.close()
                        return
                except stdlib_queue.Empty:
                    break

            if preview["status"] == "stopped" and sent == 0:
                await websocket.send_json({
                    "type": "run_log_status",
                    "status": "stopped",
                    "message": "Log monitoring stopped.",
                })
                await websocket.close()
                return

            await asyncio.sleep(0.3)

    except WebSocketDisconnect:
        # Client disconnected — stop the streamer to free resources
        streamer = preview.get("streamer")
        if streamer:
            streamer.stop()


# ─── Pipeline Designer (main-screen chat → ASCII diagram → YAML) ─────────────

_designer_chats: dict[str, list[dict]] = {}
_designer_yaml: dict[str, str] = {}    # chat_id → latest pipeline YAML
_designer_diagram: dict[str, str] = {} # chat_id → latest ASCII diagram


@app.post("/pipeline-designer/chat")
async def pipeline_designer_chat(request: Request) -> JSONResponse:
    """Design-phase chat: returns ASCII flow diagram + pipeline YAML from layman description."""
    body = await request.json()
    message = (body.get("message") or "").strip()
    chat_id = body.get("chat_id", "")

    if not message:
        return JSONResponse(status_code=400, content={"detail": "message is required"})

    api_key = _admin_config.get("anthropic_api_key")
    if not api_key:
        import os as _os
        api_key = _os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        return JSONResponse(status_code=400, content={
            "detail": "Anthropic API key required. Set it in Admin > Configure API Key."
        })

    from agents.pipeline_builder_agent import PipelineBuilderAgent

    try:
        agent = PipelineBuilderAgent(api_key=api_key, model="claude-sonnet-4-5")
    except RuntimeError as exc:
        return JSONResponse(status_code=400, content={"detail": str(exc)})

    history = _designer_chats.get(chat_id, []) if chat_id else []
    current_yaml = _designer_yaml.get(chat_id, "") if chat_id else ""
    current_diagram = _designer_diagram.get(chat_id, "") if chat_id else ""

    try:
        if current_yaml:
            result = await asyncio.to_thread(
                agent.redesign, message, current_yaml, current_diagram, history,
            )
        else:
            result = await asyncio.to_thread(
                agent.design, message, history,
            )

        diagram = result.get("diagram", "")
        yaml_text = result.get("yaml", "")

        # Validate the YAML parses as a PipelineRequest
        parsed = yaml.safe_load(yaml_text)
        pipeline_req = PipelineRequest.model_validate(parsed)

        # Update conversation state
        if not chat_id:
            chat_id = uuid.uuid4().hex
        if chat_id not in _designer_chats:
            _designer_chats[chat_id] = []
        _designer_chats[chat_id].append({"role": "user", "content": message})
        _designer_chats[chat_id].append({"role": "assistant", "content": json.dumps(result)})
        _designer_yaml[chat_id] = yaml_text
        _designer_diagram[chat_id] = diagram

        if len(_designer_chats[chat_id]) > 20:
            _designer_chats[chat_id] = _designer_chats[chat_id][-20:]

        return JSONResponse({
            "chat_id": chat_id,
            "diagram": diagram,
            "yaml": yaml_text,
            "pipeline_name": pipeline_req.pipeline_name,
            "services": [{"name": s.name, "type": s.type} for s in pipeline_req.services],
            "integrations": [
                {"source": i.source, "target": i.target, "event": i.event}
                for i in pipeline_req.integrations
            ],
        })

    except Exception as exc:
        error_msg = str(exc)
        return JSONResponse(status_code=422, content={
            "detail": f"Design failed: {error_msg}",
            "raw_yaml": yaml_text if "yaml_text" in dir() else None,
        })


@app.post("/pipeline-designer/build")
async def pipeline_designer_build(request: Request) -> JSONResponse:
    """Build Terraform from the designer's stored YAML."""
    body = await request.json()
    chat_id = body.get("chat_id", "")

    yaml_text = _designer_yaml.get(chat_id, "")
    if not yaml_text:
        return JSONResponse(status_code=400, content={
            "detail": "No pipeline design available. Chat with the designer first."
        })

    try:
        parsed = yaml.safe_load(yaml_text)
        bu = (body.get("business_unit") or "").strip()
        cc = (body.get("cost_center") or "").strip()
        if bu:
            parsed["business_unit"] = bu
        if cc:
            parsed["cost_center"] = cc
        pipeline_req = PipelineRequest.model_validate(parsed)
    except Exception as exc:
        return JSONResponse(status_code=422, content={
            "detail": f"Invalid pipeline YAML: {exc}"
        })

    job_id = uuid.uuid4().hex
    log_q: stdlib_queue.SimpleQueue = stdlib_queue.SimpleQueue()
    _jobs[job_id] = {
        "status": "running", "result_info": None,
        "log_q": log_q, "task": None,
        "details": None, "matrix": [], "plan_text": "",
    }
    task = asyncio.create_task(_execute_job_from_request(job_id, pipeline_req))
    _jobs[job_id]["task"] = task

    return JSONResponse({"job_id": job_id, "pipeline_name": pipeline_req.pipeline_name})


# ─── Pipeline Builder Agent ───────────────────────────────────────────────────

_builder_chats: dict[str, list[dict]] = {}
_builder_yaml: dict[str, str] = {}  # chat_id → latest generated YAML


@app.post("/pipeline-builder/chat")
async def pipeline_builder_chat(request: Request) -> JSONResponse:
    """Chat with the Pipeline Builder Agent to design pipelines from requirements."""
    body = await request.json()
    message = (body.get("message") or "").strip()
    chat_id = body.get("chat_id", "")

    if not message:
        return JSONResponse(status_code=400, content={"detail": "message is required"})

    api_key = _admin_config.get("anthropic_api_key")
    if not api_key:
        import os as _os
        api_key = _os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        return JSONResponse(status_code=400, content={
            "detail": "Anthropic API key required. Set it in Admin > Configure API Key."
        })

    from agents.pipeline_builder_agent import PipelineBuilderAgent

    try:
        agent = PipelineBuilderAgent(api_key=api_key, model="claude-sonnet-4-5")
    except RuntimeError as exc:
        return JSONResponse(status_code=400, content={"detail": str(exc)})

    history = _builder_chats.get(chat_id, []) if chat_id else []
    current_yaml = _builder_yaml.get(chat_id, "") if chat_id else ""

    try:
        if current_yaml:
            # Refinement mode — user is iterating on existing pipeline
            yaml_text = await asyncio.to_thread(
                agent.refine, message, current_yaml, history,
            )
        else:
            # Initial generation
            yaml_text = await asyncio.to_thread(
                agent.generate, message, history,
            )

        # Validate the YAML parses as a PipelineRequest
        parsed = yaml.safe_load(yaml_text)
        pipeline_req = PipelineRequest.model_validate(parsed)

        # Update conversation state
        if not chat_id:
            chat_id = uuid.uuid4().hex
        if chat_id not in _builder_chats:
            _builder_chats[chat_id] = []
        _builder_chats[chat_id].append({"role": "user", "content": message})
        _builder_chats[chat_id].append({"role": "assistant", "content": yaml_text})
        _builder_yaml[chat_id] = yaml_text

        if len(_builder_chats[chat_id]) > 20:
            _builder_chats[chat_id] = _builder_chats[chat_id][-20:]

        return JSONResponse({
            "chat_id": chat_id,
            "yaml": yaml_text,
            "pipeline_name": pipeline_req.pipeline_name,
            "services": [{"name": s.name, "type": s.type} for s in pipeline_req.services],
            "integrations": [
                {"source": i.source, "target": i.target, "event": i.event}
                for i in pipeline_req.integrations
            ],
        })

    except Exception as exc:
        error_msg = str(exc)
        # If YAML validation failed, still return the raw YAML for visibility
        return JSONResponse(status_code=422, content={
            "detail": f"Generated YAML failed validation: {error_msg}",
            "raw_yaml": yaml_text if 'yaml_text' in dir() else None,
        })


@app.post("/pipeline-builder/chat-image")
async def pipeline_builder_chat_image(
    image: UploadFile = File(...),
    message: str = Form(default=""),
    chat_id: str = Form(default=""),
) -> JSONResponse:
    """Generate or refine a pipeline from an uploaded architecture diagram.

    Parses arrow directions to build integrations, detects bidirectional access,
    and warns about architecturally impossible patterns (passive service as caller).
    After the image is processed, subsequent text messages to /pipeline-builder/chat
    use refinement mode on the stored YAML.
    """
    supported = {"image/png", "image/jpeg", "image/gif", "image/webp"}
    media_type = image.content_type or "image/png"
    if media_type not in supported:
        return JSONResponse(status_code=400, content={
            "detail": f"Unsupported image type '{media_type}'. Use PNG, JPEG, GIF, or WebP."
        })

    image_bytes = await image.read()
    if len(image_bytes) > 5 * 1024 * 1024:
        return JSONResponse(status_code=400, content={"detail": "Image exceeds 5 MB limit."})

    api_key = _admin_config.get("anthropic_api_key")
    if not api_key:
        import os as _os
        api_key = _os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        return JSONResponse(status_code=400, content={
            "detail": "Anthropic API key required. Set it in Admin > Configure API Key."
        })

    from agents.pipeline_builder_agent import PipelineBuilderAgent

    try:
        agent = PipelineBuilderAgent(api_key=api_key, model="claude-sonnet-4-5")
    except RuntimeError as exc:
        return JSONResponse(status_code=400, content={"detail": str(exc)})

    history = _builder_chats.get(chat_id, []) if chat_id else []

    try:
        yaml_text, warnings = await asyncio.to_thread(
            agent.generate_from_image,
            image_bytes, media_type, message.strip(), history,
        )

        parsed = yaml.safe_load(yaml_text)
        pipeline_req = PipelineRequest.model_validate(parsed)

        if not chat_id:
            chat_id = uuid.uuid4().hex
        if chat_id not in _builder_chats:
            _builder_chats[chat_id] = []
        img_note = f"[Uploaded diagram: {image.filename}]" + (f" {message.strip()}" if message.strip() else "")
        _builder_chats[chat_id].append({"role": "user", "content": img_note})
        _builder_chats[chat_id].append({"role": "assistant", "content": yaml_text})
        _builder_yaml[chat_id] = yaml_text

        if len(_builder_chats[chat_id]) > 20:
            _builder_chats[chat_id] = _builder_chats[chat_id][-20:]

        # Cross-sync into designer state so /pipeline-designer/chat can continue
        _designer_yaml[chat_id] = yaml_text
        _designer_diagram[chat_id] = ""
        if chat_id not in _designer_chats:
            _designer_chats[chat_id] = []
        _designer_chats[chat_id].append({"role": "user", "content": img_note})
        _designer_chats[chat_id].append({"role": "assistant", "content": yaml_text})

        return JSONResponse({
            "chat_id": chat_id,
            "yaml": yaml_text,
            "pipeline_name": pipeline_req.pipeline_name,
            "services": [{"name": s.name, "type": s.type} for s in pipeline_req.services],
            "integrations": [
                {"source": i.source, "target": i.target, "event": i.event}
                for i in pipeline_req.integrations
            ],
            "warnings": warnings,
        })

    except Exception as exc:
        error_msg = str(exc)
        return JSONResponse(status_code=422, content={
            "detail": f"Diagram analysis failed: {error_msg}",
            "raw_yaml": yaml_text if "yaml_text" in dir() else None,
        })


@app.post("/pipeline-builder/build")
async def pipeline_builder_build(request: Request) -> JSONResponse:
    """Build Terraform from the Pipeline Builder Agent's generated YAML."""
    body = await request.json()
    chat_id = body.get("chat_id", "")
    yaml_override = body.get("yaml")  # optional: use this instead of stored

    yaml_text = yaml_override or _builder_yaml.get(chat_id, "")
    if not yaml_text:
        return JSONResponse(status_code=400, content={
            "detail": "No pipeline YAML available. Chat with the agent first."
        })

    try:
        parsed = yaml.safe_load(yaml_text)
        # Apply project/cost-center overrides from the UI
        bu = (body.get("business_unit") or "").strip()
        cc = (body.get("cost_center") or "").strip()
        if bu:
            parsed["business_unit"] = bu
        if cc:
            parsed["cost_center"] = cc
        pipeline_req = PipelineRequest.model_validate(parsed)
    except Exception as exc:
        return JSONResponse(status_code=422, content={
            "detail": f"Invalid pipeline YAML: {exc}"
        })

    # Create job and run the pipeline builder (same pattern as run-from-diagram)
    job_id = uuid.uuid4().hex
    log_q: stdlib_queue.SimpleQueue = stdlib_queue.SimpleQueue()
    _jobs[job_id] = {
        "status": "running", "result_info": None,
        "log_q": log_q, "task": None,
        "details": None, "matrix": [], "plan_text": "",
    }
    task = asyncio.create_task(_execute_job_from_request(job_id, pipeline_req))
    _jobs[job_id]["task"] = task

    return JSONResponse({"job_id": job_id, "pipeline_name": pipeline_req.pipeline_name})


# ─── Config Chat endpoints ────────────────────────────────────────────────────
# Chat-based infrastructure customization using the feature index (Tier 0)
# and LLM agents (Tier 1/2) as fallback.

_config_chats: dict[str, list[dict]] = {}


@app.post("/config/chat")
async def config_chat(request: Request) -> JSONResponse:
    """Chat-based infrastructure customization.

    Resolves natural-language config requests using a tiered strategy:
      Tier 0: Keyword matching against the feature index (zero LLM cost)
      Tier 1: Haiku for single-feature ambiguity (~$0.0002)
      Tier 2: Sonnet for complex/multi-feature requests (~$0.003)
    """
    body = await request.json()
    message = body.get("message", "").strip()
    job_id = body.get("job_id", "")
    service_name = body.get("service_name")  # optional
    chat_id = body.get("chat_id")

    if not message:
        return JSONResponse(status_code=400, content={"detail": "Message is required"})

    # Resolve pipeline services from job
    job = _jobs.get(job_id)
    pipeline_services: list[dict] = []
    service_type: str | None = None
    current_config: dict = {}

    if job and job.get("result_info"):
        # Load pipeline YAML to get services
        result_info = job["result_info"]
        tf_path = result_info.get("main_tf_path")
        if tf_path:
            yaml_path = Path(tf_path).resolve().parent / "pipeline.yaml"
            if yaml_path.exists():
                try:
                    raw = yaml.safe_load(yaml_path.read_text())
                    for svc in raw.get("services", []):
                        pipeline_services.append({
                            "name": svc["name"],
                            "type": svc["type"],
                            "config": svc.get("config", {}),
                        })
                        if service_name and svc["name"] == service_name:
                            service_type = svc["type"]
                            current_config = svc.get("config", {})
                except Exception:
                    pass

    if not pipeline_services:
        return JSONResponse(status_code=400, content={
            "detail": "Pipeline not found or not built yet"
        })

    # If service_name not given but message mentions a service name, try to match
    if not service_name:
        for svc in pipeline_services:
            if svc["name"].lower() in message.lower():
                service_name = svc["name"]
                service_type = svc["type"]
                current_config = svc.get("config", {})
                break

    # ── Tier 0: keyword matching ─────────────────────────────────────
    resolution = _feature_index.resolve_tier0(
        message=message,
        service_type=service_type,
        service_name=service_name,
        pipeline_services=pipeline_services,
    )

    if resolution and resolution.config_patch:
        if not chat_id:
            chat_id = uuid.uuid4().hex
        return JSONResponse({
            "chat_id": chat_id,
            "tier": resolution.tier,
            "resolution": {
                "service_name": resolution.service_name,
                "config_patch": resolution.config_patch,
                "explanation": resolution.explanation,
                "confidence": resolution.confidence,
                "warnings": resolution.warnings,
                "cost_warning": resolution.cost_warning,
            },
            "needs_confirmation": True,
        })

    # ── Tier 1/2: LLM fallback ──────────────────────────────────────
    api_key = _admin_config.get("anthropic_api_key")
    if not api_key:
        # No API key — try environment
        import os
        api_key = os.environ.get("ANTHROPIC_API_KEY")

    if not api_key:
        # Tier 0 failed and no LLM available
        supported = []
        if service_type:
            supported = [
                {"key": k.key, "description": k.description, "default": k.default}
                for k in get_supported_keys(service_type)
            ]
        return JSONResponse({
            "chat_id": chat_id or uuid.uuid4().hex,
            "tier": 0,
            "resolution": None,
            "error": "Could not resolve your request from keywords alone. "
                     "Configure an Anthropic API key in the Admin panel to "
                     "enable AI-assisted config resolution.",
            "supported_keys": supported,
            "needs_confirmation": False,
        })

    # Determine tier: single feature on one service → Tier 1, else Tier 2
    try:
        from agents.config_agent import ConfigAgent, load_kb_content

        agent = ConfigAgent(api_key=api_key)

        if service_type and service_name:
            # Extract keywords for section lookup
            tokens = message.lower().split()
            spec_section = _feature_index.get_relevant_sections(service_type, tokens)

            if len(spec_section) < 5000:  # fits in Tier 1
                resolution = agent.resolve_tier1(
                    message=message,
                    service_type=service_type,
                    service_name=service_name,
                    spec_section=spec_section,
                    current_config=current_config,
                )
            else:
                kb_content = load_kb_content(service_type)
                history = _config_chats.get(chat_id, []) if chat_id else []
                resolution = agent.resolve_tier2(
                    message=message,
                    service_type=service_type,
                    service_name=service_name,
                    spec_sections=spec_section,
                    kb_content=kb_content,
                    current_config=current_config,
                    conversation_history=history,
                )
        else:
            # No service scope — use Tier 2 with broader context
            # Try to find the most relevant service type from message
            best_type = None
            for svc in pipeline_services:
                if svc["type"] in message.lower() or svc["name"].lower() in message.lower():
                    best_type = svc["type"]
                    service_name = svc["name"]
                    current_config = svc.get("config", {})
                    break

            if not best_type and len(pipeline_services) == 1:
                best_type = pipeline_services[0]["type"]
                service_name = pipeline_services[0]["name"]
                current_config = pipeline_services[0].get("config", {})

            if not best_type:
                return JSONResponse({
                    "chat_id": chat_id or uuid.uuid4().hex,
                    "tier": 0,
                    "resolution": None,
                    "error": "Could not determine which service to configure. "
                             "Please specify a service name.",
                    "needs_confirmation": False,
                })

            kb_content = load_kb_content(best_type)
            tokens = message.lower().split()
            spec_section = _feature_index.get_relevant_sections(best_type, tokens)
            history = _config_chats.get(chat_id, []) if chat_id else []

            resolution = agent.resolve_tier2(
                message=message,
                service_type=best_type,
                service_name=service_name,
                spec_sections=spec_section,
                kb_content=kb_content,
                current_config=current_config,
                conversation_history=history,
            )

        # Save conversation history
        if not chat_id:
            chat_id = uuid.uuid4().hex
        if chat_id not in _config_chats:
            _config_chats[chat_id] = []
        _config_chats[chat_id].append({"role": "user", "content": message})
        _config_chats[chat_id].append({
            "role": "assistant",
            "content": json.dumps(resolution.config_patch),
        })
        if len(_config_chats[chat_id]) > 20:
            _config_chats[chat_id] = _config_chats[chat_id][-20:]

        return JSONResponse({
            "chat_id": chat_id,
            "tier": resolution.tier,
            "resolution": {
                "service_name": resolution.service_name,
                "config_patch": resolution.config_patch,
                "explanation": resolution.explanation,
                "confidence": resolution.confidence,
                "warnings": resolution.warnings,
                "cost_warning": resolution.cost_warning,
            },
            "needs_confirmation": bool(resolution.config_patch),
        })

    except Exception as e:
        logging.error("Config chat LLM error: %s", e)
        return JSONResponse(status_code=500, content={
            "detail": f"LLM resolution failed: {e}"
        })


@app.post("/config/apply")
async def config_apply(request: Request) -> JSONResponse:
    """Apply a confirmed config patch and re-render the pipeline.

    Merges config_patch into the target service's config, saves the updated
    pipeline YAML, and triggers a full re-render via build_pipeline().
    """
    body = await request.json()
    job_id = body.get("job_id", "")
    service_name = body.get("service_name", "")
    config_patch = body.get("config_patch", {})

    if not service_name or not config_patch:
        return JSONResponse(status_code=400, content={
            "detail": "service_name and config_patch are required"
        })

    job = _jobs.get(job_id)
    if not job or not job.get("result_info"):
        return JSONResponse(status_code=404, content={"detail": "Job not found"})

    # Find pipeline YAML
    result_info = job["result_info"]
    tf_path = result_info.get("main_tf_path")
    if not tf_path:
        return JSONResponse(status_code=400, content={"detail": "No output path"})

    work_dir = Path(tf_path).resolve().parent
    yaml_path = work_dir / "pipeline.yaml"
    if not yaml_path.exists():
        return JSONResponse(status_code=400, content={
            "detail": "No pipeline.yaml found"
        })

    # Load and modify pipeline YAML
    try:
        raw = yaml.safe_load(yaml_path.read_text())
    except Exception as e:
        return JSONResponse(status_code=400, content={
            "detail": f"Invalid pipeline YAML: {e}"
        })

    # Find the target service and merge config
    found = False
    service_type = None
    for svc in raw.get("services", []):
        if svc["name"] == service_name:
            if "config" not in svc:
                svc["config"] = {}
            service_type = svc["type"]

            # Validate patch before applying
            clean_patch, warnings = validate_config_patch(service_type, config_patch)
            if not clean_patch:
                return JSONResponse(status_code=400, content={
                    "detail": f"No valid config keys: {'; '.join(warnings)}",
                    "warnings": warnings,
                })

            svc["config"].update(clean_patch)
            found = True
            break

    if not found:
        return JSONResponse(status_code=404, content={
            "detail": f"Service '{service_name}' not found in pipeline"
        })

    # Save updated YAML
    try:
        yaml_path.write_text(yaml.dump(raw, allow_unicode=True))
    except Exception as e:
        return JSONResponse(status_code=500, content={
            "detail": f"Failed to save pipeline YAML: {e}"
        })

    # Create a new job for the re-rendered pipeline
    try:
        pipeline_request = PipelineRequest.model_validate(raw)
    except Exception as e:
        return JSONResponse(status_code=400, content={
            "detail": f"Invalid pipeline after config merge: {e}"
        })

    new_job_id = uuid.uuid4().hex
    log_q: stdlib_queue.SimpleQueue = stdlib_queue.SimpleQueue()
    new_job = {
        "status": "running",
        "result_info": None,
        "log_q": log_q,
        "task": None,
        "config_patch_from": job_id,
    }
    _jobs[new_job_id] = new_job

    task = asyncio.create_task(_execute_job_from_request(new_job_id, pipeline_request))
    new_job["task"] = task

    return JSONResponse({
        "new_job_id": new_job_id,
        "service_name": service_name,
        "applied_config": clean_patch,
        "warnings": warnings if warnings else [],
        "message": f"Config updated for {service_name}. Pipeline re-rendering started.",
    })


@app.get("/config/templates/{service_type}")
async def config_templates(service_type: str) -> JSONResponse:
    """Return available config templates for a service type."""
    templates = _feature_index.get_templates(service_type)
    supported_keys = [
        {
            "key": k.key,
            "type": k.type.__name__,
            "default": k.default,
            "description": k.description,
            "allowed_values": k.allowed_values,
            "min_value": k.min_value,
            "max_value": k.max_value,
        }
        for k in get_supported_keys(service_type)
    ]
    return JSONResponse({
        "service_type": service_type,
        "templates": templates,
        "supported_keys": supported_keys,
    })


@app.post("/config/template/apply")
async def config_template_apply(request: Request) -> JSONResponse:
    """Apply a config template preset.

    Same as /config/apply but resolves the template name to a config patch first.
    """
    body = await request.json()
    job_id = body.get("job_id", "")
    service_name = body.get("service_name", "")
    template_id = body.get("template_id", "")
    service_type = body.get("service_type", "")

    if not service_name or not template_id or not service_type:
        return JSONResponse(status_code=400, content={
            "detail": "service_name, service_type, and template_id are required"
        })

    # Find the template
    templates = _feature_index.get_templates(service_type)
    template = next((t for t in templates if t["id"] == template_id), None)
    if not template:
        return JSONResponse(status_code=404, content={
            "detail": f"Template '{template_id}' not found for {service_type}"
        })

    # Delegate to config_apply with the template's config
    from starlette.requests import Request as StarletteRequest

    class _FakeRequest:
        async def json(self):
            return {
                "job_id": job_id,
                "service_name": service_name,
                "config_patch": template["config"],
            }

    return await config_apply(_FakeRequest())


@app.get("/config/supported-keys/{service_type}")
async def config_supported_keys(service_type: str) -> JSONResponse:
    """Return the config keys the renderer supports for this service type."""
    keys = get_supported_keys(service_type)
    return JSONResponse({
        "service_type": service_type,
        "supported_keys": [
            {
                "key": k.key,
                "type": k.type.__name__,
                "default": k.default,
                "description": k.description,
                "allowed_values": k.allowed_values,
                "min_value": k.min_value,
                "max_value": k.max_value,
            }
            for k in keys
        ],
        "has_keys": len(keys) > 0,
    })


# ─── Entry point ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
