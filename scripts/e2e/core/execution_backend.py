from __future__ import annotations

from pathlib import Path


def classify_execution_backend(dry_run: bool, bridge_command: str, backend_module: str = "") -> str:
    if dry_run:
        return "dry_run"

    bridge = _normalize(bridge_command)
    backend = _normalize(backend_module)
    if not bridge:
        return "unconfigured_bridge"
    if "mock_bridge.py" in bridge or bridge.endswith("mock_bridge"):
        return "mock_bridge"
    if "harmonyos_mcp_bridge.py" in bridge or bridge.endswith("harmonyos_mcp_bridge"):
        if "real_harmonyos_mcp_backend.py" in backend or backend.endswith("real_harmonyos_mcp_backend"):
            return "real_bridge"
        if backend:
            return "configured_bridge"
        return "unconfigured_bridge"
    return "custom_bridge"


def build_bridge_evidence(bridge_command: str, backend_module: str, execution_backend: str) -> dict[str, str]:
    evidence = {"execution_backend": execution_backend}
    bridge = _normalize(bridge_command)
    if bridge_command:
        evidence["bridge_command"] = bridge_command
    if "mock_bridge.py" in bridge or bridge.endswith("mock_bridge"):
        evidence["bridge"] = "mock_bridge"
    elif "harmonyos_mcp_bridge.py" in bridge or bridge.endswith("harmonyos_mcp_bridge"):
        evidence["bridge"] = "harmonyos_mcp_bridge"

    if backend_module:
        evidence["backend_module"] = backend_module
        evidence["bridge_backend"] = _module_stem(backend_module)
    return evidence


def _normalize(value: str) -> str:
    return value.strip().strip('"').strip("'").replace("\\", "/").lower()


def _module_stem(value: str) -> str:
    return Path(value.strip().strip('"').strip("'")).stem
