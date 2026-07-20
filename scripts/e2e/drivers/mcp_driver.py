from __future__ import annotations

from dataclasses import dataclass
import json
import os
import shlex
import subprocess
from pathlib import Path
from typing import Any

from scripts.e2e.core.execution_backend import build_bridge_evidence, classify_execution_backend
from scripts.e2e.core.failures import (
    MCP_ACTION_PENDING,
    MCP_BACKEND_NOT_CONFIGURED,
    MCP_BRIDGE_PROTOCOL_ERROR,
    MCP_EXECUTION_FAILED,
)


@dataclass
class MpcActionRequest:
    action: str
    params: dict[str, Any]
    expected: str = ""


@dataclass
class McpExecutionResult:
    status: str
    failure_code: str
    message: str
    evidence: dict[str, Any]
    command: list[str] | None = None
    raw_stdout: str | None = None
    raw_stderr: str | None = None
    returncode: int | None = None


class McpDriver:
    """UI driver that can describe or execute MCP-backed actions.

    Runtime execution is delegated to an optional external bridge command
    configured through `HARMONYOS_E2E_MCP_BRIDGE`. The bridge receives a JSON
    payload on stdin and should return a JSON result on stdout.
    """

    def __init__(self, project_root: Path, dry_run: bool):
        self.project_root = project_root
        self.dry_run = dry_run
        self.bridge_command = os.environ.get("HARMONYOS_E2E_MCP_BRIDGE", "").strip()
        self.backend_module = os.environ.get("HARMONYOS_E2E_MCP_BACKEND_MODULE", "").strip()
        self.execution_backend = classify_execution_backend(dry_run, self.bridge_command, self.backend_module)

    def describe(self, request: MpcActionRequest) -> dict[str, Any]:
        return {
            "type": "mcp_action",
            "action": request.action,
            "params": request.params,
            "expected": request.expected,
        }

    def execute(self, request: MpcActionRequest) -> McpExecutionResult:
        evidence = self.describe(request)
        bridge_evidence = build_bridge_evidence(self.bridge_command, self.backend_module, self.execution_backend)
        if self.dry_run:
            return McpExecutionResult(
                status="UNKNOWN",
                failure_code=MCP_ACTION_PENDING,
                message="Dry run: MCP action execution skipped",
                evidence={**evidence, **bridge_evidence},
            )

        if not self.bridge_command:
            return McpExecutionResult(
                status="UNKNOWN",
                failure_code=MCP_BACKEND_NOT_CONFIGURED,
                message="MCP bridge command is not configured",
                evidence={**evidence, **bridge_evidence},
            )

        command = shlex.split(self.bridge_command, posix=False)
        payload = json.dumps(evidence, ensure_ascii=False)
        result = subprocess.run(
            command,
            input=payload,
            text=True,
            encoding="utf-8",
            errors="replace",
            capture_output=True,
            cwd=self.project_root,
        )
        if result.returncode != 0:
            return McpExecutionResult(
                status="FAIL",
                failure_code=MCP_EXECUTION_FAILED,
                message="MCP bridge command failed",
                evidence=evidence,
                command=command,
                raw_stdout=result.stdout,
                raw_stderr=result.stderr,
                returncode=result.returncode,
            )

        try:
            parsed = json.loads(result.stdout) if result.stdout.strip() else {}
        except json.JSONDecodeError:
            return McpExecutionResult(
                status="FAIL",
                failure_code=MCP_BRIDGE_PROTOCOL_ERROR,
                message="MCP bridge returned invalid JSON",
                evidence=evidence,
                command=command,
                raw_stdout=result.stdout,
                raw_stderr=result.stderr,
                returncode=result.returncode,
            )

        status = parsed.get("status", "UNKNOWN")
        failure_code = parsed.get("failure_code", "" if status == "PASS" else MCP_ACTION_PENDING)
        message = parsed.get("message", "MCP bridge executed")
        merged_evidence = {**evidence, **parsed.get("evidence", {})}
        for key, value in bridge_evidence.items():
            merged_evidence.setdefault(key, value)
        return McpExecutionResult(
            status=status,
            failure_code=failure_code,
            message=message,
            evidence=merged_evidence,
            command=command,
            raw_stdout=result.stdout,
            raw_stderr=result.stderr,
            returncode=result.returncode,
        )

    def get_toggle_state(
        self,
        *,
        bundle_name: str,
        text: str = "",
        element_id: str = "",
        window_id: str = "",
    ) -> dict[str, Any]:
        request = MpcActionRequest(
            action="__driver_get_toggle_state",
            params={
                "bundle_name": bundle_name,
                "text": text,
                "element_id": element_id,
                "window_id": window_id,
            },
            expected="Read toggle state",
        )
        execution = self.execute(request)
        return {
            "status": execution.status,
            "failure_code": execution.failure_code,
            "message": execution.message,
            "checked": execution.evidence.get("checked"),
            "element": execution.evidence.get("element", {}),
            "evidence": execution.evidence,
        }

    def wait_for_text(
        self,
        *,
        bundle_name: str,
        text: str,
        timeout_ms: int = 5000,
        interval_ms: int = 300,
        window_id: str = "",
    ) -> dict[str, Any]:
        request = MpcActionRequest(
            action="__driver_wait_element",
            params={
                "bundle_name": bundle_name,
                "text": text,
                "state": "found",
                "timeout_ms": timeout_ms,
                "interval_ms": interval_ms,
                "window_id": window_id,
            },
            expected=f"Wait for text {text}",
        )
        execution = self.execute(request)
        return {
            "status": execution.status,
            "failure_code": execution.failure_code,
            "message": execution.message,
            "element": execution.evidence.get("element", {}),
            "evidence": execution.evidence,
        }

    def scroll_until_text(
        self,
        *,
        bundle_name: str,
        text: str,
        direction: str = "up",
        max_swipes: int = 8,
        timeout_ms: int = 1500,
    ) -> dict[str, Any]:
        request = MpcActionRequest(
            action="__driver_scroll_until_text",
            params={
                "bundle_name": bundle_name,
                "text": text,
                "direction": direction,
                "max_swipes": max_swipes,
                "timeout_ms": timeout_ms,
            },
            expected=f"Scroll until text {text} becomes visible",
        )
        execution = self.execute(request)
        return {
            "status": execution.status,
            "failure_code": execution.failure_code,
            "message": execution.message,
            "element": execution.evidence.get("element", {}),
            "swipes_used": execution.evidence.get("swipes_used"),
            "evidence": execution.evidence,
        }


    def input_password_if_prompted(
        self,
        *,
        bundle_name: str,
        timeout_ms: int = 4000,
    ) -> dict[str, Any]:
        request = MpcActionRequest(
            action="__driver_input_password_if_prompted",
            params={
                "bundle_name": bundle_name,
                "timeout_ms": timeout_ms,
            },
            expected="Clear lock screen password prompt when present",
        )
        execution = self.execute(request)
        return {
            "status": execution.status,
            "failure_code": execution.failure_code,
            "message": execution.message,
            "handled": bool(execution.evidence.get("handled", False)),
            "prompt_detected": bool(execution.evidence.get("prompt_detected", False)),
            "evidence": execution.evidence,
        }

    def text_presence(
        self,
        *,
        bundle_name: str,
        text: str,
        expected_present: bool | None = None,
        match_mode: str = "contains",
        timeout_ms: int = 1500,
        interval_ms: int = 250,
        window_id: str = "",
    ) -> dict[str, Any]:
        request = MpcActionRequest(
            action="__driver_text_presence",
            params={
                "bundle_name": bundle_name,
                "text": text,
                "expected_present": expected_present,
                "match_mode": match_mode,
                "timeout_ms": timeout_ms,
                "interval_ms": interval_ms,
                "window_id": window_id,
            },
            expected=f"Detect whether text {text} is present",
        )
        execution = self.execute(request)
        return {
            "status": execution.status,
            "failure_code": execution.failure_code,
            "message": execution.message,
            "exists": bool(execution.evidence.get("exists", False)),
            "element": execution.evidence.get("element", {}),
            "source": execution.evidence.get("source", ""),
            "evidence": execution.evidence,
        }
