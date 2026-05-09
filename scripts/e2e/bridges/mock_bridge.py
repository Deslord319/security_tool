#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys


def main() -> int:
    if hasattr(sys.stdin, "reconfigure"):
        sys.stdin.reconfigure(encoding="utf-8")
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    payload = json.load(sys.stdin)
    mode = os.environ.get("HARMONYOS_E2E_MCP_BRIDGE_MODE", "unknown").strip().lower()
    status = "PASS" if mode == "pass" else "UNKNOWN"
    failure_code = "" if status == "PASS" else "MCP_ACTION_PENDING"
    message = "Mock bridge executed" if status == "PASS" else "Mock bridge returns pending execution"
    evidence = {
        "bridge": "mock_bridge",
        "action": payload.get("action", ""),
    }
    if status == "PASS":
        evidence.update(_build_pass_evidence(payload))
    json.dump(
        {
            "status": status,
            "failure_code": failure_code,
            "message": message,
            "evidence": evidence,
        },
        sys.stdout,
        ensure_ascii=False,
    )
    return 0


def _build_pass_evidence(payload: dict) -> dict:
    action = payload.get("action", "")
    params = payload.get("params", {})
    if action == "__driver_text_presence":
        return {"exists": bool(params.get("expected_present", True)), "match_mode": params.get("match_mode", "contains")}
    if action in {"__driver_element_exists", "__driver_wait_element", "__driver_wait_for_page"}:
        return {"exists": True, "element": {"mock": True}}
    if action == "__driver_get_toggle_state":
        return {"checked": False, "element": {"mock": True}}
    if action == "__driver_scroll_until_text":
        return {"element": {"mock": True}, "swipes_used": 1}
    if action == "__driver_input_password_if_prompted":
        return {"handled": False, "prompt_detected": False}
    return {}


if __name__ == "__main__":
    raise SystemExit(main())
