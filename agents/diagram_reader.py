"""T0: DiagramReaderAgent — converts architecture diagram image to pipeline YAML.

This is the ONLY LLM call in the entire framework. Everything after this
is deterministic (spec lookup → blueprint → golden template → lint → validate).
"""
from __future__ import annotations

import base64
import logging
import mimetypes
import os
from pathlib import Path

logger = logging.getLogger(__name__)

SUPPORTED_TYPES = frozenset({"image/png", "image/jpeg", "image/gif", "image/webp"})
MAX_BYTES = 5 * 1024 * 1024

PROMPTS_DIR = Path(__file__).resolve().parent.parent / "prompts"


def _load_prompt() -> str:
    return (PROMPTS_DIR / "diagram_reader.md").read_text()


def _strip_fences(text: str) -> str:
    s = text.strip()
    if s.startswith("```"):
        lines = s.splitlines()
        if lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip().startswith("```"):
            lines = lines[:-1]
        s = "\n".join(lines).strip()
    return s


class DiagramReaderAgent:
    """Reads an architecture diagram image and returns pipeline YAML."""

    def __init__(self, api_key: str | None = None, model: str = "claude-sonnet-4-5"):
        import anthropic
        key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        if not key:
            raise RuntimeError("ANTHROPIC_API_KEY not set")
        self._client = anthropic.Anthropic(api_key=key)
        self._model = model
        self._prompt = _load_prompt()

    def run(self, image_path: Path, hint: str = "") -> str:
        """Analyze diagram image and return pipeline YAML string."""
        data = image_path.read_bytes()
        if len(data) > MAX_BYTES:
            raise ValueError(f"{image_path.name} is {len(data):,} bytes (max {MAX_BYTES:,})")

        media_type, _ = mimetypes.guess_type(str(image_path))
        if media_type not in SUPPORTED_TYPES:
            raise ValueError(f"Unsupported: {media_type}. Need: {sorted(SUPPORTED_TYPES)}")

        image_block = {
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": media_type,
                "data": base64.standard_b64encode(data).decode("utf-8"),
            },
        }
        text_block = {
            "type": "text",
            "text": (
                "Analyze the attached architecture diagram and produce the YAML "
                "pipeline specification as instructed."
                + (f" Additional context: {hint}" if hint else "")
            ),
        }

        logger.info("[T0] analyzing diagram: %s", image_path.name)
        resp = self._client.messages.create(
            model=self._model,
            max_tokens=4096,
            system=[{
                "type": "text",
                "text": self._prompt,
                "cache_control": {"type": "ephemeral"},
            }],
            messages=[{"role": "user", "content": [image_block, text_block]}],
        )
        raw = "".join(b.text for b in resp.content if getattr(b, "type", None) == "text").strip()
        return _strip_fences(raw)
