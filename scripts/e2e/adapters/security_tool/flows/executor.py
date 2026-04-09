from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from scripts.e2e.adapters.security_tool.operations import resolve_operation_binding
from scripts.e2e.core.failures import COMMAND_FAILED, FLOW_NOT_IMPLEMENTED
from scripts.e2e.drivers.hdc_driver import HdcDriver
from scripts.e2e.drivers.mcp_driver import McpDriver, McpExecutionResult, MpcActionRequest


@dataclass
class FlowExecutionResult:
    status: str
    failure_code: str
    message: str
    command: list[str] | None = None
    command_result: Any | None = None
    evidence: dict[str, Any] | None = None


class SecurityToolFlowExecutor:
    def __init__(self, hdc: HdcDriver, mcp: McpDriver, dry_run: bool, bundle_name: str, main_ability: str):
        self.hdc = hdc
        self.mcp = mcp
        self.dry_run = dry_run
        self.bundle_name = bundle_name
        self.main_ability = main_ability

    def _read_toggle_state(self, *, text: str = "", element_id: str = "") -> dict[str, Any]:
        return self.mcp.get_toggle_state(
            bundle_name=self.bundle_name,
            text=text,
            element_id=element_id,
        )

    def _attach_toggle_state_evidence(
        self,
        execution: FlowExecutionResult,
        *,
        before: dict[str, Any] | None,
        after: dict[str, Any] | None,
    ) -> FlowExecutionResult:
        evidence = dict(execution.evidence or {})
        if before is not None:
            evidence["before_toggle_state"] = before
        if after is not None:
            evidence["after_toggle_state"] = after
        execution.evidence = evidence
        return execution

    def _from_mcp(self, request: MpcActionRequest) -> FlowExecutionResult:
        execution: McpExecutionResult = self.mcp.execute(request)
        return FlowExecutionResult(
            status=execution.status,
            failure_code=execution.failure_code,
            message=execution.message,
            command=execution.command,
            command_result=None,
            evidence=execution.evidence,
        )

    def execute(self, flow_ref: str, params: dict[str, Any] | None = None) -> FlowExecutionResult:
        params = params or {}

        binding = resolve_operation_binding(flow_ref, params)
        if binding is not None:
            before = None if self.dry_run or not binding.toggle_probe else self._read_toggle_state(**binding.toggle_probe)
            execution = self._from_mcp(
                MpcActionRequest(
                    action=binding.bridge_action,
                    params=binding.params,
                    expected=binding.expected,
                )
            )
            after = None
            if not self.dry_run and execution.status == "PASS" and binding.toggle_probe:
                after = self._read_toggle_state(**binding.toggle_probe)
            if binding.toggle_probe:
                return self._attach_toggle_state_evidence(execution, before=before, after=after)
            return execution

        if flow_ref == "app.launch":
            launch_args = [
                "aa start",
                f"-a {self.main_ability}",
                f"-b {self.bundle_name}",
                "-m entry",
            ]
            shell_command = " ".join(launch_args)
            command = self.hdc.command(["shell", shell_command])
            if self.dry_run:
                return FlowExecutionResult("PASS", "", "Dry run: skipped execution", command=command)
            result = self.hdc.shell(shell_command, params.get("timeout_sec", 20))
            if result.returncode != 0:
                return FlowExecutionResult("FAIL", COMMAND_FAILED, "App launch command failed", command=command, command_result=result)
            password_result = self.mcp.input_password_if_prompted(bundle_name=self.bundle_name)
            require_auth_prompt = bool(params.get("require_auth_prompt", False))
            require_auth_handled = bool(params.get("require_auth_handled", require_auth_prompt))
            if require_auth_prompt and not password_result.get("prompt_detected", False):
                return FlowExecutionResult(
                    "FAIL",
                    COMMAND_FAILED,
                    "Startup auth prompt was required but not detected",
                    command=command,
                    command_result=result,
                    evidence={"password_prompt": password_result},
                )
            if require_auth_handled and not password_result.get("handled", False):
                return FlowExecutionResult(
                    "FAIL",
                    COMMAND_FAILED,
                    "Startup auth prompt was required but not handled successfully",
                    command=command,
                    command_result=result,
                    evidence={"password_prompt": password_result},
                )
            return FlowExecutionResult(
                "PASS",
                "",
                "Flow executed",
                command=command,
                command_result=result,
                evidence={"password_prompt": password_result},
            )

        if flow_ref == "navigation.open_page":
            page_id = params.get("page_id", "")
            request = MpcActionRequest(action="navigate_page", params={"page_id": page_id, **params}, expected=f"Navigate to page {page_id}")
            return self._from_mcp(request)

        if flow_ref == "theme_menu.open":
            request = MpcActionRequest(action="open_top_menu", params=params, expected="Theme and settings menu is visible")
            return self._from_mcp(request)

        if flow_ref == "ui.capture_screenshot":
            request = MpcActionRequest(action="capture_screenshot", params=params, expected="Screenshot saved successfully")
            return self._from_mcp(request)

        if flow_ref == "ui.click_text":
            request = MpcActionRequest(action="click_text", params=params, expected=f"Click visible text {params.get('text', '')}")
            return self._from_mcp(request)

        if flow_ref == "ui.click_element":
            request = MpcActionRequest(action="click_element", params=params, expected="Click visible element")
            return self._from_mcp(request)

        if flow_ref == "ui.scroll_until_text":
            result = self.mcp.scroll_until_text(
                bundle_name=self.bundle_name,
                text=str(params.get("text", "")),
                direction=str(params.get("direction", "up")),
                max_swipes=int(params.get("max_swipes", 8)),
                timeout_ms=int(params.get("timeout_ms", 1500)),
            )
            return FlowExecutionResult(
                status=result.get("status", "UNKNOWN"),
                failure_code=result.get("failure_code", ""),
                message=result.get("message", ""),
                evidence=result.get("evidence", {}),
            )

        if flow_ref == "ui.press_key":
            request = MpcActionRequest(action="press_key", params=params, expected=f"Press device key {params.get('key', '')}")
            return self._from_mcp(request)

        if flow_ref == "firewall.toggle_status":
            before = None if self.dry_run else self._read_toggle_state()
            request = MpcActionRequest(action="toggle_firewall", params=params, expected="Firewall switch state changes")
            execution = self._from_mcp(request)
            after = None if self.dry_run or execution.status != "PASS" else self._read_toggle_state()
            return self._attach_toggle_state_evidence(execution, before=before, after=after)

        if flow_ref == "browser.open_url":
            request = MpcActionRequest(action="open_browser_url", params=params, expected="Browser opens target URL")
            return self._from_mcp(request)

        if flow_ref == "logs.export":
            request = MpcActionRequest(action="export_logs", params=params, expected="Log export flow completes")
            return self._from_mcp(request)

        if flow_ref == "logs.change_any_policy":
            request = MpcActionRequest(action="change_any_policy", params=params, expected="A policy change is applied")
            return self._from_mcp(request)

        if flow_ref == "tool_settings.set_password":
            request = MpcActionRequest(action="set_tool_password", params=params, expected="Tool password is saved")
            return self._from_mcp(request)

        if flow_ref == "tool_settings.save":
            request = MpcActionRequest(action="save_tool_settings", params=params, expected="Tool settings are saved")
            return self._from_mcp(request)

        return FlowExecutionResult(
            "UNKNOWN",
            FLOW_NOT_IMPLEMENTED,
            f"Flow '{flow_ref}' is declared but not implemented in the runtime executor",
            evidence={"type": "flow_action", "ref": flow_ref, "params": params},
        )
