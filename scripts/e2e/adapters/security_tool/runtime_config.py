from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class SecurityToolRuntimeConfig:
    tool_password: str = ""


def load_runtime_config() -> SecurityToolRuntimeConfig:
    local_values: dict[str, object] = {}
    try:
        from . import local_config  # type: ignore

        local_values = {
            "tool_password": getattr(local_config, "TOOL_PASSWORD", ""),
        }
    except Exception:
        local_values = {}

    tool_password = os.getenv("HARMONYOS_E2E_TOOL_PASSWORD", str(local_values.get("tool_password", "") or ""))
    return SecurityToolRuntimeConfig(
        tool_password=tool_password,
    )
