from __future__ import annotations

from typing import Any


def build_ui_evidence(step_name: str, detail: str, extra: dict[str, Any] | None = None) -> dict[str, Any]:
    evidence = {
        "category": "ui",
        "step_name": step_name,
        "detail": detail,
    }
    if extra:
        evidence.update(extra)
    return evidence
