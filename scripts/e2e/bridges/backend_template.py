from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

PROJECT_ROOT = Path(__file__).resolve().parents[3]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.e2e.bridges.action_plans import ACTION_PLANS


class HarmonyOsMcpBackend:
    """Template backend for the stdin/stdout MCP bridge.

    Replace the UNKNOWN branches with real HarmonyOS MCP integration.
    The backend should stay focused on atomic UI actions and return
    structured results to the runner bridge.
    """

    def handle_action(self, payload: dict[str, Any]) -> dict[str, Any]:
        action = payload.get("action", "")
        params = payload.get("params", {})
        plan = ACTION_PLANS.get(action, {})

        return {
            "status": "UNKNOWN",
            "failure_code": "MCP_ACTION_PENDING",
            "message": f"Backend template does not implement action: {action}",
            "evidence": {
                "bridge_backend": "backend_template",
                "action": action,
                "params": params,
                "action_plan": plan,
            },
        }


BACKEND = HarmonyOsMcpBackend()
