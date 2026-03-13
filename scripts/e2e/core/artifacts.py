from __future__ import annotations

from pathlib import Path


def sanitize_artifact_segment(value: str) -> str:
    cleaned = "".join(ch if ch.isalnum() or ch in {"-", "_"} else "_" for ch in value.strip())
    return cleaned or "unnamed"


def build_artifact_relative_path(case_id: str, step_name: str, extension: str, timestamp: str) -> str:
    case_segment = sanitize_artifact_segment(case_id)
    step_segment = sanitize_artifact_segment(step_name)
    ext = extension.lstrip(".")
    return str(Path("artifacts") / case_segment / f"{step_segment}__{timestamp}.{ext}")
