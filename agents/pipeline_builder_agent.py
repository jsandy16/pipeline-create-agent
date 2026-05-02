"""Pipeline Builder Agent — converts natural language requirements to pipeline YAML.

Takes a user's natural-language description of their desired AWS pipeline and
produces valid PipelineRequest YAML that the deterministic engine can consume.
Uses Claude (Sonnet by default) with a constrained system prompt.

Also supports image input: upload an architecture diagram and the agent will
parse arrow directions to build integrations, detect bidirectional access, and
warn about architecturally impossible patterns.
"""
from __future__ import annotations

import base64
import json
import logging
import os
from pathlib import Path

logger = logging.getLogger(__name__)

PROMPTS_DIR = Path(__file__).resolve().parent.parent / "prompts"


def _load_prompt() -> str:
    return (PROMPTS_DIR / "pipeline_builder.md").read_text()


def _load_image_prompt() -> str:
    return (PROMPTS_DIR / "pipeline_builder_image.md").read_text()


def _load_designer_prompt() -> str:
    return (PROMPTS_DIR / "pipeline_designer.md").read_text()


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


class PipelineBuilderAgent:
    """Converts natural-language pipeline requirements into pipeline YAML."""

    def __init__(self, api_key: str | None = None, model: str = "claude-sonnet-4-5"):
        import anthropic
        key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        if not key:
            raise RuntimeError("ANTHROPIC_API_KEY not set")
        self._client = anthropic.Anthropic(api_key=key)
        self._model = model
        self._prompt = _load_prompt()

    def generate(self, requirements: str, conversation_history: list[dict] | None = None) -> str:
        """Generate pipeline YAML from natural-language requirements.

        Args:
            requirements: User's description of the pipeline they want.
            conversation_history: Optional previous messages for multi-turn refinement.

        Returns:
            Raw YAML string matching the PipelineRequest schema.
        """
        messages = []

        # Add conversation history for multi-turn refinement
        if conversation_history:
            messages.extend(conversation_history)

        messages.append({
            "role": "user",
            "content": requirements,
        })

        logger.info("[PipelineBuilder] generating YAML from requirements (%d chars)", len(requirements))

        resp = self._client.messages.create(
            model=self._model,
            max_tokens=4096,
            system=[{
                "type": "text",
                "text": self._prompt,
                "cache_control": {"type": "ephemeral"},
            }],
            messages=messages,
        )

        raw = "".join(
            b.text for b in resp.content if getattr(b, "type", None) == "text"
        ).strip()

        return _strip_fences(raw)

    def generate_from_image(
        self,
        image_bytes: bytes,
        media_type: str,
        hint: str = "",
        conversation_history: list[dict] | None = None,
    ) -> tuple[str, list[str]]:
        """Generate pipeline YAML from an architecture diagram image.

        Parses AWS service icons and arrow directions to build integrations.
        Bidirectional arrows create two integrations. Impossible access patterns
        (passive service as caller) generate warning messages.

        Args:
            image_bytes: Raw bytes of the image file.
            media_type: MIME type (e.g. "image/png").
            hint: Optional extra context from the user.
            conversation_history: Previous messages for multi-turn refinement.

        Returns:
            (yaml_text, warnings) — yaml_text is valid PipelineRequest YAML;
            warnings is a list of human-readable warning strings (may be empty).
        """
        image_block = {
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": media_type,
                "data": base64.standard_b64encode(image_bytes).decode("utf-8"),
            },
        }
        text_block = {
            "type": "text",
            "text": (
                "Analyze this AWS architecture diagram. "
                "Identify all services and connection arrows, parse arrow directions, "
                "and return JSON with 'yaml' and 'warnings' fields as instructed."
                + (f"\n\nAdditional context from the user: {hint}" if hint else "")
            ),
        }

        # Combined system prompt: pipeline schema rules + image parsing rules
        combined_prompt = self._prompt + "\n\n" + _load_image_prompt()

        messages = []
        if conversation_history:
            messages.extend(conversation_history)
        messages.append({"role": "user", "content": [image_block, text_block]})

        logger.info("[PipelineBuilder] generating YAML from diagram image (%d bytes)", len(image_bytes))

        resp = self._client.messages.create(
            model=self._model,
            max_tokens=4096,
            system=[{
                "type": "text",
                "text": combined_prompt,
                "cache_control": {"type": "ephemeral"},
            }],
            messages=messages,
        )

        raw = "".join(
            b.text for b in resp.content if getattr(b, "type", None) == "text"
        ).strip()

        # Strip markdown fences if the model wrapped the JSON
        raw = _strip_fences(raw)

        try:
            data = json.loads(raw)
            yaml_text = _strip_fences(data.get("yaml", ""))
            warnings = [str(w) for w in data.get("warnings", []) if w]
            return yaml_text, warnings
        except (json.JSONDecodeError, TypeError):
            # Fallback: treat the entire response as YAML with no warnings
            logger.warning("[PipelineBuilder] image response was not JSON, treating as raw YAML")
            return _strip_fences(raw), []

    def design(self, requirements: str,
               conversation_history: list[dict] | None = None) -> dict:
        """Generate an ASCII flow diagram + pipeline YAML from requirements.

        Returns:
            Dict with 'diagram' (ASCII art) and 'yaml' (pipeline YAML) keys.
        """
        messages = []
        if conversation_history:
            messages.extend(conversation_history)
        messages.append({"role": "user", "content": requirements})

        logger.info("[PipelineBuilder] designing pipeline from requirements (%d chars)", len(requirements))

        designer_prompt = _load_designer_prompt()
        resp = self._client.messages.create(
            model=self._model,
            max_tokens=8192,
            system=[{
                "type": "text",
                "text": designer_prompt,
                "cache_control": {"type": "ephemeral"},
            }],
            messages=messages,
        )

        raw = "".join(
            b.text for b in resp.content if getattr(b, "type", None) == "text"
        ).strip()

        raw = _strip_fences(raw)

        try:
            data = json.loads(raw)
            diagram = data.get("diagram", "")
            yaml_text = _strip_fences(data.get("yaml", ""))
            return {"diagram": diagram, "yaml": yaml_text}
        except (json.JSONDecodeError, TypeError):
            # Fallback: treat as YAML only
            logger.warning("[PipelineBuilder] design response was not JSON, treating as raw YAML")
            return {"diagram": "", "yaml": _strip_fences(raw)}

    def redesign(self, feedback: str, current_yaml: str, current_diagram: str,
                 conversation_history: list[dict] | None = None) -> dict:
        """Redesign a pipeline based on user feedback.

        Returns:
            Dict with 'diagram' and 'yaml' keys.
        """
        messages = []
        if conversation_history:
            messages.extend(conversation_history)

        messages.append({
            "role": "user",
            "content": (
                f"Here is the current pipeline design:\n\n"
                f"Current diagram:\n```\n{current_diagram}\n```\n\n"
                f"Current YAML:\n```yaml\n{current_yaml}\n```\n\n"
                f"Please modify the design based on this feedback: {feedback}\n\n"
                "Output ONLY the JSON with 'diagram' and 'yaml' keys as instructed."
            ),
        })

        logger.info("[PipelineBuilder] redesigning pipeline based on feedback")

        designer_prompt = _load_designer_prompt()
        resp = self._client.messages.create(
            model=self._model,
            max_tokens=8192,
            system=[{
                "type": "text",
                "text": designer_prompt,
                "cache_control": {"type": "ephemeral"},
            }],
            messages=messages,
        )

        raw = "".join(
            b.text for b in resp.content if getattr(b, "type", None) == "text"
        ).strip()

        raw = _strip_fences(raw)

        try:
            data = json.loads(raw)
            diagram = data.get("diagram", "")
            yaml_text = _strip_fences(data.get("yaml", ""))
            return {"diagram": diagram, "yaml": yaml_text}
        except (json.JSONDecodeError, TypeError):
            logger.warning("[PipelineBuilder] redesign response was not JSON, treating as raw YAML")
            return {"diagram": "", "yaml": _strip_fences(raw)}

    def refine(self, feedback: str, current_yaml: str,
               conversation_history: list[dict] | None = None) -> str:
        """Refine an existing pipeline YAML based on user feedback.

        Args:
            feedback: User's change request (e.g. "add another Lambda for error handling").
            current_yaml: The current pipeline YAML to modify.
            conversation_history: Previous messages for context.

        Returns:
            Updated YAML string.
        """
        messages = []
        if conversation_history:
            messages.extend(conversation_history)

        messages.append({
            "role": "user",
            "content": (
                f"Here is the current pipeline YAML:\n\n```yaml\n{current_yaml}\n```\n\n"
                f"Please modify it based on this feedback: {feedback}\n\n"
                "Output ONLY the complete updated YAML. No prose, no fences."
            ),
        })

        logger.info("[PipelineBuilder] refining YAML based on feedback")

        resp = self._client.messages.create(
            model=self._model,
            max_tokens=4096,
            system=[{
                "type": "text",
                "text": self._prompt,
                "cache_control": {"type": "ephemeral"},
            }],
            messages=messages,
        )

        raw = "".join(
            b.text for b in resp.content if getattr(b, "type", None) == "text"
        ).strip()

        return _strip_fences(raw)
