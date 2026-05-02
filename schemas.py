"""Typed data models for the pipeline engine.

Every inter-component boundary is validated by Pydantic.
No LLM-specific concerns — these are pure data contracts.
"""
from __future__ import annotations

import re
from typing import Any

from pydantic import BaseModel, Field, model_validator


class ServiceSpec(BaseModel):
    """One AWS service instance declared in a pipeline."""
    name: str = Field(..., min_length=1, max_length=64,
                      pattern=r"^[a-zA-Z][a-zA-Z0-9_]*$")
    type: str = Field(..., min_length=1, pattern=r"^[a-z][a-z0-9_]*$")
    config: dict[str, Any] = Field(default_factory=dict)


class IntegrationSpec(BaseModel):
    """A directional wiring between two services."""
    source: str
    target: str
    event: str = Field(..., min_length=1)
    prefix: str | None = None
    suffix: str | None = None

    @model_validator(mode="after")
    def _no_self_loop(self):
        if self.source == self.target:
            raise ValueError(f"Self-loop: {self.source}")
        return self


class PipelineRequest(BaseModel):
    """Top-level input. Validated before any processing."""
    pipeline_name: str = Field(..., min_length=1, max_length=64,
                               pattern=r"^[a-zA-Z][a-zA-Z0-9_]*$")
    business_unit: str = Field(default="engineering", min_length=1, max_length=32,
                               pattern=r"^[a-zA-Z][a-zA-Z0-9_]*$")
    cost_center: str = Field(default="cc001", min_length=1, max_length=32,
                             pattern=r"^[a-zA-Z0-9][a-zA-Z0-9_]*$")
    region: str = Field(default="us-east-1")
    services: list[ServiceSpec] = Field(..., min_length=1)
    integrations: list[IntegrationSpec] = Field(default_factory=list)

    @model_validator(mode="after")
    def _validate_refs(self):
        names = [s.name for s in self.services]
        if len(names) != len(set(names)):
            raise ValueError("Duplicate service names")
        valid = set(names)
        for i, integ in enumerate(self.integrations):
            if integ.source not in valid:
                raise ValueError(f"integrations[{i}].source '{integ.source}' not declared")
            if integ.target not in valid:
                raise ValueError(f"integrations[{i}].target '{integ.target}' not declared")
        return self


class ServiceBlueprint(BaseModel):
    """Computed blueprint for one service instance — deterministic, no LLM.

    Built by spec_builder from the service spec YAML + pipeline integrations.
    Consumed by hcl_renderer to produce the Terraform fragment.
    """
    service_name: str
    service_type: str
    resource_label: str               # terraform identifier (underscores)
    resource_name: str                # AWS resource name (hyphens, length-safe)
    is_principal: bool
    required_configuration: dict[str, Any]
    iam_permissions: list[str]        # computed from integration patterns
    env_vars: dict[str, str]          # name → terraform reference
    vpc_required: bool
    integrations_as_source: list[IntegrationSpec]
    integrations_as_target: list[IntegrationSpec]
    tags: dict[str, str]
