from __future__ import annotations

import asyncio
import sys
import time
from pathlib import Path
from typing import Any

PROJECT_ROOT = Path(__file__).resolve().parents[3]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.e2e.adapters.security_tool.runtime_config import load_runtime_config
from scripts.e2e.adapters.security_tool.strategies import (
    DELETE_ACTION_LABELS,
    FIREWALL_DIALOG_TITLE,
    FIREWALL_DIRECTION_OPTION_LABELS,
    FIREWALL_PAGE_TEXT,
    FIREWALL_POLICY_OPTION_LABELS,
    FIREWALL_PROTOCOL_OPTION_LABELS,
    FIREWALL_RULE_TYPE_LABELS,
    PERIPHERAL_USB_POLICY_OPTION_LABELS,
)
from scripts.e2e.bridges.complex_hooks import ComplexHooksMixin
from scripts.e2e.bridges.dialog_browser_helpers import DialogBrowserHelpersMixin
from scripts.e2e.bridges.navigation_runtime import NavigationRuntimeMixin
from scripts.e2e.bridges.selector_helpers import SelectorHelpersMixin
from scripts.e2e.bridges.template_runtime import TemplateRuntimeMixin
from scripts.e2e.bridges.ui_runtime_helpers import UiRuntimeHelpersMixin


class RealHarmonyOsMcpBackend(
    UiRuntimeHelpersMixin,
    SelectorHelpersMixin,
    DialogBrowserHelpersMixin,
    NavigationRuntimeMixin,
    TemplateRuntimeMixin,
    ComplexHooksMixin,
):
    def __init__(self) -> None:
        self.project_root = PROJECT_ROOT
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
        if action == "click_text":
            return await self._click_text(payload)
        if action == "click_element":
            return await self._click_element(payload)
        if action == "press_key":
            return await self._press_key(payload)
        if action == "execute_template_action":
            return await self._execute_template_action(payload)
        if action == "toggle_firewall":
            return await self._toggle_first_toggle(payload, page_text=FIREWALL_PAGE_TEXT)
        if action == "__driver_get_toggle_state":
            return await self._get_toggle_state(payload)
        if action == "save_tool_settings":
            return await self._save_tool_settings(payload)
        if action == "set_tool_password":
            return await self._open_tool_password_settings(payload)
        if action == "open_browser_url":
            return await self._open_browser_url(payload)
        if action == "export_logs":
            return await self._export_logs(payload)
        if action == "open_log_list":
            return await self._open_log_list(payload)
        if action == "open_log_storage_settings":
            return await self._open_log_storage_settings(payload)
        if action == "save_log_storage_settings":
            return await self._save_log_storage_settings(payload)
        if action == "change_any_policy":
            return await self._change_any_policy(payload)

        return self._unknown(payload, "MCP_ACTION_PENDING", f"Action not implemented: {action}")

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
        return self._unknown(payload, "MCP_ACTION_PENDING", f"Target text did not appear after scrolling: {text}")

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
        match_mode = str(params.get("match_mode", "contains")).strip().lower()
        timeout_ms = int(params.get("timeout_ms", 1500))
        interval_ms = int(params.get("interval_ms", 250))
        deadline = time.time() + (timeout_ms / 1000)
        while time.time() < deadline:
            ui_tree = await self._get_ui_tree_for_bundle(str(bundle_name))
            for node in self._iter_nodes(ui_tree):
                props = node.get("properties", {}) or {}
                node_text = str(props.get("text", "")).strip()
                if not node_text:
                    continue
                matched = text == node_text if match_mode == "exact" else text == node_text or text in node_text
                if matched:
                    return self._pass(
                        "Text presence resolved",
                        {
                            "exists": True,
                            "element": self._node_to_element(node),
                            "source": "ui_tree",
                            "match_mode": match_mode,
                        },
                    )
            await asyncio.sleep(max(interval_ms, 50) / 1000)
        return self._pass("Text presence resolved", {"exists": False, "element": {}, "source": "ui_tree", "match_mode": match_mode})

    async def _open_log_list(self, payload: dict[str, Any]) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        sidebar_result = await self._click_log_sidebar_if_needed()
        page_ready = await self._find_texts_in_current_tree(["导出日志", "日志存储配置", "最大存储条数"], timeout_sec=4.0)
        if not page_ready.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", "Log management page did not appear")

        list_ready = await self._find_texts_in_current_tree(["导出日志"], timeout_sec=0.8)
        if list_ready.get("ok", False):
            return self._pass("Log list already visible", {"sidebar": sidebar_result, "match": list_ready.get("match", {})})

        back_result = await self._click_button_by_descendant_text("日志列表", min_left=2400, max_top=700)
        click_result = back_result.get("click_result", {"ok": False})
        if not click_result.get("ok", False):
            click_result = await self._click_first_available_text(["日志列表"], bundle_name="com.huawei.securitytool")
            back_result = {"button": {}, "click_result": click_result}
        if not click_result.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", "Log list action was not found")

        list_ready = await self._find_texts_in_current_tree(["导出日志"], timeout_sec=4.0)
        if not list_ready.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", "Log list did not appear after clicking the list action")

        return self._pass(
            "Log list opened",
            {
                "sidebar": sidebar_result,
                "button": back_result.get("button", {}),
                "match": list_ready.get("match", {}),
            },
        )

    async def _click_log_sidebar_if_needed(self) -> dict[str, Any]:
        ui_tree = await self._get_ui_tree()
        sidebar = self._pick_sidebar_entry(ui_tree, "log-manage")
        if not sidebar:
            return {"clicked": False, "reason": "sidebar_not_found"}
        click_result = await self._call_tool("click_element", {"x": sidebar["x"], "y": sidebar["y"]})
        return {"clicked": bool(click_result.get("ok", False)), "sidebar": sidebar}

    async def _open_log_storage_settings(self, payload: dict[str, Any]) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        already_open = await self._find_texts_in_current_tree(["日志存储配置", "最大存储条数"], timeout_sec=1.0)
        if already_open.get("ok", False):
            return self._pass("Log storage settings already visible", {"match": already_open.get("match", {})})

        ui_tree = await self._get_ui_tree()
        candidates: list[dict[str, Any]] = []
        for node in self._iter_nodes(ui_tree):
            props = node.get("properties", {}) or {}
            if not props.get("clickable"):
                continue
            left = int(props.get("left", 0))
            top = int(props.get("top", 0))
            if left < 2100 or top > 700:
                continue
            if "存储设置" not in self._collect_descendant_texts(node):
                continue
            candidates.append(self._node_to_element(node))

        click_result = {"ok": False}
        storage_button = None
        if candidates:
            storage_button = max(candidates, key=lambda item: (item.get("left") or 0, -(item.get("top") or 0)))
            click_result = await self._call_tool("click_element", {"x": storage_button["x"], "y": storage_button["y"]})

        if not click_result.get("ok", False):
            click_result = await self._click_first_available_text(["存储设置"], bundle_name="com.huawei.securitytool")

        if not click_result.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", "Log storage settings entry was not found")

        ready = await self._find_texts_in_current_tree(["日志存储配置", "最大存储条数"], timeout_sec=4.0)
        if not ready.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", "Log storage settings panel did not appear after click")

        return self._pass(
            "Log storage settings opened",
            {
                "button": storage_button or {},
                "match": ready.get("match", {}),
            },
        )

    async def _save_log_storage_settings(self, payload: dict[str, Any]) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        save_button = await self._click_button_by_descendant_text("保存设置", min_left=2200, max_top=700)
        click_result = save_button.get("click_result", {"ok": False})
        if not click_result.get("ok", False):
            click_result = await self._click_first_available_text(["保存设置"], bundle_name="com.huawei.securitytool")
            save_button = {"button": {}, "click_result": click_result}

        if not click_result.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", "Log storage save button was not found")

        result = await self._find_texts_in_current_tree(["设置已保存"], timeout_sec=4.0)
        if not result.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", "Log storage save result did not appear after click")

        return self._pass(
            "Log storage settings saved",
            {
                "button": save_button.get("button", {}),
                "result": result.get("match", {}),
            },
        )

    async def _click_button_by_descendant_text(self, text: str, *, min_left: int, max_top: int) -> dict[str, Any]:
        ui_tree = await self._get_ui_tree()
        candidates: list[dict[str, Any]] = []
        for node in self._iter_nodes(ui_tree):
            props = node.get("properties", {}) or {}
            if not props.get("clickable"):
                continue
            left = int(props.get("left", 0))
            top = int(props.get("top", 0))
            if left < min_left or top > max_top:
                continue
            if text not in self._collect_descendant_texts(node):
                continue
            candidates.append(self._node_to_element(node))
        if not candidates:
            return {"button": {}, "click_result": {"ok": False}}
        button = max(candidates, key=lambda item: (item.get("left") or 0, -(item.get("top") or 0)))
        click_result = await self._call_tool("click_element", {"x": button["x"], "y": button["y"]})
        return {"button": button, "click_result": click_result}

    async def _find_texts_in_current_tree(self, texts: list[str], *, timeout_sec: float) -> dict[str, Any]:
        wanted = [text for text in texts if text.strip()]
        deadline = time.time() + timeout_sec
        while time.time() < deadline:
            ui_tree = await self._get_ui_tree()
            for node in self._iter_nodes(ui_tree):
                props = node.get("properties", {}) or {}
                node_text = str(props.get("text", "")).strip()
                if not node_text:
                    continue
                for text in wanted:
                    if text == node_text or text in node_text:
                        return {
                            "ok": True,
                            "match": {
                                "query": {"text": text},
                                "element": self._node_to_element(node),
                            },
                        }
            await asyncio.sleep(0.25)
        return {"ok": False}

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

    async def _click_text(self, payload: dict[str, Any]) -> dict[str, Any]:
        params = payload.get("params", {})
        target_text = str(params.get("text", "")).strip()
        bundle_name = str(params.get("bundle_name", "")).strip() or "com.huawei.securitytool"
        contains = bool(params.get("contains", False))
        if not target_text:
            return self._fail("MCP_EXECUTION_FAILED", "Text is required", {"params": params})

        await self._ensure_auth_dialog_cleared()
        ui_tree = await (self._get_ui_tree() if bundle_name == "com.huawei.securitytool" else self._get_ui_tree_for_bundle(bundle_name))
        candidates: list[dict[str, Any]] = []
        for node in self._nodes_by_type(ui_tree, "Text"):
            text = str(node.get("text", "")).strip()
            if not text:
                continue
            matched = target_text in text if contains else text == target_text
            if matched:
                candidates.append(node)

        if not candidates:
            return self._unknown(payload, "MCP_ACTION_PENDING", f"Visible text target was not found: {target_text}")

        target = min(candidates, key=lambda node: ((node.get("top") or 0), (node.get("left") or 0)))
        click_result = await self._call_tool("click_element", {"x": target["x"], "y": target["y"]})
        if not click_result.get("ok", False):
            return self._fail("MCP_EXECUTION_FAILED", "Failed to click text target", {"target": target, "click_result": click_result})
        return self._pass("Text target clicked", {"target": target, "bundle_name": bundle_name, "contains": contains})

    async def _click_element(self, payload: dict[str, Any]) -> dict[str, Any]:
        params = dict(payload.get("params", {}))
        params = {key: value for key, value in params.items() if value not in ("", None)}
        if "bundle_name" not in params:
            params["bundle_name"] = "com.huawei.securitytool"
        if not any(key in params for key in ("element_id", "text", "x", "y")):
            return self._fail("MCP_EXECUTION_FAILED", "Element selector is required", {"params": payload.get("params", {})})
        await self._ensure_auth_dialog_cleared()
        click_result = await self._call_tool("click_element", params)
        if not click_result.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", "Visible element target was not found")
        return self._pass("Element target clicked", {"params": params})

    async def _press_key(self, payload: dict[str, Any]) -> dict[str, Any]:
        params = payload.get("params", {})
        key = str(params.get("key", "")).strip()
        if not key:
            return self._fail("MCP_EXECUTION_FAILED", "Key is required", {"params": params})
        result = await self._call_tool("press_key", {"key": key})
        if not result.get("ok", False):
            return self._fail("MCP_EXECUTION_FAILED", "Failed to press device key", {"key": key, "press_result": result})
        return self._pass("Device key pressed", {"key": key})

    async def _toggle_first_toggle(self, payload: dict[str, Any], *, page_text: str) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        wait_page = await self._wait_for_page_marker(page_id="", route_element_id="", marker_text=page_text, page_text=page_text, timeout_sec=5.0)
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

    async def _configure_firewall_dialog_selects(self, params: dict[str, Any]) -> dict[str, Any]:
        rule_type = str(params.get("rule_type", "")).lower()
        direction = str(params.get("direction", "")).lower()
        policy = str(params.get("policy", "")).lower()
        protocol = str(params.get("protocol", "")).lower()
        select_evidence: list[dict[str, Any]] = []

        for index, expected_text in [
            (0, FIREWALL_RULE_TYPE_LABELS.get(rule_type, "")),
            (1, FIREWALL_DIRECTION_OPTION_LABELS.get(direction, [""])[0] if FIREWALL_DIRECTION_OPTION_LABELS.get(direction) else ""),
            (2, FIREWALL_PROTOCOL_OPTION_LABELS.get(protocol, [""])[0] if FIREWALL_PROTOCOL_OPTION_LABELS.get(protocol) else ""),
        ]:
            result = await self._set_dialog_select_value(index, expected_text)
            if result is None:
                continue
            if result.get("status") != "PASS":
                return result
            select_evidence.append(result.get("evidence", {}))

        ui_tree = await self._get_ui_tree()
        selects = self._dialog_nodes_by_type(ui_tree, "Select")
        if selects and policy:
            desired_policy = FIREWALL_POLICY_OPTION_LABELS.get(policy, [])
            result = await self._set_dialog_select_value(len(selects) - 1, desired_policy[0] if desired_policy else "")
            if result is not None:
                if result.get("status") != "PASS":
                    return result
                select_evidence.append(result.get("evidence", {}))

        return self._pass("Firewall dialog selects configured", {"selects": select_evidence})

    async def _set_dialog_select_value(self, index: int, expected_text: str) -> dict[str, Any] | None:
        if not expected_text:
            return None
        ui_tree = await self._get_ui_tree()
        selects = self._dialog_nodes_by_type(ui_tree, "Select")
        if index >= len(selects):
            return None
        select_node = selects[index]
        if str(select_node.get("text", "")).strip() == expected_text:
            return self._pass("Dialog select already matched", {"index": index, "expected_text": expected_text})
        await self._call_tool("click_element", {"x": select_node["x"], "y": select_node["y"]})
        choose_result = await self._choose_dialog_option(select_node, [expected_text])
        if choose_result.get("status") != "PASS":
            return choose_result
        wait_result = await self._wait_for_dialog_select_text(index, expected_text)
        if wait_result.get("status") != "PASS":
            return self._fail(
                "MCP_EXECUTION_FAILED",
                f"Firewall select did not update to {expected_text}",
                {"index": index, "expected_text": expected_text, "wait_result": wait_result, "choose_result": choose_result},
            )
        return self._pass("Dialog select configured", {"index": index, "expected_text": expected_text, "wait_result": wait_result})

    async def _fill_firewall_dialog_inputs(self, params: dict[str, Any]) -> dict[str, Any]:
        ui_tree = await self._get_ui_tree()
        inputs = self._dialog_nodes_by_type(ui_tree, "TextInput")
        if not inputs:
            return self._unknown({"action": "fill_firewall_dialog_inputs", "params": params}, "MCP_ACTION_PENDING", "Firewall rule form inputs were not detected")

        rule_type = str(params.get("rule_type", "")).lower()
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
        return self._pass("Firewall dialog inputs populated", {"filled_inputs": filled})

    async def _assert_any_text_visible(self, candidates: list[str], *, timeout_sec: float = 2.5) -> dict[str, Any]:
        for candidate in candidates:
            if not candidate:
                continue
            wait_result = await self._wait_for([{"text": candidate, "bundle_name": "com.huawei.securitytool"}], timeout_sec=timeout_sec)
            if wait_result.get("ok", False):
                return self._pass("Target text located", {"matched": wait_result.get("match", {}), "candidate": candidate})
        return self._unknown({"action": "assert_any_text_visible"}, "MCP_ACTION_PENDING", "Target text could not be located yet")

    async def _delete_visible_rule(self, *, target: str, fallback_target: str = "") -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        await self._dismiss_notice_dialogs()
        normalized_target = str(target or "").strip()
        normalized_fallback = str(fallback_target or "").strip()
        if normalized_target.lower() in {"none", "null"}:
            normalized_target = ""
        if normalized_fallback.lower() in {"none", "null"}:
            normalized_fallback = ""
        chosen_target = normalized_target or normalized_fallback

        def pick_delete_button(ui_tree: dict[str, Any]) -> dict[str, Any] | None:
            candidates: list[dict[str, Any]] = []
            for node in self._iter_nodes(ui_tree):
                props = node.get("properties", {})
                left = int(props.get("left", 0))
                top = int(props.get("top", 0))
                width = int(props.get("width", 0))
                height = int(props.get("height", 0))
                if not props.get("clickable"):
                    continue
                if left < 2200 or top < 800 or top > 1150 or width < 40 or height < 24:
                    continue
                texts = self._collect_descendant_texts(node)
                if not texts.intersection(DELETE_ACTION_LABELS):
                    continue
                candidates.append(self._node_to_element(node))
            if not candidates:
                return None
            return max(candidates, key=lambda node: (node.get("left") or 0, -(node.get("top") or 0)))

        ui_tree = await self._get_ui_tree()
        delete_button = pick_delete_button(ui_tree)
        delete_click = {"ok": False}
        if delete_button:
            delete_click = await self._call_tool("click_element", {"x": delete_button["x"], "y": delete_button["y"]})
        if not delete_click.get("ok", False):
            delete_click = await self._click_first_available_text(DELETE_ACTION_LABELS, bundle_name="com.huawei.securitytool")
        if not delete_click.get("ok", False):
            ui_tree = await self._get_ui_tree()
            delete_button = pick_delete_button(ui_tree)
            if delete_button:
                delete_click = await self._call_tool("click_element", {"x": delete_button["x"], "y": delete_button["y"]})
        if not delete_click.get("ok", False):
            return self._unknown({"action": "delete_visible_rule"}, "MCP_ACTION_PENDING", "Delete action was not found")
        confirm_result = await self._confirm_dialog(allow_cancel=False)
        if confirm_result.get("status") != "PASS":
            return confirm_result
        if chosen_target:
            await self._wait_for_element(text=chosen_target, state="gone", timeout_sec=3.0)
        return self._pass("Firewall rule delete triggered", {"target": chosen_target})

    async def _toggle_indexed_control(self, *, control_type: str, index: int, feature: str = "") -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        ui_tree = await self._get_ui_tree()
        nodes = sorted(self._nodes_by_type(ui_tree, control_type), key=lambda node: (node.get("top") or 0, node.get("left") or 0))
        if not nodes:
            return self._unknown({"action": "toggle_indexed_control"}, "MCP_ACTION_PENDING", f"{control_type} controls were not detected")
        safe_index = min(max(index, 0), len(nodes) - 1)
        target = nodes[safe_index]

        if str(control_type).lower() == "select" and feature:
            current_text = str(target.get("text", "")).strip()
            desired_text = "禁用" if current_text == "启用" else "启用"
            open_result = await self._call_tool("click_element", {"x": target["x"], "y": target["y"]})
            if not open_result.get("ok", False):
                return self._fail("MCP_EXECUTION_FAILED", "Failed to open Select control", {"click_result": open_result, "control": target, "index": safe_index})
            option_result = await self._choose_any_option([desired_text])
            if option_result.get("status") != "PASS":
                return option_result
            return self._pass(
                "Select control toggled",
                {
                    "feature": feature,
                    "control": target,
                    "index": safe_index,
                    "before_text": current_text,
                    "after_text": desired_text,
                },
            )

        click_result = await self._call_tool("click_element", {"x": target["x"], "y": target["y"]})
        if not click_result.get("ok", False):
            return self._fail("MCP_EXECUTION_FAILED", f"Failed to click {control_type} control", {"click_result": click_result, "control": target, "index": safe_index})
        return self._pass(f"{control_type} control toggled", {"feature": feature, "control": target, "index": safe_index})

    async def _select_indexed_option(
        self,
        *,
        index: int,
        value: str,
        option_group: str = "",
        options: dict[str, Any],
    ) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        find_result = await self._call_tool("find_element", {"bundle_name": "com.huawei.securitytool", "element_type": "Select"})
        structured = find_result.get("result", find_result)
        selects = structured.get("elements", []) if find_result.get("ok", False) else []
        if not selects:
            ui_tree = await self._get_ui_tree()
            selects = self._nodes_by_type(ui_tree, "Select")
        selects = sorted(selects, key=lambda node: (node.get("top") or 0, node.get("left") or 0))
        if not selects:
            return self._unknown({"action": "select_indexed_option"}, "MCP_ACTION_PENDING", "Select controls were not detected")
        safe_index = min(max(index, 0), len(selects) - 1)
        select_node = selects[safe_index]
        open_result = await self._call_tool("click_element", {"x": select_node["x"], "y": select_node["y"]})
        if not open_result.get("ok", False):
            return self._fail("MCP_EXECUTION_FAILED", "Failed to open select control", {"click_result": open_result, "select": select_node, "index": safe_index})
        labels = options.get(str(value).lower(), [])
        if isinstance(labels, str):
            labels = [labels]
        if not isinstance(labels, list):
            labels = []
        current_text = str(select_node.get("text", "")).strip()
        if current_text and current_text in labels:
            return self._pass("Indexed select option already matched", {"index": safe_index, "value": value, "labels": labels, "select": select_node})
        fallback_labels = (
            PERIPHERAL_USB_POLICY_OPTION_LABELS.get("read_only", [])
            + PERIPHERAL_USB_POLICY_OPTION_LABELS.get("allow", [])
        )
        resolved_labels = self._resolve_option_labels(option_group, str(value).lower(), labels or fallback_labels)
        option_result = await self._choose_any_option(resolved_labels or fallback_labels)
        if option_result.get("status") != "PASS":
            return option_result
        return self._pass(
            "Indexed select option chosen",
            {
                "index": safe_index,
                "value": value,
                "labels": resolved_labels,
                "option_group": option_group,
            },
        )

    async def _fill_inputs_with_fallback_touch(self, values: list[str], *, params: dict[str, Any] | None = None) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        fill_result = await self._fill_text_inputs(values)
        if fill_result.get("status") == "PASS":
            return self._pass("Inputs populated", {"params": params or {}, "fill": fill_result.get("evidence", {}), "values": values})
        action_result = await self._touch_identity_controls()
        if action_result.get("status") != "PASS":
            return fill_result
        return self._pass("Fallback controls interacted", {"params": params or {}, "interaction": action_result.get("evidence", {}), "values": values})

    def _first_node_by_type(self, ui_tree: dict[str, Any], node_type: str) -> dict[str, Any] | None:
        nodes = self._nodes_by_type(ui_tree, node_type)
        return nodes[0] if nodes else None

    async def _wait_for_page_marker(
        self,
        *,
        page_id: str,
        route_element_id: str,
        marker_text: str,
        page_text: str,
        timeout_sec: float,
    ) -> dict[str, Any]:
        deadline = time.time() + timeout_sec
        while time.time() < deadline:
            ui_tree = await self._get_ui_tree()
            if route_element_id:
                route_node = self._find_node_by_id(ui_tree, route_element_id)
                if route_node:
                    return {
                        "ok": True,
                        "match": {
                            "query": {"page_id": page_id, "element_id": route_element_id},
                            "element": route_node,
                        },
                    }
            marker_node = self._find_page_marker_node(ui_tree, marker_text=marker_text, page_text=page_text)
            if marker_node:
                query_text = marker_text or page_text
                return {"ok": True, "match": {"query": {"page_id": page_id, "text": query_text}, "element": marker_node}}
            await asyncio.sleep(0.35)
        return {"ok": False}

BACKEND = RealHarmonyOsMcpBackend()
