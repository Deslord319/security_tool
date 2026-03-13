from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class SecurityToolRuntimeConfig:
    tool_password: str = ""
    skip_startup_auth: bool = False


def _parse_bool(value: object, default: bool = False) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    normalized = str(value).strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    return default


def load_runtime_config() -> SecurityToolRuntimeConfig:
    local_values: dict[str, object] = {}
    try:
        from . import local_config  # type: ignore

        local_values = {
            "tool_password": getattr(local_config, "TOOL_PASSWORD", ""),
            "skip_startup_auth": getattr(local_config, "SKIP_STARTUP_AUTH", False),
        }
    except Exception:
        local_values = {}

    tool_password = os.getenv("HARMONYOS_E2E_TOOL_PASSWORD", str(local_values.get("tool_password", "") or ""))
    skip_startup_auth = _parse_bool(
        os.getenv("HARMONYOS_E2E_SKIP_STARTUP_AUTH", local_values.get("skip_startup_auth", False)),
        False,
    )
    return SecurityToolRuntimeConfig(
        tool_password=tool_password,
        skip_startup_auth=skip_startup_auth,
    )
