from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

PROJECT_ROOT = Path(__file__).resolve().parents[3]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.e2e.bridges.action_plans import ACTION_PLANS


class ScriptedHarmonyOsMcpBackend:
    """Configurable backend for bridge bring-up and suite validation.

    Configure with:
      HARMONYOS_E2E_SCRIPTED_RESULTS=<json file path>

    File format:
    {
      "default": {
        "status": "UNKNOWN",
        "failure_code": "MCP_ACTION_PENDING",
        "message": "Not implemented"
      },
      "navigate_page": {
        "status": "PASS",
        "message": "Navigation completed"
      }
    }
    """

    def __init__(self) -> None:
        self._loaded_path = ""
        self._data: dict[str, Any] = {}

    def _load(self) -> None:
        path = os.environ.get("HARMONYOS_E2E_SCRIPTED_RESULTS", "").strip()
        if path == self._loaded_path:
            return
        self._loaded_path = path
        self._data = {}
        if not path:
            return

        result_file = Path(path)
        if not result_file.is_absolute():
            result_file = Path.cwd() / result_file
        self._data = json.loads(result_file.read_text(encoding="utf-8"))

    def handle_action(self, payload: dict[str, Any]) -> dict[str, Any]:
        self._load()
        action = payload.get("action", "")
        params = payload.get("params", {})
        default_entry = self._data.get(
            "default",
            {
                "status": "UNKNOWN",
                "failure_code": "MCP_ACTION_PENDING",
                "message": "Scripted backend has no configured result for this action",
            },
        )
        entry = {**default_entry, **self._data.get(action, {})}

        evidence = {
            "bridge_backend": "scripted_backend",
            "action": action,
            "params": params,
            "scripted_result_file": self._loaded_path,
            "action_plan": ACTION_PLANS.get(action, {}),
        }
        evidence.update(entry.get("evidence", {}))

        return {
            "status": entry.get("status", "UNKNOWN"),
            "failure_code": entry.get("failure_code", ""),
            "message": entry.get("message", f"Scripted backend executed action: {action}"),
            "evidence": evidence,
        }


BACKEND = ScriptedHarmonyOsMcpBackend()
