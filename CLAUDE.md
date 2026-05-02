# CLAUDE.md

Spec-driven framework: AWS architecture diagrams / YAML / natural language → validated, deployable Terraform HCL. Deterministic engine (zero LLM for YAML input). See `docs/ARCHITECTURE.md` for detailed reference.

## Commands

```bash
pip install -r requirements.txt
python main.py examples/simple_ingest.yaml                    # YAML → HCL (0 LLM, <1s)
python main.py examples/simple_ingest.yaml --validate         # + terraform validate
python main.py examples/simple_ingest.yaml --dry-run          # print HCL, no writes
python main.py examples/simple_ingest.yaml --apply            # deploy to AWS
python main.py diagram.png                                     # image → HCL (1 LLM call)
python main.py                                                 # batch: scan input_dgm/
python -m pytest tests/ -v                                     # all tests (offline, 149 tests)
python -m uvicorn app:app --reload --port 8000                 # web UI
```

CLI flags: `--out DIR`, `--validate`, `--dry-run`, `--apply`, `--model MODEL`, `--log-level`

## AWS credentials

`.env` (gitignored): `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION=us-east-1`

## Core architecture

Input → `PipelineRequest` (Pydantic) → FOR EACH SERVICE: spec_loader → spec_builder (IAM/env/VPC from integration graph) → hcl_renderer (`_render_<type>()`) → pipeline_builder (consolidate + lint + write) → terraform fmt/validate

## Key design rules

1. **No LLM in the engine.** Fixes go in specs or renderers, not prompts.
2. **Specs hold knowledge.** `specs/<type>.yaml` = defaults, IAM rules, env var wiring, VPC triggers. IAM is a table lookup from the integration graph.
3. **Golden templates only.** No LLM fallback for HCL. Missing renderer → `ValueError`.
4. **Names are length-safe.** Always use `engine/naming.py`. Use `suffixed_name()` when appending suffixes.
5. **Tags are mandatory.** Use `_tags_block(bp)`. Linter checks.
6. **Free tier defaults.** Never upsize spec defaults without considering cost. Check `_NOT_FREE_TIER` in `hcl_renderer.py`.
7. **Every renderer creates a CloudWatch Log Group.** No native CW Logs → add to `_CLOUDTRAIL_SERVICES` in `log_aggregator.py`.
8. **Tests must pass.** `python -m pytest tests/ -v` after every change.

## Adding a new AWS service type

1. Create `specs/<type>.yaml` (defaults, iam, env_vars, vpc_triggers)
2. Add `_render_<type>()` to `engine/hcl_renderer.py` + register in `_RENDERERS`
3. Add log group pattern to `tools/log_aggregator.py`
4. Add tests (parametrized tests auto-discover new types)
5. Update `prompts/diagram_reader.md` and `prompts/pipeline_builder.md`
6. If configurable: add to `engine/config_registry.py`, optionally `config_templates/<type>.yaml`

Zero changes needed in: spec_loader, spec_builder, pipeline_builder, hcl_linter, naming, schemas, main.

## LLM call boundaries

| Agent/Tool | When | Model |
|---|---|---|
| `agents/diagram_reader.py` | image → YAML | Vision (1 call) |
| `agents/pipeline_builder_agent.py` | text → YAML | Sonnet (1/turn) |
| `agents/config_agent.py` | config chat Tier 1/2 | Haiku/Sonnet |
| `agents/developer_agent.py` | boto3 codegen | Haiku |
| `agents/pipeline_inspector.py` | runtime error fix | Haiku |
| `tools/terraform_fix.py` | minor TF errors | Haiku |
| `tools/autofix_agent.py` | TF apply failures | conditional |

## Claude Code approach (token efficiency)

- **Never read large files whole.** Use grep/targeted reads for specific sections. `templates/index.html` is especially large — always search within it, never read fully.
- **Never read files you don't need.** Only read files directly relevant to the current task. Don't explore speculatively.
- **Use targeted tests.** Run specific test classes/methods (`pytest tests/test_engine.py::TestClass::test_method -v`) instead of the full suite unless explicitly asked.
- **Skip explanations unless asked.** Go straight to the change. No preamble, no recap, no "here's what I did" summaries.
- **Don't re-read files.** If you already read a file in this conversation, don't read it again unless it was modified.
- **Batch related edits.** Make all changes to a file in one edit call, not multiple sequential edits.
- **Consult `docs/ARCHITECTURE.md` only when needed.** Don't read it preemptively — only when the task involves routes, wiring tables, log coverage, config keys, or inspector details.
- **Minimize tool output.** When running shell commands, use flags that reduce output (e.g., `--quiet`, `--no-header`, pipe to `tail`/`head`).
- **No redundant searches.** If you can infer a file path from context or CLAUDE.md, open it directly instead of globbing/grepping for it.

## Engineering standards

- Integrations are source-of-truth for IAM, env vars, VPC placement
- Every service type needs both spec AND renderer
- Integration wiring ownership is in renderers (e.g., S3 owns bucket notification, Lambda owns event source mapping)
- Config Chat: Tier 0 (keyword, $0) → Tier 1 (Haiku) → Tier 2 (Sonnet). See `engine/spec_index.py`, `engine/config_registry.py`
