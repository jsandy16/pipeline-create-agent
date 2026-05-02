"""Generic, spec-driven sub-component renderer.

Reads the ``sub_components`` section from a service spec and generates
Terraform HCL for child resources (Glue tables, S3 prefix objects,
Athena named queries, etc.) based purely on declarative YAML definitions.

Adding a new sub-component type requires **zero Python changes** — just
add a ``sub_components`` entry to the service's spec YAML.
"""
from __future__ import annotations

import logging
import re
from typing import Any

from engine.naming import suffixed_name
from schemas import PipelineRequest, ServiceBlueprint

logger = logging.getLogger(__name__)

# ── Public API ───────────────────────────────────────────────────────────────

def render_sub_components(bp: ServiceBlueprint, req: PipelineRequest) -> str:
    """Return HCL for all sub-components declared in the spec.

    Returns an empty string if the service has no ``sub_components`` in its
    spec or the user config does not trigger any.
    """
    from engine.spec_loader import load_spec
    from engine.naming import resource_label as _resource_label

    spec = load_spec(bp.service_type)
    if spec is None or not spec.sub_components:
        return ""

    # Build a map of service_name → actual Terraform bucket id reference
    # so Glue table locations like "s3://staging_bucket/prefix/" are rewritten
    # to "s3://${aws_s3_bucket.LABEL.id}/prefix/" at render time.
    _s3_service_map: dict[str, str] = {
        svc.name: f"aws_s3_bucket.{_resource_label(req, svc)}.id"
        for svc in req.services
        if svc.type == "s3"
    }

    cfg = bp.required_configuration
    parts: list[str] = []

    for comp_name, comp_def in spec.sub_components.items():
        trigger_key = comp_def.get("trigger_key", comp_name)
        raw_value = cfg.get(trigger_key)
        if not raw_value:
            continue

        is_list = comp_def.get("is_list", False)
        items = raw_value if (is_list and isinstance(raw_value, list)) else [raw_value]

        for idx, item in enumerate(items):
            # For scalar lists (e.g. prefixes: ["a/", "b/"]), wrap in a dict
            if not isinstance(item, dict):
                item = {"value": item}

            # Resolve S3 service name references in item values before rendering.
            # Rewrites e.g. {"location": "s3://staging_bucket/collision/"} to
            # {"location": "s3://${aws_s3_bucket.LABEL.id}/collision/"}
            item = _resolve_s3_refs(item, _s3_service_map)

            ctx = _build_context(bp, req, spec, comp_def, item, idx)
            hcl = _render_resource(comp_def, ctx, bp)
            if hcl:
                parts.append(hcl)

    return "\n\n".join(parts)


def _resolve_s3_refs(item: dict, s3_map: dict[str, str]) -> dict:
    """Rewrite ``s3://service_name/path`` values to Terraform interpolations.

    For each string value in *item*, if it starts with ``s3://`` and the
    hostname part matches a known S3 service name, replace it with
    ``s3://${tf_resource_ref}/path`` so the rendered HCL uses the real
    bucket name at apply time rather than the literal service name.
    """
    if not s3_map:
        return item
    result = {}
    for k, v in item.items():
        if isinstance(v, str) and v.startswith("s3://"):
            # Extract: s3://<host>/<rest>
            without_scheme = v[5:]  # strip "s3://"
            slash_pos = without_scheme.find("/")
            if slash_pos > 0:
                host = without_scheme[:slash_pos]
                rest = without_scheme[slash_pos:]  # includes leading "/"
            else:
                host = without_scheme
                rest = "/"
            if host in s3_map:
                v = f"s3://${{  {s3_map[host]}  }}{rest}"
                # Use clean Terraform interpolation syntax (no extra spaces)
                v = f"s3://${{{s3_map[host]}}}{rest}"
        result[k] = v
    return result


# ── Context builder ──────────────────────────────────────────────────────────

def _build_context(
    bp: ServiceBlueprint,
    req: PipelineRequest,
    spec: Any,
    comp_def: dict,
    item: dict,
    idx: int,
) -> dict[str, Any]:
    """Build the variable-resolution context for one sub-component item."""
    return {
        "parent_label": bp.resource_label,
        "parent_name": bp.resource_name,
        "parent_resource_ref": f"{spec.terraform_resource}.{bp.resource_label}",
        "pipeline_name": getattr(req, "pipeline_name", ""),
        "item": item,
        "index": idx,
    }


# ── HCL block builder ───────────────────────────────────────────────────────

def _render_resource(comp_def: dict, ctx: dict, bp: ServiceBlueprint) -> str:
    """Render a single ``resource "type" "label" { ... }`` block."""
    tf_resource = comp_def["terraform_resource"]
    label = _make_label(comp_def, ctx, bp)

    body_lines: list[str] = []

    # Top-level attributes
    for attr_name, attr_tmpl in comp_def.get("attributes", {}).items():
        val = _resolve(attr_tmpl, ctx)
        if val is None or val == "":
            continue
        body_lines.append(_format_attr(attr_name, val, indent=2))

    # Nested blocks (single)
    for block_name, block_def in comp_def.get("nested_blocks", {}).items():
        block_hcl = _render_nested_block(block_name, block_def, ctx, indent=2)
        if block_hcl:
            body_lines.append(block_hcl)

    # List blocks (repeated)
    for block_name, block_def in comp_def.get("list_blocks", {}).items():
        blocks_hcl = _render_list_blocks(block_name, block_def, ctx, indent=2)
        if blocks_hcl:
            body_lines.append(blocks_hcl)

    # Tags
    if comp_def.get("tags") == "inherit":
        body_lines.append(_tags_block(bp, indent=2))

    body = "\n\n".join(body_lines)
    return f'resource "{tf_resource}" "{label}" {{\n{body}\n}}'


def _render_nested_block(
    block_name: str, block_def: dict, ctx: dict, indent: int
) -> str:
    """Render a single nested block like ``storage_descriptor { ... }``."""
    pad = " " * indent
    lines: list[str] = []

    for attr_name, attr_tmpl in block_def.get("attributes", {}).items():
        val = _resolve(attr_tmpl, ctx)
        if val is None or val == "":
            continue
        lines.append(_format_attr(attr_name, val, indent=indent + 2))

    # Recursively render nested blocks within this block
    for sub_name, sub_def in block_def.get("nested_blocks", {}).items():
        sub_hcl = _render_nested_block(sub_name, sub_def, ctx, indent=indent + 2)
        if sub_hcl:
            lines.append(sub_hcl)

    # List blocks within this nested block
    for lb_name, lb_def in block_def.get("list_blocks", {}).items():
        lb_hcl = _render_list_blocks(lb_name, lb_def, ctx, indent=indent + 2)
        if lb_hcl:
            lines.append(lb_hcl)

    if not lines:
        return ""

    body = "\n\n".join(lines)
    return f"{pad}{block_name} {{\n{body}\n{pad}}}"


def _render_list_blocks(
    block_name: str, block_def: dict, ctx: dict, indent: int
) -> str:
    """Render repeated blocks (e.g. multiple ``columns { ... }`` blocks)."""
    source_key = block_def.get("source_key", block_name)
    items = _resolve_list(source_key, ctx)
    if not items:
        return ""

    pad = " " * indent
    blocks: list[str] = []

    for col_idx, col_item in enumerate(items):
        if not isinstance(col_item, dict):
            col_item = {"value": col_item}
        col_ctx = {**ctx, "col": col_item, "key": col_item, "col_index": col_idx}

        lines: list[str] = []
        for attr_name, attr_tmpl in block_def.get("attributes", {}).items():
            val = _resolve(attr_tmpl, col_ctx)
            if val is None or val == "":
                continue
            lines.append(_format_attr(attr_name, val, indent=indent + 2))

        if lines:
            body = "\n".join(lines)
            blocks.append(f"{pad}{block_name} {{\n{body}\n{pad}}}")

    return "\n\n".join(blocks)


# ── Value resolution ─────────────────────────────────────────────────────────

_TEMPLATE_RE = re.compile(r"\{([^}]+)\}")


def _resolve(template: Any, ctx: dict) -> Any:
    """Resolve a template string like ``{item.name}`` or ``{item.type|string}``.

    If the template is not a string, return it as-is (e.g. ints, bools).
    Dicts are resolved recursively so map attributes (e.g. ``parameters``)
    get their template variables substituted.
    Returns None if a required reference is missing.
    """
    if isinstance(template, dict):
        return {k: _resolve(v, ctx) for k, v in template.items()}
    if not isinstance(template, str):
        return template

    # Check if the entire value is a single reference (preserve type)
    m = _TEMPLATE_RE.fullmatch(template)
    if m:
        return _lookup(m.group(1), ctx)

    # Otherwise do string interpolation for mixed templates
    def _replacer(match: re.Match) -> str:
        val = _lookup(match.group(1), ctx)
        return "" if val is None else str(val)

    result = _TEMPLATE_RE.sub(_replacer, template)
    return result if result else None


def _lookup(expr: str, ctx: dict) -> Any:
    """Look up ``expr`` in context. Supports dotted paths and ``|default``."""
    # Split off default
    if "|" in expr:
        path, default = expr.rsplit("|", 1)
    else:
        path, default = expr, None

    parts = path.strip().split(".")
    obj: Any = ctx
    for part in parts:
        if isinstance(obj, dict):
            obj = obj.get(part)
        else:
            obj = getattr(obj, part, None)
        if obj is None:
            return default

    return obj


def _resolve_list(source_key: str, ctx: dict) -> list:
    """Resolve a source key to a list from the item context."""
    item = ctx.get("item", {})
    if isinstance(item, dict):
        val = item.get(source_key, [])
    else:
        val = getattr(item, source_key, [])
    return val if isinstance(val, list) else []


# ── Helpers ──────────────────────────────────────────────────────────────────

def _make_label(comp_def: dict, ctx: dict, bp: ServiceBlueprint) -> str:
    """Build a length-safe Terraform label for a sub-component resource."""
    name_field = comp_def.get("name_field", "name")
    item = ctx["item"]
    item_name = item.get(name_field, f"item_{ctx['index']}") if isinstance(item, dict) else str(item)
    suffix = comp_def.get("label_suffix", "sub")

    safe_item = _sanitize(item_name)
    label = f"{bp.resource_label}_{safe_item}_{suffix}"
    # Terraform labels have no strict length limit, but keep reasonable
    # and ensure valid identifier (no leading digits/hyphens)
    label = re.sub(r"[^a-zA-Z0-9_]", "_", label)
    label = re.sub(r"_+", "_", label).strip("_")
    return label


def _sanitize(name: str) -> str:
    """Make a name safe for Terraform identifiers."""
    s = re.sub(r"[^a-zA-Z0-9_]", "_", name)
    s = re.sub(r"_+", "_", s)
    return s.strip("_").lower()


def _format_attr(name: str, value: Any, indent: int) -> str:
    """Format a single HCL attribute line."""
    pad = " " * indent
    # Terraform references (resource.label.attr) must not be quoted
    if isinstance(value, str) and re.match(
        r"^(aws_|data\.|var\.|local\.|module\.)", value
    ):
        return f"{pad}{name} = {value}"
    if isinstance(value, bool):
        return f'{pad}{name} = {"true" if value else "false"}'
    if isinstance(value, (int, float)):
        return f"{pad}{name} = {value}"
    if isinstance(value, list):
        items = ", ".join(f'"{v}"' for v in value)
        return f"{pad}{name} = [{items}]"
    if isinstance(value, dict):
        # Render as HCL map
        entries = ", ".join(f'{k} = "{v}"' for k, v in value.items())
        return f"{pad}{name} = {{{entries}}}"
    # Default: quoted string
    escaped = str(value).replace("\\", "\\\\").replace('"', '\\"')
    return f'{pad}{name} = "{escaped}"'


def _tags_block(bp: ServiceBlueprint, indent: int) -> str:
    """Render a tags block inheriting the parent's pipeline tags."""
    pad = " " * indent
    inner = " " * (indent + 2)
    lines = [f"{pad}tags = {{"]
    for k, v in bp.tags.items():
        lines.append(f'{inner}{k:<14}= "{v}"')
    lines.append(f"{pad}}}")
    return "\n".join(lines)
