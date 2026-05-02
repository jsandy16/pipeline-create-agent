# Architecture Reference

Detailed reference for the pipeline engine. For quick-start, see `CLAUDE.md`.

## Architecture diagram

```
Input (YAML, Diagram Image, Architect Canvas, or Natural Language)
     │
     ├─ YAML ──────────────────────────────────────────────┐
     │                                                      │
     ├─ Image ──→ agents/diagram_reader.py (1 LLM call) ──┤
     │                                                      │
     ├─ Canvas ──→ /run-from-diagram (0 LLM calls) ───────┤
     │                                                      │
     └─ Text ───→ agents/pipeline_builder_agent.py ────────┘
                  (1 LLM call)                              │
                                                            ▼
                                                   PipelineRequest
                                                   (Pydantic model)
                                                            │
               ┌────────────────────────────────────────────┘
               │ FOR EACH SERVICE (deterministic, <1ms each):
               │  1. engine/spec_loader.py → loads specs/<type>.yaml
               │  2. engine/spec_builder.py → ServiceBlueprint (IAM, env, VPC, tags)
               │  3. engine/hcl_renderer.py → HCL fragment
               └────────────────────────────────────────────┐
                                                            ▼
                                              engine/pipeline_builder.py
                                              → consolidate → lint → write → validate
                                                            ▼
                                                        main.tf
```

## Web application routes (app.py)

- `POST /run` — diagram upload → `job_id`
- `POST /run-from-diagram` — `PipelineRequest` JSON (Architect canvas) → `job_id`
- `GET /ws/{job_id}` — WebSocket: streams log, progress, service_update, done events
- `GET /details/{job_id}` — pipeline details after completion
- `DELETE /cancel/{job_id}` — cancel in-progress job
- `POST /deploy/plan/{job_id}` — terraform init + plan
- `POST /deploy/apply/{job_id}` — terraform apply (background)
- `GET /ws/deploy/{deploy_id}` — deploy log WebSocket
- `POST /developer-agent/chat` — boto3 code generation
- `POST /developer-agent/execute` — execute generated code
- `POST /pipeline/run-preview/{job_id}/start` — start log monitoring → `preview_id`
- `POST /pipeline/run-preview/by-name/{pipeline_name}/start` — historical pipeline monitoring
- `DELETE /pipeline/run-preview/{preview_id}/stop` — stop monitoring
- `GET /ws/pipeline-run/{preview_id}` — runtime log WebSocket
- `POST /pipeline-builder/chat` — natural language → YAML (multi-turn)
- `POST /pipeline-builder/build` — build from agent YAML
- `POST /config/chat` — config customization (tiered resolution)
- `POST /config/apply` — apply config patch, re-render
- `GET /config/templates/{service_type}` — preset templates
- `POST /config/template/apply` — apply preset
- `GET /config/supported-keys/{service_type}` — renderer-supported keys

## AWS Free Tier enforcement

| Status | Services |
|--------|---------|
| Always free | Lambda, S3, SQS, SNS, DynamoDB (PROVISIONED <=25 RCU/WCU), EventBridge, Step Functions, IAM, CloudWatch, Glue Data Catalog, Lake Formation |
| Free 12 months | EC2 (t2.micro/t3.micro 750hrs), DMS (t2.micro 6-month trial) |
| Never free (warned) | Redshift, Aurora, EMR, EMR Serverless, MSK, Kinesis Streams, Kinesis Firehose, Kinesis Analytics, Athena, Glue DataBrew, SageMaker, SageMaker Notebook, QuickSight |

## Pipeline Run Preview (log aggregator)

`tools/log_aggregator.py` reads `terraform.tfstate` to discover deployed resources, maps each to its CloudWatch Log Group, polls `FilterLogEvents` every ~3s.

### Log coverage

| Method | Services |
|---|---|
| CloudWatch Logs (real-time) | Lambda, Step Functions, Glue, Glue DataBrew, EMR, EMR Serverless, SageMaker, Kinesis Firehose, Kinesis Analytics, MSK, Aurora, Redshift, DMS, Athena |
| CloudTrail (~5-15 min delay) | S3, SQS, SNS, DynamoDB, EventBridge, CloudWatch rules, Kinesis Streams |
| No monitoring | IAM, Lake Formation, Glue Data Catalog, QuickSight, EC2, SageMaker Notebook |

### Adding log support

1. Create `aws_cloudwatch_log_group` in `_render_<type>()` + configure native logging
2. Add pattern to `_LOG_GROUP_PATTERNS` in `tools/log_aggregator.py`
3. Add to `_SERVICE_TO_TF` and `_TF_NAME_ATTR`
4. If no native CW Logs: add to `_CLOUDTRAIL_SERVICES` and `_CLOUDTRAIL_TF_MAP`

## Pipeline Inspector Agent

Auto-detects and fixes runtime errors. Classifies by regex → 1 Haiku call for diagnosis + boto3 fix → executes fix → re-triggers pipeline → watches 45s for recurrence. Limits: 30 calls or 10 min per service.

WebSocket events: `inspector_start`, `inspector_diagnosing`, `inspector_diagnosis`, `inspector_fixing`, `inspector_fixed`, `inspector_fix_failed`, `inspector_manual`, `inspector_retrigger`, `inspector_retrigger_ok`, `inspector_retrigger_failed`, `inspector_resolved`, `inspector_error_recurred`, `inspector_budget_exhausted`

## Config Chat

Three-tier resolution: Tier 0 (keyword matching, $0, ~70%) → Tier 1 (Haiku, ~$0.0002) → Tier 2 (Sonnet, ~$0.003).

### Config keys per service type

- **s3**: versioning_status
- **lambda**: runtime, handler, memory_size, timeout
- **dynamodb**: billing_mode, hash_key, hash_key_type, read_capacity, write_capacity
- **sqs**: visibility_timeout_seconds, message_retention_seconds
- **stepfunctions**: type
- **cloudwatch/eventbridge**: schedule_expression
- **kinesis_streams**: stream_mode, shard_count, retention_period
- **ec2**: instance_type
- **msk**: kafka_version, number_of_broker_nodes, broker_instance_type, volume_size
- **redshift**: node_type, number_of_nodes, database_name, master_username
- **aurora**: engine, engine_version, database_name, master_username
- **emr**: release_label, master_instance_type, core_instance_type, core_instance_count, applications
- **emr_serverless**: release_label, type, architecture, idle_timeout_minutes, max_cpu, max_memory, max_disk
- **sagemaker**: instance_type, initial_instance_count, container_image, framework, image_tag, model_data_url

## Pipeline Builder Agent

System prompt (`prompts/pipeline_builder.md`): 27 canonical service types, integration event conventions, required config, prefix patterns, 20 strict rules. Supports multi-turn refinement via `refine()`.

## Spec knowledge base structure

Each `specs/<type>.yaml`:
1. **defaults** — Terraform attributes (min-cost)
2. **iam** — `always`, `as_target_of.<peer>`, `as_source_to.<peer>`
3. **env_vars** — pattern-based wiring (`{PEER_UPPER}`)
4. **vpc_triggers** — peer types forcing VPC
5. **sub_components** (optional) — declarative child resources, zero Python changes

## Integration wiring ownership (hardcoded in renderers)

| Wiring | Owned by |
|--------|----------|
| S3 → Lambda trigger | S3 fragment |
| S3 → SQS notification | S3 fragment |
| SQS → Lambda event source | Lambda fragment |
| SQS ← S3/CloudWatch policy | SQS fragment |
| CloudWatch → SQS/Lambda target | CloudWatch fragment |
| Lambda → Lambda invoke | Caller Lambda fragment |
| SNS → SQS/Lambda subscription | SNS fragment |

## File-by-file reference

| File | Purpose | LLM? |
|------|---------|------|
| `main.py` | CLI entry point | no |
| `app.py` | FastAPI web UI | yes (via agents) |
| `templates/index.html` | Single-page UI | — |
| `schemas.py` | Pydantic models | no |
| `engine/spec_loader.py` | Loads specs/*.yaml | no |
| `engine/spec_builder.py` | Computes ServiceBlueprint | no |
| `engine/hcl_renderer.py` | Golden templates per type | no |
| `engine/hcl_linter.py` | Cross-reference validation | no |
| `engine/naming.py` | Length-safe resource names | no |
| `engine/config_registry.py` | Supported config keys registry | no |
| `engine/spec_index.py` | Feature index for Tier 0 matching | no |
| `engine/config_validator.py` | Pre-render config validation | no |
| `engine/integration_validator.py` | Integration completeness checks | no |
| `engine/pipeline_builder.py` | Orchestrator | no |
| `engine/sub_component_renderer.py` | Declarative child resources | no |
| `agents/diagram_reader.py` | Image → YAML | yes (1 call) |
| `agents/pipeline_builder_agent.py` | Text → YAML | yes (1/turn) |
| `agents/config_agent.py` | Config chat Tier 1/2 | yes |
| `agents/developer_agent.py` | boto3 codegen + execute | yes |
| `agents/pipeline_inspector.py` | Runtime error auto-fix | yes |
| `tools/terraform_fix.py` | Minor TF error fix | yes |
| `tools/autofix_agent.py` | TF apply failure fix | yes |
| `tools/log_aggregator.py` | Pipeline run log polling | no |
| `tools/terraform_cli.py` | terraform fmt/init/validate | no |

## Testing

149 tests, all offline. Parametrized tests auto-discover new types.

| Test class | Covers |
|---|---|
| TestNaming | Length caps, format, uniqueness |
| TestSpecLoader | Spec loading, classification, IAM rules |
| TestSpecBuilder | IAM computation, env vars, tags, config merge |
| TestHclRenderer | All renderers, resource presence, wiring |
| TestLinter | Cross-refs, duplicates |
| TestPipelineBuilder | End-to-end YAML → HCL |
| TestConfigRegistry | Type validation, range/allowed values |
| TestFeatureIndex | Keyword matching, templates |
| TestConfigResolution | Tier 0 → patch → re-render |
| TestPipelineBuilderAgent | Prompt validation, schema compliance |
