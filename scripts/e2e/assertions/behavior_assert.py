from __future__ import annotations

from typing import Any


def build_behavior_evidence(source: str, detail: str, extra: dict[str, Any] | None = None) -> dict[str, Any]:
    evidence = {
        "category": "behavior",
        "source": source,
        "detail": detail,
    }
    if extra:
        evidence.update(extra)
    return evidence
