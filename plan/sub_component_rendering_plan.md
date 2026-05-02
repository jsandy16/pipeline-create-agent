# Plan: Spec-Driven Sub-Component Rendering System

## Context

When users tell the Pipeline Builder Agent to create sub-components (S3 prefixes, Glue catalog tables, Athena named queries, custom Lambda code), the engine can't do it. Renderers only create primary resources. Adding any sub-component currently requires modifying Python renderer code.

**Goal:** A generic, spec-driven system where sub-component creation is defined in YAML specs. Adding new sub-components = editing a spec file, zero Python changes.

**Constraints:**
- Rendering stays deterministic (0 LLM calls for YAML input)
- Pipeline Builder Agent already makes 1 LLM call — we make it smarter, not add more calls
- `ServiceSpec.config: dict[str, Any]` already supports nested dicts/lists — no schema changes

---

## Architecture

```
User config (nested)  →  spec_builder merges defaults  →  ServiceBlueprint.required_configuration
                                                                    │
                          ┌─────────────────────────────────────────┘
                          │
               _render_<type>(bp, req)     ← existing renderer (primary resource)
                          │
               render_sub_components(bp)   ← NEW generic renderer
                          │                   reads spec.sub_components
                          │                   checks cfg for trigger keys
                          │                   builds HCL from declarative spec
                          ▼
                   Combined HCL fragment
```

---

## Changes (6 files modified, 1 new file)

### 1. NEW: `engine/sub_component_renderer.py` (~150-200 lines)

Core generic renderer. Key function:

```python
def render_sub_components(bp: ServiceBlueprint, req: PipelineRequest) -> str:
```

Algorithm:
1. Load spec via `load_spec(bp.service_type)`
2. If no `spec.sub_components`, return `""`
3. For each sub-component definition, check if `trigger_key` exists in `bp.required_configuration`
4. If present, iterate items (for lists) or process single value
5. Build HCL block from declarative attribute/block definitions in spec
6. Use `engine/naming.py` for length-safe labels
7. Return joined HCL fragments

Helper functions:
- `_build_resource_block(tf_resource, label, comp_def, context, bp)` — recursively builds HCL from `attributes`, `nested_blocks`, `list_blocks`
- `_resolve_value(template, context)` — resolves `{item.field}`, `{parent_label}`, `{item.field|default}` references
- `_sanitize_label(name)` — makes name safe for Terraform identifiers

### 2. MODIFY: `engine/spec_loader.py` (3 lines)

Add to `ServiceTypeSpec` dataclass:
```python
sub_components: dict[str, Any]  # sub-component definitions from spec
```

Add to `_parse_spec()`:
```python
sub_components=raw.get("sub_components", {}),
```

### 3. MODIFY: `engine/hcl_renderer.py` (5 lines)

Hook into `render()` at line 2225:
```python
def render(bp, req):
    hcl = renderer(bp, req)
    sub_hcl = render_sub_components(bp, req)  # NEW
    if sub_hcl:
        hcl = hcl + "\n\n" + sub_hcl
    return hcl
```

### 4. MODIFY: `specs_new/*.yaml` — Add `sub_components` sections

Priority services (covers the user's exact use case):

**glue_data_catalog** — `tables` (aws_glue_catalog_table with storage_descriptor, columns, partition_keys)
**athena** — `named_queries` (aws_athena_named_query), `database` config key for Glue binding
**s3** — `prefixes` (aws_s3_object for prefix "folders"), `lifecycle_rules`
**lambda** — `handler_code` config key (replaces placeholder in existing renderer — this is a cfg.get() change, not a sub-component)

Spec format example (Glue Data Catalog tables):
```yaml
sub_components:
  tables:
    terraform_resource: aws_glue_catalog_table
    trigger_key: tables
    is_list: true
    label_suffix: table
    name_field: name
    attributes:
      database_name: "{parent_resource_ref}.name"
      name: "{item.name}"
      table_type: "{item.table_type|EXTERNAL_TABLE}"
    nested_blocks:
      storage_descriptor:
        attributes:
          location: "{item.location}"
          input_format: "{item.input_format|org.apache.hadoop.mapred.TextInputFormat}"
          output_format: "{item.output_format|org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat}"
        nested_blocks:
          ser_de_info:
            attributes:
              serialization_library: "{item.serde|org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe}"
        list_blocks:
          columns:
            source_key: columns
            attributes:
              name: "{col.name}"
              type: "{col.type|string}"
    list_blocks:
      partition_keys:
        source_key: partition_keys
        attributes:
          name: "{key.name}"
          type: "{key.type|string}"
    tags: inherit
```

### 5. MODIFY: `prompts/pipeline_builder.md`

Add sub-component documentation so the agent generates rich nested config:
- Available sub-components per service type
- Config structure examples for tables, prefixes, named queries
- Rules for when to include sub-components based on user language

### 6. MODIFY: `engine/config_registry.py`

Add list-type config keys: `tables` (glue_data_catalog), `named_queries` (athena), `prefixes` (s3), `handler_code` (lambda)

### 7. MODIFY: `tests/test_engine.py`

New `TestSubComponentRenderer` class:
- Glue table renders aws_glue_catalog_table with columns
- Multiple tables produce multiple resources
- Athena named query renders correctly
- S3 prefix creates aws_s3_object
- No sub-components = no change to existing HCL
- Sub-component names are length-safe
- Full pipeline with sub-components passes linter

---

## Lambda handler_code (special case)

This isn't a sub-component (new resource) — it's overriding the existing placeholder. Handle via the established `cfg.get()` pattern:

1. Add `handler_code` to Lambda spec defaults (empty string = use placeholder)
2. Add `handler_code` to config_registry
3. In `_render_lambda()`, replace the hardcoded placeholder content with `cfg.get("handler_code", DEFAULT_PLACEHOLDER)`

This is ~3 lines in the Lambda renderer — the one code change, but it follows the existing pattern exactly.

---

## IAM / Access Patterns

The enriched specs (from 2026-04-20) already have comprehensive bidirectional IAM rules. Sub-component resources (Glue tables, Athena named queries) are Terraform metadata created at plan/apply time — they don't need runtime IAM. Cross-service access (Athena → Glue → S3) is already covered by the existing IAM rules in the specs.

---

## What This Enables (User's Use Case)

Pipeline Builder Agent generates:
```yaml
services:
  - name: src
    type: s3
    config:
      prefixes: ["case/", "party/", "collision/", "victim/"]
  - name: case_processor
    type: lambda
    config:
      handler_code: "def handler(event, context):\n    print('Hello World')"
  # ... 3 more lambdas
  - name: collision_db
    type: glue_data_catalog
    config:
      tables:
        - name: case
          location: "s3://src/case/"
          columns: [{name: id, type: string}, {name: date, type: date}]
        - name: victim
          location: "s3://src/victim/"
          columns: [{name: id, type: string}, {name: name, type: string}]
  - name: query_engine
    type: athena
    config:
      database: collision_db
```

Engine deterministically produces all Terraform resources: bucket + prefix objects + lambdas with custom code + catalog database + 4 tables + athena workgroup. Zero additional LLM calls.

---

## Verification

1. Run `python -m pytest tests/ -v` — all 149 existing tests + new sub-component tests pass
2. Build the user's exact pipeline from YAML — produces valid HCL with all sub-components
3. Run `terraform validate` on output
4. Test Pipeline Builder Agent with the user's original prompt — generates correct nested config
