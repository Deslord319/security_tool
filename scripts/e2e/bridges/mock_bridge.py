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
    json.dump(
        {
            "status": status,
            "failure_code": failure_code,
            "message": message,
            "evidence": {
                "bridge": "mock_bridge",
                "action": payload.get("action", ""),
            },
        },
        sys.stdout,
        ensure_ascii=False,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
