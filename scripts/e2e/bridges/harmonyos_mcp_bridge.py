#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from types import ModuleType
from typing import Any, Protocol


class BackendProtocol(Protocol):
    def handle_action(self, payload: dict[str, Any]) -> dict[str, Any]:
        ...


@dataclass
class BridgeResult:
    status: str
    failure_code: str
    message: str
    evidence: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return {
            "status": self.status,
            "failure_code": self.failure_code,
            "message": self.message,
            "evidence": self.evidence,
        }


def unknown(payload: dict[str, Any], failure_code: str, message: str) -> BridgeResult:
    return BridgeResult(
        status="UNKNOWN",
        failure_code=failure_code,
        message=message,
        evidence={
            "bridge": "harmonyos_mcp_bridge",
            "action": payload.get("action", ""),
            "params": payload.get("params", {}),
        },
    )


def load_backend_module(module_path: Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location("harmonyos_e2e_backend", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load backend module from {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def resolve_backend() -> BackendProtocol | None:
    backend_module_path = os.environ.get("HARMONYOS_E2E_MCP_BACKEND_MODULE", "").strip()
    if not backend_module_path:
        return None

    module_path = Path(backend_module_path)
    if not module_path.is_absolute():
        module_path = Path.cwd() / module_path
    module = load_backend_module(module_path.resolve())
    backend = getattr(module, "BACKEND", None)
    if backend is None or not hasattr(backend, "handle_action"):
        raise RuntimeError("Backend module must expose BACKEND.handle_action(payload)")
    return backend


def main() -> int:
    if hasattr(sys.stdin, "reconfigure"):
        sys.stdin.reconfigure(encoding="utf-8")
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    payload = json.load(sys.stdin)
    try:
        backend = resolve_backend()
        if backend is None:
            result = unknown(
                payload,
                "MCP_BACKEND_NOT_CONFIGURED",
                "No HarmonyOS MCP backend module configured. Set HARMONYOS_E2E_MCP_BACKEND_MODULE.",
            )
        else:
            backend_result = backend.handle_action(payload)
            result = BridgeResult(
                status=backend_result.get("status", "UNKNOWN"),
                failure_code=backend_result.get("failure_code", ""),
                message=backend_result.get("message", "HarmonyOS MCP backend executed"),
                evidence=backend_result.get("evidence", {}),
            )
    except Exception as exc:  # noqa: BLE001
        result = unknown(payload, "MCP_BRIDGE_PROTOCOL_ERROR", f"Bridge crashed: {exc}")

    json.dump(result.to_dict(), sys.stdout, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
