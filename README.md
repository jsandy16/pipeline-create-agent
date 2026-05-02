# AWS Pipeline Engine

Spec-driven framework that converts AWS architecture diagrams (or YAML specs) into
validated, deployable Terraform. **Zero LLM calls for YAML input.** One LLM call
for diagram input (Claude Vision reads the image).

## How it works

```
Architecture Diagram (PNG/JPEG)
        │
        ▼
T0 DiagramReader (1 LLM call — Claude Vision)
        │
        ▼
Pipeline YAML (services + integrations)
        │
        ▼ (deterministic from here — zero LLM calls)
        │
┌───────┴────────────────────────────┐
│ For each service:                  │
│   1. Load specs/<type>.yaml        │  ← knowledge base
│   2. Build blueprint (IAM, env,    │  ← deterministic Python
│      VPC from integration patterns)│
│   3. Render HCL (golden template)  │  ← deterministic Python
└────────────────────────────────────┘
        │
        ▼
Consolidate → Lint → terraform fmt + validate
        │
        ▼
output/<pipeline>/<timestamp>/main.tf
```

## Quick start

```bash
pip install -r requirements.txt

# From YAML (zero LLM calls, runs in <2 seconds):
python main.py examples/simple_ingest.yaml

# From diagram (1 LLM call, ~15 seconds):
export ANTHROPIC_API_KEY=sk-ant-...
python main.py diagram.png

# With terraform validation:
python main.py examples/data_processing_pipeline.yaml --validate

# Dry run (print HCL to stdout):
python main.py examples/simple_ingest.yaml --dry-run
```

## Adding a new service type

1. Create `specs/<service_type>.yaml` with defaults, IAM rules, env var patterns
2. Add a `_render_<type>()` function to `engine/hcl_renderer.py`
3. Register it in the `_RENDERERS` dict
4. Add a test in `tests/test_engine.py`

No prompts to edit. No LLM behavior to debug.

## Architecture

| Component | File | LLM calls | Purpose |
|-----------|------|-----------|---------|
| Diagram reader | `agents/diagram_reader.py` | 1 (vision) | Image → YAML |
| Spec loader | `engine/spec_loader.py` | 0 | Load service type knowledge |
| Blueprint builder | `engine/spec_builder.py` | 0 | Compute IAM, env vars, VPC |
| HCL renderer | `engine/hcl_renderer.py` | 0 | Generate Terraform fragments |
| Linter | `engine/hcl_linter.py` | 0 | Cross-reference validation |
| Pipeline builder | `engine/pipeline_builder.py` | 0 | Orchestrate everything |

## Supported services (12)

s3, lambda, sqs, dynamodb, stepfunctions, glue, cloudwatch, sns,
kinesis_streams, athena, eventbridge, ec2

## Tests

```bash
python -m pytest tests/ -v
```
# pipeline-agent-v1
# pipeline-agent-v1
