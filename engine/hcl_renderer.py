"""Deterministic HCL renderer — produces Terraform fragments from ServiceBlueprints.

One function per service type. Every function is pure: same inputs → same output.
No LLM calls. No network. No randomness.

Adding a new service type:
  1. Create specs/<type>.yaml (knowledge base)
  2. Add a _render_<type>() function here
  3. Register it in _RENDERERS dict

For simple services, the _render_generic() function handles the common
pattern (one resource + IAM role if principal + tags). Complex services
(StepFunctions, Glue) need custom renderers.
"""
from __future__ import annotations

import json
from typing import Callable

from schemas import PipelineRequest, ServiceBlueprint, IntegrationSpec
from engine.naming import label_for, name_for, suffixed_name

import hashlib


def _safe_id(prefix: str, *parts: str, limit: int = 100) -> str:
    """Build a length-safe, unique ID for AWS resources with char limits.

    Used for statement_id (1-100 chars), target_id (1-64 chars), and similar.
    When the natural ID exceeds the limit, truncate and append a stable hash
    suffix so that different inputs always produce different outputs.
    """
    full = prefix + "-" + "-".join(parts)
    # These IDs allow alphanumeric + hyphen + underscore
    full = full.replace(" ", "_")
    if len(full) <= limit:
        return full
    suffix = hashlib.sha1(full.encode()).hexdigest()[:8]
    return full[:limit - 9] + "-" + suffix


# Backward-compatible alias
_statement_id = _safe_id

# Type alias for renderer functions
Renderer = Callable[[ServiceBlueprint, PipelineRequest], str]


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

# Services that are NOT AWS Free Tier eligible — always emit a warning comment.
_NOT_FREE_TIER = {
    "redshift", "aurora", "emr", "emr_serverless", "msk", "kinesis_streams",
    "kinesis_firehose", "kinesis_analytics", "athena",
    "glue_databrew", "dms", "quicksight", "sagemaker",
}

def _free_tier_warning(bp: ServiceBlueprint) -> str:
    if bp.service_type in _NOT_FREE_TIER:
        return (
            f"# ⚠️  WARNING: {bp.service_type} is NOT AWS Free Tier eligible.\n"
            f"# Costs will be incurred when this resource is deployed.\n"
            f"# Defaults are set to minimum viable size to reduce cost.\n\n"
        )
    return ""


def _tags_block(bp: ServiceBlueprint, indent: int = 2) -> str:
    pad = " " * indent
    lines = [f"{pad}tags = {{"]
    for k, v in bp.tags.items():
        lines.append(f'{pad}  {k:<14}= "{v}"')
    lines.append(f"{pad}}}")
    return "\n".join(lines)


def _iam_role(bp: ServiceBlueprint, principal: str = "lambda.amazonaws.com") -> str:
    role_name = suffixed_name(bp.resource_name, "-role", limit=64)
    return (
        f'resource "aws_iam_role" "{bp.resource_label}_role" {{\n'
        f'  name = "{role_name}"\n\n'
        f"  assume_role_policy = jsonencode({{\n"
        f'    Version = "2012-10-17"\n'
        f"    Statement = [{{\n"
        f'      Effect    = "Allow"\n'
        f'      Principal = {{ Service = "{principal}" }}\n'
        f'      Action    = "sts:AssumeRole"\n'
        f"    }}]\n"
        f"  }})\n\n"
        f"{_tags_block(bp)}\n"
        f"}}"
    )


def _iam_policy(bp: ServiceBlueprint, actions: list[str] | None = None) -> str:
    acts = actions or bp.iam_permissions
    action_lines = ",\n".join(f'          "{a}"' for a in acts)
    policy_name = suffixed_name(bp.resource_name, "-policy", limit=64)
    return (
        f'resource "aws_iam_role_policy" "{bp.resource_label}_policy" {{\n'
        f'  name = "{policy_name}"\n'
        f'  role = aws_iam_role.{bp.resource_label}_role.id\n\n'
        f"  policy = jsonencode({{\n"
        f'    Version = "2012-10-17"\n'
        f"    Statement = [{{\n"
        f'      Effect   = "Allow"\n'
        f"      Action   = [\n{action_lines}\n      ]\n"
        f'      Resource = "*"\n'
        f"    }}]\n"
        f"  }})\n"
        f"}}"
    )


def _find_svc(name: str, request: PipelineRequest):
    return next((s for s in request.services if s.name == name), None)


# ---------------------------------------------------------------------------
# S3
# ---------------------------------------------------------------------------

def _render_s3(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    cfg = bp.required_configuration
    versioning = cfg.get("versioning_status", "Suspended")
    parts = []

    # Bucket
    parts.append(
        f'resource "aws_s3_bucket" "{bp.resource_label}" {{\n'
        f'  bucket        = "{bp.resource_name}"\n'
        f'  force_destroy = true\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    # Versioning
    parts.append(
        f'resource "aws_s3_bucket_versioning" "{bp.resource_label}_versioning" {{\n'
        f'  bucket = aws_s3_bucket.{bp.resource_label}.id\n\n'
        f'  versioning_configuration {{\n    status = "{versioning}"\n  }}\n}}'
    )

    # SSE
    parts.append(
        f'resource "aws_s3_bucket_server_side_encryption_configuration" "{bp.resource_label}_sse" {{\n'
        f'  bucket = aws_s3_bucket.{bp.resource_label}.id\n\n'
        f'  rule {{\n    apply_server_side_encryption_by_default {{\n'
        f'      sse_algorithm = "AES256"\n    }}\n  }}\n}}'
    )

    lambda_integ = [
        i for i in bp.integrations_as_source
        if (t := _find_svc(i.target, req)) and t.type == "lambda"
    ]
    sqs_integ = [
        i for i in bp.integrations_as_source
        if (t := _find_svc(i.target, req)) and t.type == "sqs"
    ]

    # Detect whether any two Lambda targets share the same event type without
    # distinct prefix/suffix filters.  AWS rejects such overlapping notification
    # configs at the API level, so we route via EventBridge instead.
    def _has_overlap() -> bool:
        seen: set[str] = set()
        for i in lambda_integ:
            if i.prefix or i.suffix:
                continue
            ev = i.event if ":" in i.event else "s3:ObjectCreated:*"
            if ev in seen:
                return True
            seen.add(ev)
        return False

    use_eventbridge = bool(lambda_integ) and _has_overlap()

    if use_eventbridge:
        # ── EventBridge fan-out ──────────────────────────────────────────────
        # Enable S3 → EventBridge forwarding on the bucket.  One EventBridge
        # rule is created per distinct event type; every Lambda that listens
        # to that event type becomes a separate target on the rule.
        # This satisfies AWS's constraint that S3 notification configs cannot
        # share event types without non-overlapping filters.

        def _eb_detail_type(ev: str) -> str | None:
            if ev.startswith("s3:ObjectCreated"):
                return "Object Created"
            if ev.startswith("s3:ObjectRemoved"):
                return "Object Deleted"
            return None

        # Group lambda integrations by (event type, prefix) so that integrations
        # with distinct prefixes each get their own rule with a key-prefix filter.
        # Integrations without a prefix sharing the same event type are grouped
        # together under a single rule (the original fan-out behaviour).
        event_groups: dict[tuple, list] = {}
        for integ in lambda_integ:
            ev = integ.event if ":" in integ.event else "s3:ObjectCreated:*"
            # Integrations with a prefix get an isolated rule; others share one.
            group_key = (ev, integ.prefix or "")
            event_groups.setdefault(group_key, []).append(integ)

        for (ev, prefix), integ_list in event_groups.items():
            ev_slug = ev.replace("s3:", "").replace(":", "_").replace("*", "all").lower()
            # Include a stable prefix slug in the rule label so rules don't collide.
            pfx_slug = prefix.rstrip("/").replace("/", "_") if prefix else ""
            rule_label = f"{bp.resource_label}_eb_{ev_slug}" + (f"_{pfx_slug}" if pfx_slug else "")
            rule_name = suffixed_name(bp.resource_name, f"-eb-{ev_slug[:8]}" + (f"-{pfx_slug[:8]}" if pfx_slug else ""), 64)

            pattern: dict = {
                "source": ["aws.s3"],
                "detail": {"bucket": {"name": [bp.resource_name]}},
            }
            dt = _eb_detail_type(ev)
            if dt:
                pattern["detail-type"] = [dt]
            # Add object key prefix filter so only matching uploads reach this rule.
            if prefix:
                pattern["detail"]["object"] = {"key": [{"prefix": prefix}]}

            parts.append(
                f'resource "aws_cloudwatch_event_rule" "{rule_label}" {{\n'
                f'  name          = "{rule_name}"\n'
                f'  description   = "S3 EventBridge fan-out: {bp.resource_name} / {ev}' + (f' / {prefix}' if prefix else '') + f'"\n'
                f'  event_pattern = {json.dumps(json.dumps(pattern))}\n\n'
                f"{_tags_block(bp)}\n}}"
            )

            for integ in integ_list:
                t_label = label_for(integ.target, "lambda", req)
                # target_id: max 64 chars, must be unique per rule
                target_id = _safe_id(ev_slug[:16], t_label, limit=64)
                parts.append(
                    f'resource "aws_cloudwatch_event_target" "{rule_label}_to_{t_label}" {{\n'
                    f'  rule      = aws_cloudwatch_event_rule.{rule_label}.name\n'
                    f'  target_id = "{target_id}"\n'
                    f'  arn       = aws_lambda_function.{t_label}.arn\n}}'
                )
                # statement_id: unique per (Lambda, source rule), max 100 chars
                sid = _statement_id("AllowS3EB", bp.resource_label, t_label)
                parts.append(
                    f'resource "aws_lambda_permission" "{t_label}_allow_eb_{bp.resource_label}" {{\n'
                    f'  statement_id  = "{sid}"\n'
                    f'  action        = "lambda:InvokeFunction"\n'
                    f'  function_name = aws_lambda_function.{t_label}.function_name\n'
                    f'  principal     = "events.amazonaws.com"\n'
                    f'  source_arn    = aws_cloudwatch_event_rule.{rule_label}.arn\n}}'
                )

        # Single notification resource: EventBridge enabled + any SQS queues
        notif = [
            f'resource "aws_s3_bucket_notification" "{bp.resource_label}_notification" {{',
            f'  bucket      = aws_s3_bucket.{bp.resource_label}.id',
            f'  eventbridge = true',
            '',
        ]
        for integ in sqs_integ:
            t_label = label_for(integ.target, "sqs", req)
            ev = integ.event if ":" in integ.event else "s3:ObjectCreated:*"
            notif.append(
                f'  queue {{\n'
                f'    queue_arn = aws_sqs_queue.{t_label}.arn\n'
                f'    events   = ["{ev}"]\n'
                f'  }}'
            )
        notif.append('}')
        parts.append('\n'.join(notif))

    else:
        # ── Direct S3 notifications (no overlap) ─────────────────────────────
        # statement_id includes bucket label so two different buckets invoking
        # the same Lambda function never collide on the function's policy.
        perm_labels: list[str] = []
        for integ in lambda_integ:
            t_label = label_for(integ.target, "lambda", req)
            perm_label = f"{bp.resource_label}_invoke_{t_label}"
            perm_labels.append(perm_label)
            parts.append(
                f'resource "aws_lambda_permission" "{perm_label}" {{\n'
                f'  statement_id  = "{_statement_id("AllowS3", bp.resource_label, t_label)}"\n'
                f'  action        = "lambda:InvokeFunction"\n'
                f'  function_name = aws_lambda_function.{t_label}.function_name\n'
                f'  principal     = "s3.amazonaws.com"\n'
                f'  source_arn    = aws_s3_bucket.{bp.resource_label}.arn\n}}'
            )

        if lambda_integ or sqs_integ:
            # Add a 15-second sleep after Lambda permissions are created.
            # AWS IAM is eventually consistent: PutBucketNotificationConfiguration
            # validates Lambda permissions via GetPolicy.  If the permission hasn't
            # fully propagated when S3 calls GetPolicy, the notification is silently
            # not registered — Lambda never triggers even though Terraform reports
            # success.  The sleep ensures propagation before the notification is set.
            sleep_label = f"{bp.resource_label}_iam_sleep"
            if perm_labels:
                sleep_deps = ", ".join(f"aws_lambda_permission.{l}" for l in perm_labels)
                parts.append(
                    f'resource "time_sleep" "{sleep_label}" {{\n'
                    f'  depends_on      = [{sleep_deps}]\n'
                    f'  create_duration = "15s"\n'
                    f'}}'
                )

            notif = [
                f'resource "aws_s3_bucket_notification" "{bp.resource_label}_notification" {{',
                f'  bucket = aws_s3_bucket.{bp.resource_label}.id',
                '',
            ]
            for integ in lambda_integ:
                t_label = label_for(integ.target, "lambda", req)
                event = integ.event if ":" in integ.event else "s3:ObjectCreated:*"
                notif_id = f"{bp.resource_label}_{t_label}"
                filter_lines = f'\n    id                  = "{notif_id}"'
                if integ.prefix:
                    filter_lines += f'\n    filter_prefix       = "{integ.prefix}"'
                if integ.suffix:
                    filter_lines += f'\n    filter_suffix       = "{integ.suffix}"'
                notif.append(
                    f'  lambda_function {{{filter_lines}\n'
                    f'    lambda_function_arn = aws_lambda_function.{t_label}.arn\n'
                    f'    events              = ["{event}"]\n'
                    f'  }}'
                )
            for integ in sqs_integ:
                t_label = label_for(integ.target, "sqs", req)
                event = integ.event if ":" in integ.event else "s3:ObjectCreated:*"
                notif.append(
                    f'  queue {{\n'
                    f'    queue_arn = aws_sqs_queue.{t_label}.arn\n'
                    f'    events   = ["{event}"]\n'
                    f'  }}'
                )
            if perm_labels:
                deps = ", ".join(f"aws_lambda_permission.{l}" for l in perm_labels)
                deps += f", time_sleep.{sleep_label}"
                notif.append(f'  depends_on = [{deps}]')
            notif.append('}')
            parts.append('\n'.join(notif))

    return "\n\n".join(parts)


# ---------------------------------------------------------------------------
# Lambda
# ---------------------------------------------------------------------------

_DEFAULT_LAMBDA_CODE = 'def handler(event, context):\\n    return {\\\"statusCode\\\": 200}'


def _lambda_code(cfg: dict) -> str:
    """Return Lambda handler code: user-provided or default placeholder."""
    custom = cfg.get("handler_code", "")
    if not custom:
        return _DEFAULT_LAMBDA_CODE
    # Escape for HCL string embedding
    return custom.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def _render_lambda(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    cfg = bp.required_configuration
    runtime = cfg.get("runtime", "python3.12")
    handler = cfg.get("handler", "index.handler")
    memory = cfg.get("memory_size", 128)
    timeout = cfg.get("timeout", 30)

    parts = []

    # IAM role + policy
    parts.append(_iam_role(bp, "lambda.amazonaws.com"))
    parts.append(_iam_policy(bp))

    # Log group (owned by Lambda, never by a separate CloudWatch service)
    parts.append(
        f'resource "aws_cloudwatch_log_group" "{bp.resource_label}_lg" {{\n'
        f'  name              = "/aws/lambda/{bp.resource_name}"\n'
        f'  retention_in_days = 7\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    # Environment variables
    env_block = ""
    if bp.env_vars:
        var_lines = "\n".join(f"      {k} = {v}" for k, v in bp.env_vars.items())
        env_block = f"\n\n  environment {{\n    variables = {{\n{var_lines}\n    }}\n  }}"

    # VPC config
    vpc_block = ""
    if bp.vpc_required:
        parts.append(
            f'resource "aws_security_group" "{bp.resource_label}_sg" {{\n'
            f'  name        = "{bp.resource_name}-sg"\n'
            f'  description = "SG for {bp.resource_name}"\n'
            f'  vpc_id      = data.aws_vpc.default.id\n\n'
            f"  egress {{\n    from_port   = 0\n    to_port     = 0\n"
            f'    protocol    = "-1"\n    cidr_blocks = ["0.0.0.0/0"]\n  }}\n\n'
            f"{_tags_block(bp)}\n}}"
        )
        vpc_block = (
            f"\n\n  vpc_config {{\n"
            f"    subnet_ids         = data.aws_subnets.default.ids\n"
            f"    security_group_ids = [aws_security_group.{bp.resource_label}_sg.id]\n"
            f"  }}"
        )

    # Inline placeholder zip — no pre-existing file required at apply time
    parts.insert(0,
        f'data "archive_file" "{bp.resource_label}_placeholder" {{\n'
        f'  type        = "zip"\n'
        f'  output_path = "${{path.module}}/{bp.resource_label}_placeholder.zip"\n'
        f'  source {{\n'
        f'    content  = "{_lambda_code(cfg)}"\n'
        f'    filename = "index.py"\n'
        f'  }}\n}}'
    )

    # Lambda function
    parts.append(
        f'resource "aws_lambda_function" "{bp.resource_label}" {{\n'
        f'  function_name    = "{bp.resource_name}"\n'
        f'  role             = aws_iam_role.{bp.resource_label}_role.arn\n'
        f'  runtime          = "{runtime}"\n'
        f'  handler          = "{handler}"\n'
        f"  memory_size      = {memory}\n"
        f"  timeout          = {timeout}\n"
        f'  filename         = data.archive_file.{bp.resource_label}_placeholder.output_path\n'
        f'  source_code_hash = data.archive_file.{bp.resource_label}_placeholder.output_base64sha256'
        f"{env_block}{vpc_block}\n\n"
        f"{_tags_block(bp)}\n\n"
        f"  depends_on = [aws_cloudwatch_log_group.{bp.resource_label}_lg]\n}}"
    )

    # Event source mappings (SQS / Kinesis Streams / DynamoDB Streams → this Lambda)
    for integ in bp.integrations_as_target:
        src = _find_svc(integ.source, req)
        if not src:
            continue
        s_label = label_for(integ.source, src.type, req)
        if src.type == "sqs":
            parts.append(
                f'resource "aws_lambda_event_source_mapping" "{bp.resource_label}_esm_{s_label}" {{\n'
                f'  event_source_arn = aws_sqs_queue.{s_label}.arn\n'
                f'  function_name    = aws_lambda_function.{bp.resource_label}.arn\n'
                f"  batch_size       = 10\n}}"
            )
        elif src.type == "kinesis_streams":
            parts.append(
                f'resource "aws_lambda_event_source_mapping" "{bp.resource_label}_esm_{s_label}" {{\n'
                f'  event_source_arn  = aws_kinesis_stream.{s_label}.arn\n'
                f'  function_name     = aws_lambda_function.{bp.resource_label}.arn\n'
                f'  starting_position = "LATEST"\n'
                f"  batch_size        = 100\n}}"
            )
        elif src.type == "dynamodb":
            parts.append(
                f'resource "aws_lambda_event_source_mapping" "{bp.resource_label}_esm_{s_label}" {{\n'
                f'  event_source_arn  = aws_dynamodb_table.{s_label}.stream_arn\n'
                f'  function_name     = aws_lambda_function.{bp.resource_label}.arn\n'
                f'  starting_position = "LATEST"\n'
                f"  batch_size        = 100\n}}"
            )

    # Lambda → Lambda permissions (this Lambda invokes another)
    for integ in bp.integrations_as_source:
        tgt = _find_svc(integ.target, req)
        if not tgt or tgt.type != "lambda":
            continue
        t_label = label_for(integ.target, "lambda", req)
        parts.append(
            f'resource "aws_lambda_permission" "{t_label}_allow_{bp.resource_label}" {{\n'
            f'  statement_id  = "{_statement_id("AllowInvoke", bp.resource_label, t_label)}"\n'
            f'  action        = "lambda:InvokeFunction"\n'
            f'  function_name = aws_lambda_function.{t_label}.function_name\n'
            f'  principal     = "lambda.amazonaws.com"\n'
            f'  source_arn    = aws_lambda_function.{bp.resource_label}.arn\n}}'
        )

    return "\n\n".join(parts)


# ---------------------------------------------------------------------------
# SQS
# ---------------------------------------------------------------------------

def _render_sqs(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    cfg = bp.required_configuration
    vis = cfg.get("visibility_timeout_seconds", 30)
    ret = cfg.get("message_retention_seconds", 86400)
    parts = []

    parts.append(
        f'resource "aws_sqs_queue" "{bp.resource_label}" {{\n'
        f'  name                       = "{bp.resource_name}"\n'
        f"  visibility_timeout_seconds = {vis}\n"
        f"  message_retention_seconds  = {ret}\n\n"
        f"{_tags_block(bp)}\n}}"
    )

    # Queue policy: AWS allows exactly ONE aws_sqs_queue_policy per queue.
    # Consolidate all source principals (S3, CloudWatch/EventBridge, SNS) into
    # a single policy with multiple statements to avoid the second resource
    # silently overwriting the first at apply time.
    s3_sources = [
        integ for integ in bp.integrations_as_target
        if (s := _find_svc(integ.source, req)) and s.type == "s3"
    ]
    events_sources = [
        integ for integ in bp.integrations_as_target
        if (s := _find_svc(integ.source, req)) and s.type in ("cloudwatch", "eventbridge")
    ]
    sns_sources = [
        integ for integ in bp.integrations_as_target
        if (s := _find_svc(integ.source, req)) and s.type == "sns"
    ]

    if s3_sources or events_sources or sns_sources:
        statements: list[str] = []
        for integ in s3_sources:
            s_label = label_for(integ.source, "s3", req)
            statements.append(
                f"    {{\n"
                f'      Effect    = "Allow"\n'
                f'      Principal = {{ Service = "s3.amazonaws.com" }}\n'
                f'      Action    = "sqs:SendMessage"\n'
                f"      Resource  = aws_sqs_queue.{bp.resource_label}.arn\n"
                f"      Condition = {{\n"
                f"        ArnEquals = {{\n"
                f'          "aws:SourceArn" = aws_s3_bucket.{s_label}.arn\n'
                f"        }}\n"
                f"      }}\n"
                f"    }}"
            )
        if events_sources:
            statements.append(
                f"    {{\n"
                f'      Effect    = "Allow"\n'
                f'      Principal = {{ Service = "events.amazonaws.com" }}\n'
                f'      Action    = "sqs:SendMessage"\n'
                f"      Resource  = aws_sqs_queue.{bp.resource_label}.arn\n"
                f"    }}"
            )
        for integ in sns_sources:
            s_label = label_for(integ.source, "sns", req)
            statements.append(
                f"    {{\n"
                f'      Effect    = "Allow"\n'
                f'      Principal = {{ Service = "sns.amazonaws.com" }}\n'
                f'      Action    = "sqs:SendMessage"\n'
                f"      Resource  = aws_sqs_queue.{bp.resource_label}.arn\n"
                f"      Condition = {{\n"
                f"        ArnEquals = {{\n"
                f'          "aws:SourceArn" = aws_sns_topic.{s_label}.arn\n'
                f"        }}\n"
                f"      }}\n"
                f"    }}"
            )
        stmts_body = ",\n".join(statements)
        parts.append(
            f'resource "aws_sqs_queue_policy" "{bp.resource_label}_policy" {{\n'
            f'  queue_url = aws_sqs_queue.{bp.resource_label}.id\n\n'
            f"  policy = jsonencode({{\n"
            f'    Version = "2012-10-17"\n'
            f"    Statement = [\n{stmts_body}\n"
            f"    ]\n"
            f"  }})\n}}"
        )

    return "\n\n".join(parts)


# ---------------------------------------------------------------------------
# DynamoDB
# ---------------------------------------------------------------------------

def _render_dynamodb(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    cfg = bp.required_configuration
    billing   = cfg.get("billing_mode", "PROVISIONED")
    hash_key  = cfg.get("hash_key", "id")
    key_type  = cfg.get("hash_key_type", "S")

    # PROVISIONED mode needs read/write capacity — free tier: 25 RCU + 25 WCU
    capacity_lines = ""
    if billing == "PROVISIONED":
        rcu = cfg.get("read_capacity", 5)
        wcu = cfg.get("write_capacity", 5)
        capacity_lines = (
            f"  # Free tier: up to 25 RCU + 25 WCU across all PROVISIONED tables\n"
            f"  read_capacity  = {rcu}\n"
            f"  write_capacity = {wcu}\n"
        )

    # Enable DynamoDB Streams when a Lambda reads from this table
    stream_lines = ""
    for integ in bp.integrations_as_source:
        tgt = _find_svc(integ.target, req)
        if tgt and tgt.type == "lambda":
            stream_lines = (
                f"  stream_enabled   = true\n"
                f'  stream_view_type = "NEW_AND_OLD_IMAGES"\n'
            )
            break

    return (
        f'resource "aws_dynamodb_table" "{bp.resource_label}" {{\n'
        f'  name         = "{bp.resource_name}"\n'
        f'  billing_mode = "{billing}"\n'
        f"{capacity_lines}"
        f'  hash_key     = "{hash_key}"\n\n'
        f'  attribute {{\n    name = "{hash_key}"\n    type = "{key_type}"\n  }}\n\n'
        f"{stream_lines}"
        f"{_tags_block(bp)}\n}}"
    )


# ---------------------------------------------------------------------------
# Step Functions
# ---------------------------------------------------------------------------

def _render_stepfunctions(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    cfg = bp.required_configuration
    sf_type = cfg.get("type", "STANDARD")
    parts = []

    # IAM role
    parts.append(_iam_role(bp, "states.amazonaws.com"))
    parts.append(_iam_policy(bp))

    # Build state machine definition from outgoing integrations
    states_json = _build_state_machine_definition(bp, req)
    definition_escaped = json.dumps(json.dumps(states_json))

    # CloudWatch log group for execution logs
    parts.append(
        f'resource "aws_cloudwatch_log_group" "{bp.resource_label}_lg" {{\n'
        f'  name              = "/aws/vendedlogs/states/{bp.resource_name}"\n'
        f'  retention_in_days = 7\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    parts.append(
        f'resource "aws_sfn_state_machine" "{bp.resource_label}" {{\n'
        f'  name     = "{bp.resource_name}"\n'
        f'  role_arn = aws_iam_role.{bp.resource_label}_role.arn\n'
        f'  type     = "{sf_type}"\n\n'
        f"  definition = {definition_escaped}\n\n"
        f"  logging_configuration {{\n"
        f'    log_destination        = "${{aws_cloudwatch_log_group.{bp.resource_label}_lg.arn}}:*"\n'
        f'    include_execution_data = true\n'
        f'    level                  = "ALL"\n'
        f"  }}\n\n"
        f"{_tags_block(bp)}\n}}"
    )

    return "\n\n".join(parts)


def _build_state_machine_definition(bp: ServiceBlueprint, req: PipelineRequest) -> dict:
    """Build an AWS States Language JSON definition from outgoing integrations."""
    states = {}
    state_names = []

    for integ in bp.integrations_as_source:
        tgt = _find_svc(integ.target, req)
        if not tgt:
            continue
        t_label = label_for(integ.target, tgt.type, req)
        state_name = f"Invoke_{integ.target}"
        state_names.append(state_name)

        if tgt.type == "lambda":
            states[state_name] = {
                "Type": "Task",
                "Resource": "arn:aws:states:::lambda:invoke",
                "Parameters": {
                    "FunctionName.$": f"$.function_name",
                    "Payload.$": "$"
                },
            }
        elif tgt.type == "glue":
            states[state_name] = {
                "Type": "Task",
                "Resource": "arn:aws:states:::glue:startJobRun.sync",
                "Parameters": {"JobName": integ.target},
            }
        elif tgt.type == "dynamodb":
            states[state_name] = {
                "Type": "Task",
                "Resource": "arn:aws:states:::dynamodb:putItem",
                "Parameters": {
                    "TableName": integ.target,
                    "Item": {"id": {"S.$": "$.id"}},
                },
            }
        elif tgt.type == "sqs":
            states[state_name] = {
                "Type": "Task",
                "Resource": "arn:aws:states:::sqs:sendMessage",
                "Parameters": {
                    "QueueUrl.$": "$.queue_url",
                    "MessageBody.$": "$",
                },
            }
        elif tgt.type == "sns":
            states[state_name] = {
                "Type": "Task",
                "Resource": "arn:aws:states:::sns:publish",
                "Parameters": {
                    "TopicArn.$": "$.topic_arn",
                    "Message.$": "$",
                },
            }
        elif tgt.type == "s3":
            states[state_name] = {
                "Type": "Task",
                "Resource": "arn:aws:states:::aws-sdk:s3:putObject",
                "Parameters": {
                    "Bucket.$": "$.bucket",
                    "Key.$": "$.key",
                    "Body.$": "$.body",
                },
            }
        elif tgt.type == "emr_serverless":
            states[state_name] = {
                "Type": "Task",
                "Resource": "arn:aws:states:::emr-serverless:startJobRun.sync",
                "Parameters": {
                    "ApplicationId.$": "$.application_id",
                    "ExecutionRoleArn.$": "$.execution_role_arn",
                    "JobDriver": {
                        "SparkSubmit": {
                            "EntryPoint.$": "$.entry_point",
                        }
                    },
                },
            }
        elif tgt.type == "emr":
            states[state_name] = {
                "Type": "Task",
                "Resource": "arn:aws:states:::elasticmapreduce:addStep.sync",
                "Parameters": {
                    "ClusterId.$": "$.cluster_id",
                    "Step": {
                        "Name": integ.target,
                        "ActionOnFailure": "CONTINUE",
                        "HadoopJarStep": {
                            "Jar": "command-runner.jar",
                            "Args.$": "$.step_args",
                        },
                    },
                },
            }
        elif tgt.type == "sagemaker":
            states[state_name] = {
                "Type": "Task",
                "Resource": "arn:aws:states:::sagemaker:createTransformJob.sync",
                "Parameters": {
                    "TransformJobName.$": "$.job_name",
                    "ModelName.$": "$.model_name",
                    "TransformInput": {
                        "DataSource": {
                            "S3DataSource": {
                                "S3DataType": "S3Prefix",
                                "S3Uri.$": "$.input_uri",
                            }
                        },
                        "ContentType": "text/csv",
                    },
                    "TransformOutput": {"S3OutputPath.$": "$.output_uri"},
                    "TransformResources": {
                        "InstanceCount": 1,
                        "InstanceType": "ml.m5.large",
                    },
                },
            }
        elif tgt.type == "athena":
            states[state_name] = {
                "Type": "Task",
                "Resource": "arn:aws:states:::athena:startQueryExecution.sync",
                "Parameters": {
                    "QueryString.$": "$.query",
                    "WorkGroup": integ.target,
                },
            }
        elif tgt.type == "eventbridge":
            states[state_name] = {
                "Type": "Task",
                "Resource": "arn:aws:states:::events:putEvents",
                "Parameters": {
                    "Entries": [{
                        "Source": f"stepfunctions.{bp.service_name}",
                        "DetailType": "StepFunctionOutput",
                        "Detail.$": "$",
                    }],
                },
            }
        else:
            states[state_name] = {
                "Type": "Task",
                "Resource": f"arn:aws:states:::aws-sdk:{tgt.type}:invoke",
                "Parameters": {},
            }

    # Chain states
    for i, name in enumerate(state_names):
        if i < len(state_names) - 1:
            states[name]["Next"] = state_names[i + 1]
        else:
            states[name]["End"] = True

    if not state_names:
        states["PassState"] = {"Type": "Pass", "End": True}
        state_names = ["PassState"]

    return {"Comment": f"State machine for {bp.service_name}", "StartAt": state_names[0], "States": states}


# ---------------------------------------------------------------------------
# Glue
# ---------------------------------------------------------------------------

def _render_glue(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    parts = []

    # CloudWatch log group for Glue crawler/job logs
    parts.append(
        f'resource "aws_cloudwatch_log_group" "{bp.resource_label}_lg" {{\n'
        f'  name              = "/aws-glue/jobs/{bp.resource_name}"\n'
        f'  retention_in_days = 7\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    # Catalog database
    parts.append(
        f'resource "aws_glue_catalog_database" "{bp.resource_label}_db" {{\n'
        f'  name = "{bp.resource_name.replace("-", "_")}_db"\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    # IAM role for crawler
    parts.append(_iam_role(bp, "glue.amazonaws.com"))
    parts.append(_iam_policy(bp))

    # Crawler — target S3 buckets from integrations
    s3_targets = ""
    for integ in bp.integrations_as_source:
        tgt = _find_svc(integ.target, req)
        if tgt and tgt.type == "s3":
            t_label = label_for(integ.target, "s3", req)
            s3_targets += (
                f'\n  s3_target {{\n'
                f'    path = "s3://${{aws_s3_bucket.{t_label}.id}}/"\n'
                f"  }}\n"
            )
    # Also check if Glue reads FROM S3 (is target of integration from S3)
    for integ in bp.integrations_as_target:
        src = _find_svc(integ.source, req)
        if src and src.type == "s3":
            s_label = label_for(integ.source, "s3", req)
            s3_targets += (
                f'\n  s3_target {{\n'
                f'    path = "s3://${{aws_s3_bucket.{s_label}.id}}/"\n'
                f"  }}\n"
            )

    if not s3_targets:
        s3_targets = '\n  s3_target {\n    path = "s3://placeholder/"\n  }\n'

    parts.append(
        f'resource "aws_glue_crawler" "{bp.resource_label}" {{\n'
        f'  name          = "{bp.resource_name}"\n'
        f'  database_name = aws_glue_catalog_database.{bp.resource_label}_db.name\n'
        f'  role          = aws_iam_role.{bp.resource_label}_role.arn\n'
        f"{s3_targets}\n"
        f"  schema_change_policy {{\n"
        f'    update_behavior = "UPDATE_IN_DATABASE"\n'
        f'    delete_behavior = "LOG"\n'
        f"  }}\n\n"
        f"{_tags_block(bp)}\n}}"
    )

    return "\n\n".join(parts)


# ---------------------------------------------------------------------------
# CloudWatch (scheduled event rule)
# ---------------------------------------------------------------------------

def _render_cloudwatch(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    cfg = bp.required_configuration
    schedule = cfg.get("schedule_expression", "rate(5 minutes)")
    parts = []

    # Event rule
    parts.append(
        f'resource "aws_cloudwatch_event_rule" "{bp.resource_label}_rule" {{\n'
        f'  name                = "{suffixed_name(bp.resource_name, "-rule", 64)}"\n'
        f'  schedule_expression = "{schedule}"\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    # Targets — one per outgoing integration
    for integ in bp.integrations_as_source:
        tgt = _find_svc(integ.target, req)
        if not tgt:
            continue
        t_label = label_for(integ.target, tgt.type, req)

        if tgt.type == "sqs":
            parts.append(
                f'resource "aws_cloudwatch_event_target" "{bp.resource_label}_target_{t_label}" {{\n'
                f'  rule      = aws_cloudwatch_event_rule.{bp.resource_label}_rule.name\n'
                f'  target_id = "{_safe_id("cw", bp.resource_label, t_label, limit=64)}"\n'
                f'  arn       = aws_sqs_queue.{t_label}.arn\n}}'
            )
        elif tgt.type == "lambda":
            parts.append(
                f'resource "aws_cloudwatch_event_target" "{bp.resource_label}_target_{t_label}" {{\n'
                f'  rule      = aws_cloudwatch_event_rule.{bp.resource_label}_rule.name\n'
                f'  target_id = "{_safe_id("cw", bp.resource_label, t_label, limit=64)}"\n'
                f'  arn       = aws_lambda_function.{t_label}.arn\n}}'
            )
            # statement_id includes source rule label — two different CW rules
            # invoking the same Lambda must not share a statement_id.
            parts.append(
                f'resource "aws_lambda_permission" "{t_label}_allow_{bp.resource_label}" {{\n'
                f'  statement_id  = "{_safe_id("AllowCW", bp.resource_label, t_label)}"\n'
                f'  action        = "lambda:InvokeFunction"\n'
                f'  function_name = aws_lambda_function.{t_label}.function_name\n'
                f'  principal     = "events.amazonaws.com"\n'
                f'  source_arn    = aws_cloudwatch_event_rule.{bp.resource_label}_rule.arn\n}}'
            )

    return "\n\n".join(parts)


# ---------------------------------------------------------------------------
# SNS
# ---------------------------------------------------------------------------

def _render_sns(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    parts = []
    parts.append(
        f'resource "aws_sns_topic" "{bp.resource_label}" {{\n'
        f'  name = "{bp.resource_name}"\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    # Subscriptions for outgoing integrations (SNS → SQS, SNS → Lambda)
    for integ in bp.integrations_as_source:
        tgt = _find_svc(integ.target, req)
        if not tgt:
            continue
        t_label = label_for(integ.target, tgt.type, req)
        if tgt.type == "sqs":
            parts.append(
                f'resource "aws_sns_topic_subscription" "{bp.resource_label}_sub_{t_label}" {{\n'
                f'  topic_arn = aws_sns_topic.{bp.resource_label}.arn\n'
                f'  protocol  = "sqs"\n'
                f'  endpoint  = aws_sqs_queue.{t_label}.arn\n}}'
            )
        elif tgt.type == "lambda":
            parts.append(
                f'resource "aws_sns_topic_subscription" "{bp.resource_label}_sub_{t_label}" {{\n'
                f'  topic_arn = aws_sns_topic.{bp.resource_label}.arn\n'
                f'  protocol  = "lambda"\n'
                f'  endpoint  = aws_lambda_function.{t_label}.arn\n}}'
            )

    return "\n\n".join(parts)


# ---------------------------------------------------------------------------
# Kinesis Streams
# ---------------------------------------------------------------------------

def _render_kinesis_streams(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    warn = _free_tier_warning(bp)
    cfg = bp.required_configuration
    mode = cfg.get("stream_mode", "ON_DEMAND")
    shard_count = 1 if mode == "ON_DEMAND" else cfg.get("shard_count", 1)
    retention = cfg.get("retention_period", 24)

    return (
        warn +
        f'resource "aws_kinesis_stream" "{bp.resource_label}" {{\n'
        f'  name             = "{bp.resource_name}"\n'
        f"  shard_count      = {shard_count}\n"
        f"  retention_period = {retention}\n\n"
        f"  stream_mode_details {{\n"
        f'    stream_mode = "{mode}"\n'
        f"  }}\n\n"
        f"{_tags_block(bp)}\n}}"
    )


# ---------------------------------------------------------------------------
# Athena
# ---------------------------------------------------------------------------

def _render_athena(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    warn = _free_tier_warning(bp)
    cfg = bp.required_configuration

    # CloudWatch log group for Athena query execution logs
    warn += (
        f'resource "aws_cloudwatch_log_group" "{bp.resource_label}_lg" {{\n'
        f'  name              = "/aws/athena/{bp.resource_name}"\n'
        f'  retention_in_days = 7\n\n'
        f"{_tags_block(bp)}\n}}\n\n"
    )

    # Find an S3 bucket in the pipeline for query results
    output_bucket = None
    for integ in bp.integrations_as_source:
        tgt = _find_svc(integ.target, req)
        if tgt and tgt.type == "s3":
            output_bucket = name_for(integ.target, "s3", req)
            break
    if not output_bucket:
        # Fallback: use a conventional name
        output_bucket = f"{bp.resource_name}-results"

    return warn + (
        f'resource "aws_athena_workgroup" "{bp.resource_label}" {{\n'
        f'  name = "{bp.resource_name}"\n\n'
        f"  configuration {{\n"
        f"    enforce_workgroup_configuration    = true\n"
        f"    publish_cloudwatch_metrics_enabled = false\n\n"
        f"    result_configuration {{\n"
        f'      output_location = "s3://{output_bucket}/query-results/"\n'
        f"    }}\n\n"
        f"    engine_version {{\n"
        f'      selected_engine_version = "AUTO"\n'
        f"    }}\n"
        f"  }}\n\n"
        f"{_tags_block(bp)}\n}}"
    )


# ---------------------------------------------------------------------------
# EventBridge
# ---------------------------------------------------------------------------

def _render_eventbridge(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    cfg = bp.required_configuration
    schedule = cfg.get("schedule_expression", "")
    pattern = cfg.get("event_pattern", "")
    parts = []

    rule_body = ""
    if schedule:
        rule_body = f'  schedule_expression = "{schedule}"\n'
    elif pattern:
        rule_body = f"  event_pattern = jsonencode({json.dumps(pattern)})\n"
    else:
        rule_body = '  schedule_expression = "rate(1 hour)"\n'

    parts.append(
        f'resource "aws_cloudwatch_event_rule" "{bp.resource_label}_rule" {{\n'
        f'  name = "{suffixed_name(bp.resource_name, "-rule", 64)}"\n'
        f"{rule_body}\n"
        f"{_tags_block(bp)}\n}}"
    )

    for integ in bp.integrations_as_source:
        tgt = _find_svc(integ.target, req)
        if not tgt:
            continue
        t_label = label_for(integ.target, tgt.type, req)
        if tgt.type == "lambda":
            parts.append(
                f'resource "aws_cloudwatch_event_target" "{bp.resource_label}_target_{t_label}" {{\n'
                f'  rule      = aws_cloudwatch_event_rule.{bp.resource_label}_rule.name\n'
                f'  target_id = "{_safe_id("eb", bp.resource_label, t_label, limit=64)}"\n'
                f'  arn       = aws_lambda_function.{t_label}.arn\n}}'
            )
            # statement_id includes source rule label — two EventBridge rules
            # invoking the same Lambda must not share a statement_id.
            parts.append(
                f'resource "aws_lambda_permission" "{t_label}_allow_{bp.resource_label}" {{\n'
                f'  statement_id  = "{_safe_id("AllowEB", bp.resource_label, t_label)}"\n'
                f'  action        = "lambda:InvokeFunction"\n'
                f'  function_name = aws_lambda_function.{t_label}.function_name\n'
                f'  principal     = "events.amazonaws.com"\n'
                f'  source_arn    = aws_cloudwatch_event_rule.{bp.resource_label}_rule.arn\n}}'
            )
        elif tgt.type == "sqs":
            parts.append(
                f'resource "aws_cloudwatch_event_target" "{bp.resource_label}_target_{t_label}" {{\n'
                f'  rule      = aws_cloudwatch_event_rule.{bp.resource_label}_rule.name\n'
                f'  target_id = "{_safe_id("eb", bp.resource_label, t_label, limit=64)}"\n'
                f'  arn       = aws_sqs_queue.{t_label}.arn\n}}'
            )

    return "\n\n".join(parts)


# ---------------------------------------------------------------------------
# EC2
# ---------------------------------------------------------------------------

def _render_ec2(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    cfg = bp.required_configuration
    instance_type = cfg.get("instance_type", "t3.micro")
    parts = []

    # AMI data source
    parts.append(
        f'data "aws_ami" "{bp.resource_label}_ami" {{\n'
        f"  most_recent = true\n"
        f'  owners      = ["amazon"]\n\n'
        f'  filter {{\n    name   = "name"\n'
        f'    values = ["amzn2-ami-hvm-*-x86_64-gp2"]\n  }}\n'
        f'  filter {{\n    name   = "virtualization-type"\n'
        f'    values = ["hvm"]\n  }}\n}}'
    )

    # IAM
    parts.append(_iam_role(bp, "ec2.amazonaws.com"))
    parts.append(_iam_policy(bp))
    parts.append(
        f'resource "aws_iam_instance_profile" "{bp.resource_label}_profile" {{\n'
        f'  name = "{suffixed_name(bp.resource_name, "-profile", limit=64)}"\n'
        f'  role = aws_iam_role.{bp.resource_label}_role.name\n}}'
    )

    # Security group
    parts.append(
        f'resource "aws_security_group" "{bp.resource_label}_sg" {{\n'
        f'  name        = "{bp.resource_name}-sg"\n'
        f'  description = "SG for {bp.resource_name}"\n\n'
        f"  egress {{\n    from_port   = 0\n    to_port     = 0\n"
        f'    protocol    = "-1"\n    cidr_blocks = ["0.0.0.0/0"]\n  }}\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    # Instance
    parts.append(
        f'resource "aws_instance" "{bp.resource_label}" {{\n'
        f'  ami                    = data.aws_ami.{bp.resource_label}_ami.id\n'
        f'  instance_type          = "{instance_type}"\n'
        f'  iam_instance_profile   = aws_iam_instance_profile.{bp.resource_label}_profile.name\n'
        f'  vpc_security_group_ids = [aws_security_group.{bp.resource_label}_sg.id]\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    return "\n\n".join(parts)


# ---------------------------------------------------------------------------
# Kinesis Firehose
# ---------------------------------------------------------------------------

def _render_kinesis_firehose(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    warn = _free_tier_warning(bp)
    cfg = bp.required_configuration
    buf_size = cfg.get("buffering_size", 128)
    buf_interval = cfg.get("buffering_interval", 300)
    compression = cfg.get("compression_format", "GZIP")
    parts = []

    # CloudWatch log group for delivery error logs
    parts.append(
        f'resource "aws_cloudwatch_log_group" "{bp.resource_label}_lg" {{\n'
        f'  name              = "/aws/kinesisfirehose/{bp.resource_name}"\n'
        f'  retention_in_days = 7\n\n'
        f"{_tags_block(bp)}\n}}"
    )
    parts.append(
        f'resource "aws_cloudwatch_log_stream" "{bp.resource_label}_ls" {{\n'
        f'  name           = "DestinationDelivery"\n'
        f'  log_group_name = aws_cloudwatch_log_group.{bp.resource_label}_lg.name\n}}'
    )

    parts.append(_iam_role(bp, "firehose.amazonaws.com"))
    parts.append(_iam_policy(bp))

    # Find S3 destination from outgoing integrations
    s3_dest = None
    for integ in bp.integrations_as_source:
        tgt = _find_svc(integ.target, req)
        if tgt and tgt.type == "s3":
            s3_dest = label_for(integ.target, "s3", req)
            break

    # Check if sourcing from Kinesis Streams
    kinesis_source_block = ""
    for integ in bp.integrations_as_target:
        src = _find_svc(integ.source, req)
        if src and src.type == "kinesis_streams":
            s_label = label_for(integ.source, "kinesis_streams", req)
            kinesis_source_block = (
                f"\n  kinesis_source_configuration {{\n"
                f"    kinesis_stream_arn = aws_kinesis_stream.{s_label}.arn\n"
                f"    role_arn           = aws_iam_role.{bp.resource_label}_role.arn\n"
                f"  }}\n"
            )
            break

    cw_log_opts = (
        f"\n    cloudwatch_logging_options {{\n"
        f"      enabled         = true\n"
        f"      log_group_name  = aws_cloudwatch_log_group.{bp.resource_label}_lg.name\n"
        f"      log_stream_name = aws_cloudwatch_log_stream.{bp.resource_label}_ls.name\n"
        f"    }}\n"
    )

    if s3_dest:
        dest_block = (
            f"\n  extended_s3_configuration {{\n"
            f"    role_arn           = aws_iam_role.{bp.resource_label}_role.arn\n"
            f"    bucket_arn         = aws_s3_bucket.{s3_dest}.arn\n"
            f"    buffering_size     = {buf_size}\n"
            f"    buffering_interval = {buf_interval}\n"
            f'    compression_format = "{compression}"\n'
            f"{cw_log_opts}"
            f"  }}\n"
        )
        destination = "extended_s3"
    else:
        dest_block = (
            f"\n  extended_s3_configuration {{\n"
            f"    role_arn           = aws_iam_role.{bp.resource_label}_role.arn\n"
            f'    bucket_arn         = "arn:aws:s3:::placeholder-bucket"\n'
            f"    buffering_size     = {buf_size}\n"
            f"    buffering_interval = {buf_interval}\n"
            f'    compression_format = "{compression}"\n'
            f"{cw_log_opts}"
            f"  }}\n"
        )
        destination = "extended_s3"

    parts.append(
        f'resource "aws_kinesis_firehose_delivery_stream" "{bp.resource_label}" {{\n'
        f'  name        = "{bp.resource_name}"\n'
        f'  destination = "{destination}"{kinesis_source_block}{dest_block}\n'
        f"{_tags_block(bp)}\n}}"
    )
    return warn + "\n\n".join(parts)


# ---------------------------------------------------------------------------
# Kinesis Analytics
# ---------------------------------------------------------------------------

def _render_kinesis_analytics(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    warn = _free_tier_warning(bp)
    cfg = bp.required_configuration
    runtime = cfg.get("runtime_environment", "SQL-1_0")
    parts = []

    # CloudWatch log group for application logs
    parts.append(
        f'resource "aws_cloudwatch_log_group" "{bp.resource_label}_lg" {{\n'
        f'  name              = "/aws/kinesis-analytics/{bp.resource_name}"\n'
        f'  retention_in_days = 7\n\n'
        f"{_tags_block(bp)}\n}}"
    )
    parts.append(
        f'resource "aws_cloudwatch_log_stream" "{bp.resource_label}_ls" {{\n'
        f'  name           = "application-logs"\n'
        f'  log_group_name = aws_cloudwatch_log_group.{bp.resource_label}_lg.name\n}}'
    )

    parts.append(_iam_role(bp, "kinesisanalytics.amazonaws.com"))
    parts.append(_iam_policy(bp))

    # Find input stream
    input_block = ""
    for integ in bp.integrations_as_target:
        src = _find_svc(integ.source, req)
        if src and src.type == "kinesis_streams":
            s_label = label_for(integ.source, "kinesis_streams", req)
            input_block = (
                f"\n  inputs {{\n"
                f'    name_prefix = "SOURCE_SQL_STREAM"\n'
                f"    kinesis_streams_input {{\n"
                f"      resource_arn = aws_kinesis_stream.{s_label}.arn\n"
                f"      role_arn     = aws_iam_role.{bp.resource_label}_role.arn\n"
                f"    }}\n"
                f"    parallelism {{ count = 1 }}\n"
                f"    schema {{\n"
                f'      record_format {{ mapping_parameters {{ json {{ record_row_path = "$" }} }} }}\n'
                f'      record_columns {{ name = "payload" sql_type = "VARCHAR(65536)" mapping = "$.payload" }}\n'
                f"    }}\n"
                f"  }}\n"
            )
            break

    parts.append(
        f'resource "aws_kinesisanalyticsv2_application" "{bp.resource_label}" {{\n'
        f'  name                   = "{bp.resource_name}"\n'
        f'  runtime_environment    = "{runtime}"\n'
        f'  service_execution_role = aws_iam_role.{bp.resource_label}_role.arn\n\n'
        f"  application_configuration {{\n"
        f"    sql_application_configuration {{{input_block}}}\n"
        f"  }}\n\n"
        f"  cloudwatch_logging_options {{\n"
        f"    log_stream_arn = aws_cloudwatch_log_stream.{bp.resource_label}_ls.arn\n"
        f"  }}\n\n"
        f"{_tags_block(bp)}\n}}"
    )
    return warn + "\n\n".join(parts)


# ---------------------------------------------------------------------------
# MSK
# ---------------------------------------------------------------------------

def _render_msk(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    warn = _free_tier_warning(bp)
    cfg = bp.required_configuration
    kafka_ver = cfg.get("kafka_version", "3.5.1")
    broker_count = cfg.get("number_of_broker_nodes", 3)
    instance_type = cfg.get("broker_instance_type", "kafka.m5.large")
    volume_size = cfg.get("volume_size", 100)
    parts = []

    # CloudWatch log group for broker logs
    parts.append(
        f'resource "aws_cloudwatch_log_group" "{bp.resource_label}_lg" {{\n'
        f'  name              = "/aws/msk/{bp.resource_name}"\n'
        f'  retention_in_days = 7\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    # Security group
    parts.append(
        f'resource "aws_security_group" "{bp.resource_label}_sg" {{\n'
        f'  name        = "{bp.resource_name}-sg"\n'
        f'  description = "MSK cluster security group"\n\n'
        f"  egress {{\n    from_port   = 0\n    to_port     = 0\n"
        f'    protocol    = "-1"\n    cidr_blocks = ["0.0.0.0/0"]\n  }}\n\n'
        f'  ingress {{\n    from_port   = 9092\n    to_port     = 9096\n'
        f'    protocol    = "tcp"\n    cidr_blocks = ["10.0.0.0/8"]\n  }}\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    parts.append(
        f'resource "aws_msk_cluster" "{bp.resource_label}" {{\n'
        f'  cluster_name           = "{bp.resource_name}"\n'
        f'  kafka_version          = "{kafka_ver}"\n'
        f"  number_of_broker_nodes = {broker_count}\n\n"
        f"  broker_node_group_info {{\n"
        f'    instance_type   = "{instance_type}"\n'
        f"    client_subnets  = data.aws_subnets.default.ids\n"
        f"    security_groups = [aws_security_group.{bp.resource_label}_sg.id]\n\n"
        f"    storage_info {{\n"
        f"      ebs_storage_info {{\n"
        f"        volume_size = {volume_size}\n"
        f"      }}\n"
        f"    }}\n"
        f"  }}\n\n"
        f"  encryption_info {{\n"
        f'    encryption_in_transit {{ client_broker = "TLS" }}\n'
        f"  }}\n\n"
        f"  logging_info {{\n"
        f"    broker_logs {{\n"
        f"      cloudwatch_logs {{\n"
        f"        enabled   = true\n"
        f"        log_group = aws_cloudwatch_log_group.{bp.resource_label}_lg.name\n"
        f"      }}\n"
        f"    }}\n"
        f"  }}\n\n"
        f"{_tags_block(bp)}\n}}"
    )
    return warn + "\n\n".join(parts)


# ---------------------------------------------------------------------------
# DMS
# ---------------------------------------------------------------------------

def _render_dms(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    warn = _free_tier_warning(bp)
    cfg = bp.required_configuration
    instance_class = cfg.get("replication_instance_class", "dms.t3.medium")
    storage = cfg.get("allocated_storage", 50)
    parts = []

    # CloudWatch log group for DMS replication task logs
    parts.append(
        f'resource "aws_cloudwatch_log_group" "{bp.resource_label}_lg" {{\n'
        f'  name              = "dms-tasks-{bp.resource_name}"\n'
        f'  retention_in_days = 7\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    parts.append(_iam_role(bp, "dms.amazonaws.com"))
    parts.append(_iam_policy(bp))

    parts.append(
        f'resource "aws_dms_replication_subnet_group" "{bp.resource_label}_subnet_grp" {{\n'
        f'  replication_subnet_group_description = "DMS subnet group for {bp.resource_name}"\n'
        f'  replication_subnet_group_id          = "{bp.resource_name}-subnet-grp"\n'
        f"  subnet_ids                            = data.aws_subnets.default.ids\n\n"
        f"{_tags_block(bp)}\n}}"
    )

    parts.append(
        f'resource "aws_dms_replication_instance" "{bp.resource_label}" {{\n'
        f'  replication_instance_id    = "{bp.resource_name}"\n'
        f'  replication_instance_class = "{instance_class}"\n'
        f"  allocated_storage          = {storage}\n"
        f"  publicly_accessible        = false\n"
        f"  replication_subnet_group_id = aws_dms_replication_subnet_group.{bp.resource_label}_subnet_grp.id\n\n"
        f"{_tags_block(bp)}\n}}"
    )
    return warn + "\n\n".join(parts)


# ---------------------------------------------------------------------------
# Redshift
# ---------------------------------------------------------------------------

def _render_redshift(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    warn = _free_tier_warning(bp)
    cfg = bp.required_configuration
    node_type = cfg.get("node_type", "dc2.large")
    num_nodes = cfg.get("number_of_nodes", 1)
    database = cfg.get("database_name", "dev")
    username = cfg.get("master_username", "admin")
    parts = []

    # CloudWatch log group for Redshift audit logs
    parts.append(
        f'resource "aws_cloudwatch_log_group" "{bp.resource_label}_lg" {{\n'
        f'  name              = "/aws/redshift/cluster/{bp.resource_name}"\n'
        f'  retention_in_days = 7\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    # IAM role for Spectrum / COPY / UNLOAD
    parts.append(_iam_role(bp, "redshift.amazonaws.com"))
    parts.append(_iam_policy(bp))

    cluster_type = "single-node" if num_nodes == 1 else "multi-node"
    node_line = "" if num_nodes == 1 else f"  number_of_nodes       = {num_nodes}\n"

    # Random password for master user
    parts.append(
        f'resource "random_password" "{bp.resource_label}_password" {{\n'
        f"  length  = 32\n"
        f"  special = false\n}}"
    )

    parts.append(
        f'resource "aws_redshift_cluster" "{bp.resource_label}" {{\n'
        f'  cluster_identifier    = "{bp.resource_name}"\n'
        f'  node_type             = "{node_type}"\n'
        f'  cluster_type          = "{cluster_type}"\n'
        f'{node_line}'
        f'  database_name         = "{database}"\n'
        f'  master_username       = "{username}"\n'
        f'  master_password       = random_password.{bp.resource_label}_password.result\n'
        f"  publicly_accessible   = false\n"
        f"  skip_final_snapshot   = true\n"
        f"  iam_roles             = [aws_iam_role.{bp.resource_label}_role.arn]\n\n"
        f"  logging {{\n"
        f'    log_destination_type = "cloudwatch"\n'
        f"    log_exports         = [\"connectionlog\", \"useractivitylog\", \"userlog\"]\n"
        f"  }}\n\n"
        f"{_tags_block(bp)}\n}}"
    )
    return warn + "\n\n".join(parts)


# ---------------------------------------------------------------------------
# Lake Formation
# ---------------------------------------------------------------------------

def _render_lake_formation(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    parts = []

    # Register S3 locations as data lake locations
    for integ in bp.integrations_as_target:
        src = _find_svc(integ.source, req)
        if src and src.type == "s3":
            s_label = label_for(integ.source, "s3", req)
            parts.append(
                f'resource "aws_lakeformation_resource" "{bp.resource_label}_{s_label}" {{\n'
                f'  arn = aws_s3_bucket.{s_label}.arn\n}}'
            )

    if not parts:
        parts.append(
            f'resource "aws_lakeformation_resource" "{bp.resource_label}_placeholder" {{\n'
            f'  arn = "arn:aws:s3:::placeholder-data-lake-bucket"\n}}'
        )

    # Data lake settings
    parts.append(
        f'resource "aws_lakeformation_data_lake_settings" "{bp.resource_label}_settings" {{\n'
        f"  create_database_default_permissions {{\n"
        f'    principal   = "IAM_ALLOWED_PRINCIPALS"\n'
        f'    permissions = ["ALL"]\n'
        f"  }}\n\n"
        f"  create_table_default_permissions {{\n"
        f'    principal   = "IAM_ALLOWED_PRINCIPALS"\n'
        f'    permissions = ["ALL"]\n'
        f"  }}\n}}"
    )
    return "\n\n".join(parts)


# ---------------------------------------------------------------------------
# Aurora
# ---------------------------------------------------------------------------

def _render_aurora(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    warn = _free_tier_warning(bp)
    cfg = bp.required_configuration
    engine = cfg.get("engine", "aurora-postgresql")
    engine_ver = cfg.get("engine_version", "15.4")
    database = cfg.get("database_name", "appdb")
    username = cfg.get("master_username", "admin")
    min_cap = cfg.get("min_capacity", 0.5)
    max_cap = cfg.get("max_capacity", 8)
    parts = []

    # CloudWatch log group for Aurora error/slow query logs
    log_type = "postgresql" if "postgresql" in engine else "error"
    parts.append(
        f'resource "aws_cloudwatch_log_group" "{bp.resource_label}_lg" {{\n'
        f'  name              = "/aws/rds/cluster/{bp.resource_name}/{log_type}"\n'
        f'  retention_in_days = 7\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    # Security group
    parts.append(
        f'resource "aws_security_group" "{bp.resource_label}_sg" {{\n'
        f'  name        = "{bp.resource_name}-sg"\n'
        f'  description = "Aurora cluster security group"\n\n'
        f"  egress {{\n    from_port   = 0\n    to_port     = 0\n"
        f'    protocol    = "-1"\n    cidr_blocks = ["0.0.0.0/0"]\n  }}\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    # Subnet group
    parts.append(
        f'resource "aws_db_subnet_group" "{bp.resource_label}_subnet_grp" {{\n'
        f'  name       = "{bp.resource_name}-subnet-grp"\n'
        f"  subnet_ids = data.aws_subnets.default.ids\n\n"
        f"{_tags_block(bp)}\n}}"
    )

    # Random password for master user
    parts.append(
        f'resource "random_password" "{bp.resource_label}_password" {{\n'
        f"  length  = 32\n"
        f"  special = false\n}}"
    )

    # Aurora cluster (serverless v2)
    parts.append(
        f'resource "aws_rds_cluster" "{bp.resource_label}" {{\n'
        f'  cluster_identifier     = "{bp.resource_name}"\n'
        f'  engine                 = "{engine}"\n'
        f'  engine_mode            = "provisioned"\n'
        f'  engine_version         = "{engine_ver}"\n'
        f'  database_name          = "{database}"\n'
        f'  master_username        = "{username}"\n'
        f'  master_password        = random_password.{bp.resource_label}_password.result\n'
        f"  skip_final_snapshot    = true\n"
        f"  deletion_protection    = false\n"
        f"  db_subnet_group_name   = aws_db_subnet_group.{bp.resource_label}_subnet_grp.name\n"
        f"  vpc_security_group_ids = [aws_security_group.{bp.resource_label}_sg.id]\n\n"
        f'  enabled_cloudwatch_logs_exports = ["{log_type}"]\n\n'
        f"  serverlessv2_scaling_configuration {{\n"
        f"    min_capacity = {min_cap}\n"
        f"    max_capacity = {max_cap}\n"
        f"  }}\n\n"
        f"{_tags_block(bp)}\n}}"
    )

    # Serverless v2 instance
    parts.append(
        f'resource "aws_rds_cluster_instance" "{bp.resource_label}_instance" {{\n'
        f'  identifier         = "{bp.resource_name}-instance"\n'
        f"  cluster_identifier = aws_rds_cluster.{bp.resource_label}.id\n"
        f'  instance_class     = "db.serverless"\n'
        f'  engine             = aws_rds_cluster.{bp.resource_label}.engine\n'
        f'  engine_version     = aws_rds_cluster.{bp.resource_label}.engine_version\n\n'
        f"{_tags_block(bp)}\n}}"
    )
    return warn + "\n\n".join(parts)


# ---------------------------------------------------------------------------
# Glue DataBrew
# ---------------------------------------------------------------------------

def _render_glue_databrew(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    warn = _free_tier_warning(bp)
    cfg = bp.required_configuration
    parts = []

    # CloudWatch log group for DataBrew job logs
    parts.append(
        f'resource "aws_cloudwatch_log_group" "{bp.resource_label}_lg" {{\n'
        f'  name              = "/aws-glue-databrew/jobs/{bp.resource_name}"\n'
        f'  retention_in_days = 7\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    parts.append(_iam_role(bp, "databrew.amazonaws.com"))
    parts.append(_iam_policy(bp))

    # Find source S3 dataset
    dataset_name = f"{bp.resource_name}-dataset"
    s3_input = None
    for integ in bp.integrations_as_target:
        src = _find_svc(integ.source, req)
        if src and src.type == "s3":
            s3_input = label_for(integ.source, "s3", req)
            break

    input_block = (
        f'    s3_input_definition {{\n'
        f'      bucket = aws_s3_bucket.{s3_input}.id\n'
        f'      key    = "input/"\n'
        f'    }}\n'
    ) if s3_input else (
        f'    s3_input_definition {{\n'
        f'      bucket = "placeholder-input-bucket"\n'
        f'      key    = "input/"\n'
        f'    }}\n'
    )

    parts.append(
        f'resource "aws_databrew_dataset" "{bp.resource_label}_dataset" {{\n'
        f'  name = "{dataset_name}"\n\n'
        f"  input {{\n{input_block}  }}\n}}"
    )

    # Find output S3 bucket
    output_bucket = None
    for integ in bp.integrations_as_source:
        tgt = _find_svc(integ.target, req)
        if tgt and tgt.type == "s3":
            output_bucket = name_for(integ.target, "s3", req)
            break

    output_location = f"s3://{output_bucket}/databrew-output/" if output_bucket else "s3://placeholder-output-bucket/output/"

    parts.append(
        f'resource "aws_databrew_project" "{bp.resource_label}" {{\n'
        f'  name         = "{bp.resource_name}"\n'
        f'  dataset_name = aws_databrew_dataset.{bp.resource_label}_dataset.name\n'
        f'  recipe_name  = "{bp.resource_name}-recipe"\n'
        f"  role_arn     = aws_iam_role.{bp.resource_label}_role.arn\n\n"
        f"{_tags_block(bp)}\n}}"
    )

    parts.append(
        f'resource "aws_databrew_job" "{bp.resource_label}_job" {{\n'
        f'  name      = "{bp.resource_name}-job"\n'
        f'  type      = "PROFILE"\n'
        f"  role_arn  = aws_iam_role.{bp.resource_label}_role.arn\n"
        f'  dataset_name = aws_databrew_dataset.{bp.resource_label}_dataset.name\n\n'
        f"  s3_location {{\n"
        f'    bucket = split("/", "{output_location}")[2]\n'
        f"  }}\n\n"
        f"{_tags_block(bp)}\n}}"
    )
    return warn + "\n\n".join(parts)


# ---------------------------------------------------------------------------
# EMR
# ---------------------------------------------------------------------------

def _render_emr(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    warn = _free_tier_warning(bp)
    cfg = bp.required_configuration
    release = cfg.get("release_label", "emr-6.15.0")
    master_type = cfg.get("master_instance_type", "m5.xlarge")
    core_type = cfg.get("core_instance_type", "m5.xlarge")
    core_count = cfg.get("core_instance_count", 2)
    apps = cfg.get("applications", ["Spark", "Hive"])
    parts = []

    # CloudWatch log group for EMR Spark/YARN logs
    parts.append(
        f'resource "aws_cloudwatch_log_group" "{bp.resource_label}_lg" {{\n'
        f'  name              = "/aws/emr/{bp.resource_name}"\n'
        f'  retention_in_days = 7\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    # EMR service role
    parts.append(_iam_role(bp, "elasticmapreduce.amazonaws.com"))
    parts.append(_iam_policy(bp))

    # EC2 instance profile role for EMR nodes
    ec2_role_name    = suffixed_name(bp.resource_name, "-ec2-role",    limit=64)
    ec2_profile_name = suffixed_name(bp.resource_name, "-ec2-profile", limit=64)
    parts.append(
        f'resource "aws_iam_role" "{bp.resource_label}_ec2_role" {{\n'
        f'  name = "{ec2_role_name}"\n\n'
        f"  assume_role_policy = jsonencode({{\n"
        f'    Version = "2012-10-17"\n'
        f"    Statement = [{{\n"
        f'      Effect    = "Allow"\n'
        f'      Principal = {{ Service = "ec2.amazonaws.com" }}\n'
        f'      Action    = "sts:AssumeRole"\n'
        f"    }}]\n"
        f"  }})\n\n"
        f"{_tags_block(bp)}\n}}"
    )
    parts.append(
        f'resource "aws_iam_instance_profile" "{bp.resource_label}_ec2_profile" {{\n'
        f'  name = "{ec2_profile_name}"\n'
        f'  role = aws_iam_role.{bp.resource_label}_ec2_role.name\n}}'
    )

    # S3 log bucket reference
    log_uri = "s3://placeholder-emr-logs/"
    for integ in bp.integrations_as_source:
        tgt = _find_svc(integ.target, req)
        if tgt and tgt.type == "s3":
            t_label = label_for(integ.target, "s3", req)
            log_uri = f"s3://${{aws_s3_bucket.{t_label}.id}}/emr-logs/"
            break

    apps_str = ", ".join(f'"{a}"' for a in apps)

    parts.append(
        f'resource "aws_emr_cluster" "{bp.resource_label}" {{\n'
        f'  name          = "{bp.resource_name}"\n'
        f'  release_label = "{release}"\n'
        f'  applications  = [{apps_str}]\n\n'
        f"  master_instance_group {{\n"
        f'    instance_type = "{master_type}"\n'
        f"  }}\n\n"
        f"  core_instance_group {{\n"
        f'    instance_type  = "{core_type}"\n'
        f"    instance_count = {core_count}\n"
        f"  }}\n\n"
        f'  service_role     = aws_iam_role.{bp.resource_label}_role.arn\n'
        f'  ec2_attributes {{\n'
        f'    instance_profile = aws_iam_instance_profile.{bp.resource_label}_ec2_profile.arn\n'
        f'  }}\n\n'
        f'  log_uri                          = "{log_uri}"\n'
        f"  keep_job_flow_alive_when_no_steps = false\n"
        f"  termination_protection            = false\n\n"
        f"  configurations_json = jsonencode([\n"
        f"    {{\n"
        f'      Classification = "spark-log4j"\n'
        f'      Properties = {{ "log4j.rootCategory" = "INFO,console,CloudWatch" }}\n'
        f"    }},\n"
        f"    {{\n"
        f'      Classification = "yarn-site"\n'
        f'      Properties = {{ "yarn.log-aggregation-enable" = "true" }}\n'
        f"    }}\n"
        f"  ])\n\n"
        f"{_tags_block(bp)}\n}}"
    )
    return warn + "\n\n".join(parts)


# ---------------------------------------------------------------------------
# Glue Data Catalog
# ---------------------------------------------------------------------------

def _render_glue_data_catalog(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    cfg = bp.required_configuration
    description = cfg.get("description", "Glue Data Catalog database")

    return (
        f'resource "aws_glue_catalog_database" "{bp.resource_label}" {{\n'
        f'  name        = "{bp.resource_name.replace("-", "_")}"\n'
        f'  description = "{description}"\n}}'
    )


# ---------------------------------------------------------------------------
# IAM (standalone role)
# ---------------------------------------------------------------------------

def _render_iam(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    cfg = bp.required_configuration
    path = cfg.get("path", "/")
    session_duration = cfg.get("max_session_duration", 3600)

    return (
        f'resource "aws_iam_role" "{bp.resource_label}" {{\n'
        f'  name                 = "{bp.resource_name}"\n'
        f'  path                 = "{path}"\n'
        f"  max_session_duration = {session_duration}\n\n"
        f"  assume_role_policy = jsonencode({{\n"
        f'    Version = "2012-10-17"\n'
        f"    Statement = [{{\n"
        f'      Effect    = "Allow"\n'
        f'      Principal = {{ Service = "lambda.amazonaws.com" }}\n'
        f'      Action    = "sts:AssumeRole"\n'
        f"    }}]\n"
        f"  }})\n\n"
        f"{_tags_block(bp)}\n}}"
    )


# ---------------------------------------------------------------------------
# SageMaker
# ---------------------------------------------------------------------------

def _render_sagemaker(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    warn = _free_tier_warning(bp)
    cfg = bp.required_configuration
    instance_type  = cfg.get("instance_type", "ml.t2.medium")
    instance_count = cfg.get("initial_instance_count", 1)

    # --- Container image resolution -------------------------------------------
    # Two modes:
    #   1. Default (recommended): use the `aws_sagemaker_prebuilt_ecr_image`
    #      Terraform data source.  This resolves the correct DLC registry URI
    #      for the current account/region AND avoids the
    #      "does not grant permission to sagemaker.amazonaws.com" error that
    #      occurs when hardcoding the 763104351884.dkr.ecr.* DLC registry URI
    #      directly.  SageMaker's service principal automatically has access to
    #      images retrieved through this data source.
    #   2. Override: set `container_image` in the service config to a fully-
    #      qualified custom ECR URI (e.g. your own account's repository).
    #      You are responsible for granting sagemaker.amazonaws.com access to
    #      that repository via an aws_ecr_repository_policy resource.
    custom_image = cfg.get("container_image", "")
    framework    = cfg.get("framework",   "sagemaker-scikit-learn")
    image_tag    = cfg.get("image_tag",   "1.2-1-cpu-py3")
    img_label    = f"{bp.resource_label}_img"

    # --- Model data URL -------------------------------------------------------
    # When an S3 integration exists, auto-upload a placeholder model artifact
    # so that terraform apply succeeds without manual pre-upload.  The user
    # should replace the placeholder with a real trained model afterwards.
    model_data_url = cfg.get("model_data_url", "s3://placeholder-model-bucket/model.tar.gz")
    s3_artifact_label = ""          # set when we auto-upload
    for integ in bp.integrations_as_target:
        src = _find_svc(integ.source, req)
        if src and src.type == "s3":
            s3_label = label_for(integ.source, "s3", req)
            s3_artifact_label = f"{bp.resource_label}_model_artifact"
            model_data_url = f"s3://${{aws_s3_bucket.{s3_label}.id}}/model.tar.gz"
            break

    parts = []

    # --- IAM execution role ---------------------------------------------------
    # AmazonSageMakerFullAccess is attached in addition to the inline policy so
    # that the execution role can read ECR, write CloudWatch metrics, and invoke
    # other SageMaker APIs (e.g. DescribeModel, CreateTrainingJob) without
    # enumerating every action individually.
    parts.append(_iam_role(bp, "sagemaker.amazonaws.com"))
    parts.append(_iam_policy(bp))
    parts.append(
        f'resource "aws_iam_role_policy_attachment" "{bp.resource_label}_sagemaker_full" {{\n'
        f'  role       = aws_iam_role.{bp.resource_label}_role.name\n'
        f'  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"\n'
        f"}}"
    )

    # --- Pre-built image data source (default path) ---------------------------
    # Only emitted when the user has NOT overridden container_image.
    # The data source contacts the SageMaker image registry on your behalf;
    # no ECR authentication or resource-policy setup is required.
    if not custom_image:
        parts.append(
            f'# Resolves the correct DLC image URI for this account + region.\n'
            f'# Supported repository_name values: sklearn, pytorch-inference,\n'
            f'# tensorflow-inference, xgboost, huggingface-pytorch-inference,\n'
            f'# mxnet-inference, pytorch-training, tensorflow-training, etc.\n'
            f'data "aws_sagemaker_prebuilt_ecr_image" "{img_label}" {{\n'
            f'  repository_name = "{framework}"\n'
            f'  image_tag       = "{image_tag}"\n'
            f"}}"
        )
        image_ref = f"data.aws_sagemaker_prebuilt_ecr_image.{img_label}.registry_path"
    else:
        # Custom image: user owns the ECR repo; they must add an ECR resource
        # policy granting sagemaker.amazonaws.com access themselves.
        image_ref = f'"{custom_image}"'

    # --- Placeholder model artifact upload ------------------------------------
    # When auto-resolving model_data_url from an S3 integration, upload a
    # minimal placeholder model.tar.gz so CreateModel succeeds on first apply.
    # The file is copied to the output dir by pipeline_builder; here we just
    # reference it.  Replace with a real trained model after deployment.
    if s3_artifact_label:
        parts.append(
            f'# Placeholder model artifact — replace with your trained model.\n'
            f'# File: sagemaker_placeholder_model.tar.gz (in this directory)\n'
            f'resource "aws_s3_object" "{s3_artifact_label}" {{\n'
            f'  bucket = aws_s3_bucket.{s3_label}.id\n'
            f'  key    = "model.tar.gz"\n'
            f'  source = "${{path.module}}/sagemaker_placeholder_model.tar.gz"\n'
            f"}}"
        )

    # --- Length-safe names (SageMaker limit: 63 chars) ------------------------
    model_name = suffixed_name(bp.resource_name, "-model", limit=63)
    cfg_name   = suffixed_name(bp.resource_name, "-cfg",   limit=63)
    ep_name    = suffixed_name(bp.resource_name, "",        limit=63)

    # --- CloudWatch log group -------------------------------------------------
    parts.append(
        f'resource "aws_cloudwatch_log_group" "{bp.resource_label}_lg" {{\n'
        f'  name              = "/aws/sagemaker/Endpoints/{ep_name}"\n'
        f"  retention_in_days = 7\n\n"
        f"{_tags_block(bp)}\n}}"
    )

    # --- Model ----------------------------------------------------------------
    depends_line = ""
    if s3_artifact_label:
        depends_line = f"\n  depends_on = [aws_s3_object.{s3_artifact_label}]\n"
    parts.append(
        f'resource "aws_sagemaker_model" "{bp.resource_label}_model" {{\n'
        f'  name               = "{model_name}"\n'
        f'  execution_role_arn = aws_iam_role.{bp.resource_label}_role.arn\n\n'
        f"  primary_container {{\n"
        f'    image          = {image_ref}\n'
        f'    model_data_url = "{model_data_url}"\n'
        f"  }}\n"
        f"{depends_line}\n"
        f"{_tags_block(bp)}\n}}"
    )

    # --- Endpoint configuration -----------------------------------------------
    parts.append(
        f'resource "aws_sagemaker_endpoint_configuration" "{bp.resource_label}_cfg" {{\n'
        f'  name = "{cfg_name}"\n\n'
        f"  production_variants {{\n"
        f'    variant_name           = "primary"\n'
        f'    model_name             = aws_sagemaker_model.{bp.resource_label}_model.name\n'
        f'    initial_instance_count = {instance_count}\n'
        f'    instance_type          = "{instance_type}"\n'
        f"    initial_variant_weight = 1\n"
        f"  }}\n\n"
        f"{_tags_block(bp)}\n}}"
    )

    # --- Endpoint -------------------------------------------------------------
    parts.append(
        f'resource "aws_sagemaker_endpoint" "{bp.resource_label}" {{\n'
        f'  name                 = "{ep_name}"\n'
        f'  endpoint_config_name = aws_sagemaker_endpoint_configuration.{bp.resource_label}_cfg.name\n\n'
        f"{_tags_block(bp)}\n}}"
    )

    return warn + "\n\n".join(parts)


# ---------------------------------------------------------------------------
# QuickSight
# ---------------------------------------------------------------------------

# Maps pipeline peer types to QuickSight data source types + parameter blocks
_QS_SOURCE_TYPE: dict[str, str] = {
    "athena":           "ATHENA",
    "glue_data_catalog":"ATHENA",   # query via Athena over Glue catalog
    "s3":               "S3",
    "redshift":         "REDSHIFT",
    "aurora":           "AURORA_POSTGRESQL",
}


def _render_quicksight(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    warn = _free_tier_warning(bp)
    cfg = bp.required_configuration
    parts = []

    # IAM role for QuickSight service to access data sources
    parts.append(_iam_role(bp, "quicksight.amazonaws.com"))
    parts.append(_iam_policy(bp))

    # Determine data source type from integrations (first recognised peer wins)
    ds_type = cfg.get("type", "ATHENA")
    peer_label: str | None = None
    peer_type: str | None = None

    for integ in bp.integrations_as_target:
        src = _find_svc(integ.source, req)
        if src and src.type in _QS_SOURCE_TYPE:
            ds_type = _QS_SOURCE_TYPE[src.type]
            peer_label = label_for(integ.source, src.type, req)
            peer_type = src.type
            break

    # Build the parameters block based on data source type
    if ds_type == "ATHENA":
        work_group = cfg.get("work_group", "primary")
        if peer_type in ("athena",) and peer_label:
            # Reference the workgroup from the connected Athena resource
            params_block = (
                f"  parameters {{\n"
                f"    athena {{\n"
                f'      work_group = aws_athena_workgroup.{peer_label}.name\n'
                f"    }}\n"
                f"  }}\n"
            )
        else:
            params_block = (
                f"  parameters {{\n"
                f"    athena {{\n"
                f'      work_group = "{work_group}"\n'
                f"    }}\n"
                f"  }}\n"
            )
    elif ds_type == "S3":
        if peer_label:
            bucket_ref = f"aws_s3_bucket.{peer_label}.id"
        else:
            bucket_ref = f'"{cfg.get("manifest_bucket", "placeholder-bucket")}"'
        manifest_key = cfg.get("manifest_key", "manifest.json")
        params_block = (
            f"  parameters {{\n"
            f"    s3 {{\n"
            f"      manifest_file_location {{\n"
            f"        bucket = {bucket_ref}\n"
            f'        key    = "{manifest_key}"\n'
            f"      }}\n"
            f"    }}\n"
            f"  }}\n"
        )
    elif ds_type == "REDSHIFT":
        db = cfg.get("redshift_database", "dev")
        if peer_label:
            cluster_ref = f"aws_redshift_cluster.{peer_label}.id"
        else:
            cluster_ref = '"placeholder-cluster"'
        params_block = (
            f"  parameters {{\n"
            f"    redshift {{\n"
            f"      cluster_id = {cluster_ref}\n"
            f'      database   = "{db}"\n'
            f"    }}\n"
            f"  }}\n"
        )
    elif ds_type in ("AURORA_POSTGRESQL", "AURORA"):
        db = cfg.get("aurora_database", "mydb")
        if peer_label:
            host_ref = f"aws_rds_cluster.{peer_label}.endpoint"
        else:
            host_ref = '"placeholder-aurora-endpoint"'
        params_block = (
            f"  parameters {{\n"
            f"    rds_parameters {{\n"
            f"      instance_id = {host_ref}\n"
            f'      database    = "{db}"\n'
            f"    }}\n"
            f"  }}\n"
        )
    else:
        # Fallback: Athena with primary workgroup
        params_block = (
            f"  parameters {{\n"
            f"    athena {{\n"
            f'      work_group = "primary"\n'
            f"    }}\n"
            f"  }}\n"
        )

    parts.append(
        f'resource "aws_quicksight_data_source" "{bp.resource_label}" {{\n'
        f'  data_source_id = "{bp.resource_name}"\n'
        f'  name           = "{bp.resource_name}"\n'
        f'  type           = "{ds_type}"\n\n'
        f"{params_block}\n"
        f"  ssl_properties {{\n"
        f"    disable_ssl = false\n"
        f"  }}\n\n"
        f"{_tags_block(bp)}\n}}"
    )

    return warn + "\n\n".join(parts)


# ---------------------------------------------------------------------------
# EMR Serverless
# ---------------------------------------------------------------------------

def _render_emr_serverless(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    warn = _free_tier_warning(bp)
    cfg = bp.required_configuration
    release = cfg.get("release_label", "emr-6.15.0")
    app_type = cfg.get("type", "SPARK")
    arch = cfg.get("architecture", "X86_64")
    idle_timeout = int(cfg.get("idle_timeout_minutes", 15)) * 60  # convert to seconds

    # Capacity config
    drv_cpu = cfg.get("initial_capacity_driver_cpu", "1vCPU")
    drv_mem = cfg.get("initial_capacity_driver_memory", "2gb")
    exc_cpu = cfg.get("initial_capacity_executor_cpu", "1vCPU")
    exc_mem = cfg.get("initial_capacity_executor_memory", "2gb")
    exc_count = cfg.get("initial_capacity_executor_count", 1)
    max_cpu = cfg.get("max_cpu", "4vCPU")
    max_mem = cfg.get("max_memory", "8gb")
    max_disk = cfg.get("max_disk", "20gb")

    parts = []

    # Job execution role (used by job runs to access S3, Glue, etc.)
    parts.append(_iam_role(bp, "emr-serverless.amazonaws.com"))
    parts.append(_iam_policy(bp))

    # CloudWatch log group
    parts.append(
        f'resource "aws_cloudwatch_log_group" "{bp.resource_label}_lg" {{\n'
        f'  name              = "/aws/emr-serverless/{bp.resource_name}"\n'
        f"  retention_in_days = 7\n\n"
        f"{_tags_block(bp)}\n}}"
    )

    # EMR Serverless application
    # ⚠️ PREREQUISITE: EMR Serverless must be enabled in your AWS account before
    # terraform apply, otherwise CreateApplication returns SubscriptionRequiredException.
    # Enable it at: AWS Console → EMR → EMR Serverless → Get started (one-time per account).
    parts.append(
        f'# ⚠️ PREREQUISITE: Enable EMR Serverless in your AWS account first.\n'
        f'# Go to: AWS Console → EMR → EMR Serverless → Get started (one-time per account/region).\n'
        f'# Without this step, terraform apply will fail with SubscriptionRequiredException.\n'
        f'resource "aws_emrserverless_application" "{bp.resource_label}" {{\n'
        f'  name          = "{bp.resource_name}"\n'
        f'  release_label = "{release}"\n'
        f'  type          = "{app_type}"\n\n'
        f"  initial_capacity {{\n"
        f'    initial_capacity_type = "Driver"\n\n'
        f"    initial_capacity_config {{\n"
        f"      worker_count = 1\n"
        f"      worker_configuration {{\n"
        f'        cpu    = "{drv_cpu}"\n'
        f'        memory = "{drv_mem}"\n'
        f"      }}\n"
        f"    }}\n"
        f"  }}\n\n"
        f"  initial_capacity {{\n"
        f'    initial_capacity_type = "Executor"\n\n'
        f"    initial_capacity_config {{\n"
        f"      worker_count = {exc_count}\n"
        f"      worker_configuration {{\n"
        f'        cpu    = "{exc_cpu}"\n'
        f'        memory = "{exc_mem}"\n'
        f"      }}\n"
        f"    }}\n"
        f"  }}\n\n"
        f"  maximum_capacity {{\n"
        f'    cpu    = "{max_cpu}"\n'
        f'    memory = "{max_mem}"\n'
        f'    disk   = "{max_disk}"\n'
        f"  }}\n\n"
        f"  auto_start_configuration {{\n"
        f"    enabled = true\n"
        f"  }}\n\n"
        f"  auto_stop_configuration {{\n"
        f"    enabled              = true\n"
        f"    idle_timeout_minutes = {int(cfg.get('idle_timeout_minutes', 15))}\n"
        f"  }}\n\n"
        f"  architecture = \"{arch}\"\n\n"
        f"{_tags_block(bp)}\n}}"
    )

    return warn + "\n\n".join(parts)


# ---------------------------------------------------------------------------
# Renderer dispatch
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# SageMaker Notebook Instance
# ---------------------------------------------------------------------------

def _render_sagemaker_notebook(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    cfg = bp.required_configuration
    instance_type = cfg.get("instance_type", "ml.t2.medium")
    volume_size = cfg.get("volume_size", 5)
    direct_internet = cfg.get("direct_internet_access", "Enabled")

    parts = []

    # IAM role — assumed by sagemaker.amazonaws.com
    parts.append(_iam_role(bp, "sagemaker.amazonaws.com"))
    parts.append(_iam_policy(bp))

    nb_name = suffixed_name(bp.resource_name, "", limit=63)

    # VPC config (only when vpc_required)
    vpc_block = ""
    if bp.vpc_required:
        parts.append(
            f'resource "aws_security_group" "{bp.resource_label}_sg" {{\n'
            f'  name        = "{bp.resource_name}-sg"\n'
            f'  description = "SG for SageMaker notebook {bp.resource_name}"\n'
            f'  vpc_id      = data.aws_vpc.default.id\n\n'
            f"  egress {{\n    from_port   = 0\n    to_port     = 0\n"
            f'    protocol    = "-1"\n    cidr_blocks = ["0.0.0.0/0"]\n  }}\n\n'
            f"{_tags_block(bp)}\n}}"
        )
        vpc_block = (
            f'\n  subnet_id              = tolist(data.aws_subnets.default.ids)[0]\n'
            f'  security_groups        = [aws_security_group.{bp.resource_label}_sg.id]\n'
            f'  direct_internet_access = "Disabled"\n'
        )
    else:
        vpc_block = f'\n  direct_internet_access = "{direct_internet}"\n'

    # Notebook instance — no platform_identifier (not supported in all regions;
    # AWS defaults to the latest available platform automatically)
    parts.append(
        f'resource "aws_sagemaker_notebook_instance" "{bp.resource_label}" {{\n'
        f'  name          = "{nb_name}"\n'
        f'  role_arn      = aws_iam_role.{bp.resource_label}_role.arn\n'
        f'  instance_type = "{instance_type}"\n'
        f"  volume_size   = {volume_size}"
        f'{vpc_block}\n'
        f"{_tags_block(bp)}\n}}"
    )

    return "\n\n".join(parts)


_RENDERERS: dict[str, Renderer] = {
    "s3": _render_s3,
    "lambda": _render_lambda,
    "sqs": _render_sqs,
    "dynamodb": _render_dynamodb,
    "stepfunctions": _render_stepfunctions,
    "glue": _render_glue,
    "cloudwatch": _render_cloudwatch,
    "sns": _render_sns,
    "kinesis_streams": _render_kinesis_streams,
    "athena": _render_athena,
    "eventbridge": _render_eventbridge,
    "ec2": _render_ec2,
    "kinesis_firehose": _render_kinesis_firehose,
    "kinesis_analytics": _render_kinesis_analytics,
    "msk": _render_msk,
    "dms": _render_dms,
    "redshift": _render_redshift,
    "lake_formation": _render_lake_formation,
    "aurora": _render_aurora,
    "glue_databrew": _render_glue_databrew,
    "emr": _render_emr,
    "emr_serverless": _render_emr_serverless,
    "sagemaker": _render_sagemaker,
    "sagemaker_notebook": _render_sagemaker_notebook,
    "quicksight": _render_quicksight,
    "glue_data_catalog": _render_glue_data_catalog,
    "iam": _render_iam,
}


def render(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    """Render a complete HCL fragment for one service.

    Raises ValueError if no renderer exists for the service type.
    """
    renderer = _RENDERERS.get(bp.service_type)
    if renderer is None:
        raise ValueError(
            f"No HCL renderer for service type '{bp.service_type}'. "
            f"Add a _render_{bp.service_type}() function to hcl_renderer.py."
        )
    hcl = renderer(bp, req)

    # Append spec-driven sub-component resources (tables, prefixes, etc.)
    from engine.sub_component_renderer import render_sub_components
    sub_hcl = render_sub_components(bp, req)
    if sub_hcl:
        hcl = hcl + "\n\n" + sub_hcl

    return hcl


def supported_types() -> list[str]:
    return sorted(_RENDERERS.keys())
