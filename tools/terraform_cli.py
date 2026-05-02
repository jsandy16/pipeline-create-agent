"""Terraform CLI wrapper with shared plugin cache.

Runs fmt, init, validate, plan, apply, destroy. Caches the AWS provider
across runs (~45 seconds saved per run). Falls back gracefully if terraform
is not installed.

Optimisations applied:
  - Shared plugin cache (TF_PLUGIN_CACHE_DIR) — avoids re-downloading providers
  - Smart init: skips `terraform init` when .terraform/ is already populated
  - Refresh-free plan: uses -refresh=false on fresh deploys (no state to refresh)
  - Higher parallelism (default 30) for plan / apply / destroy
"""
from __future__ import annotations

import logging
import os
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator

logger = logging.getLogger(__name__)

_PLUGIN_CACHE = Path.home() / ".pipeline_cache" / "terraform_plugins"

# Parallelism for plan/apply/destroy (Terraform default is 10)
_PARALLELISM = 30

# Runtime AWS credential overrides set via the Admin panel
_override_env: dict[str, str] = {}

def set_extra_env(env: dict[str, str]) -> None:
    """Merge additional env vars (e.g. admin-provided AWS keys) into Terraform calls."""
    _override_env.update(env)


def _tf_env() -> dict[str, str]:
    env = os.environ.copy()
    env.update(_override_env)          # admin-provided keys override .env
    _PLUGIN_CACHE.mkdir(parents=True, exist_ok=True)
    env["TF_PLUGIN_CACHE_DIR"] = str(_PLUGIN_CACHE)
    env["CHECKPOINT_DISABLE"] = "1"
    env["TF_IN_AUTOMATION"] = "1"
    return env


@dataclass
class TerraformResult:
    ok: bool
    skipped: bool
    stdout: str
    stderr: str
    command: str


def terraform_available() -> bool:
    return shutil.which("terraform") is not None


def _run(args: list[str], cwd: Path, timeout: int = 120) -> TerraformResult:
    cmd = " ".join(args)
    if not terraform_available():
        return TerraformResult(False, True, "", "terraform not on PATH", cmd)
    try:
        proc = subprocess.run(
            args, cwd=str(cwd), capture_output=True, text=True,
            timeout=timeout, check=False, env=_tf_env(),
        )
        return TerraformResult(proc.returncode == 0, False, proc.stdout, proc.stderr, cmd)
    except subprocess.TimeoutExpired:
        return TerraformResult(False, False, "", f"timeout {timeout}s", cmd)


def _run_streaming(args: list[str], cwd: Path, timeout: int = 600) -> Iterator[str]:
    """Run terraform and yield stdout+stderr lines as they arrive."""
    if not terraform_available():
        yield "ERROR: terraform not on PATH"
        return
    proc = subprocess.Popen(
        args, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, env=_tf_env(),
    )
    try:
        assert proc.stdout
        for line in iter(proc.stdout.readline, ""):
            yield line.rstrip("\n")
        proc.wait(timeout=timeout)
        yield f"__EXIT_CODE_{proc.returncode}__"
    except subprocess.TimeoutExpired:
        proc.kill()
        yield f"ERROR: timeout after {timeout}s"
        yield "__EXIT_CODE_1__"


# ---------------------------------------------------------------------------
# Smart init helpers
# ---------------------------------------------------------------------------

def _is_already_initialised(work_dir: Path) -> bool:
    """Return True if terraform init can be skipped.

    We check for:
      1. .terraform/ directory exists (providers downloaded)
      2. .terraform.lock.hcl exists (dependency lock written)
      3. Lock file contains all required providers (aws, archive, time)

    If the lock file is missing a provider (e.g. time was added after the
    last init), this returns False so init runs with -upgrade.
    """
    tf_dir = work_dir / ".terraform"
    lock_file = work_dir / ".terraform.lock.hcl"
    if not (tf_dir.is_dir() and lock_file.is_file()):
        return False
    # Verify the lock file contains all providers the engine now requires.
    # If any are missing, a re-init with -upgrade is needed.
    required_providers = [
        "registry.terraform.io/hashicorp/aws",
        "registry.terraform.io/hashicorp/archive",
        "registry.terraform.io/hashicorp/time",
    ]
    content = lock_file.read_text()
    return all(p in content for p in required_providers)


def _has_existing_state(work_dir: Path) -> bool:
    """Return True if a terraform.tfstate with actual resources exists."""
    state_file = work_dir / "terraform.tfstate"
    if not state_file.exists():
        return False
    # A fresh/empty state file is ~150 bytes with zero resources.
    # If it's larger, real resources exist and we should refresh.
    return state_file.stat().st_size > 200


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def init_and_validate(hcl: str, work_dir: Path) -> TerraformResult:
    """Offline validation — no backend, no AWS credentials needed."""
    work_dir.mkdir(parents=True, exist_ok=True)
    (work_dir / "main.tf").write_text(hcl)
    init = _run(["terraform", "init", "-backend=false", "-input=false", "-no-color"],
                cwd=work_dir, timeout=300)
    if init.skipped or not init.ok:
        return init
    return _run(["terraform", "validate", "-no-color"], cwd=work_dir)


def init_for_deploy(work_dir: Path, force: bool = False) -> TerraformResult:
    """terraform init with real backend — required before plan/apply.

    Skips init when .terraform/ is already populated AND the lock file
    contains all required providers (saves ~2-4 seconds).
    Uses -upgrade when the lock file exists but is missing providers added
    after the last init (e.g. the time provider).
    Pass force=True to re-initialise unconditionally (e.g. after autofix
    modifies provider requirements).
    """
    if not force and _is_already_initialised(work_dir):
        logger.info("terraform already initialised — skipping init")
        return TerraformResult(True, False, "already initialised (cached)", "", "terraform init (skipped)")

    lock_file = work_dir / ".terraform.lock.hcl"
    upgrade = lock_file.is_file()  # upgrade if lock exists but is stale
    cmd = ["terraform", "init", "-input=false", "-no-color", "-reconfigure"]
    if upgrade:
        cmd.append("-upgrade")
        logger.info("terraform lock file is stale — running init -upgrade")
    return _run(cmd, cwd=work_dir, timeout=300)


def plan(work_dir: Path, plan_file: str = "tfplan") -> TerraformResult:
    """terraform plan — previews what will be created. Saves plan to file.

    Uses -refresh=false on fresh deploys (no existing state → nothing to
    refresh from AWS APIs, saves ~1-3 seconds).
    """
    args = [
        "terraform", "plan",
        f"-out={plan_file}",
        "-input=false",
        "-no-color",
        f"-parallelism={_PARALLELISM}",
        "-compact-warnings",
    ]
    if not _has_existing_state(work_dir):
        args.append("-refresh=false")
    return _run(args, cwd=work_dir, timeout=300)


def apply_streaming(work_dir: Path, plan_file: str = "tfplan") -> Iterator[str]:
    """terraform apply — deploys to AWS. Yields output lines as they arrive."""
    yield from _run_streaming(
        [
            "terraform", "apply",
            "-input=false",
            "-no-color",
            "-auto-approve",
            f"-parallelism={_PARALLELISM}",
            plan_file,
        ],
        cwd=work_dir, timeout=600,
    )


def get_output(work_dir: Path) -> TerraformResult:
    """terraform output — returns resource outputs after apply."""
    return _run(["terraform", "output", "-no-color"], cwd=work_dir, timeout=30)


def destroy_streaming(work_dir: Path) -> Iterator[str]:
    """terraform destroy — tears down all resources. Yields output lines."""
    yield from _run_streaming(
        [
            "terraform", "destroy",
            "-input=false",
            "-no-color",
            "-auto-approve",
            f"-parallelism={_PARALLELISM}",
        ],
        cwd=work_dir, timeout=600,
    )
