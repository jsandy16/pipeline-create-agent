"""Tests for the pipeline engine.

Covers: naming, spec loading, blueprint building, HCL rendering,
linting, sub-component rendering, and end-to-end pipeline generation.

All tests are deterministic — no LLM calls, no network, no terraform binary.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest
import yaml

# Add project root to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from schemas import PipelineRequest, ServiceSpec, ServiceBlueprint
from engine.naming import resource_label, resource_name
from engine.spec_loader import load_spec, list_known_types, has_spec
from engine.spec_builder import build_blueprint
from engine.hcl_renderer import render, supported_types
from engine.hcl_linter import lint_hcl
from engine.pipeline_builder import build_pipeline
from engine.config_validator import validate_blueprint, ValidationError
from engine.sub_component_renderer import render_sub_components


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def simple_request():
    return PipelineRequest(
        pipeline_name="demo",
        business_unit="ops",
        cost_center="cc001",
        services=[
            ServiceSpec(name="src_bucket", type="s3"),
            ServiceSpec(name="processor", type="lambda", config={"runtime": "python3.12"}),
            ServiceSpec(name="output_queue", type="sqs"),
        ],
        integrations=[
            {"source": "src_bucket", "target": "processor", "event": "s3:ObjectCreated:*"},
            {"source": "processor", "target": "output_queue", "event": "send_message"},
        ],
    )


@pytest.fixture
def complex_request():
    """Request matching the sample architecture diagram."""
    yaml_path = Path(__file__).parent.parent / "examples" / "data_processing_pipeline.yaml"
    raw = yaml.safe_load(yaml_path.read_text())
    return PipelineRequest.model_validate(raw)


# ---------------------------------------------------------------------------
# Naming
# ---------------------------------------------------------------------------

class TestNaming:
    def test_resource_label_format(self, simple_request):
        svc = simple_request.services[0]
        label = resource_label(simple_request, svc)
        # Format: project_costcenter_businessunit_type_name_4hex
        assert label.startswith("demo_cc001_ops_s3_src_bucket_")
        assert len(label.split("_")[-1]) == 4  # 4-char hash
        assert "_" in label
        assert "-" not in label

    def test_resource_name_format(self, simple_request):
        svc = simple_request.services[0]
        name = resource_name(simple_request, svc)
        # Format: project-costcenter-businessunit-type-name-4hex
        assert name.startswith("demo-cc001-ops-s3-src-bucket-")
        assert "-" in name

    def test_s3_name_length_capped(self):
        req = PipelineRequest(
            pipeline_name="very_long_pipeline_name_that_exceeds_limits",
            business_unit="engineering",
            cost_center="cc001",
            services=[ServiceSpec(name="source_bucket", type="s3")],
        )
        name = resource_name(req, req.services[0])
        assert len(name) <= 63, f"S3 name too long: {len(name)} chars"

    def test_lambda_name_length_capped(self):
        req = PipelineRequest(
            pipeline_name="very_long_pipeline_name_that_exceeds_limits",
            business_unit="engineering",
            cost_center="cc001",
            services=[ServiceSpec(name="processing_lambda", type="lambda")],
        )
        name = resource_name(req, req.services[0])
        assert len(name) <= 64, f"Lambda name too long: {len(name)} chars"

    def test_unique_names_for_different_services(self):
        req = PipelineRequest(
            pipeline_name="long_pipeline",
            business_unit="eng",
            cost_center="cc001",
            services=[
                ServiceSpec(name="bucket_a", type="s3"),
                ServiceSpec(name="bucket_b", type="s3"),
            ],
        )
        a = resource_name(req, req.services[0])
        b = resource_name(req, req.services[1])
        assert a != b

    def test_ordinal_suffix_on_duplicate_types(self):
        """Services sharing a type get unique names via 4-char hash."""
        req = PipelineRequest(
            pipeline_name="myapp",
            business_unit="eng",
            cost_center="cc001",
            services=[
                ServiceSpec(name="raw_bucket",       type="s3"),
                ServiceSpec(name="processed_bucket", type="s3"),
                ServiceSpec(name="archive_bucket",   type="s3"),
            ],
        )
        names  = [resource_name(req, s)  for s in req.services]
        labels = [resource_label(req, s) for s in req.services]

        # All names are unique (hash differentiates them)
        assert len(set(names)) == 3
        assert len(set(labels)) == 3

        # Diagram/YAML service name is present in the physical name
        assert "raw-bucket"       in names[0]
        assert "processed-bucket" in names[1]
        assert "archive-bucket"   in names[2]

    def test_no_ordinal_for_unique_types(self, simple_request):
        """Single-instance services have a 4-char hash suffix, all unique."""
        labels = [resource_label(simple_request, svc) for svc in simple_request.services]
        names  = [resource_name(simple_request, svc)  for svc in simple_request.services]
        assert len(set(labels)) == len(labels), "Labels not unique"
        assert len(set(names))  == len(names),  "Names not unique"
        # Each label ends with a 4-char hash
        for label in labels:
            assert len(label.split("_")[-1]) == 4

    def test_ordinal_mixed_types(self):
        """Duplicate types produce unique names via hash differentiation."""
        req = PipelineRequest(
            pipeline_name="pipe",
            business_unit="eng",
            cost_center="cc001",
            services=[
                ServiceSpec(name="ingest",    type="lambda"),
                ServiceSpec(name="queue_a",   type="sqs"),
                ServiceSpec(name="transform", type="lambda"),
                ServiceSpec(name="queue_b",   type="sqs"),
            ],
            integrations=[
                {"source": "ingest",    "target": "queue_a",   "event": "send_message"},
                {"source": "transform", "target": "queue_b",   "event": "send_message"},
            ],
        )
        svcs = {s.name: s for s in req.services}

        # All labels and names are unique
        labels = [resource_label(req, s) for s in req.services]
        names  = [resource_name(req, s)  for s in req.services]
        assert len(set(labels)) == 4
        assert len(set(names))  == 4

        # Service name embedded in the label/name
        assert "ingest" in resource_label(req, svcs["ingest"])
        assert "transform" in resource_label(req, svcs["transform"])
        assert "queue-a" in resource_name(req, svcs["queue_a"])
        assert "queue-b" in resource_name(req, svcs["queue_b"])


# ---------------------------------------------------------------------------
# Spec loading
# ---------------------------------------------------------------------------

class TestSpecLoader:
    def test_core_types_have_specs(self):
        expected = {"s3", "lambda", "sqs", "dynamodb", "stepfunctions", "glue",
                    "cloudwatch", "sns", "kinesis_streams", "athena", "eventbridge", "ec2"}
        known = set(list_known_types())
        assert expected <= known, f"Missing specs: {expected - known}"

    @pytest.mark.parametrize("stype", list_known_types())
    def test_each_spec_loads(self, stype):
        spec = load_spec(stype)
        assert spec is not None
        assert spec.service_type == stype

    def test_unknown_type_returns_none(self):
        assert load_spec("nonexistent_service") is None

    def test_lambda_is_principal(self):
        spec = load_spec("lambda")
        assert spec.is_principal is True

    def test_s3_is_passive(self):
        spec = load_spec("s3")
        assert spec.is_principal is False

    def test_lambda_has_iam_rules(self):
        spec = load_spec("lambda")
        assert "s3:GetObject" in spec.iam_as_target_of.get("s3", [])
        assert "sqs:SendMessage" in spec.iam_as_source_to.get("sqs", [])
        assert "logs:CreateLogGroup" in spec.iam_always


# ---------------------------------------------------------------------------
# Blueprint building
# ---------------------------------------------------------------------------

class TestSpecBuilder:
    def test_passive_service_no_iam(self, simple_request):
        svc = simple_request.services[0]  # S3
        bp = build_blueprint(svc, simple_request)
        assert bp.iam_permissions == []
        assert bp.is_principal is False

    def test_lambda_iam_from_integrations(self, simple_request):
        svc = simple_request.services[1]  # Lambda
        bp = build_blueprint(svc, simple_request)
        assert bp.is_principal is True
        # Should have: logs (always) + s3:GetObject (target of S3) + sqs:SendMessage (source to SQS)
        assert "logs:CreateLogGroup" in bp.iam_permissions
        assert "s3:GetObject" in bp.iam_permissions
        assert "sqs:SendMessage" in bp.iam_permissions

    def test_lambda_env_vars_from_integrations(self, simple_request):
        svc = simple_request.services[1]  # Lambda → SQS
        bp = build_blueprint(svc, simple_request)
        assert "OUTPUT_QUEUE_QUEUE_URL" in bp.env_vars

    def test_tags_present(self, simple_request):
        bp = build_blueprint(simple_request.services[0], simple_request)
        assert bp.tags["Pipeline"] == "demo"
        assert bp.tags["ManagedBy"] == "aws-pipeline-engine"

    def test_config_merges_user_hints(self, simple_request):
        svc = simple_request.services[1]  # Lambda with runtime hint
        bp = build_blueprint(svc, simple_request)
        assert bp.required_configuration["runtime"] == "python3.12"

    def test_complex_pipeline_all_blueprints(self, complex_request):
        for svc in complex_request.services:
            bp = build_blueprint(svc, complex_request)
            assert bp.service_name == svc.name
            assert bp.resource_label is not None
            assert bp.resource_name is not None


# ---------------------------------------------------------------------------
# HCL rendering
# ---------------------------------------------------------------------------

class TestHclRenderer:
    def test_core_types_have_renderers(self):
        expected = {"s3", "lambda", "sqs", "dynamodb", "stepfunctions", "glue",
                    "cloudwatch", "sns", "kinesis_streams", "athena", "eventbridge", "ec2"}
        actual = set(supported_types())
        assert expected <= actual, f"Missing renderers: {expected - actual}"

    @pytest.mark.parametrize("stype", supported_types())
    def test_each_type_renders_nonempty(self, stype):
        req = PipelineRequest(
            pipeline_name="test",
            business_unit="ops",
            cost_center="cc001",
            services=[ServiceSpec(name=f"test_{stype}", type=stype)],
        )
        bp = build_blueprint(req.services[0], req)
        hcl = render(bp, req)
        assert len(hcl) > 50, f"HCL too short for {stype}: {len(hcl)} chars"
        assert 'resource "' in hcl or 'data "' in hcl

    def test_s3_includes_bucket_resource(self, simple_request):
        bp = build_blueprint(simple_request.services[0], simple_request)
        hcl = render(bp, simple_request)
        assert 'resource "aws_s3_bucket"' in hcl
        assert 'resource "aws_s3_bucket_versioning"' in hcl
        assert 'sse_algorithm = "AES256"' in hcl

    def test_lambda_includes_role_and_function(self, simple_request):
        bp = build_blueprint(simple_request.services[1], simple_request)
        hcl = render(bp, simple_request)
        assert 'resource "aws_iam_role"' in hcl
        assert 'resource "aws_lambda_function"' in hcl
        assert 'resource "aws_cloudwatch_log_group"' in hcl
        assert "sqs:SendMessage" in hcl

    def test_s3_lambda_notification_wiring(self, simple_request):
        bp = build_blueprint(simple_request.services[0], simple_request)
        hcl = render(bp, simple_request)
        assert 'resource "aws_lambda_permission"' in hcl
        assert 'resource "aws_s3_bucket_notification"' in hcl
        # statement_id now includes bucket label for uniqueness across multiple sources
        assert "AllowS3-" in hcl

    def test_statement_id_length_capped(self):
        """statement_id in aws_lambda_permission must never exceed 100 chars."""
        req = PipelineRequest(
            pipeline_name="traffic_collision_analytics_visualization_pipeline",
            business_unit="engineering",
            cost_center="cc001",
            services=[
                ServiceSpec(name="traffic_collision_raw", type="s3"),
                ServiceSpec(name="collision_preprocessor", type="lambda"),
                ServiceSpec(name="victim_preprocessor", type="lambda"),
            ],
            integrations=[
                {"source": "traffic_collision_raw", "target": "collision_preprocessor",
                 "event": "s3:ObjectCreated:*"},
                {"source": "traffic_collision_raw", "target": "victim_preprocessor",
                 "event": "s3:ObjectCreated:*"},
            ],
        )
        result = build_pipeline(req, run_terraform=False)
        # Extract all statement_id values from the HCL
        import re
        sids = re.findall(r'statement_id\s*=\s*"([^"]+)"', result.main_tf)
        for sid in sids:
            assert len(sid) <= 100, f"statement_id too long ({len(sid)} chars): {sid}"

    def test_target_id_length_and_uniqueness(self):
        """target_id in aws_cloudwatch_event_target must be <=64 chars and unique per rule."""
        req = PipelineRequest(
            pipeline_name="traffic_collision_analytics_visualization_pipeline",
            business_unit="engineering",
            cost_center="cc001",
            services=[
                ServiceSpec(name="traffic_collision_raw", type="s3"),
                ServiceSpec(name="collision_preprocessor", type="lambda"),
                ServiceSpec(name="victim_preprocessor", type="lambda"),
                ServiceSpec(name="party_preprocessor", type="lambda"),
                ServiceSpec(name="case_preprocessor", type="lambda"),
            ],
            integrations=[
                {"source": "traffic_collision_raw", "target": "collision_preprocessor",
                 "event": "s3:ObjectCreated:*"},
                {"source": "traffic_collision_raw", "target": "victim_preprocessor",
                 "event": "s3:ObjectCreated:*"},
                {"source": "traffic_collision_raw", "target": "party_preprocessor",
                 "event": "s3:ObjectCreated:*"},
                {"source": "traffic_collision_raw", "target": "case_preprocessor",
                 "event": "s3:ObjectCreated:*"},
            ],
        )
        result = build_pipeline(req, run_terraform=False)
        import re
        tids = re.findall(r'target_id\s*=\s*"([^"]+)"', result.main_tf)
        for tid in tids:
            assert len(tid) <= 64, f"target_id too long ({len(tid)} chars): {tid}"
        # All target_ids must be unique (this was the ConcurrentModificationException bug)
        assert len(tids) == len(set(tids)), f"Duplicate target_ids found: {tids}"

    def test_s3_multi_lambda_single_notification(self):
        """One S3 bucket → two Lambdas must produce exactly one notification resource."""
        req = PipelineRequest(
            pipeline_name="multi",
            business_unit="eng",
            cost_center="cc001",
            services=[
                ServiceSpec(name="src",    type="s3"),
                ServiceSpec(name="fn_a",   type="lambda"),
                ServiceSpec(name="fn_b",   type="lambda"),
            ],
            integrations=[
                {"source": "src", "target": "fn_a", "event": "s3:ObjectCreated:*"},
                {"source": "src", "target": "fn_b", "event": "s3:ObjectCreated:*"},
            ],
        )
        bp = build_blueprint(req.services[0], req)
        hcl = render(bp, req)

        # Exactly one notification resource (not two)
        assert hcl.count('resource "aws_s3_bucket_notification"') == 1

        # Overlap detected → EventBridge fan-out path
        assert "eventbridge = true" in hcl
        assert 'resource "aws_cloudwatch_event_rule"' in hcl

        # Both lambda targets wired as EventBridge targets
        assert "fn_a" in hcl
        assert "fn_b" in hcl

        # Two separate lambda permissions (one per target, EventBridge principal)
        assert hcl.count('resource "aws_lambda_permission"') == 2
        assert "events.amazonaws.com" in hcl

        # Full pipeline must also be lint-clean
        result = build_pipeline(req, run_terraform=False)
        hard = [e for e in result.lint_errors if e.severity == "error"]
        assert hard == [], f"Full pipeline lint errors: {[e.format() for e in hard]}"

    def test_tags_in_rendered_hcl(self, simple_request):
        bp = build_blueprint(simple_request.services[0], simple_request)
        hcl = render(bp, simple_request)
        assert "Pipeline" in hcl
        assert "ManagedBy" in hcl
        assert "aws-pipeline-engine" in hcl


# ---------------------------------------------------------------------------
# Linting
# ---------------------------------------------------------------------------

class TestLinter:
    def test_clean_hcl_no_errors(self, simple_request):
        result = build_pipeline(simple_request, run_terraform=False)
        hard = [e for e in result.lint_errors if e.severity == "error"]
        assert hard == [], f"Unexpected errors: {[e.format() for e in hard]}"

    def test_catches_undeclared_reference(self):
        broken = '''
resource "aws_lambda_function" "my_fn" {
  function_name = "fn"
  role = aws_iam_role.nonexistent_role.arn
  tags = { Pipeline = "x", BusinessUnit = "x", CostCenter = "x", ManagedBy = "x" }
}
'''
        errors = lint_hcl(broken)
        refs = [e for e in errors if e.code == "REF"]
        assert len(refs) >= 1
        assert "nonexistent_role" in refs[0].message

    def test_catches_duplicate(self):
        duped = '''
resource "aws_s3_bucket" "my_bucket" { bucket = "a" }
resource "aws_s3_bucket" "my_bucket" { bucket = "b" }
'''
        errors = lint_hcl(duped)
        dups = [e for e in errors if e.code == "DUPLICATE"]
        assert len(dups) == 1


# ---------------------------------------------------------------------------
# End-to-end pipeline building
# ---------------------------------------------------------------------------

class TestPipelineBuilder:
    def test_simple_pipeline_produces_valid_hcl(self, simple_request):
        result = build_pipeline(simple_request, run_terraform=False)
        assert result.main_tf is not None
        assert len(result.main_tf) > 100
        assert 'terraform {' in result.main_tf
        assert 'provider "aws"' in result.main_tf

    def test_simple_pipeline_no_lint_errors(self, simple_request):
        result = build_pipeline(simple_request, run_terraform=False)
        hard = [e for e in result.lint_errors if e.severity == "error"]
        assert hard == []

    def test_complex_pipeline_15_services(self, complex_request):
        result = build_pipeline(complex_request, run_terraform=False)
        assert result.main_tf is not None
        hard = [e for e in result.lint_errors if e.severity == "error"]
        assert hard == [], f"Lint errors: {[e.format() for e in hard]}"
        # Verify all 15 services are represented
        for svc in complex_request.services:
            assert svc.name in result.blueprints

    def test_output_writes_to_disk(self, simple_request, tmp_path):
        result = build_pipeline(simple_request, output_dir=tmp_path, run_terraform=False)
        assert result.main_tf_path is not None
        assert result.main_tf_path.exists()
        content = result.main_tf_path.read_text()
        assert 'resource "aws_s3_bucket"' in content

    def test_all_services_in_all_examples(self):
        """Verify every example YAML builds without errors."""
        examples_dir = Path(__file__).parent.parent / "examples"
        for yaml_path in sorted(examples_dir.glob("*.yaml")):
            raw = yaml.safe_load(yaml_path.read_text())
            req = PipelineRequest.model_validate(raw)
            result = build_pipeline(req, run_terraform=False)
            hard = [e for e in result.lint_errors if e.severity == "error"]
            assert hard == [], f"{yaml_path.name} has lint errors: {[e.format() for e in hard]}"

    def test_validation_errors_in_result(self, simple_request):
        """PipelineResult includes validation_errors field."""
        result = build_pipeline(simple_request, run_terraform=False)
        assert hasattr(result, "validation_errors")
        assert isinstance(result.validation_errors, list)


# ---------------------------------------------------------------------------
# VPC data source injection (Layer 3)
# ---------------------------------------------------------------------------

class TestVpcDataSourceInjection:
    def test_vpc_data_sources_injected_for_aurora(self):
        """Aurora always needs VPC data sources — they must appear in generated HCL."""
        req = PipelineRequest(
            pipeline_name="test_vpc",
            business_unit="ops",
            cost_center="cc001",
            services=[ServiceSpec(name="db", type="aurora")],
        )
        result = build_pipeline(req, run_terraform=False)
        assert 'data "aws_vpc" "default"' in result.main_tf
        assert 'data "aws_subnets" "default"' in result.main_tf

    def test_vpc_data_sources_injected_for_msk(self):
        req = PipelineRequest(
            pipeline_name="test_msk",
            business_unit="ops",
            cost_center="cc001",
            services=[ServiceSpec(name="cluster", type="msk")],
        )
        result = build_pipeline(req, run_terraform=False)
        assert 'data "aws_vpc" "default"' in result.main_tf

    def test_vpc_data_sources_injected_for_dms(self):
        req = PipelineRequest(
            pipeline_name="test_dms",
            business_unit="ops",
            cost_center="cc001",
            services=[ServiceSpec(name="repl", type="dms")],
        )
        result = build_pipeline(req, run_terraform=False)
        assert 'data "aws_vpc" "default"' in result.main_tf

    def test_vpc_data_sources_injected_for_vpc_lambda(self):
        """Lambda in VPC (via redshift peer) gets VPC data sources."""
        req = PipelineRequest(
            pipeline_name="test_vpc_lambda",
            business_unit="ops",
            cost_center="cc001",
            services=[
                ServiceSpec(name="fn", type="lambda"),
                ServiceSpec(name="dw", type="redshift"),
            ],
            integrations=[
                {"source": "fn", "target": "dw", "event": "query"},
            ],
        )
        result = build_pipeline(req, run_terraform=False)
        assert 'data "aws_vpc" "default"' in result.main_tf
        assert 'data "aws_subnets" "default"' in result.main_tf

    def test_no_vpc_data_sources_when_not_needed(self):
        """Simple S3+Lambda pipeline should NOT get VPC data sources."""
        req = PipelineRequest(
            pipeline_name="simple",
            business_unit="ops",
            cost_center="cc001",
            services=[
                ServiceSpec(name="bucket", type="s3"),
                ServiceSpec(name="fn", type="lambda"),
            ],
            integrations=[
                {"source": "bucket", "target": "fn", "event": "s3:ObjectCreated:*"},
            ],
        )
        result = build_pipeline(req, run_terraform=False)
        assert 'data "aws_vpc" "default"' not in result.main_tf

    def test_vpc_pipelines_lint_clean(self):
        """Pipelines with VPC services should pass lint (no undeclared data refs)."""
        req = PipelineRequest(
            pipeline_name="vpc_lint",
            business_unit="ops",
            cost_center="cc001",
            services=[
                ServiceSpec(name="db", type="aurora"),
                ServiceSpec(name="fn", type="lambda"),
            ],
            integrations=[
                {"source": "fn", "target": "db", "event": "query"},
            ],
        )
        result = build_pipeline(req, run_terraform=False)
        hard = [e for e in result.lint_errors if e.severity == "error"]
        assert hard == [], f"VPC pipeline lint errors: {[e.format() for e in hard]}"


# ---------------------------------------------------------------------------
# Config validation (Layer 1)
# ---------------------------------------------------------------------------

class TestConfigValidator:
    def test_dynamodb_billing_conflict_detected(self):
        """PAY_PER_REQUEST + read_capacity should produce a validation error."""
        req = PipelineRequest(
            pipeline_name="test",
            business_unit="ops",
            cost_center="cc001",
            services=[ServiceSpec(name="table", type="dynamodb", config={
                "billing_mode": "PAY_PER_REQUEST",
                "read_capacity": 5,
            })],
        )
        bp = build_blueprint(req.services[0], req)
        errors = validate_blueprint(bp)
        assert any(e.rule == "DYNAMO_BILLING_CONFLICT" for e in errors)

    def test_dynamodb_provisioned_ok(self):
        req = PipelineRequest(
            pipeline_name="test",
            business_unit="ops",
            cost_center="cc001",
            services=[ServiceSpec(name="table", type="dynamodb")],
        )
        bp = build_blueprint(req.services[0], req)
        errors = validate_blueprint(bp)
        assert not any(e.rule.startswith("DYNAMO_") for e in errors)

    def test_emr_serverless_capacity_exceeds_max(self):
        req = PipelineRequest(
            pipeline_name="test",
            business_unit="ops",
            cost_center="cc001",
            services=[ServiceSpec(name="app", type="emr_serverless", config={
                "initial_capacity_driver_cpu": "2vCPU",
                "initial_capacity_executor_cpu": "4vCPU",
                "initial_capacity_executor_count": 1,
                "max_cpu": "4vCPU",
            })],
        )
        bp = build_blueprint(req.services[0], req)
        errors = validate_blueprint(bp)
        assert any(e.rule == "EMR_CAPACITY_EXCEEDS_MAX" for e in errors)

    def test_emr_serverless_valid_config_ok(self):
        req = PipelineRequest(
            pipeline_name="test",
            business_unit="ops",
            cost_center="cc001",
            services=[ServiceSpec(name="app", type="emr_serverless")],
        )
        bp = build_blueprint(req.services[0], req)
        errors = validate_blueprint(bp)
        hard = [e for e in errors if e.severity == "error"]
        assert hard == []

    def test_lambda_memory_too_low(self):
        req = PipelineRequest(
            pipeline_name="test",
            business_unit="ops",
            cost_center="cc001",
            services=[ServiceSpec(name="fn", type="lambda", config={"memory_size": 64})],
        )
        bp = build_blueprint(req.services[0], req)
        errors = validate_blueprint(bp)
        assert any(e.rule == "LAMBDA_MEMORY_TOO_LOW" for e in errors)

    def test_lambda_timeout_too_high(self):
        req = PipelineRequest(
            pipeline_name="test",
            business_unit="ops",
            cost_center="cc001",
            services=[ServiceSpec(name="fn", type="lambda", config={"timeout": 1200})],
        )
        bp = build_blueprint(req.services[0], req)
        errors = validate_blueprint(bp)
        assert any(e.rule == "LAMBDA_TIMEOUT_TOO_HIGH" for e in errors)

    def test_sagemaker_invalid_instance_type(self):
        req = PipelineRequest(
            pipeline_name="test",
            business_unit="ops",
            cost_center="cc001",
            services=[ServiceSpec(name="ep", type="sagemaker", config={
                "instance_type": "t2.medium",  # missing ml. prefix
            })],
        )
        bp = build_blueprint(req.services[0], req)
        errors = validate_blueprint(bp)
        assert any(e.rule == "SAGEMAKER_INVALID_INSTANCE" for e in errors)

    def test_kinesis_invalid_retention(self):
        req = PipelineRequest(
            pipeline_name="test",
            business_unit="ops",
            cost_center="cc001",
            services=[ServiceSpec(name="stream", type="kinesis_streams", config={
                "retention_period": 12,  # min is 24
            })],
        )
        bp = build_blueprint(req.services[0], req)
        errors = validate_blueprint(bp)
        assert any(e.rule == "KINESIS_RETENTION_LOW" for e in errors)

    def test_validation_errors_surfaced_in_pipeline_result(self):
        """build_pipeline should include validation errors in the result."""
        req = PipelineRequest(
            pipeline_name="test",
            business_unit="ops",
            cost_center="cc001",
            services=[ServiceSpec(name="table", type="dynamodb", config={
                "billing_mode": "PAY_PER_REQUEST",
                "read_capacity": 5,
            })],
        )
        result = build_pipeline(req, run_terraform=False)
        assert any(e.rule == "DYNAMO_BILLING_CONFLICT" for e in result.validation_errors)


# ---------------------------------------------------------------------------
# Enhanced linter (Layer 2)
# ---------------------------------------------------------------------------

class TestEnhancedLinter:
    def test_catches_undeclared_data_source(self):
        """Linter should error when a data source is referenced but not declared."""
        hcl = '''
resource "aws_lambda_function" "fn" {
  subnet_ids = data.aws_subnets.default.ids
  tags = { Pipeline = "x", BusinessUnit = "x", CostCenter = "x", ManagedBy = "x" }
}
'''
        errors = lint_hcl(hcl)
        data_errors = [e for e in errors if e.code == "UNDECLARED_DATA"]
        assert len(data_errors) >= 1
        assert "data.aws_subnets.default" in data_errors[0].message

    def test_declared_data_source_no_error(self):
        """No error when data source is both declared and referenced."""
        hcl = '''
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_db_subnet_group" "grp" {
  name       = "grp"
  subnet_ids = data.aws_subnets.default.ids
  tags = { Pipeline = "x", BusinessUnit = "x", CostCenter = "x", ManagedBy = "x" }
}
'''
        errors = lint_hcl(hcl)
        data_errors = [e for e in errors if e.code == "UNDECLARED_DATA"]
        assert data_errors == []

    def test_dynamodb_billing_conflict_in_linter(self):
        """Linter catches PAY_PER_REQUEST + capacity at the HCL level too."""
        hcl = '''
resource "aws_dynamodb_table" "tbl" {
  name         = "tbl"
  billing_mode = "PAY_PER_REQUEST"
  read_capacity = 5
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
  tags = { Pipeline = "x", BusinessUnit = "x", CostCenter = "x", ManagedBy = "x" }
}
'''
        errors = lint_hcl(hcl)
        billing_errors = [e for e in errors if e.code == "DYNAMO_BILLING_CONFLICT"]
        assert len(billing_errors) == 1


# ---------------------------------------------------------------------------
# Integration completeness (Layer 4)
# ---------------------------------------------------------------------------

class TestIntegrationCompleteness:
    def test_warns_on_missing_iam_rule(self, caplog):
        """When a principal connects to a peer with no spec rule, a warning is logged."""
        req = PipelineRequest(
            pipeline_name="test",
            business_unit="ops",
            cost_center="cc001",
            services=[
                ServiceSpec(name="fn", type="lambda"),
                ServiceSpec(name="catalog", type="glue_data_catalog"),
            ],
            integrations=[
                {"source": "fn", "target": "catalog", "event": "write"},
            ],
        )
        import logging
        with caplog.at_level(logging.WARNING, logger="engine.spec_builder"):
            build_blueprint(req.services[0], req)
        assert any("no IAM rule" in msg for msg in caplog.messages)

    def test_sagemaker_invalid_framework_detected(self):
        req = PipelineRequest(
            pipeline_name="test",
            business_unit="ops",
            cost_center="cc001",
            services=[ServiceSpec(name="ep", type="sagemaker", config={
                "framework": "sklearn",  # wrong — should be sagemaker-scikit-learn
            })],
        )
        bp = build_blueprint(req.services[0], req)
        errors = validate_blueprint(bp)
        assert any(e.rule == "SAGEMAKER_INVALID_FRAMEWORK" for e in errors)

    def test_sagemaker_valid_framework_ok(self):
        req = PipelineRequest(
            pipeline_name="test",
            business_unit="ops",
            cost_center="cc001",
            services=[ServiceSpec(name="ep", type="sagemaker")],
        )
        bp = build_blueprint(req.services[0], req)
        errors = validate_blueprint(bp)
        assert not any(e.rule == "SAGEMAKER_INVALID_FRAMEWORK" for e in errors)

    def test_no_warning_for_covered_integration(self, caplog):
        """S3 → Lambda is fully covered in specs, no warning expected."""
        req = PipelineRequest(
            pipeline_name="test",
            business_unit="ops",
            cost_center="cc001",
            services=[
                ServiceSpec(name="bucket", type="s3"),
                ServiceSpec(name="fn", type="lambda"),
            ],
            integrations=[
                {"source": "bucket", "target": "fn", "event": "s3:ObjectCreated:*"},
            ],
        )
        import logging
        with caplog.at_level(logging.WARNING, logger="engine.spec_builder"):
            build_blueprint(req.services[1], req)  # Lambda is the principal
        assert not any("no IAM rule" in msg for msg in caplog.messages)


# ---------------------------------------------------------------------------
# Config Registry
# ---------------------------------------------------------------------------

from engine.config_registry import (
    SUPPORTED_CONFIG,
    get_supported_keys,
    get_supported_key_names,
    validate_config_patch,
    ConfigKeyInfo,
)


class TestConfigRegistry:
    """Validates the config registry matches actual renderer cfg.get() calls."""

    def test_all_renderer_types_have_registry_entries(self):
        """Every type that has a renderer should have a registry entry."""
        for stype in supported_types():
            assert stype in SUPPORTED_CONFIG, (
                f"Service type '{stype}' has a renderer but no SUPPORTED_CONFIG entry"
            )

    def test_registry_keys_are_config_key_info(self):
        """Every entry should be a list of ConfigKeyInfo."""
        for stype, keys in SUPPORTED_CONFIG.items():
            assert isinstance(keys, list), f"{stype} should map to a list"
            for k in keys:
                assert isinstance(k, ConfigKeyInfo), f"{stype}.{k} should be ConfigKeyInfo"

    def test_get_supported_keys(self):
        keys = get_supported_keys("lambda")
        assert len(keys) >= 4
        key_names = {k.key for k in keys}
        assert "runtime" in key_names
        assert "memory_size" in key_names
        assert "timeout" in key_names
        assert "handler" in key_names

    def test_get_supported_key_names(self):
        names = get_supported_key_names("s3")
        assert "versioning_status" in names

    def test_validate_config_patch_valid(self):
        patch = {"memory_size": 512, "timeout": 60}
        clean, warnings = validate_config_patch("lambda", patch)
        assert clean == {"memory_size": 512, "timeout": 60}
        assert warnings == []

    def test_validate_config_patch_unknown_key(self):
        patch = {"nonexistent_key": "value"}
        clean, warnings = validate_config_patch("lambda", patch)
        assert clean == {}
        assert len(warnings) == 1
        assert "not supported" in warnings[0]

    def test_validate_config_patch_type_coercion(self):
        patch = {"memory_size": "512"}
        clean, warnings = validate_config_patch("lambda", patch)
        assert clean == {"memory_size": 512}

    def test_validate_config_patch_out_of_range(self):
        patch = {"memory_size": 999999}
        clean, warnings = validate_config_patch("lambda", patch)
        assert clean == {}
        assert len(warnings) == 1
        assert "exceeds maximum" in warnings[0]

    def test_validate_config_patch_invalid_allowed_value(self):
        patch = {"versioning_status": "InvalidValue"}
        clean, warnings = validate_config_patch("s3", patch)
        assert clean == {}
        assert len(warnings) == 1
        assert "not allowed" in warnings[0]

    def test_empty_service_types_have_empty_lists(self):
        """Services with no config keys should have empty lists, not missing."""
        for stype in ["sns", "glue", "lake_formation", "glue_databrew"]:
            assert stype in SUPPORTED_CONFIG
            assert SUPPORTED_CONFIG[stype] == []


# ---------------------------------------------------------------------------
# Feature Index
# ---------------------------------------------------------------------------

from engine.spec_index import FeatureIndex, ConfigResolution


class TestFeatureIndex:
    """Tests for the feature index and Tier 0 resolver."""

    @pytest.fixture(scope="class")
    def index(self):
        return FeatureIndex()

    def test_index_builds_entries(self, index):
        """Index should have entries from specs_new/."""
        assert index.total_entries > 0

    def test_index_covers_multiple_types(self, index):
        """Index should cover multiple service types."""
        assert len(index.indexed_service_types) > 10

    def test_lambda_features_indexed(self, index):
        entries = index.get_entries_for_service("lambda")
        keys = {e.config_key for e in entries}
        assert "runtime" in keys
        assert "memory_size" in keys
        assert "timeout" in keys

    def test_s3_features_indexed(self, index):
        entries = index.get_entries_for_service("s3")
        keys = {e.config_key for e in entries}
        assert "versioning_status" in keys

    def test_dynamodb_features_indexed(self, index):
        entries = index.get_entries_for_service("dynamodb")
        keys = {e.config_key for e in entries}
        assert "billing_mode" in keys

    # ── Tier 0 resolution tests ──────────────────────────────────

    def test_resolve_enable_versioning(self, index):
        services = [{"name": "bucket", "type": "s3", "config": {}}]
        res = index.resolve_tier0("enable versioning", "s3", "bucket", services)
        assert res is not None
        assert res.config_patch == {"versioning_status": "Enabled"}
        assert res.tier == 0
        assert res.service_name == "bucket"

    def test_resolve_set_memory(self, index):
        services = [{"name": "fn", "type": "lambda", "config": {}}]
        res = index.resolve_tier0("set memory to 512", "lambda", "fn", services)
        assert res is not None
        assert res.config_patch == {"memory_size": 512}
        assert res.tier == 0

    def test_resolve_set_timeout(self, index):
        services = [{"name": "fn", "type": "lambda", "config": {}}]
        res = index.resolve_tier0("change timeout to 60", "lambda", "fn", services)
        assert res is not None
        assert res.config_patch == {"timeout": 60}

    def test_resolve_billing_mode(self, index):
        services = [{"name": "table", "type": "dynamodb", "config": {}}]
        res = index.resolve_tier0(
            "switch to on-demand billing", "dynamodb", "table", services
        )
        assert res is not None
        assert res.config_patch == {"billing_mode": "PAY_PER_REQUEST"}

    def test_resolve_returns_none_for_gibberish(self, index):
        services = [{"name": "fn", "type": "lambda", "config": {}}]
        res = index.resolve_tier0("xyzzy plugh", "lambda", "fn", services)
        assert res is None

    def test_resolve_auto_detects_single_service(self, index):
        services = [{"name": "my_bucket", "type": "s3", "config": {}}]
        res = index.resolve_tier0(
            "enable versioning", "s3", None, services
        )
        assert res is not None
        assert res.service_name == "my_bucket"

    def test_resolve_returns_none_ambiguous_services(self, index):
        """With multiple S3 buckets and no service_name, should return None."""
        services = [
            {"name": "a", "type": "s3", "config": {}},
            {"name": "b", "type": "s3", "config": {}},
        ]
        res = index.resolve_tier0(
            "enable versioning", "s3", None, services
        )
        assert res is None

    # ── Template tests ───────────────────────────────────────────

    def test_lambda_templates_loaded(self, index):
        templates = index.get_templates("lambda")
        assert len(templates) > 0
        names = {t["id"] for t in templates}
        assert "high_memory" in names

    def test_s3_templates_loaded(self, index):
        templates = index.get_templates("s3")
        assert len(templates) > 0

    # ── Spec section extraction ──────────────────────────────────

    def test_get_relevant_sections(self, index):
        sections = index.get_relevant_sections("s3", ["versioning"])
        assert "identity" in sections  # always included
        assert "defaults" in sections  # always included
        assert len(sections) > 50  # should have meaningful content

    def test_get_relevant_sections_lambda(self, index):
        sections = index.get_relevant_sections("lambda", ["concurrency"])
        assert len(sections) > 50


# ---------------------------------------------------------------------------
# Config Resolution end-to-end
# ---------------------------------------------------------------------------

class TestConfigResolution:
    """End-to-end tests: resolve config → validate → merge → render."""

    @pytest.fixture(scope="class")
    def index(self):
        return FeatureIndex()

    def test_versioning_patch_renders_different_hcl(self, simple_request):
        """Applying versioning=Enabled produces different HCL than default."""
        from engine.hcl_renderer import render

        # Default rendering
        bp_default = build_blueprint(simple_request.services[0], simple_request)
        hcl_default = render(bp_default, simple_request)

        # With versioning enabled
        modified = simple_request.model_copy(deep=True)
        modified.services[0].config["versioning_status"] = "Enabled"
        bp_modified = build_blueprint(modified.services[0], modified)
        hcl_modified = render(bp_modified, modified)

        assert 'status = "Enabled"' in hcl_modified
        assert 'status = "Suspended"' in hcl_default
        assert hcl_default != hcl_modified

    def test_memory_patch_renders_different_hcl(self, simple_request):
        """Applying memory_size=1024 produces different HCL than default."""
        from engine.hcl_renderer import render

        bp_default = build_blueprint(simple_request.services[1], simple_request)
        hcl_default = render(bp_default, simple_request)

        modified = simple_request.model_copy(deep=True)
        modified.services[1].config["memory_size"] = 1024
        bp_modified = build_blueprint(modified.services[1], modified)
        hcl_modified = render(bp_modified, modified)

        assert "memory_size" in hcl_modified and "1024" in hcl_modified
        assert "memory_size" in hcl_default and "128" in hcl_default

    def test_full_tier0_to_render(self, index, simple_request):
        """Full flow: Tier 0 resolve → validate → merge → render."""
        from engine.hcl_renderer import render

        services = [
            {"name": s.name, "type": s.type, "config": dict(s.config)}
            for s in simple_request.services
        ]

        # Resolve
        res = index.resolve_tier0("set timeout to 120", "lambda", "processor", services)
        assert res is not None
        assert res.config_patch == {"timeout": 120}

        # Merge and render
        modified = simple_request.model_copy(deep=True)
        for svc in modified.services:
            if svc.name == res.service_name:
                svc.config.update(res.config_patch)
                break
        bp = build_blueprint(
            next(s for s in modified.services if s.name == "processor"),
            modified,
        )
        hcl = render(bp, modified)
        assert "timeout" in hcl and "120" in hcl


# ---------------------------------------------------------------------------
# Pipeline Builder Agent (offline tests — no LLM calls)
# ---------------------------------------------------------------------------

class TestPipelineBuilderAgent:
    """Tests for the pipeline builder agent's prompt and YAML parsing."""

    def test_prompt_file_exists(self):
        prompt_path = Path(__file__).resolve().parent.parent / "prompts" / "pipeline_builder.md"
        assert prompt_path.exists(), "Pipeline builder prompt must exist"

    def test_prompt_contains_service_types(self):
        prompt_path = Path(__file__).resolve().parent.parent / "prompts" / "pipeline_builder.md"
        text = prompt_path.read_text()
        for stype in ["s3", "lambda", "sqs", "dynamodb", "stepfunctions", "glue",
                       "cloudwatch", "sns", "kinesis_streams", "eventbridge", "ec2"]:
            assert stype in text, f"Prompt should mention '{stype}'"

    def test_prompt_contains_integration_events(self):
        prompt_path = Path(__file__).resolve().parent.parent / "prompts" / "pipeline_builder.md"
        text = prompt_path.read_text()
        for event in ["s3:ObjectCreated:*", "sqs_trigger", "send_message",
                       "invoke", "start_execution", "scheduled_event"]:
            assert event in text, f"Prompt should mention event '{event}'"

    def test_prompt_mentions_prefix(self):
        prompt_path = Path(__file__).resolve().parent.parent / "prompts" / "pipeline_builder.md"
        text = prompt_path.read_text()
        assert "prefix" in text, "Prompt should explain prefix-based triggers"

    def test_strip_fences(self):
        from agents.pipeline_builder_agent import _strip_fences
        yaml_text = "pipeline_name: test\nservices:\n  - name: s3_1\n    type: s3"
        fenced = f"```yaml\n{yaml_text}\n```"
        assert _strip_fences(fenced) == yaml_text

    def test_agent_module_importable(self):
        from agents.pipeline_builder_agent import PipelineBuilderAgent
        assert PipelineBuilderAgent is not None

    def test_sample_yaml_validates(self):
        """Verify that the kind of YAML the agent should produce passes validation."""
        yaml_text = """
pipeline_name: prefix_trigger_pipeline
business_unit: engineering
cost_center: cc001
region: us-east-1
services:
  - name: source_bucket
    type: s3
  - name: case_processor
    type: lambda
    config:
      runtime: python3.12
      handler: index.handler
      memory_size: 128
      timeout: 30
  - name: party_processor
    type: lambda
    config:
      runtime: python3.12
      handler: index.handler
      memory_size: 128
      timeout: 30
  - name: target_bucket
    type: s3
integrations:
  - source: source_bucket
    target: case_processor
    event: "s3:ObjectCreated:*"
    prefix: "case/"
  - source: source_bucket
    target: party_processor
    event: "s3:ObjectCreated:*"
    prefix: "party/"
  - source: case_processor
    target: target_bucket
    event: put_object
  - source: party_processor
    target: target_bucket
    event: put_object
"""
        parsed = yaml.safe_load(yaml_text)
        req = PipelineRequest.model_validate(parsed)
        assert req.pipeline_name == "prefix_trigger_pipeline"
        assert len(req.services) == 4
        assert len(req.integrations) == 4

    def test_sample_yaml_builds_pipeline(self, tmp_path):
        """End-to-end: sample YAML the agent would produce → build_pipeline succeeds."""
        yaml_text = """
pipeline_name: agent_test_pipeline
services:
  - name: ingest_bucket
    type: s3
  - name: processor
    type: lambda
    config:
      runtime: python3.12
      handler: index.handler
      memory_size: 256
      timeout: 60
  - name: output_bucket
    type: s3
integrations:
  - source: ingest_bucket
    target: processor
    event: "s3:ObjectCreated:*"
  - source: processor
    target: output_bucket
    event: put_object
"""
        parsed = yaml.safe_load(yaml_text)
        req = PipelineRequest.model_validate(parsed)
        result = build_pipeline(req, tmp_path / "output", False)
        assert result.main_tf_path is not None
        hcl = Path(result.main_tf_path).read_text()
        assert "aws_s3_bucket" in hcl
        assert "aws_lambda_function" in hcl


# ---------------------------------------------------------------------------
# Sub-component renderer
# ---------------------------------------------------------------------------

class TestSubComponentRenderer:
    """Tests for the generic, spec-driven sub-component renderer."""

    def _build_bp(self, name, stype, config, tmp_path):
        """Helper: build a ServiceBlueprint with the given config."""
        req = PipelineRequest(
            pipeline_name="sc_test",
            services=[{"name": name, "type": stype, "config": config}],
            integrations=[],
        )
        return build_blueprint(req.services[0], req), req

    def test_s3_prefixes_create_objects(self, tmp_path):
        bp, req = self._build_bp("bkt", "s3", {"prefixes": ["raw/", "staging/"]}, tmp_path)
        hcl = render(bp, req)
        assert 'resource "aws_s3_object"' in hcl
        assert '"raw/"' in hcl
        assert '"staging/"' in hcl
        assert hcl.count('resource "aws_s3_object"') == 2

    def test_glue_table_renders(self, tmp_path):
        bp, req = self._build_bp("mydb", "glue_data_catalog", {
            "tables": [{
                "name": "events",
                "location": "s3://bucket/events/",
                "columns": [{"name": "id", "type": "string"}, {"name": "ts", "type": "bigint"}],
            }]
        }, tmp_path)
        hcl = render(bp, req)
        assert 'resource "aws_glue_catalog_table"' in hcl
        assert 'name = "events"' in hcl
        assert 'location = "s3://bucket/events/"' in hcl
        assert 'name = "id"' in hcl
        assert 'type = "bigint"' in hcl

    def test_glue_multiple_tables(self, tmp_path):
        bp, req = self._build_bp("db", "glue_data_catalog", {
            "tables": [
                {"name": "t1", "location": "s3://b/t1/", "columns": [{"name": "a", "type": "string"}]},
                {"name": "t2", "location": "s3://b/t2/", "columns": [{"name": "b", "type": "int"}]},
                {"name": "t3", "location": "s3://b/t3/", "columns": [{"name": "c", "type": "double"}]},
            ]
        }, tmp_path)
        hcl = render(bp, req)
        assert hcl.count('resource "aws_glue_catalog_table"') == 3

    def test_athena_named_query(self, tmp_path):
        bp, req = self._build_bp("qe", "athena", {
            "named_queries": [{"name": "q1", "database": "mydb", "query": "SELECT 1"}]
        }, tmp_path)
        hcl = render(bp, req)
        assert 'resource "aws_athena_named_query"' in hcl
        assert 'name = "q1"' in hcl
        assert 'database = "mydb"' in hcl
        assert 'query = "SELECT 1"' in hcl

    def test_no_sub_components_unchanged(self, tmp_path):
        """Services without sub-component config produce same HCL as before."""
        bp, req = self._build_bp("plain", "s3", {}, tmp_path)
        hcl = render(bp, req)
        assert 'resource "aws_s3_object"' not in hcl
        assert 'resource "aws_s3_bucket"' in hcl

    def test_lambda_handler_code(self, tmp_path):
        bp, req = self._build_bp("fn", "lambda", {
            "handler_code": "def handler(event, context):\n    print('hello')"
        }, tmp_path)
        hcl = render(bp, req)
        assert "hello" in hcl
        assert "aws_lambda_function" in hcl

    def test_lambda_default_placeholder(self, tmp_path):
        bp, req = self._build_bp("fn", "lambda", {}, tmp_path)
        hcl = render(bp, req)
        assert "statusCode" in hcl

    def test_full_pipeline_with_sub_components_lint_clean(self, tmp_path):
        """End-to-end: pipeline with sub-components passes linter."""
        req = PipelineRequest(
            pipeline_name="full_sc",
            services=[
                {"name": "src", "type": "s3", "config": {
                    "prefixes": ["case/", "victim/"]
                }},
                {"name": "proc", "type": "lambda", "config": {
                    "handler_code": "def handler(e, c):\n    return {'ok': True}"
                }},
                {"name": "catalog", "type": "glue_data_catalog", "config": {
                    "tables": [{
                        "name": "case_data",
                        "location": "s3://src/case/",
                        "columns": [{"name": "id", "type": "string"}],
                    }]
                }},
                {"name": "qe", "type": "athena", "config": {
                    "named_queries": [{
                        "name": "all_cases",
                        "database": "catalog",
                        "query": "SELECT * FROM case_data",
                    }]
                }},
            ],
            integrations=[
                {"source": "src", "target": "proc", "event": "s3:ObjectCreated:*"},
            ],
        )
        result = build_pipeline(req, tmp_path / "full_sc_out", False)
        assert result.main_tf_path is not None
        hcl = Path(result.main_tf_path).read_text()
        # All sub-component resources present
        assert 'resource "aws_s3_object"' in hcl
        assert 'resource "aws_glue_catalog_table"' in hcl
        assert 'resource "aws_athena_named_query"' in hcl
        assert "hello" not in hcl  # custom code only on proc
        assert "ok" in hcl  # proc has custom handler
        # Lint clean
        assert len([e for e in result.lint_errors if e.severity == "error"]) == 0
