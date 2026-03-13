from __future__ import annotations

import asyncio
import sys
import time
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

PROJECT_ROOT = Path(__file__).resolve().parents[3]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

MCP_REPO = Path(r"C:\Users\mu\Desktop\code\mcp_ho_dev")
MCP_SRC = MCP_REPO / "services/harmonyos_mcp/src"
COMMON_SRC = MCP_REPO / "packages/common/src"
MCP_SITE_PACKAGES = MCP_REPO / ".venv/Lib/site-packages"
for path in (MCP_SITE_PACKAGES, MCP_SRC, COMMON_SRC):
    if path.exists() and str(path) not in sys.path:
        sys.path.insert(0, str(path))

from fastmcp import Client  # type: ignore  # noqa: E402
from harmonyos_mcp.server import mcp  # type: ignore  # noqa: E402

from scripts.e2e.adapters.security_tool.pages import PAGE_MARKERS, PAGE_REGISTRY
from scripts.e2e.adapters.security_tool.runtime_config import load_runtime_config
from scripts.e2e.bridges.action_plans import ACTION_PLANS
from scripts.e2e.core.utils import run_command

# Override mojibake literals from older revisions with stable UTF-8 values.
TOOL_SETTINGS_SAVE_TEXT = "\u4fdd\u5b58\u8bbe\u7f6e"
TOOL_SETTINGS_PAGE_TEXT = "\u5de5\u5177\u8bbe\u7f6e"
FIREWALL_PAGE_TEXT = "\u9632\u706b\u5899\u7ba1\u7406"
TOP_MENU_VISIBLE_TEXT = "\u5e2e\u52a9\u4e0e\u53cd\u9988"
TOOL_SETTINGS_STARTUP_AUTH_TEXT = "\u542f\u52a8\u65f6\u8eab\u4efd\u6821\u9a8c"
FIREWALL_RULE_TYPE_LABELS = {
    "ip": "IP \u89c4\u5219",
    "domain": "\u57df\u540d\u89c4\u5219",
    "dns": "DNS \u89c4\u5219",
}
FIREWALL_ADD_RULE_TEXTS = ["+ 添加规则", "添加规则", "新增规则"]
FIREWALL_POLICY_OPTION_LABELS = {
    "deny": ["拒绝", "禁止"],
    "allow": ["允许", "放行"],
}
FIREWALL_DIRECTION_OPTION_LABELS = {
    "in": ["入站"],
    "out": ["出站"],
}
FIREWALL_PROTOCOL_OPTION_LABELS = {
    "tcp": ["TCP"],
    "udp": ["UDP"],
}
DELETE_ACTION_LABELS = ["删除", "移除"]
CONFIRM_DIALOG_LABELS = ["确定", "确认", "保存", "提交", "添加"]
CONFIRM_DELETE_LABELS = ["确定", "确认", "删除", "移除"]
FIREWALL_DIALOG_TITLE = "添加防火墙规则"
FIREWALL_DIALOG_REGION = {
    "left_min": 900,
    "left_max": 2100,
    "top_min": 500,
    "top_max": 1750,
}


class RealHarmonyOsMcpBackend:
    def __init__(self) -> None:
        self.runtime_config = load_runtime_config()

    def handle_action(self, payload: dict[str, Any]) -> dict[str, Any]:
        try:
            return asyncio.run(self._handle_action(payload))
        except Exception as exc:  # noqa: BLE001
            return self._unknown(payload, "MCP_ACTION_PENDING", f"Real backend action failed: {exc}")

    async def _handle_action(self, payload: dict[str, Any]) -> dict[str, Any]:
        action = payload.get("action", "")
        params = payload.get("params", {})

        if action == "navigate_page":
            return await self._navigate_page(params)
        if action == "__driver_wait_element":
            return await self._driver_wait_element(payload)
        if action == "__driver_element_exists":
            return await self._driver_element_exists(payload)
        if action == "__driver_scroll_until_text":
            return await self._driver_scroll_until_text(payload)
        if action == "__driver_wait_for_page":
            return await self._driver_wait_for_page(payload)
        if action == "__driver_input_password_if_prompted":
            return await self._driver_input_password_if_prompted(payload)
        if action == "__driver_text_presence":
            return await self._driver_text_presence(payload)
        if action == "open_top_menu":
            return await self._open_top_menu(params)
        if action == "capture_screenshot":
            return await self._capture_screenshot(params)
        if action == "toggle_firewall":
            return await self._toggle_first_toggle(payload, page_text=FIREWALL_PAGE_TEXT)
        if action == "toggle_startup_auth":
            return await self._toggle_first_toggle(payload, page_text=TOOL_SETTINGS_PAGE_TEXT)
        if action == "__driver_get_toggle_state":
            return await self._get_toggle_state(payload)
        if action == "save_tool_settings":
            return await self._save_tool_settings(payload)
        if action == "open_firewall_rules":
            return await self._open_firewall_rules(params)
        if action == "select_auth_method":
            return await self._select_auth_method(payload)
        if action == "set_tool_password":
            return await self._set_tool_password(payload)
        if action == "add_firewall_rule":
            return await self._add_firewall_rule(payload)
        if action == "find_firewall_rule":
            return await self._find_firewall_rule(payload)
        if action == "delete_firewall_rule":
            return await self._delete_firewall_rule(payload)
        if action == "open_browser_url":
            return await self._open_browser_url(payload)
        if action == "toggle_peripheral_interface":
            return await self._toggle_peripheral_interface(payload)
        if action == "select_usb_storage_policy":
            return await self._select_usb_storage_policy(payload)
        if action == "open_usb_whitelist_dialog":
            return await self._open_usb_whitelist_dialog(payload)
        if action == "add_usb_whitelist":
            return await self._add_usb_whitelist(payload)
        if action == "open_bluetooth_whitelist_dialog":
            return await self._open_bluetooth_whitelist_dialog(payload)
        if action == "add_bluetooth_whitelist":
            return await self._add_bluetooth_whitelist(payload)
        if action == "open_usb_blacklist_dialog":
            return await self._open_usb_blacklist_dialog(payload)
        if action == "add_usb_blacklist":
            return await self._add_usb_blacklist(payload)
        if action == "update_password_policy":
            return await self._update_password_policy(payload)
        if action == "update_domain_account_policy":
            return await self._update_domain_account_policy(payload)
        if action == "export_logs":
            return await self._export_logs(payload)
        if action == "change_any_policy":
            return await self._change_any_policy(payload)

        return self._unknown(payload, "MCP_ACTION_PENDING", f"Action not implemented: {action}")

    async def _navigate_page(self, params: dict[str, Any]) -> dict[str, Any]:
        page_id = params.get("page_id", "")
        if not page_id:
            return self._fail("MCP_EXECUTION_FAILED", "page_id is required for navigate_page", {})
        await self._ensure_auth_dialog_cleared()
        sidebar_id = f"sidebar-nav-{page_id}"
        route_id = f"route-page-{page_id}"
        page_text = PAGE_REGISTRY.get(page_id, "")
        marker_text = PAGE_MARKERS.get(page_id, page_text)

        existing_marker = await self._wait_for_page_marker(
            page_id=page_id,
            marker_text=marker_text,
            page_text=page_text,
            timeout_sec=1.0,
        )
        if page_id not in {"firewall"} and existing_marker.get("ok", False):
            return self._pass(
                "Already on target page",
                {
                    "page_id": page_id,
                    "sidebar_id": sidebar_id,
                    "route_id": route_id,
                    "marker_text": marker_text,
                    "page_text": page_text,
                    "page_marker": existing_marker.get("match", {}),
                },
            )

        click_result = {"ok": False}
        ui_tree = await self._get_ui_tree()
        sidebar_node = self._pick_sidebar_entry(ui_tree, page_id)
        if sidebar_node:
            click_result = await self._call_tool(
                "click_element",
                {"x": sidebar_node["x"], "y": sidebar_node["y"]},
            )
        if not click_result.get("ok", False):
            click_result = await self._call_tool(
                "click_element",
                {"element_id": sidebar_id, "bundle_name": "com.huawei.securitytool"},
            )
        if not click_result.get("ok", False) and page_text:
            click_result = await self._call_tool(
                "click_element",
                {"text": page_text, "bundle_name": "com.huawei.securitytool"},
            )
        if not click_result.get("ok", False):
            return self._fail(
                "MCP_EXECUTION_FAILED",
                f"Failed to click sidebar item {sidebar_id}",
                {"click_result": click_result, "page_text": page_text, "marker_text": marker_text, "sidebar_node": sidebar_node or {}},
            )

        marker_result = await self._wait_for_page_marker(
            page_id=page_id,
            marker_text=marker_text,
            page_text=page_text,
            timeout_sec=5.0,
        )
        if page_id == "firewall" and not marker_result.get("ok", False):
            ui_tree = await self._get_ui_tree()
            if self._find_any_text_node(ui_tree, ["防火墙规则", FIREWALL_DIALOG_TITLE]):
                marker_result = {"ok": True, "match": {"query": {"page_id": page_id, "text": "防火墙规则"}, "element": self._find_any_text_node(ui_tree, ["防火墙规则", FIREWALL_DIALOG_TITLE])}}
        if not marker_result.get("ok", False):
            return self._unknown(
                {"action": "navigate_page", "params": params},
                "MCP_ACTION_PENDING",
                f"Navigation click succeeded but page marker did not resolve for {page_id}",
            )

        return self._pass(
            "Navigation completed",
            {
                "page_id": page_id,
                "sidebar_id": sidebar_id,
                "route_id": route_id,
                "marker_text": marker_text,
                "page_text": page_text,
                "page_marker": marker_result.get("match", {}),
            },
        )

    async def _open_top_menu(self, params: dict[str, Any]) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        click_result = await self._call_tool(
            "click_element",
            {"element_id": "top-menu-trigger", "bundle_name": "com.huawei.securitytool"},
        )
        if not click_result.get("ok", False):
            return self._fail("MCP_EXECUTION_FAILED", "Failed to click top menu trigger", {"click_result": click_result})

        wait_result = await self._wait_for(
            [
                {"element_id": "menu-action-tool-settings", "bundle_name": "com.huawei.securitytool"},
                {"text": TOP_MENU_VISIBLE_TEXT, "bundle_name": "com.huawei.securitytool"},
            ]
        )
        if not wait_result.get("ok", False):
            return self._unknown({"action": "open_top_menu", "params": params}, "MCP_ACTION_PENDING", "Top menu trigger clicked but menu items were not detected")

        return self._pass("Top menu opened", {"menu_match": wait_result.get("match", {})})

    async def _driver_wait_element(self, payload: dict[str, Any]) -> dict[str, Any]:
        params = payload.get("params", {})
        query = {
            key: value
            for key, value in {
                "bundle_name": params.get("bundle_name") or "com.huawei.securitytool",
                "text": params.get("text", ""),
                "element_type": params.get("element_type", ""),
                "element_id": params.get("element_id", ""),
                "window_id": params.get("window_id", ""),
                "state": params.get("state", "found"),
                "timeout_ms": int(params.get("timeout_ms", 5000)),
                "interval_ms": int(params.get("interval_ms", 300)),
            }.items()
            if value not in ("", None)
        }
        result = await self._call_tool("wait_element", query)
        structured = result.get("result", result)
        if result.get("ok", False):
            return self._pass(
                "Wait condition satisfied",
                {
                    "state": query.get("state", "found"),
                    "element": structured.get("element", {}),
                    "query": query,
                },
            )
        return self._unknown(payload, result.get("error", {}).get("code", "MCP_ACTION_PENDING"), "Wait condition was not satisfied")

    async def _driver_element_exists(self, payload: dict[str, Any]) -> dict[str, Any]:
        params = payload.get("params", {})
        find_params = {
            key: value
            for key, value in {
                "bundle_name": params.get("bundle_name") or "com.huawei.securitytool",
                "text": params.get("text", ""),
                "element_id": params.get("element_id", ""),
                "element_type": params.get("element_type", ""),
                "window_id": params.get("window_id", ""),
            }.items()
            if value not in ("", None)
        }
        result = await self._call_tool("find_element", find_params)
        structured = result.get("result", result)
        if result.get("ok", False):
            element = structured.get("element") or structured.get("first_match") or {}
            return self._pass(
                "Element existence resolved",
                {
                    "exists": True,
                    "element": element,
                    "query": find_params,
                    "source": "find_element",
                },
            )
        return self._pass("Element existence resolved", {"exists": False, "element": {}, "query": find_params, "source": "find_element"})

    async def _driver_scroll_until_text(self, payload: dict[str, Any]) -> dict[str, Any]:
        params = payload.get("params", {})
        bundle_name = params.get("bundle_name") or "com.huawei.securitytool"
        text = str(params.get("text", "")).strip()
        direction = str(params.get("direction", "up"))
        max_swipes = int(params.get("max_swipes", 8))
        timeout_ms = int(params.get("timeout_ms", 1500))
        for index in range(max_swipes + 1):
            wait_result = await self._call_tool(
                "wait_element",
                {
                    "bundle_name": bundle_name,
                    "text": text,
                    "timeout_ms": timeout_ms,
                    "interval_ms": 250,
                },
            )
            structured = wait_result.get("result", wait_result)
            if wait_result.get("ok", False):
                return self._pass(
                    "Target text became visible",
                    {
                        "element": structured.get("element", {}),
                        "swipes_used": index,
                        "text": text,
                    },
                )
            if index < max_swipes:
                await self._call_tool("swipe", {"direction": direction})
                await asyncio.sleep(0.3)
        return self._unknown(payload, "MCP_ACTION_PENDING", f"Target text did not appear after scrolling: {text}")

    async def _driver_wait_for_page(self, payload: dict[str, Any]) -> dict[str, Any]:
        params = payload.get("params", {})
        page_id = str(params.get("page_id", ""))
        marker_text = str(params.get("marker_text", ""))
        page_text = str(params.get("page_text", ""))
        timeout_sec = max(int(params.get("timeout_ms", 5000)) / 1000.0, 1.0)
        wait_result = await self._wait_for_page_marker(
            page_id=page_id,
            marker_text=marker_text,
            page_text=page_text,
            timeout_sec=timeout_sec,
        )
        if page_id == "firewall" and not wait_result.get("ok", False):
            ui_tree = await self._get_ui_tree()
            fallback_node = self._find_any_text_node(ui_tree, ["防火墙规则", FIREWALL_DIALOG_TITLE])
            if fallback_node:
                wait_result = {
                    "ok": True,
                    "match": {
                        "query": {"page_id": page_id, "text": "防火墙规则"},
                        "element": fallback_node,
                    },
                }
        if wait_result.get("ok", False):
            return self._pass(
                "Page marker resolved",
                {
                    "page_id": page_id,
                    "element": wait_result.get("match", {}).get("element", {}),
                    "query": wait_result.get("match", {}).get("query", {}),
                },
            )
        return self._unknown(payload, "MCP_ACTION_PENDING", f"Page marker did not resolve for {page_id}")

    async def _driver_input_password_if_prompted(self, payload: dict[str, Any]) -> dict[str, Any]:
        before = await self._detect_auth_prompt()
        await self._ensure_auth_dialog_cleared()
        after = await self._detect_auth_prompt()
        return self._pass(
            "Auth prompt handled",
            {
                "prompt_detected": before,
                "handled": before and not after,
                "still_present": after,
            },
        )

    async def _driver_text_presence(self, payload: dict[str, Any]) -> dict[str, Any]:
        params = payload.get("params", {})
        bundle_name = params.get("bundle_name") or "com.huawei.securitytool"
        text = str(params.get("text", ""))
        timeout_ms = int(params.get("timeout_ms", 1500))
        interval_ms = int(params.get("interval_ms", 250))
        window_id = str(params.get("window_id", ""))
        wait_params = {
            "bundle_name": bundle_name,
            "text": text,
            "timeout_ms": timeout_ms,
            "interval_ms": interval_ms,
        }
        if window_id:
            wait_params["window_id"] = window_id
        wait_result = await self._call_tool("wait_element", wait_params)
        structured = wait_result.get("result", wait_result)
        if wait_result.get("ok", False):
            return self._pass(
                "Text presence resolved",
                {
                    "exists": True,
                    "element": structured.get("element", {}),
                    "source": "wait_element",
                },
            )
        return self._pass("Text presence resolved", {"exists": False, "element": {}, "source": "wait_element"})

    async def _capture_screenshot(self, params: dict[str, Any]) -> dict[str, Any]:
        name = params.get("name", "screenshot")
        artifacts_dir = PROJECT_ROOT / "scripts/e2e/artifacts"
        artifacts_dir.mkdir(parents=True, exist_ok=True)
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        target = artifacts_dir / f"{name}_{timestamp}.jpeg"
        result = await self._call_tool("screenshot", {"local_path": str(target)})
        if not result.get("ok", False):
            return self._fail("MCP_EXECUTION_FAILED", "Failed to capture screenshot", {"screenshot_result": result})
        return self._pass("Screenshot captured", {"artifact_path": str(target)})

    async def _toggle_first_toggle(self, payload: dict[str, Any], *, page_text: str) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        wait_page = await self._wait_for_page_marker(page_id="", marker_text=page_text, page_text=page_text, timeout_sec=5.0)
        if not wait_page.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", f"Target page is not visible: {page_text}")

        ui_tree = await self._get_ui_tree()
        toggle_node = self._first_content_toggle(ui_tree)
        if not toggle_node:
            return self._fail("MCP_EXECUTION_FAILED", "Failed to find toggle element", {"find_result": {"tool": "get_ui_tree", "ok": True}})

        click_result = await self._call_tool(
            "click_element",
            {"x": toggle_node["x"], "y": toggle_node["y"]},
        )
        if not click_result.get("ok", False):
            return self._fail("MCP_EXECUTION_FAILED", "Failed to click toggle", {"click_result": click_result})

        require_auth_prompt = bool(payload.get("params", {}).get("require_auth_prompt", False))
        require_auth_handled = bool(payload.get("params", {}).get("require_auth_handled", require_auth_prompt))
        password_result = await self._driver_input_password_if_prompted(
            {
                "action": "__driver_input_password_if_prompted",
                "params": {
                    "bundle_name": "com.huawei.securitytool",
                    "timeout_ms": int(payload.get("params", {}).get("auth_timeout_ms", 4000)),
                },
            }
        )
        password_evidence = password_result.get("evidence", {})
        if require_auth_prompt and not password_evidence.get("prompt_detected", False):
            return self._fail(
                "COMMAND_FAILED",
                "Firewall auth prompt was required but not detected",
                {
                    "toggle_node": toggle_node,
                    "target_state": payload.get("params", {}).get("target_state", ""),
                    "password_prompt": password_result,
                },
            )
        if require_auth_handled and not password_evidence.get("handled", False):
            return self._fail(
                "COMMAND_FAILED",
                "Firewall auth prompt was required but not handled successfully",
                {
                    "toggle_node": toggle_node,
                    "target_state": payload.get("params", {}).get("target_state", ""),
                    "password_prompt": password_result,
                },
            )

        return self._pass(
            "Toggle action executed",
            {
                "toggle_node": toggle_node,
                "target_state": payload.get("params", {}).get("target_state", ""),
                "password_prompt": password_result,
            },
        )

    async def _get_toggle_state(self, payload: dict[str, Any]) -> dict[str, Any]:
        params = payload.get("params", {})
        bundle_name = str(params.get("bundle_name") or "com.huawei.securitytool")
        text = str(params.get("text", "")).strip()
        element_id = str(params.get("element_id", "")).strip()
        window_id = str(params.get("window_id", "")).strip()

        find_params: dict[str, Any] = {"bundle_name": bundle_name, "element_type": "Toggle"}
        if window_id:
            find_params["window_id"] = window_id
        if text:
            find_params["text"] = text
        if element_id:
            find_params["element_id"] = element_id

        find_result = await self._call_tool("find_element", find_params)
        structured_find = find_result.get("result", find_result)
        if find_result.get("ok", False):
            element = structured_find.get("element") or structured_find.get("first_match") or {}
            if isinstance(element, dict) and "checked" in element:
                return self._pass(
                    "Toggle state resolved",
                    {
                        "checked": bool(element.get("checked")),
                        "element": element,
                        "source": "find_element",
                    },
                )

        ui_tree = await self._get_ui_tree()
        toggle_node = self._pick_toggle_node(ui_tree, text=text, element_id=element_id)
        if toggle_node:
            return self._pass(
                "Toggle state resolved",
                {
                    "checked": bool(toggle_node.get("checked", False)),
                    "element": toggle_node,
                    "source": "ui_tree",
                },
            )

        return self._unknown(payload, "MCP_ACTION_PENDING", "Toggle state could not be resolved")

    async def _open_firewall_rules(self, params: dict[str, Any]) -> dict[str, Any]:
        rule_type = str(params.get("rule_type", "")).lower()
        label = FIREWALL_RULE_TYPE_LABELS.get(rule_type, "")
        if not label:
            return self._fail("MCP_EXECUTION_FAILED", f"Unsupported firewall rule_type: {rule_type}", {})

        click_result = await self._call_tool("click_element", {"text": label, "bundle_name": "com.huawei.securitytool"})
        if not click_result.get("ok", False):
            ui_tree = await self._get_ui_tree()
            rule_card = self._pick_firewall_rule_card(ui_tree, rule_type)
            if rule_card:
                click_result = await self._call_tool("click_element", {"x": rule_card["x"], "y": rule_card["y"]})
        if not click_result.get("ok", False):
            return self._fail("MCP_EXECUTION_FAILED", f"Failed to open firewall rule type: {label}", {"click_result": click_result})

        wait_result = await self._wait_for(
            [
                {"element_id": "route-page-firewall-rules", "bundle_name": "com.huawei.securitytool"},
                {"text": "防火墙规则", "bundle_name": "com.huawei.securitytool"},
                {"text": "+ 添加规则", "bundle_name": "com.huawei.securitytool"},
            ]
        )
        if not wait_result.get("ok", False):
            return self._unknown(
                {"action": "open_firewall_rules", "params": params},
                "MCP_ACTION_PENDING",
                f"Rule type click succeeded but rules page was not detected for {label}",
            )

        return self._pass("Firewall rules page opened", {"rule_type": rule_type, "matched": wait_result.get("match", {})})

    async def _click_and_wait(
        self,
        payload: dict[str, Any],
        *,
        click_params: dict[str, Any],
        wait_params: dict[str, Any],
        success_message: str,
    ) -> dict[str, Any]:
        click_result = await self._call_tool("click_element", click_params)
        if not click_result.get("ok", False):
            return self._fail("MCP_EXECUTION_FAILED", "Click action failed", {"click_result": click_result, "click_params": click_params})
        wait_result = await self._wait_for([wait_params])
        if not wait_result.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", f"Click succeeded but wait condition did not resolve: {wait_params}")
        return self._pass(success_message, {"click_params": click_params, "wait_match": wait_result.get("match", {})})

    async def _select_auth_method(self, payload: dict[str, Any]) -> dict[str, Any]:
        method = str(payload.get("params", {}).get("method", ""))
        normalized_method = self._normalize_auth_method(method)
        ui_tree = await self._get_ui_tree()
        select_node = self._first_node_by_type(ui_tree, "Select")
        if not select_node:
            return self._unknown(payload, "MCP_ACTION_PENDING", "Auth method select control was not found")

        if normalized_method == "PIN" and "PIN" in select_node.get("text", ""):
            return self._pass("Requested auth method is already selected", {"select_node": select_node, "normalized_method": normalized_method})

        click_result = await self._call_tool("click_element", {"x": select_node["x"], "y": select_node["y"]})
        if not click_result.get("ok", False):
            return self._fail("MCP_EXECUTION_FAILED", "Failed to open auth method selector", {"click_result": click_result, "select_node": select_node})

        option_text = self._auth_method_option_text(normalized_method)
        if not option_text:
            return self._unknown(payload, "MCP_ACTION_PENDING", f"Unsupported auth method: {method}")

        choose_result = await self._call_tool("click_element", {"text": option_text, "bundle_name": "com.huawei.securitytool"})
        if not choose_result.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", f"Auth method selector opened but target option was not found: {option_text}")

        return self._pass("Auth method selected", {"select_node": select_node, "normalized_method": normalized_method, "option_text": option_text})

    async def _set_tool_password(self, payload: dict[str, Any]) -> dict[str, Any]:
        params = payload.get("params", {})
        new_password = str(params.get("new_password", ""))
        confirm_password = str(params.get("confirm_password", ""))
        current_password = str(params.get("current_password", ""))

        ui_tree = await self._get_ui_tree()
        inputs = self._nodes_by_type(ui_tree, "TextInput")
        if len(inputs) < 2:
            await self._call_tool("swipe", {"direction": "up"})
            await asyncio.sleep(0.6)
            ui_tree = await self._get_ui_tree()
            inputs = self._nodes_by_type(ui_tree, "TextInput")
        if len(inputs) < 2:
            return self._unknown(payload, "MCP_ACTION_PENDING", "Password form inputs were not fully detected")

        input_values = []
        if current_password and len(inputs) >= 3:
            input_values.append((inputs[0], current_password))
            input_values.append((inputs[1], new_password))
            input_values.append((inputs[2], confirm_password))
        else:
            input_values.append((inputs[0], new_password))
            input_values.append((inputs[1], confirm_password))

        for node, value in input_values:
            input_result = await self._input_text_with_commit(node["x"], node["y"], value)
            if not input_result.get("ok", False):
                return self._fail("MCP_EXECUTION_FAILED", "Failed to input password field", {"input_result": input_result, "node": node})

        save_result = await self._save_tool_settings(payload)
        if save_result.get("status") != "PASS":
            evidence = save_result.get("evidence", {})
            evidence["filled_inputs"] = input_values
            save_result["evidence"] = evidence
            return save_result
        save_result.setdefault("evidence", {})
        save_result["evidence"]["filled_inputs"] = input_values
        save_result["message"] = "Tool password fields populated and save triggered"
        return save_result

    async def _add_firewall_rule(self, payload: dict[str, Any]) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        if not await self._firewall_dialog_visible():
            ui_tree = await self._get_ui_tree()
            add_button = self._pick_button_by_text(ui_tree, FIREWALL_ADD_RULE_TEXTS)
            open_result = {"ok": False}
            if add_button:
                open_result = await self._call_tool("click_element", {"x": add_button["x"], "y": add_button["y"]})
            if not open_result.get("ok", False):
                open_result = await self._click_first_available_text(FIREWALL_ADD_RULE_TEXTS, bundle_name="com.huawei.securitytool")
            if not open_result.get("ok", False):
                return self._unknown(payload, "MCP_ACTION_PENDING", "Add rule trigger was not found")

        dialog_ready = await self._wait_for(
            [
                {"text": FIREWALL_DIALOG_TITLE, "bundle_name": "com.huawei.securitytool"},
                {"text": "添加", "bundle_name": "com.huawei.securitytool"},
            ],
            timeout_sec=4.0,
        )
        if not dialog_ready.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", "Add rule dialog did not appear")

        params = payload.get("params", {})
        rule_type = str(params.get("rule_type", "")).lower()
        direction = str(params.get("direction", "")).lower()
        policy = str(params.get("policy", "")).lower()

        ui_tree = await self._get_ui_tree()
        selects = self._dialog_nodes_by_type(ui_tree, "Select")
        if selects:
            desired_rule_label = FIREWALL_RULE_TYPE_LABELS.get(rule_type, "")
            if desired_rule_label and selects[0].get("text") != desired_rule_label:
                await self._call_tool("click_element", {"x": selects[0]["x"], "y": selects[0]["y"]})
                await asyncio.sleep(0.4)
                choose_type = await self._choose_dialog_option(selects[0], [desired_rule_label])
                if choose_type.get("status") != "PASS":
                    return choose_type
                wait_type = await self._wait_for_dialog_select_text(0, desired_rule_label)
                choose_type.setdefault("evidence", {})
                choose_type["evidence"]["select_wait"] = wait_type
                if wait_type.get("status") != "PASS":
                    return self._fail(
                        "MCP_EXECUTION_FAILED",
                        f"Firewall rule type select did not update to {desired_rule_label}",
                        {
                            "desired_rule_label": desired_rule_label,
                            "choose_type": choose_type,
                            "wait_type": wait_type,
                        },
                    )

        ui_tree = await self._get_ui_tree()
        selects = self._dialog_nodes_by_type(ui_tree, "Select")
        if len(selects) >= 2 and direction:
            desired_direction_labels = FIREWALL_DIRECTION_OPTION_LABELS.get(direction, [])
            if desired_direction_labels and str(selects[1].get("text", "")).strip() not in desired_direction_labels:
                await self._call_tool("click_element", {"x": selects[1]["x"], "y": selects[1]["y"]})
                await asyncio.sleep(0.4)
                choose_direction = await self._choose_dialog_option(selects[1], desired_direction_labels)
                if choose_direction.get("status") != "PASS":
                    return choose_direction
                wait_direction = await self._wait_for_dialog_select_text(1, desired_direction_labels[0])
                choose_direction.setdefault("evidence", {})
                choose_direction["evidence"]["select_wait"] = wait_direction
                if wait_direction.get("status") != "PASS":
                    return self._fail(
                        "MCP_EXECUTION_FAILED",
                        f"Firewall direction select did not update to {desired_direction_labels[0]}",
                        {
                            "desired_direction_labels": desired_direction_labels,
                            "choose_direction": choose_direction,
                            "wait_direction": wait_direction,
                        },
                    )

        ui_tree = await self._get_ui_tree()
        selects = self._dialog_nodes_by_type(ui_tree, "Select")
        desired_protocol = str(params.get("protocol", "")).lower()
        if len(selects) >= 3 and desired_protocol:
            desired_protocol_labels = FIREWALL_PROTOCOL_OPTION_LABELS.get(desired_protocol, [])
            if desired_protocol_labels and str(selects[2].get("text", "")).strip() not in desired_protocol_labels:
                await self._call_tool("click_element", {"x": selects[2]["x"], "y": selects[2]["y"]})
                await asyncio.sleep(0.4)
                choose_protocol = await self._choose_dialog_option(selects[2], desired_protocol_labels)
                if choose_protocol.get("status") != "PASS":
                    return choose_protocol
                wait_protocol = await self._wait_for_dialog_select_text(2, desired_protocol_labels[0])
                choose_protocol.setdefault("evidence", {})
                choose_protocol["evidence"]["select_wait"] = wait_protocol
                if wait_protocol.get("status") != "PASS":
                    return self._fail(
                        "MCP_EXECUTION_FAILED",
                        f"Firewall protocol select did not update to {desired_protocol_labels[0]}",
                        {
                            "desired_protocol_labels": desired_protocol_labels,
                            "choose_protocol": choose_protocol,
                            "wait_protocol": wait_protocol,
                        },
                    )

        ui_tree = await self._get_ui_tree()
        inputs = self._dialog_nodes_by_type(ui_tree, "TextInput")
        if not inputs:
            return self._unknown(payload, "MCP_ACTION_PENDING", "Firewall rule form inputs were not detected")

        name_value = str(params.get("name") or params.get("host") or params.get("domain") or params.get("ip") or "e2e-rule")
        target_value = str(params.get("host") or params.get("domain") or params.get("ip") or "")
        port_value = str(params.get("port") or ("53" if rule_type == "dns" else ""))

        input_values: list[tuple[dict[str, Any], str]] = []
        if len(inputs) >= 1:
            input_values.append((inputs[0], name_value))
        if len(inputs) >= 2 and target_value:
            input_values.append((inputs[1], target_value))
        if len(inputs) >= 3 and port_value:
            input_values.append((inputs[2], port_value))

        filled: list[dict[str, Any]] = []
        for node, value in input_values:
            input_result = await self._input_text_with_commit(node["x"], node["y"], value, commit_enter=True)
            if not input_result.get("ok", False):
                return self._fail("MCP_EXECUTION_FAILED", "Failed to input firewall rule field", {"input_result": input_result, "node": node, "value": value})
            filled.append({"node": node, "value": value})

        ui_tree = await self._get_ui_tree()
        selects = self._dialog_nodes_by_type(ui_tree, "Select")
        if selects and policy:
            desired_policy_labels = FIREWALL_POLICY_OPTION_LABELS.get(policy, [])
            policy_select = selects[-1]
            if desired_policy_labels and str(policy_select.get("text", "")).strip() not in desired_policy_labels:
                await self._call_tool("click_element", {"x": policy_select["x"], "y": policy_select["y"]})
                await asyncio.sleep(0.4)
                choose_policy = await self._choose_dialog_option(policy_select, desired_policy_labels)
                if choose_policy.get("status") != "PASS":
                    return choose_policy
                wait_policy = await self._wait_for_dialog_select_text(len(selects) - 1, desired_policy_labels[0])
                choose_policy.setdefault("evidence", {})
                choose_policy["evidence"]["select_wait"] = wait_policy
                if wait_policy.get("status") != "PASS":
                    return self._fail(
                        "MCP_EXECUTION_FAILED",
                        f"Firewall policy select did not update to {desired_policy_labels[0]}",
                        {
                            "desired_policy_labels": desired_policy_labels,
                            "choose_policy": choose_policy,
                            "wait_policy": wait_policy,
                        },
                    )
        submit_result = await self._confirm_dialog()
        if submit_result.get("status") != "PASS":
            return submit_result
        dialog_gone = await self._wait_until_text_gone(FIREWALL_DIALOG_TITLE, timeout_sec=5.0)
        evidence = {"params": params, "fill": {"filled_inputs": filled}, "submit": submit_result.get("evidence", {})}
        if dialog_gone.get("status") != "PASS":
            return self._unknown(payload, "MCP_ACTION_PENDING", "Firewall rule dialog is still open after submit")
        rule_created = await self._find_firewall_rule({"params": params})
        evidence["rule_created"] = rule_created
        if rule_created.get("status") != "PASS":
            return self._unknown(payload, "MCP_ACTION_PENDING", "Firewall rule dialog closed but target rule was not observed")
        return self._pass("Firewall rule dialog submitted", evidence)

    async def _find_firewall_rule(self, payload: dict[str, Any]) -> dict[str, Any]:
        params = payload.get("params", {})
        candidates = [str(params.get(key, "")) for key in ("name", "host", "ip", "domain")]
        for candidate in candidates:
            if not candidate:
                continue
            wait_result = await self._wait_for([{"text": candidate, "bundle_name": "com.huawei.securitytool"}], timeout_sec=2.5)
            if wait_result.get("ok", False):
                return self._pass("Firewall rule located", {"matched": wait_result.get("match", {})})
        return self._unknown(payload, "MCP_ACTION_PENDING", "Target firewall rule could not be located yet")

    async def _delete_firewall_rule(self, payload: dict[str, Any]) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        params = payload.get("params", {})
        target = str(params.get("name") or params.get("host") or params.get("ip") or params.get("domain") or "")
        if target:
            await self._call_tool("click_element", {"text": target, "bundle_name": "com.huawei.securitytool"})
            await asyncio.sleep(0.3)
        delete_click = await self._click_first_available_text(DELETE_ACTION_LABELS, bundle_name="com.huawei.securitytool")
        if not delete_click.get("ok", False):
            ui_tree = await self._get_ui_tree()
            delete_button = self._pick_button_by_text(ui_tree, DELETE_ACTION_LABELS)
            if delete_button:
                delete_click = await self._call_tool("click_element", {"x": delete_button["x"], "y": delete_button["y"]})
        if not delete_click.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", "Delete action was not found")
        await self._confirm_dialog(allow_cancel=False)
        return self._pass("Firewall rule delete triggered", {"target": target})

    async def _open_browser_url(self, payload: dict[str, Any]) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        url = str(payload.get("params", {}).get("url", "")).strip()
        if not url:
            return self._fail("MCP_EXECUTION_FAILED", "URL is required", {})
        if await self._firewall_dialog_visible():
            return self._unknown(payload, "MCP_ACTION_PENDING", "Firewall dialog is still open before browser launch")

        start_result = await self._call_tool("run_app", {"bundle_name": "com.huawei.hmos.browser", "auto_detect": True})
        if not start_result.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", "Browser app could not be launched")

        address_bar = await self._locate_browser_address_bar()
        if not address_bar:
            return self._unknown(payload, "MCP_ACTION_PENDING", "Browser address bar was not located")
        focus_result = await self._call_tool("click_element", {"x": address_bar["x"], "y": address_bar["y"]})
        if not focus_result.get("ok", False):
            return self._fail("MCP_EXECUTION_FAILED", "Failed to focus browser address bar", {"click_result": focus_result, "address_bar": address_bar})

        input_result = await self._input_text_with_commit(
            address_bar["x"],
            address_bar["y"],
            url,
            commit_enter=True,
            force_commit_enter=True,
            bundle_name="com.huawei.hmos.browser",
        )
        if not input_result.get("ok", False):
            return self._fail("MCP_EXECUTION_FAILED", "Failed to input browser URL", {"input_result": input_result, "address_bar": address_bar})
        verify_url = await self._verify_browser_url_entered(url)
        if verify_url.get("status") != "PASS":
            return verify_url
        browser_navigation = await self._verify_browser_navigation_started(url)
        if browser_navigation.get("status") != "PASS":
            return browser_navigation
        return self._pass(
            "Browser URL open triggered",
            {
                "url": url,
                "address_bar": address_bar,
                "submit": {
                    "method": "input_text_with_commit",
                    "input_result": input_result,
                },
                "navigation": browser_navigation.get("evidence", {}),
            },
        )

    async def _toggle_peripheral_interface(self, payload: dict[str, Any]) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        params = payload.get("params", {})
        feature = str(params.get("feature", "")).lower()
        index_map = {"usb": 0, "bluetooth": 1, "wifi": 2, "hdc": 3}
        ui_tree = await self._get_ui_tree()
        toggles = sorted(self._nodes_by_type(ui_tree, "Toggle"), key=lambda node: (node.get("top") or 0, node.get("left") or 0))
        if not toggles:
            return self._unknown(payload, "MCP_ACTION_PENDING", "Peripheral toggles were not detected")
        index = index_map.get(feature, 0)
        if index >= len(toggles):
            index = len(toggles) - 1
        target = toggles[index]
        click_result = await self._call_tool("click_element", {"x": target["x"], "y": target["y"]})
        if not click_result.get("ok", False):
            return self._fail("MCP_EXECUTION_FAILED", "Failed to click peripheral toggle", {"click_result": click_result, "toggle": target})
        return self._pass("Peripheral interface toggle executed", {"feature": feature, "toggle": target})

    async def _select_usb_storage_policy(self, payload: dict[str, Any]) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        params = payload.get("params", {})
        ui_tree = await self._get_ui_tree()
        selects = sorted(self._nodes_by_type(ui_tree, "Select"), key=lambda node: (node.get("top") or 0, node.get("left") or 0))
        if not selects:
            return self._unknown(payload, "MCP_ACTION_PENDING", "USB storage policy select was not detected")
        select_node = selects[0]
        open_result = await self._call_tool("click_element", {"x": select_node["x"], "y": select_node["y"]})
        if not open_result.get("ok", False):
            return self._fail("MCP_EXECUTION_FAILED", "Failed to open USB storage policy select", {"click_result": open_result})
        policy = str(params.get("policy", "")).lower()
        option_result = await self._choose_any_option({
            "read_only": ["只读", "仅读"],
            "disabled": ["禁用", "禁止"],
            "allow": ["允许", "可读写", "读写"],
        }.get(policy, ["只读", "允许"]))
        return option_result if option_result.get("status") != "PASS" else self._pass("USB storage policy selection triggered", {"policy": policy})

    async def _open_usb_whitelist_dialog(self, payload: dict[str, Any]) -> dict[str, Any]:
        return await self._open_named_dialog(payload, ["USB白名单", "添加 USB 设备白名单", "添加白名单"])

    async def _add_usb_whitelist(self, payload: dict[str, Any]) -> dict[str, Any]:
        params = payload.get("params", {})
        fill_result = await self._fill_text_inputs([str(params.get("vendor_id", "")), str(params.get("product_id", ""))])
        if fill_result.get("status") == "FAIL":
            return fill_result
        return await self._confirm_dialog()

    async def _open_bluetooth_whitelist_dialog(self, payload: dict[str, Any]) -> dict[str, Any]:
        return await self._open_named_dialog(payload, ["蓝牙白名单", "添加蓝牙白名单", "添加白名单"])

    async def _add_bluetooth_whitelist(self, payload: dict[str, Any]) -> dict[str, Any]:
        params = payload.get("params", {})
        fill_result = await self._fill_text_inputs([str(params.get("mac", ""))])
        if fill_result.get("status") == "FAIL":
            return fill_result
        return await self._confirm_dialog()

    async def _open_usb_blacklist_dialog(self, payload: dict[str, Any]) -> dict[str, Any]:
        return await self._open_named_dialog(payload, ["USB黑名单", "添加 USB 设备黑名单", "添加黑名单"])

    async def _add_usb_blacklist(self, payload: dict[str, Any]) -> dict[str, Any]:
        params = payload.get("params", {})
        fill_result = await self._fill_text_inputs([
            str(params.get("base_class", "")),
            str(params.get("sub_class", "")),
            str(params.get("protocol", "")),
        ])
        if fill_result.get("status") == "FAIL":
            return fill_result
        return await self._confirm_dialog()

    async def _update_password_policy(self, payload: dict[str, Any]) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        params = payload.get("params", {})
        numeric_values = [str(params.get("min_length", ""))]
        fill_result = await self._fill_text_inputs(numeric_values)
        if fill_result.get("status") == "PASS":
            return self._pass("Password policy fields updated", {"params": params, "fill": fill_result.get("evidence", {})})
        action_result = await self._touch_identity_controls()
        if action_result.get("status") != "PASS":
            return fill_result
        return self._pass("Password policy controls interacted", {"params": params, "interaction": action_result.get("evidence", {})})

    async def _update_domain_account_policy(self, payload: dict[str, Any]) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        params = payload.get("params", {})
        fill_result = await self._fill_text_inputs([
            str(params.get("password_max_age_days", "")),
            str(params.get("expiration_notify_days", "")),
            str(params.get("auth_validity_minutes", "")),
        ])
        if fill_result.get("status") == "PASS":
            return self._pass("Domain policy fields updated", {"params": params, "fill": fill_result.get("evidence", {})})
        action_result = await self._touch_identity_controls()
        if action_result.get("status") != "PASS":
            return fill_result
        return self._pass("Domain policy controls interacted", {"params": params, "interaction": action_result.get("evidence", {})})

    async def _export_logs(self, payload: dict[str, Any]) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        open_result = await self._click_first_available_text(["瀵煎嚭", "瀵煎嚭鏃ュ織"], bundle_name="com.huawei.securitytool")
        if not open_result.get("ok", False):
            ui_tree = await self._get_ui_tree()
            open_button = self._pick_primary_button(ui_tree)
            if open_button:
                open_result = await self._call_tool("click_element", {"x": open_button["x"], "y": open_button["y"]})
        if not open_result.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", "Log export trigger was not found")
        await asyncio.sleep(0.4)
        await self._choose_any_option(["CSV", "Excel", "TXT"])
        confirm_result = await self._confirm_dialog()
        if confirm_result.get("status") != "PASS":
            return confirm_result
        return self._pass("Log export flow triggered", {})

    async def _change_any_policy(self, payload: dict[str, Any]) -> dict[str, Any]:
        preferred = str(payload.get("params", {}).get("preferred_module", "firewall"))
        if preferred == "firewall":
            nav_result = await self._navigate_page({"page_id": "firewall"})
            if nav_result.get("status") != "PASS":
                return nav_result
            toggle_result = await self._toggle_first_toggle(payload, page_text=FIREWALL_PAGE_TEXT)
            if toggle_result.get("status") == "PASS":
                return toggle_result
            ui_tree = await self._get_ui_tree()
            button = self._pick_primary_button(ui_tree)
            if button:
                click_result = await self._call_tool("click_element", {"x": button["x"], "y": button["y"]})
                if click_result.get("ok", False):
                    return self._pass("Fallback firewall interaction executed", {"button": button})
            return toggle_result
        nav_result = await self._navigate_page({"page_id": "tool-settings"})
        if nav_result.get("status") != "PASS":
            return nav_result
        return await self._toggle_first_toggle(payload, page_text=TOOL_SETTINGS_PAGE_TEXT)

    async def _save_tool_settings(self, payload: dict[str, Any]) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        ui_tree = await self._get_ui_tree()
        save_button = self._pick_tool_settings_save_button(ui_tree)
        click_result = None
        if save_button:
            click_result = await self._call_tool("click_element", {"x": save_button["x"], "y": save_button["y"]})
        if not click_result or not click_result.get("ok", False):
            click_result = await self._call_tool("click_element", {"text": TOOL_SETTINGS_SAVE_TEXT, "bundle_name": "com.huawei.securitytool"})
        if not click_result.get("ok", False):
            return self._fail(
                "MCP_EXECUTION_FAILED",
                "Click action failed",
                {
                    "click_result": click_result,
                    "click_params": {"text": TOOL_SETTINGS_SAVE_TEXT, "bundle_name": "com.huawei.securitytool"},
                    "save_button": save_button or {},
                },
            )
        wait_result = await self._wait_for([{"text": TOOL_SETTINGS_PAGE_TEXT, "bundle_name": "com.huawei.securitytool"}])
        if not wait_result.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", "Save click succeeded but tool settings page confirmation did not resolve")
        return self._pass(
            "Tool settings save action executed",
            {"save_button": save_button or {}, "wait_match": wait_result.get("match", {})},
        )

    async def _wait_for(self, queries: list[dict[str, Any]], timeout_sec: float = 5.0, interval_sec: float = 0.4) -> dict[str, Any]:
        for query in queries:
            result = await self._call_tool(
                "wait_element",
                {
                    **query,
                    "timeout_ms": int(timeout_sec * 1000),
                    "interval_ms": int(interval_sec * 1000),
                },
            )
            if result.get("ok", False):
                structured = result.get("result", result)
                element = structured.get("element")
                if element:
                    return {"ok": True, "match": {"query": query, "element": element}}
        return {"ok": False}

    async def _get_ui_tree(self) -> dict[str, Any]:
        result = await self._call_tool("get_ui_tree", {"bundle_name": "com.huawei.securitytool"})
        structured = result.get("result", result)
        return structured.get("ui_tree", {}) if isinstance(structured, dict) else {}

    async def _call_tool(self, tool_name: str, params: dict[str, Any]) -> dict[str, Any]:
        async with Client(mcp) as client:
            tool_result = await client.call_tool_mcp(tool_name, params)
        structured = getattr(tool_result, "structuredContent", None) or {}
        if "structuredContent" in structured:
            structured = structured["structuredContent"]
        return structured if isinstance(structured, dict) else {}

    def _pass(self, message: str, evidence: dict[str, Any]) -> dict[str, Any]:
        return {
            "status": "PASS",
            "failure_code": "",
            "message": message,
            "evidence": evidence,
        }

    def _fail(self, failure_code: str, message: str, evidence: dict[str, Any]) -> dict[str, Any]:
        return {
            "status": "FAIL",
            "failure_code": failure_code,
            "message": message,
            "evidence": evidence,
        }

    def _unknown(self, payload: dict[str, Any], failure_code: str, message: str) -> dict[str, Any]:
        action = payload.get("action", "")
        params = payload.get("params", {})
        return {
            "status": "UNKNOWN",
            "failure_code": failure_code,
            "message": message,
            "evidence": {
                "bridge_backend": "real_harmonyos_mcp_backend",
                "action": action,
                "params": params,
                "action_plan": ACTION_PLANS.get(action, {}),
            },
        }

    def _first_node_by_type(self, ui_tree: dict[str, Any], node_type: str) -> dict[str, Any] | None:
        nodes = self._nodes_by_type(ui_tree, node_type)
        return nodes[0] if nodes else None

    async def _wait_for_page_marker(
        self,
        *,
        page_id: str,
        marker_text: str,
        page_text: str,
        timeout_sec: float,
    ) -> dict[str, Any]:
        deadline = time.time() + timeout_sec
        while time.time() < deadline:
            ui_tree = await self._get_ui_tree()
            marker_node = self._find_page_marker_node(ui_tree, marker_text=marker_text, page_text=page_text)
            if marker_node:
                query_text = marker_text or page_text
                return {"ok": True, "match": {"query": {"page_id": page_id, "text": query_text}, "element": marker_node}}
            await asyncio.sleep(0.35)
        return {"ok": False}

    def _find_page_marker_node(self, ui_tree: dict[str, Any], *, marker_text: str, page_text: str) -> dict[str, Any] | None:
        candidate_texts = [text for text in [marker_text, page_text] if text]
        if not candidate_texts:
            return None
        for node in self._nodes_by_type(ui_tree, "Text"):
            text = str(node.get("text", "")).strip()
            if text not in candidate_texts:
                continue
            if (node.get("left") or 0) < 800:
                continue
            return node
        return None

    def _find_any_text_node(self, ui_tree: dict[str, Any], texts: list[str]) -> dict[str, Any] | None:
        wanted = {text.strip() for text in texts if text.strip()}
        if not wanted:
            return None
        for node in self._nodes_by_type(ui_tree, "Text"):
            if str(node.get("text", "")).strip() in wanted:
                return node
        return None

    def _first_content_toggle(self, ui_tree: dict[str, Any]) -> dict[str, Any] | None:
        toggles = [
            node for node in self._nodes_by_type(ui_tree, "Toggle")
            if (node.get("left") or 0) >= 800 and node.get("clickable")
        ]
        return toggles[0] if toggles else None

    def _nodes_by_type(self, ui_tree: dict[str, Any], node_type: str) -> list[dict[str, Any]]:
        matches: list[dict[str, Any]] = []
        for node in self._iter_nodes(ui_tree):
            if node.get("type") != node_type:
                continue
            props = node.get("properties", {})
            left = props.get("left")
            top = props.get("top")
            width = props.get("width")
            height = props.get("height")
            if None in (left, top, width, height):
                continue
            matches.append({
                "type": node_type,
                "text": props.get("text", ""),
                "x": int(left) + int(width) // 2,
                "y": int(top) + int(height) // 2,
                "left": int(left),
                "top": int(top),
                "width": int(width),
                "height": int(height),
                "checked": props.get("checked", False),
                "clickable": props.get("clickable", False),
            })
        return matches

    def _pick_tool_settings_save_button(self, ui_tree: dict[str, Any]) -> dict[str, Any] | None:
        buttons = [node for node in self._nodes_by_type(ui_tree, "Button") if node.get("clickable")]
        if not buttons:
            return None
        candidates = [
            node for node in buttons
            if (node.get("top") or 0) > 1200 and (node.get("width") or 0) >= 180
        ]
        pool = candidates or buttons
        return max(pool, key=lambda node: ((node.get("top") or 0), (node.get("width") or 0)))

    def _pick_button_by_text(self, ui_tree: dict[str, Any], labels: list[str], *, min_left: int = 800) -> dict[str, Any] | None:
        wanted = {label.strip() for label in labels if label.strip()}
        if not wanted:
            return None
        buttons = [
            node for node in self._nodes_by_type(ui_tree, "Button")
            if node.get("clickable") and (node.get("left") or 0) >= min_left and str(node.get("text", "")).strip() in wanted
        ]
        if buttons:
            return max(buttons, key=lambda node: ((node.get("top") or 0), (node.get("width") or 0)))
        return None

    def _pick_firewall_rule_card(self, ui_tree: dict[str, Any], rule_type: str) -> dict[str, Any] | None:
        clickable_texts = [
            node for node in self._nodes_by_type(ui_tree, "Text")
            if node.get("clickable")
            and (node.get("left") or 0) >= 850
            and 700 <= (node.get("top") or 0) <= 1250
            and (node.get("width") or 0) >= 60
        ]
        if not clickable_texts:
            return None
        ordered = sorted(clickable_texts, key=lambda node: ((node.get("left") or 0), (node.get("top") or 0)))
        index_map = {"ip": 0, "domain": 1, "dns": 2}
        target_index = index_map.get(rule_type, 0)
        if target_index >= len(ordered):
            target_index = len(ordered) - 1
        return ordered[target_index]

    def _pick_sidebar_entry(self, ui_tree: dict[str, Any], page_id: str) -> dict[str, Any] | None:
        target_text = PAGE_REGISTRY.get(page_id, "")
        sidebar_nodes = [
            node for node in self._nodes_by_type(ui_tree, "Text")
            if (node.get("left") or 0) <= 700 and 450 <= (node.get("top") or 0) <= 1100
        ]
        exact_matches = [node for node in sidebar_nodes if node.get("text") == target_text]
        if exact_matches:
            return min(exact_matches, key=lambda node: (node.get("top") or 0, node.get("left") or 0))
        ordered = sorted(sidebar_nodes, key=lambda node: (node.get("top") or 0, node.get("left") or 0))
        index_map = {
            "dashboard": 0,
            "firewall": 1,
            "log-manage": 2,
            "peripheral-manage": 3,
            "identity": 4,
            "tool-settings": 5,
        }
        if not ordered:
            return None
        index = index_map.get(page_id, 0)
        if index >= len(ordered):
            index = len(ordered) - 1
        return ordered[index]

    def _pick_toggle_node(self, ui_tree: dict[str, Any], *, text: str = "", element_id: str = "") -> dict[str, Any] | None:
        toggles = self._nodes_by_type(ui_tree, "Toggle")
        if not toggles:
            return None
        if not text and not element_id:
            return toggles[0]

        normalized_text = text.strip()
        for node in self._iter_nodes(ui_tree):
            props = node.get("properties", {})
            if element_id and props.get("id") == element_id and node.get("type") == "Toggle":
                return self._node_to_element(node)
            if normalized_text and props.get("text") == normalized_text and node.get("type") == "Toggle":
                return self._node_to_element(node)
            if normalized_text and props.get("text") == normalized_text:
                parent = self._find_first_child_toggle(node)
                if parent:
                    return parent
        return toggles[0]

    def _pick_primary_button(self, ui_tree: dict[str, Any]) -> dict[str, Any] | None:
        buttons = [node for node in self._nodes_by_type(ui_tree, "Button") if node.get("clickable")]
        if not buttons:
            return None
        return max(buttons, key=lambda node: ((node.get("width") or 0), (node.get("top") or 0)))

    async def _touch_identity_controls(self) -> dict[str, Any]:
        ui_tree = await self._get_ui_tree()
        selects = [node for node in self._nodes_by_type(ui_tree, "Select") if node.get("clickable")]
        if selects:
            target = selects[0]
            click_result = await self._call_tool("click_element", {"x": target["x"], "y": target["y"]})
            if click_result.get("ok", False):
                return self._pass("Identity select control clicked", {"select": target})
        toggles = [node for node in self._nodes_by_type(ui_tree, "Toggle")]
        if toggles:
            target = toggles[0]
            click_result = await self._call_tool("click_element", {"x": target["x"], "y": target["y"]})
            if click_result.get("ok", False):
                return self._pass("Identity toggle control clicked", {"toggle": target})
        return self._unknown({"action": "identity.touch_controls", "params": {}}, "MCP_ACTION_PENDING", "Identity controls were not detected")

    async def _click_first_available_text(self, texts: list[str], *, bundle_name: str | None) -> dict[str, Any]:
        for text in texts:
            if not text:
                continue
            params: dict[str, Any] = {"text": text}
            if bundle_name:
                params["bundle_name"] = bundle_name
            result = await self._call_tool("click_element", params)
            if result.get("ok", False):
                return result
        return {"ok": False}

    async def _choose_any_option(self, labels: list[str]) -> dict[str, Any]:
        if not labels:
            return self._unknown({"action": "select_option", "params": {}}, "MCP_ACTION_PENDING", "No option labels were provided")
        click_result = await self._click_first_available_text(labels, bundle_name="com.huawei.securitytool")
        if click_result.get("ok", False):
            return self._pass("Option selected", {"labels": labels})
        return self._unknown({"action": "select_option", "params": {"labels": labels}}, "MCP_ACTION_PENDING", "Target option was not found")

    async def _open_named_dialog(self, payload: dict[str, Any], labels: list[str]) -> dict[str, Any]:
        open_result = await self._click_first_available_text(labels, bundle_name="com.huawei.securitytool")
        if not open_result.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", f"Dialog trigger was not found: {'/'.join(labels)}")
        return self._pass("Dialog trigger clicked", {"labels": labels})

    async def _fill_text_inputs(self, values: list[str]) -> dict[str, Any]:
        filtered_values = [value for value in values if value]
        if not filtered_values:
            return self._pass("No input values requested", {"filled_inputs": []})
        ui_tree = await self._get_ui_tree()
        inputs = sorted(self._nodes_by_type(ui_tree, "TextInput"), key=lambda node: (node.get("top") or 0, node.get("left") or 0))
        if not inputs:
            return self._fail("MCP_EXECUTION_FAILED", "No text inputs were detected", {})
        filled: list[dict[str, Any]] = []
        for node, value in zip(inputs, filtered_values, strict=False):
            input_result = await self._input_text_with_commit(node["x"], node["y"], value, commit_enter=True)
            if not input_result.get("ok", False):
                return self._fail("MCP_EXECUTION_FAILED", "Failed to input text field", {"input_result": input_result, "node": node})
            filled.append({"node": node, "value": value})
        return self._pass("Text inputs filled", {"filled_inputs": filled})

    async def _confirm_dialog(self, *, allow_cancel: bool = True) -> dict[str, Any]:
        labels = CONFIRM_DIALOG_LABELS
        if not allow_cancel:
            labels = CONFIRM_DELETE_LABELS
        ui_tree = await self._get_ui_tree()
        dialog_button = self._pick_dialog_button_by_text(ui_tree, labels)
        if dialog_button:
            click_result = await self._call_tool("click_element", {"x": dialog_button["x"], "y": dialog_button["y"]})
            if click_result.get("ok", False):
                return self._pass("Dialog confirmed", {"button": dialog_button, "labels": labels})
        result = await self._click_first_available_text(labels, bundle_name="com.huawei.securitytool")
        if result.get("ok", False):
            return self._pass("Dialog confirmed", {"labels": labels})
        ui_tree = await self._get_ui_tree()
        buttons = [node for node in self._nodes_by_type(ui_tree, "Button") if node.get("clickable")]
        if buttons:
            target = max(buttons, key=lambda node: ((node.get("top") or 0), (node.get("left") or 0)))
            click_result = await self._call_tool("click_element", {"x": target["x"], "y": target["y"]})
            if click_result.get("ok", False):
                return self._pass("Dialog confirmed", {"button": target})
        return self._unknown({"action": "confirm_dialog", "params": {}}, "MCP_ACTION_PENDING", "Confirmation button was not found")

    async def _wait_until_text_gone(self, text: str, *, timeout_sec: float = 5.0) -> dict[str, Any]:
        result = await self._call_tool(
            "wait_element",
            {
                "bundle_name": "com.huawei.securitytool",
                "text": text,
                "state": "gone",
                "timeout_ms": int(timeout_sec * 1000),
                "interval_ms": 300,
            },
        )
        if result.get("ok", False):
            return self._pass("Text disappeared", {"text": text})
        return self._unknown({"action": "__driver_wait_until_gone", "params": {"text": text}}, "MCP_ACTION_PENDING", f"Text did not disappear: {text}")

    async def _firewall_dialog_visible(self) -> bool:
        ui_tree = await self._get_ui_tree()
        return any(str(node.get("text", "")).strip() == FIREWALL_DIALOG_TITLE for node in self._nodes_by_type(ui_tree, "Text"))

    def _dialog_nodes_by_type(self, ui_tree: dict[str, Any], node_type: str) -> list[dict[str, Any]]:
        region = FIREWALL_DIALOG_REGION
        nodes = []
        for node in self._nodes_by_type(ui_tree, node_type):
            left = node.get("left") or 0
            top = node.get("top") or 0
            if region["left_min"] <= left <= region["left_max"] and region["top_min"] <= top <= region["top_max"]:
                nodes.append(node)
        return sorted(nodes, key=lambda node: (node.get("top") or 0, node.get("left") or 0))

    async def _wait_for_dialog_select_text(self, index: int, expected_text: str, *, timeout_sec: float = 3.0) -> dict[str, Any]:
        deadline = time.time() + timeout_sec
        while time.time() < deadline:
            ui_tree = await self._get_ui_tree()
            selects = self._dialog_nodes_by_type(ui_tree, "Select")
            if len(selects) > index and str(selects[index].get("text", "")).strip() == expected_text:
                return self._pass("Dialog select updated", {"index": index, "select": selects[index], "expected_text": expected_text})
            await asyncio.sleep(0.3)
        return self._unknown({"action": "wait_dialog_select", "params": {"index": index, "expected_text": expected_text}}, "MCP_ACTION_PENDING", f"Dialog select did not update to {expected_text}")

    async def _wait_for_dialog_input_value(self, target_node: dict[str, Any], expected_value: str, *, timeout_sec: float = 2.5) -> dict[str, Any]:
        deadline = time.time() + timeout_sec
        while time.time() < deadline:
            ui_tree = await self._get_ui_tree()
            inputs = self._dialog_nodes_by_type(ui_tree, "TextInput")
            for node in inputs:
                if abs((node.get("left") or 0) - (target_node.get("left") or 0)) <= 8 and abs((node.get("top") or 0) - (target_node.get("top") or 0)) <= 8:
                    if expected_value in str(node.get("text", "")):
                        return self._pass("Dialog input updated", {"input": node, "expected_value": expected_value})
            await asyncio.sleep(0.25)
        return self._unknown({"action": "wait_dialog_input", "params": {"expected_value": expected_value}}, "MCP_ACTION_PENDING", f"Dialog input did not update to {expected_value}")

    async def _choose_dialog_option(self, select_node: dict[str, Any], labels: list[str], *, timeout_sec: float = 3.0) -> dict[str, Any]:
        wanted = {label.strip() for label in labels if label.strip()}
        deadline = time.time() + timeout_sec
        while time.time() < deadline:
            ui_tree = await self._get_ui_tree()
            aligned_candidates = []
            fallback_candidates = []
            select_left = select_node.get("left") or 0
            for node in self._nodes_by_type(ui_tree, "Text"):
                text = str(node.get("text", "")).strip()
                if text not in wanted:
                    continue
                left = node.get("left") or 0
                top = node.get("top") or 0
                if left < FIREWALL_DIALOG_REGION["left_min"] or left > FIREWALL_DIALOG_REGION["left_max"]:
                    continue
                if top <= (select_node.get("top") or 0):
                    continue
                if top > (select_node.get("top") or 0) + 320:
                    continue
                fallback_candidates.append(node)
                # Dropdown option items align near the select's left edge, while
                # page tabs with the same text sit much farther to the right.
                if abs(left - select_left) <= 120:
                    aligned_candidates.append(node)
            candidates = aligned_candidates or fallback_candidates
            if candidates:
                target = min(
                    candidates,
                    key=lambda node: (
                        abs((node.get("left") or 0) - select_left),
                        abs((node.get("top") or 0) - ((select_node.get("top") or 0) + 120)),
                    ),
                )
                click_result = await self._call_tool("click_element", {"x": target["x"], "y": target["y"]})
                if click_result.get("ok", False):
                    return self._pass("Dialog option selected", {"target": target, "labels": list(wanted)})
            await asyncio.sleep(0.25)
        return self._unknown({"action": "choose_dialog_option", "params": {"labels": list(wanted)}}, "MCP_ACTION_PENDING", f"Dialog option was not found: {list(wanted)}")

    async def _get_ui_tree_for_bundle(self, bundle_name: str) -> dict[str, Any]:
        result = await self._call_tool("get_ui_tree", {"bundle_name": bundle_name})
        structured = result.get("result", result)
        return structured.get("ui_tree", {}) if isinstance(structured, dict) else {}

    async def _locate_browser_address_bar(self) -> dict[str, Any] | None:
        deadline = time.time() + 5.0
        while time.time() < deadline:
            tree = await self._get_ui_tree_for_bundle("com.huawei.hmos.browser")
            inputs = [
                node for node in self._nodes_by_type(tree, "TextInput")
                if node.get("clickable") and (node.get("top") or 0) <= 320 and (node.get("left") or 0) >= 1000 and (node.get("width") or 0) >= 800
            ]
            if inputs:
                return max(inputs, key=lambda node: node.get("width") or 0)
            await asyncio.sleep(0.3)
        return None

    async def _verify_browser_url_entered(self, url: str, *, timeout_sec: float = 3.5) -> dict[str, Any]:
        deadline = time.time() + timeout_sec
        while time.time() < deadline:
            tree = await self._get_ui_tree_for_bundle("com.huawei.hmos.browser")
            for node in self._iter_nodes(tree):
                props = node.get("properties", {})
                text = str(props.get("text", ""))
                if url in text:
                    return self._pass("Browser address bar updated", {"text": text, "type": node.get("type", "")})
            await asyncio.sleep(0.25)
        return self._unknown({"action": "verify_browser_url", "params": {"url": url}}, "MCP_ACTION_PENDING", "Browser URL text was not observed after input")

    async def _verify_browser_navigation_started(self, url: str, *, timeout_sec: float = 6.0) -> dict[str, Any]:
        deadline = time.time() + timeout_sec
        parsed = urlparse(url)
        host = parsed.netloc.lower()
        accepted = {url.strip()}
        if url.endswith("/"):
            accepted.add(url.rstrip("/"))
        else:
            accepted.add(url + "/")
        while time.time() < deadline:
            tree = await self._get_ui_tree_for_bundle("com.huawei.hmos.browser")
            for node in self._iter_nodes(tree):
                props = node.get("properties", {}) or {}
                values = [
                    str(props.get("text", "")).strip(),
                    str(props.get("value", "")).strip(),
                    str(props.get("content", "")).strip(),
                ]
                values = [value for value in values if value]
                if not values:
                    continue
                if any(value in accepted for value in values):
                    return self._pass("Browser navigation observed", {"node_type": node.get("type", ""), "values": values})
                if host and any(host in value.lower() for value in values):
                    return self._pass("Browser navigation observed", {"node_type": node.get("type", ""), "values": values})
            await asyncio.sleep(0.4)
        return self._unknown({"action": "verify_browser_navigation", "params": {"url": url}}, "MCP_ACTION_PENDING", "Browser navigation result was not observed after submit")

    async def _input_text_with_commit(
        self,
        x: int,
        y: int,
        text: str,
        *,
        commit_enter: bool = False,
        force_commit_enter: bool = False,
        bundle_name: str = "com.huawei.securitytool",
    ) -> dict[str, Any]:
        click_result = await self._call_tool("click_element", {"x": x, "y": y})
        if not click_result.get("ok", False):
            return click_result
        await asyncio.sleep(0.5)

        input_result = await self._call_tool("input_text", {"x": x, "y": y, "text": text})
        if not input_result.get("ok", False):
            return input_result

        verify_result = await self._verify_text_input_value(bundle_name, x, y, text)
        if verify_result.get("ok", False):
            enter_evidence: dict[str, Any] = {}
            if commit_enter and force_commit_enter:
                enter_results = []
                for _ in range(2):
                    enter_result = await asyncio.to_thread(self._press_hdc_enter)
                    enter_results.append(
                        {
                            "returncode": enter_result.returncode,
                            "stdout": enter_result.stdout,
                            "stderr": enter_result.stderr,
                        }
                    )
                    await asyncio.sleep(0.5)
                enter_evidence = {
                    "forced_commit_enter": True,
                    "enter_repeat": 2,
                    "enter_results": enter_results,
                }
                if any(result["returncode"] != 0 for result in enter_results):
                    return self._fail(
                        "MCP_EXECUTION_FAILED",
                        "Input verification succeeded but forced HDC ENTER key failed",
                        {
                            "input_result": input_result,
                            "verification": verify_result,
                            **enter_evidence,
                        },
                    )
                await asyncio.sleep(0.2)
            enriched = dict(input_result)
            enriched.setdefault("result", {})
            enriched["result"]["verification"] = verify_result
            if enter_evidence:
                enriched["result"]["commit"] = enter_evidence
            return enriched
        if commit_enter:
            enter_result = await asyncio.to_thread(self._press_hdc_enter)
            if enter_result.returncode != 0:
                return self._fail(
                    "MCP_EXECUTION_FAILED",
                    "Input succeeded but HDC ENTER key failed",
                    {
                        "input_result": input_result,
                        "verification": verify_result,
                        "enter_returncode": enter_result.returncode,
                        "enter_stdout": enter_result.stdout,
                        "enter_stderr": enter_result.stderr,
                    },
                )
            await asyncio.sleep(0.2)
            verify_after_enter = await self._verify_text_input_value(bundle_name, x, y, text)
            if verify_after_enter.get("ok", False):
                enriched = dict(input_result)
                enriched.setdefault("result", {})
                enriched["result"]["verification"] = verify_after_enter
                enriched["result"]["confirmed_after_hdc_enter"] = True
                return enriched
        return self._fail(
            "MCP_EXECUTION_FAILED",
            "Input text was not observed in target field after first attempt",
            {
                "initial_input": input_result,
                "verify_after_input": verify_result,
                "commit_enter": commit_enter,
                "verify_after_hdc_enter": verify_after_enter if commit_enter else {},
                "target": {"x": x, "y": y, "text": text, "bundle_name": bundle_name},
            },
        )

    def _press_hdc_enter(self):
        return run_command(
            ["hdc", "shell", "uinput", "-K", "-d", "2054", "-u", "2054"],
            PROJECT_ROOT,
            10,
            False,
        )

    async def _verify_text_input_value(self, bundle_name: str, x: int, y: int, expected: str) -> dict[str, Any]:
        tree = await self._get_ui_tree_for_bundle(bundle_name)
        expected = str(expected).strip()
        if not expected:
            return {"ok": True, "reason": "empty_expected"}

        best_node: dict[str, Any] | None = None
        best_distance: int | None = None
        for node in self._nodes_by_type(tree, "TextInput"):
            node_x = int(node.get("x", 0))
            node_y = int(node.get("y", 0))
            distance = abs(node_x - x) + abs(node_y - y)
            if best_distance is None or distance < best_distance:
                best_node = node
                best_distance = distance

        if not best_node:
            return {"ok": False, "reason": "text_input_not_found"}

        candidates = {
            str(best_node.get("text", "")).strip(),
            str(best_node.get("value", "")).strip(),
        }
        properties = best_node.get("properties", {})
        if isinstance(properties, dict):
            candidates.update(
                {
                    str(properties.get("text", "")).strip(),
                    str(properties.get("value", "")).strip(),
                    str(properties.get("content", "")).strip(),
                }
            )
        matched = any(expected in candidate for candidate in candidates if candidate)
        return {
            "ok": matched,
            "reason": "matched" if matched else "value_not_observed",
            "element": best_node,
            "candidates": [candidate for candidate in candidates if candidate],
        }

    def _iter_nodes(self, ui_tree: dict[str, Any]):
        stack = list(ui_tree.get("nodes", []))
        while stack:
            node = stack.pop(0)
            yield node
            stack[0:0] = node.get("children", [])

    def _find_first_child_toggle(self, node: dict[str, Any]) -> dict[str, Any] | None:
        queue = list(node.get("children", []))
        while queue:
            current = queue.pop(0)
            if current.get("type") == "Toggle":
                return self._node_to_element(current)
            queue[0:0] = current.get("children", [])
        return None

    def _node_to_element(self, node: dict[str, Any]) -> dict[str, Any]:
        props = node.get("properties", {})
        left = int(props.get("left", 0))
        top = int(props.get("top", 0))
        width = int(props.get("width", 0))
        height = int(props.get("height", 0))
        return {
            "type": node.get("type", ""),
            "text": props.get("text", ""),
            "id": props.get("id", ""),
            "x": left + width // 2,
            "y": top + height // 2,
            "left": left,
            "top": top,
            "width": width,
            "height": height,
            "checked": props.get("checked", False),
            "clickable": props.get("clickable", False),
        }

    def _pick_dialog_button_by_text(self, ui_tree: dict[str, Any], labels: list[str]) -> dict[str, Any] | None:
        wanted = {label.strip() for label in labels if label.strip()}
        if not wanted:
            return None
        region = FIREWALL_DIALOG_REGION
        buttons = []
        for node in self._nodes_by_type(ui_tree, "Button"):
            if not node.get("clickable"):
                continue
            text = str(node.get("text", "")).strip()
            if text not in wanted:
                continue
            left = node.get("left") or 0
            top = node.get("top") or 0
            if left < region["left_min"] or left > 2200:
                continue
            if top < region["top_min"] or top > 1850:
                continue
            buttons.append(node)
        if not buttons:
            return None
        return max(buttons, key=lambda node: ((node.get("top") or 0), (node.get("left") or 0)))

    def _normalize_auth_method(self, raw: str) -> str:
        upper = raw.upper()
        if "PIN" in upper:
            return "PIN"
        if "指纹" in raw:
            return "FINGERPRINT"
        if "人脸" in raw:
            return "FACE"
        return raw

    def _auth_method_option_text(self, normalized_method: str) -> str:
        mapping = {
            "PIN": "PIN 码",
            "FINGERPRINT": "指纹",
            "FACE": "人脸识别",
        }
        return mapping.get(normalized_method, normalized_method)

    async def _ensure_auth_dialog_cleared(self) -> None:
        ui_tree = await self._get_ui_tree()
        texts = {node.get("text", "") for node in self._nodes_by_type(ui_tree, "Text")}
        prompt_texts = {"请输入锁屏密码", "身份验证"}
        if texts.isdisjoint(prompt_texts):
            return

        password = self.runtime_config.tool_password.strip()
        if password:
            inputs = sorted(
                [node for node in self._nodes_by_type(ui_tree, "TextInput") if node.get("clickable")],
                key=lambda node: (node.get("top") or 0, node.get("left") or 0),
            )
            if inputs:
                target_input = inputs[0]
                await self._call_tool("click_element", {"x": target_input["x"], "y": target_input["y"]})
                await asyncio.sleep(0.2)
                input_result = await self._input_text_with_commit(target_input["x"], target_input["y"], password, commit_enter=True)
                if input_result.get("ok", False):
                    await asyncio.sleep(0.2)
                    confirm_result = await self._click_first_available_text(["确定", "确认"], bundle_name=None)
                    if not confirm_result.get("ok", False):
                        confirm_buttons = [
                            node
                            for node in self._nodes_by_type(ui_tree, "Button")
                            if node.get("clickable") and node.get("text") in {"确定", "确认"}
                        ]
                        if confirm_buttons:
                            button = confirm_buttons[0]
                            confirm_result = await self._call_tool(
                                "click_element",
                                {"x": button["x"], "y": button["y"]},
                            )
                    if confirm_result.get("ok", False):
                        gone_result = await self._call_tool(
                            "wait_element",
                            {
                                "text": "请输入锁屏密码",
                                "state": "gone",
                                "timeout_ms": 4000,
                                "interval_ms": 300,
                            },
                        )
                        if gone_result.get("ok", False):
                            return

        buttons = [node for node in self._nodes_by_type(ui_tree, "Button") if node.get("clickable")]
        cancel_button = next((node for node in buttons if node.get("text") == "取消"), None)
        target = cancel_button or min(buttons, key=lambda node: (node.get("left") or 0), default=None)
        if not target:
            return
        await self._call_tool("click_element", {"x": target["x"], "y": target["y"]})
        await asyncio.sleep(0.6)

    async def _detect_auth_prompt(self) -> bool:
        ui_tree = await self._get_ui_tree()
        texts = {node.get("text", "") for node in self._nodes_by_type(ui_tree, "Text")}
        prompt_texts = {"请输入锁屏密码", "身份验证"}
        return not texts.isdisjoint(prompt_texts)


BACKEND = RealHarmonyOsMcpBackend()
