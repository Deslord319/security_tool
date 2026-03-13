from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from scripts.e2e.core.failures import COMMAND_FAILED, FLOW_NOT_IMPLEMENTED
from scripts.e2e.adapters.security_tool.pages import PAGE_MARKERS, PAGE_REGISTRY
from scripts.e2e.adapters.security_tool.runtime_config import load_runtime_config
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
        self.runtime_config = load_runtime_config()

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

        if flow_ref == "app.launch":
            launch_args = [
                "aa start",
                f"-a {self.main_ability}",
                f"-b {self.bundle_name}",
                "-m entry",
            ]
            if params.get("skip_startup_auth", self.runtime_config.skip_startup_auth):
                launch_args.append("--ps skip_startup_auth 1")
            if params.get("ui_route"):
                launch_args.append(f"--ps ui_route {params['ui_route']}")
            if params.get("ui_theme"):
                launch_args.append(f"--ps ui_theme {params['ui_theme']}")
            shell_command = " ".join(launch_args)
            command = self.hdc.command(["shell", shell_command])
            if self.dry_run:
                return FlowExecutionResult("PASS", "", "Dry run: skipped execution", command=command)
            result = self.hdc.shell(shell_command, params.get("timeout_sec", 20))
            if result.returncode != 0:
                return FlowExecutionResult("FAIL", COMMAND_FAILED, "App launch command failed", command=command, command_result=result)
            password_result = self.mcp.input_password_if_prompted(bundle_name=self.bundle_name)
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
            execution = self._from_mcp(request)
            if not self.dry_run and execution.status == "PASS":
                marker_text = PAGE_MARKERS.get(page_id, "")
                page_text = PAGE_REGISTRY.get(page_id, "")
                wait_result = self.mcp.wait_for_page(
                    bundle_name=self.bundle_name,
                    page_id=page_id,
                    marker_text=marker_text,
                    page_text=page_text,
                    route_element_id=f"route-page-{page_id}",
                )
                evidence = dict(execution.evidence or {})
                evidence["page_wait"] = wait_result
                execution.evidence = evidence
                if wait_result["status"] == "UNKNOWN":
                    execution.status = "UNKNOWN"
                    execution.failure_code = wait_result.get("failure_code", execution.failure_code)
                    execution.message = wait_result.get("message", execution.message)
            return execution

        if flow_ref == "theme_menu.open":
            request = MpcActionRequest(action="open_top_menu", params=params, expected="Theme and settings menu is visible")
            return self._from_mcp(request)

        if flow_ref == "ui.capture_screenshot":
            request = MpcActionRequest(action="capture_screenshot", params=params, expected="Screenshot saved successfully")
            return self._from_mcp(request)

        if flow_ref == "firewall.toggle_status":
            before = None if self.dry_run else self._read_toggle_state()
            request = MpcActionRequest(action="toggle_firewall", params=params, expected="Firewall switch state changes")
            execution = self._from_mcp(request)
            after = None if self.dry_run or execution.status != "PASS" else self._read_toggle_state()
            return self._attach_toggle_state_evidence(execution, before=before, after=after)

        if flow_ref == "firewall.open_rules":
            request = MpcActionRequest(action="open_firewall_rules", params=params, expected="Firewall rule detail page is visible")
            return self._from_mcp(request)

        if flow_ref == "firewall.add_rule":
            request = MpcActionRequest(action="add_firewall_rule", params=params, expected="Firewall rule is added")
            return self._from_mcp(request)

        if flow_ref == "firewall.find_rule":
            request = MpcActionRequest(action="find_firewall_rule", params=params, expected="Target firewall rule exists")
            return self._from_mcp(request)

        if flow_ref == "firewall.delete_rule":
            request = MpcActionRequest(action="delete_firewall_rule", params=params, expected="Firewall rule is removed")
            return self._from_mcp(request)

        if flow_ref == "browser.open_url":
            request = MpcActionRequest(action="open_browser_url", params=params, expected="Browser opens target URL")
            return self._from_mcp(request)

        if flow_ref == "peripheral.toggle_interface":
            feature = str(params.get("feature", "")).lower()
            feature_text_map = {
                "usb": "USB",
                "bluetooth": "蓝牙",
                "wifi": "Wi-Fi",
                "hdc": "HDC",
            }
            before = None if self.dry_run else self._read_toggle_state(text=feature_text_map.get(feature, ""))
            request = MpcActionRequest(action="toggle_peripheral_interface", params=params, expected="Peripheral interface state changes")
            execution = self._from_mcp(request)
            after = None if self.dry_run or execution.status != "PASS" else self._read_toggle_state(text=feature_text_map.get(feature, ""))
            return self._attach_toggle_state_evidence(execution, before=before, after=after)

        if flow_ref == "peripheral.select_usb_storage_policy":
            request = MpcActionRequest(action="select_usb_storage_policy", params=params, expected="USB storage policy changes")
            return self._from_mcp(request)

        if flow_ref == "peripheral.open_usb_whitelist_dialog":
            request = MpcActionRequest(action="open_usb_whitelist_dialog", params=params, expected="USB whitelist dialog is visible")
            return self._from_mcp(request)

        if flow_ref == "peripheral.add_usb_whitelist":
            request = MpcActionRequest(action="add_usb_whitelist", params=params, expected="USB whitelist item is added")
            return self._from_mcp(request)

        if flow_ref == "peripheral.open_bluetooth_whitelist_dialog":
            request = MpcActionRequest(action="open_bluetooth_whitelist_dialog", params=params, expected="Bluetooth whitelist dialog is visible")
            return self._from_mcp(request)

        if flow_ref == "peripheral.add_bluetooth_whitelist":
            request = MpcActionRequest(action="add_bluetooth_whitelist", params=params, expected="Bluetooth whitelist item is added")
            return self._from_mcp(request)

        if flow_ref == "peripheral.open_usb_blacklist_dialog":
            request = MpcActionRequest(action="open_usb_blacklist_dialog", params=params, expected="USB blacklist dialog is visible")
            return self._from_mcp(request)

        if flow_ref == "peripheral.add_usb_blacklist":
            request = MpcActionRequest(action="add_usb_blacklist", params=params, expected="USB blacklist item is added")
            return self._from_mcp(request)

        if flow_ref == "identity.update_password_policy":
            request = MpcActionRequest(action="update_password_policy", params=params, expected="Identity password policy is updated")
            return self._from_mcp(request)

        if flow_ref == "identity.update_domain_policy":
            request = MpcActionRequest(action="update_domain_account_policy", params=params, expected="Identity domain policy is updated")
            return self._from_mcp(request)

        if flow_ref == "logs.export":
            request = MpcActionRequest(action="export_logs", params=params, expected="Log export flow completes")
            return self._from_mcp(request)

        if flow_ref == "logs.change_any_policy":
            request = MpcActionRequest(action="change_any_policy", params=params, expected="A policy change is applied")
            return self._from_mcp(request)

        if flow_ref == "tool_settings.toggle_startup_auth":
            before = None if self.dry_run else self._read_toggle_state(text="启动时身份校验")
            request = MpcActionRequest(action="toggle_startup_auth", params=params, expected="Startup auth switch state changes")
            execution = self._from_mcp(request)
            after = None if self.dry_run or execution.status != "PASS" else self._read_toggle_state(text="启动时身份校验")
            return self._attach_toggle_state_evidence(execution, before=before, after=after)

        if flow_ref == "tool_settings.select_auth_method":
            request = MpcActionRequest(action="select_auth_method", params=params, expected="Tool settings auth method is selected")
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
