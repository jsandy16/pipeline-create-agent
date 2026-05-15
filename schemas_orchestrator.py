"""Typed data models for the multi-agent orchestration system.

Extends the core schemas with orchestration-specific models for
requirement analysis, application code generation, data modeling,
and operations configuration.
"""
from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class AppCodeTask(BaseModel):
    """A task to generate application code for a specific service."""
    service_name: str
    service_type: str          # lambda, glue, athena, stepfunctions, etc.
    code_type: str             # handler, etl_script, ddl, asl_definition, query
    description: str           # what the code should do
    inputs: list[str] = Field(default_factory=list)
    outputs: list[str] = Field(default_factory=list)
    data_schema: dict[str, Any] = Field(default_factory=dict)
    dependencies: list[str] = Field(default_factory=list)


class DataModelTask(BaseModel):
    """A task to generate data model artifacts (DDL, catalog, docs)."""
    entity_name: str           # e.g., dim_customers, fact_orders
    model_type: str            # dimension, fact, staging, raw, reference
    fields: list[dict[str, Any]] = Field(default_factory=list)
    partitioning: dict[str, Any] = Field(default_factory=dict)
    source_datasets: list[str] = Field(default_factory=list)
    file_format: str = "parquet"
    database_name: str = "curated_db"


class SchedulingConfig(BaseModel):
    """Scheduling configuration extracted from requirements."""
    schedule_expression: str = "rate(1 day)"
    timezone: str = "UTC"
    description: str = ""
    trigger_chain: list[str] = Field(default_factory=list)


class MonitoringConfig(BaseModel):
    """Monitoring and alerting configuration."""
    metrics: list[dict[str, Any]] = Field(default_factory=list)
    alarms: list[dict[str, Any]] = Field(default_factory=list)
    dashboard_widgets: list[dict[str, Any]] = Field(default_factory=list)
    notification_topics: list[str] = Field(default_factory=list)


class ServiceDefinition(BaseModel):
    """A service extracted from requirements analysis."""
    name: str
    type: str
    config: dict[str, Any] = Field(default_factory=dict)
    purpose: str = ""


class IntegrationDefinition(BaseModel):
    """An integration extracted from requirements analysis."""
    source: str
    target: str
    event: str
    prefix: str | None = None
    suffix: str | None = None


class RequirementsPlan(BaseModel):
    """Complete plan produced by RequirementsAnalyzerAgent."""
    pipeline_name: str
    summary: str
    services: list[ServiceDefinition]
    integrations: list[IntegrationDefinition]
    app_code_tasks: list[AppCodeTask] = Field(default_factory=list)
    data_model_tasks: list[DataModelTask] = Field(default_factory=list)
    scheduling: SchedulingConfig = Field(default_factory=SchedulingConfig)
    monitoring: MonitoringConfig = Field(default_factory=MonitoringConfig)
    security_notes: list[str] = Field(default_factory=list)
    s3_structure: dict[str, Any] = Field(default_factory=dict)


class PhaseResult(BaseModel):
    """Result of a single orchestration phase."""
    phase: str                 # analysis, infrastructure, application_code, data_models, operations
    status: str                # pending, running, completed, failed
    message: str = ""
    artifacts: dict[str, str] = Field(default_factory=dict)  # filename -> content
    errors: list[str] = Field(default_factory=list)


class OrchestrationResult(BaseModel):
    """Complete result of the multi-agent orchestration."""
    orchestration_id: str
    pipeline_name: str
    plan: RequirementsPlan
    phases: list[PhaseResult] = Field(default_factory=list)
    pipeline_yaml: str = ""
    diagram: str = ""
    terraform_hcl: str = ""
    app_code: dict[str, str] = Field(default_factory=dict)   # path -> code
    data_models: dict[str, str] = Field(default_factory=dict) # path -> content
    operations: dict[str, str] = Field(default_factory=dict)  # path -> content
    status: str = "pending"    # pending, running, completed, failed
