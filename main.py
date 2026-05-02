"""CLI entry point for the pipeline engine.

Usage:
  python main.py                                             # Pick up diagrams from input_dgm/
  python main.py examples/simple_ingest.yaml                # YAML → Terraform
  python main.py diagram.png                                 # Diagram → YAML → Terraform
  python main.py examples/simple_ingest.yaml --validate      # Also run terraform validate
  python main.py examples/simple_ingest.yaml --dry-run       # Print HCL to stdout, don't write

The engine makes ZERO LLM calls for YAML input (fully deterministic).
Only diagram input requires one LLM call (Claude Vision).

Folder-based workflow:
  Place diagram images in input_dgm/. Run `python main.py` with no arguments.
  Successfully processed diagrams are moved to input_dgm_archive/.
"""
from __future__ import annotations

import argparse
import logging
import shutil
import sys
from datetime import datetime
from pathlib import Path

import yaml
from dotenv import load_dotenv

load_dotenv()

from schemas import PipelineRequest
from engine.pipeline_builder import build_pipeline

INPUT_DIR = Path("input_dgm")
ARCHIVE_DIR = Path("input_dgm_archive")


def _setup_logging(level: str = "INFO") -> None:
    logging.basicConfig(
        level=level,
        format="%(asctime)s %(levelname)-5s [%(name)s] %(message)s",
        datefmt="%H:%M:%S",
    )


def _is_image(path: Path) -> bool:
    return path.suffix.lower() in {".png", ".jpg", ".jpeg", ".gif", ".webp"}


def _load_yaml(path: Path) -> PipelineRequest:
    raw = yaml.safe_load(path.read_text())
    return PipelineRequest.model_validate(raw)


def _diagram_to_yaml(image_path: Path, model: str) -> str:
    from agents.diagram_reader import DiagramReaderAgent
    agent = DiagramReaderAgent(model=model)
    yaml_text = agent.run(image_path)
    # Save generated YAML next to the image
    out = image_path.with_suffix(".generated.yaml")
    out.write_text(yaml_text)
    print(f"Generated YAML: {out}")
    return yaml_text


def _archive(image_path: Path) -> None:
    ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)
    dest = ARCHIVE_DIR / image_path.name
    # Avoid overwriting an existing archive file with same name
    if dest.exists():
        stem = image_path.stem
        suffix = image_path.suffix
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        dest = ARCHIVE_DIR / f"{stem}_{ts}{suffix}"
    shutil.move(str(image_path), dest)
    print(f"Archived: {image_path.name} → {dest}")


def _process_one(input_path: Path, args) -> int:
    logger = logging.getLogger("main")

    # Step 1: Get pipeline YAML
    if _is_image(input_path):
        logger.info("Diagram input: %s — running T0 DiagramReader (1 LLM call)", input_path.name)
        yaml_text = _diagram_to_yaml(input_path, args.model)
        request = PipelineRequest.model_validate(yaml.safe_load(yaml_text))
    else:
        logger.info("YAML input: %s — zero LLM calls", input_path.name)
        request = _load_yaml(input_path)

    logger.info("Pipeline '%s': %d services, %d integrations",
                request.pipeline_name, len(request.services), len(request.integrations))

    # Step 2: Build
    out_dir = None if args.dry_run else Path(args.out) / request.pipeline_name

    result = build_pipeline(
        request,
        output_dir=out_dir,
        run_terraform=args.validate and not args.dry_run,
    )

    # Step 3: Report
    if args.dry_run:
        print(result.main_tf)
        return 0

    hard_errors = [e for e in result.lint_errors if e.severity == "error"]
    warnings = [e for e in result.lint_errors if e.severity == "warning"]

    print(f"\n{'='*60}")
    print(f"Pipeline:        {result.pipeline_name}")
    print(f"Output:          {result.main_tf_path}")
    print(f"Services:        {len(result.blueprints)}")
    print(f"Lint errors:     {len(hard_errors)}")
    print(f"Lint warnings:   {len(warnings)}")

    if hard_errors:
        print("\nLint errors (must fix):")
        for e in hard_errors:
            print(f"  {e.format()}")

    if args.validate:
        print(f"Terraform:       {'PASS' if result.terraform_ok else 'FAIL'}")
        if not result.terraform_ok and result.terraform_message:
            for line in result.terraform_message.splitlines():
                if "error" in line.lower() or "Error" in line:
                    print(f"  {line.strip()}")

    print(f"{'='*60}")

    if hard_errors:
        return 1
    if args.validate and not result.terraform_ok:
        return 1

    # Step 4: Archive if diagram came from input_dgm/
    if _is_image(input_path) and input_path.parent.resolve() == INPUT_DIR.resolve():
        _archive(input_path)

    # Step 5: Deploy to AWS if --apply flag set
    if args.apply:
        if not result.main_tf_path:
            print("ERROR: no output path — cannot deploy", file=sys.stderr)
            return 1
        return _deploy(result.main_tf_path.parent, logger)

    return 0


def _deploy(work_dir: Path, logger: logging.Logger) -> int:
    from tools.terraform_cli import init_for_deploy, plan, apply_streaming, get_output

    print(f"\n{'='*60}")
    print("DEPLOYING TO AWS")
    print(f"{'='*60}")

    # Init
    logger.info("Running terraform init…")
    init_res = init_for_deploy(work_dir)
    if not init_res.ok:
        print(f"ERROR: terraform init failed:\n{init_res.stderr}", file=sys.stderr)
        return 1

    # Plan
    logger.info("Running terraform plan…")
    plan_res = plan(work_dir)
    if not plan_res.ok:
        print(f"ERROR: terraform plan failed:\n{plan_res.stderr}", file=sys.stderr)
        return 1

    print("\n--- PLAN ---")
    print(plan_res.stdout)

    # Confirm
    try:
        confirm = input("\nDeploy these resources to AWS? [yes/no]: ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        print("\nAborted.")
        return 1

    if confirm != "yes":
        print("Deployment cancelled.")
        return 0

    # Apply (streaming)
    logger.info("Running terraform apply…")
    print("\n--- APPLY ---")
    exit_code = 0
    for line in apply_streaming(work_dir):
        if line.startswith("__EXIT_CODE_"):
            exit_code = int(line.split("_")[-1])
        else:
            print(line)

    if exit_code != 0:
        print("\nERROR: terraform apply failed.", file=sys.stderr)
        return 1

    # Outputs
    out_res = get_output(work_dir)
    if out_res.ok and out_res.stdout.strip():
        print("\n--- OUTPUTS ---")
        print(out_res.stdout)

    print(f"\n{'='*60}")
    print("Deployment complete!")
    print(f"{'='*60}")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="AWS Pipeline Engine — YAML/diagram → Terraform")
    p.add_argument("input", nargs="?", help="Pipeline YAML file or diagram image (omit to process input_dgm/)")
    p.add_argument("--out", default="output", help="Output directory (default: ./output)")
    p.add_argument("--validate", action="store_true", help="Run terraform validate after generation")
    p.add_argument("--dry-run", action="store_true", help="Print HCL to stdout, don't write files")
    p.add_argument("--apply", action="store_true", help="Deploy generated Terraform to AWS (runs plan → confirm → apply)")
    p.add_argument("--model", default="claude-sonnet-4-5", help="Model for diagram reading")
    p.add_argument("--log-level", default="INFO", choices=["DEBUG", "INFO", "WARNING", "ERROR"])
    args = p.parse_args()

    _setup_logging(args.log_level)
    logger = logging.getLogger("main")

    # Folder-based mode: no argument → scan input_dgm/
    if args.input is None:
        INPUT_DIR.mkdir(parents=True, exist_ok=True)
        diagrams = sorted(f for f in INPUT_DIR.iterdir() if _is_image(f))
        if not diagrams:
            print(f"No diagrams found in {INPUT_DIR}/. Place .png/.jpg/.jpeg/.gif/.webp files there.")
            return 0
        logger.info("Found %d diagram(s) in %s/", len(diagrams), INPUT_DIR)
        exit_code = 0
        for diagram in diagrams:
            logger.info("Processing: %s", diagram.name)
            code = _process_one(diagram, args)
            if code != 0:
                exit_code = code
        return exit_code

    # Single-file mode
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"ERROR: {input_path} not found", file=sys.stderr)
        return 1
    return _process_one(input_path, args)


if __name__ == "__main__":
    sys.exit(main())
