from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from scripts.e2e.core.failures import ASSERTION_FAILED, ASSERTION_NOT_IMPLEMENTED, COMMAND_FAILED
from scripts.e2e.drivers.hdc_driver import HdcDriver
from scripts.e2e.drivers.mcp_driver import McpDriver


@dataclass
class AssertionExecutionResult:
    status: str
    failure_code: str
    message: str
    command: list[str] | None = None
    command_result: Any | None = None
    evidence: dict[str, Any] | None = None


class AssertionExecutor:
    def __init__(self, hdc: HdcDriver, mcp: McpDriver, dry_run: bool):
        self.hdc = hdc
        self.mcp = mcp
        self.dry_run = dry_run

    def execute(self, assertion_type: str, value: Any, params: dict[str, Any] | None = None) -> AssertionExecutionResult:
        params = params or {}
        if assertion_type == "enterprise_admin_enabled":
            bundle_name = params["bundle_name"]
            ability_name = params["ability_name"]
            command = self.hdc.command(
                [
                    "shell",
                    f"edm enable-admin -n {bundle_name} -a {ability_name} -t {params.get('admin_type', 'super')}",
                ]
            )
            if self.dry_run:
                return AssertionExecutionResult("PASS", "", "Dry run: assumed enterprise admin enabled", command=command)
            result = self.hdc.enable_admin(
                bundle_name=bundle_name,
                ability_name=ability_name,
                admin_type=params.get("admin_type", "super"),
                timeout_sec=params.get("timeout_sec", 20),
            )
            if result.returncode != 0:
                return AssertionExecutionResult("FAIL", COMMAND_FAILED, "Enable admin command failed", command=command, command_result=result)
            haystack = f"{result.stdout}\n{result.stderr}".lower()
            expected = str(value).lower().strip() if value else ""
            if expected and expected not in haystack:
                return AssertionExecutionResult(
                    "FAIL",
                    ASSERTION_FAILED,
                    f"Expected admin enable output to contain: {expected}",
                    command=command,
                    command_result=result,
                )
            return AssertionExecutionResult("PASS", "", "Enterprise admin enabled", command=command, command_result=result)

        if assertion_type == "assert_text_presence":
            bundle_name = params["bundle_name"]
            text = str(value)
            present = bool(params.get("present", True))
            timeout_ms = int(params.get("timeout_ms", 1500))
            interval_ms = int(params.get("interval_ms", 250))
            window_id = str(params.get("window_id", ""))
            match_mode = str(params.get("match_mode", "contains"))
            if self.dry_run:
                expectation = "exists" if present else "does not exist"
                return AssertionExecutionResult("PASS", "", f"Dry run: assumed text {expectation}: {text}")
            presence = self.mcp.text_presence(
                bundle_name=bundle_name,
                text=text,
                expected_present=present,
                match_mode=match_mode,
                timeout_ms=timeout_ms,
                interval_ms=interval_ms,
                window_id=window_id,
            )
            if presence["status"] == "UNKNOWN":
                return AssertionExecutionResult(
                    "UNKNOWN",
                    presence.get("failure_code", ASSERTION_NOT_IMPLEMENTED),
                    presence.get("message", "Text presence could not be resolved"),
                    evidence=presence.get("evidence", {}),
                )
            exists = bool(presence.get("exists", False))
            if exists != present:
                expected_text = "存在" if present else "不存在"
                return AssertionExecutionResult(
                    "FAIL",
                    ASSERTION_FAILED,
                    f"期望文本{expected_text}: {text}",
                    evidence=presence.get("evidence", {}),
                )
            return AssertionExecutionResult(
                "PASS",
                "",
                "Text presence assertion passed",
                evidence=presence.get("evidence", {}),
            )

        if assertion_type == "hdc_shell_contains":
            command_text = params["command"]
            expected = value
            command = self.hdc.command(["shell", command_text])
            if self.dry_run:
                return AssertionExecutionResult("PASS", "", f"Dry run: assumed output contains {expected}", command=command)
            result = self.hdc.shell(command_text, params.get("timeout_sec", 20))
            if result.returncode != 0:
                return AssertionExecutionResult("FAIL", COMMAND_FAILED, "Assertion command failed", command=command, command_result=result)
            haystack = f"{result.stdout}\n{result.stderr}"
            if expected not in haystack:
                return AssertionExecutionResult(
                    "FAIL",
                    ASSERTION_FAILED,
                    f"Expected output to contain: {expected}",
                    command=command,
                    command_result=result,
                )
            return AssertionExecutionResult("PASS", "", "Assertion passed", command=command, command_result=result)

        if assertion_type == "hdc_shell_not_contains":
            command_text = params["command"]
            unexpected = value
            command = self.hdc.command(["shell", command_text])
            if self.dry_run:
                return AssertionExecutionResult("PASS", "", f"Dry run: assumed output excludes {unexpected}", command=command)
            result = self.hdc.shell(command_text, params.get("timeout_sec", 20))
            if result.returncode != 0:
                return AssertionExecutionResult("FAIL", COMMAND_FAILED, "Assertion command failed", command=command, command_result=result)
            haystack = f"{result.stdout}\n{result.stderr}"
            if unexpected in haystack:
                return AssertionExecutionResult(
                    "FAIL",
                    ASSERTION_FAILED,
                    f"Unexpected output matched: {unexpected}",
                    command=command,
                    command_result=result,
                )
            return AssertionExecutionResult("PASS", "", "Assertion passed", command=command, command_result=result)

        return AssertionExecutionResult(
            "UNKNOWN",
            ASSERTION_NOT_IMPLEMENTED,
            f"Assertion '{assertion_type}' is declared but not implemented in the runtime executor",
            evidence={
                "type": "assertion_action",
                "assertion_type": assertion_type,
                "value": value,
                "params": params,
            },
        )
