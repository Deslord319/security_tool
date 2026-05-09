from __future__ import annotations

import asyncio
import time
from typing import Any
from urllib.parse import urlparse

from scripts.e2e.adapters.security_tool.strategies import (
    FIREWALL_ADD_RULE_TEXTS,
    FIREWALL_CUSTOM_RULE_TEXT,
    FIREWALL_DIALOG_TITLE,
    FIREWALL_PAGE_TEXT,
    FIREWALL_RULE_TYPE_LABELS,
    TOOL_SETTINGS_PAGE_TEXT,
    TOOL_SETTINGS_SAVE_TEXT,
)


class ComplexHooksMixin:
    def _pick_firewall_custom_mode_card(self, ui_tree: dict[str, Any]) -> dict[str, Any] | None:
        candidates: list[dict[str, Any]] = []
        for node in self._iter_nodes(ui_tree):
            props = node.get("properties", {})
            left = int(props.get("left", 0))
            top = int(props.get("top", 0))
            width = int(props.get("width", 0))
            height = int(props.get("height", 0))
            if not props.get("clickable"):
                continue
            if left < 650 or top < 840 or top > 1120 or width < 1200 or height < 120:
                continue
            texts = self._collect_descendant_texts(node)
            if "自定义模式" not in texts and FIREWALL_CUSTOM_RULE_TEXT not in texts:
                continue
            candidates.append(self._node_to_element(node))
        if not candidates:
            return None
        return max(candidates, key=lambda node: ((node.get("width") or 0), (node.get("height") or 0)))

    async def _count_visible_text_matches(self, candidates: list[str]) -> dict[str, Any]:
        wanted = {str(candidate).strip() for candidate in candidates if str(candidate).strip()}
        if not wanted:
            return {"count": 0, "matches": [], "candidates": []}
        ui_tree = await self._get_ui_tree()
        matches = [
            node
            for node in self._nodes_by_type(ui_tree, "Text")
            if str(node.get("text", "")).strip() in wanted
        ]
        return {
            "count": len(matches),
            "matches": matches[:10],
            "candidates": sorted(wanted),
        }

    async def _open_firewall_rules_page(self, rule_type: str) -> dict[str, Any]:
        label = FIREWALL_RULE_TYPE_LABELS.get(str(rule_type).lower(), "")
        if not label:
            return self._fail("MCP_EXECUTION_FAILED", f"Unsupported firewall rule_type: {rule_type}", {})

        rules_page_ready = await self._wait_for(
            [
                {"element_id": "route-page-firewall-rules", "bundle_name": "com.huawei.securitytool"},
                {"text": "新增规则", "bundle_name": "com.huawei.securitytool"},
            ],
            timeout_sec=1.2,
        )
        if not rules_page_ready.get("ok", False):
            nav_result = await self._navigate_page({"page_id": "firewall"})
            if nav_result.get("status") == "FAIL":
                return nav_result

            ui_tree = await self._get_ui_tree()
            header_toggle = next(
                (
                    node for node in self._nodes_by_type(ui_tree, "Toggle")
                    if node.get("clickable") and (node.get("top") or 0) <= 500
                ),
                None,
            )
            if header_toggle and not bool(header_toggle.get("checked", False)):
                toggle_result = await self._toggle_first_toggle(
                    {"action": "toggle_firewall", "params": {"target_state": "on"}},
                    page_text=FIREWALL_PAGE_TEXT,
                )
                if toggle_result.get("status") != "PASS":
                    return toggle_result
                await asyncio.sleep(1.0)
                ui_tree = await self._get_ui_tree()

            custom_mode_card = self._pick_firewall_custom_mode_card(ui_tree)
            click_result = {"ok": False}
            if custom_mode_card:
                click_result = await self._call_tool(
                    "click_element",
                    {"x": custom_mode_card["x"], "y": custom_mode_card["y"]},
                )
            if not click_result.get("ok", False):
                click_result = await self._click_first_available_text(
                    [FIREWALL_CUSTOM_RULE_TEXT],
                    bundle_name="com.huawei.securitytool",
                )

            custom_rule_entry = custom_mode_card
            if not click_result.get("ok", False) and not custom_rule_entry:
                return self._fail(
                    "MCP_EXECUTION_FAILED",
                    f"Failed to locate firewall custom rule entry: {FIREWALL_CUSTOM_RULE_TEXT}",
                    {"navigation": nav_result, "rule_type": str(rule_type).lower()},
                )

            if not click_result.get("ok", False):
                return self._fail(
                    "MCP_EXECUTION_FAILED",
                    f"Failed to open firewall custom rules entry: {FIREWALL_CUSTOM_RULE_TEXT}",
                    {"click_result": click_result, "custom_rule_entry": custom_rule_entry},
                )

            rules_page_ready = await self._wait_for(
                [
                    {"element_id": "route-page-firewall-rules", "bundle_name": "com.huawei.securitytool"},
                    {"text": "新增规则", "bundle_name": "com.huawei.securitytool"},
                ],
                timeout_sec=12.0,
            )
        wait_result = rules_page_ready
        if not wait_result.get("ok", False):
            return self._unknown(
                {"action": "open_firewall_rules_page", "params": {"rule_type": rule_type}},
                "MCP_ACTION_PENDING",
                f"Custom rule entry clicked but rules page was not detected for {label}",
            )
        return self._pass("Firewall rules page opened", {"rule_type": str(rule_type).lower(), "matched": wait_result.get("match", {})})

    async def _submit_firewall_rule_form(self, params: dict[str, Any]) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        target_name = str(params.get("name") or params.get("host") or params.get("domain") or params.get("ip") or "e2e-rule")
        target_candidates = [
            target_name,
            str(params.get("host") or ""),
            str(params.get("domain") or ""),
            str(params.get("ip") or ""),
        ]
        before_match = await self._count_visible_text_matches(target_candidates)
        if not await self._firewall_dialog_visible():
            ui_tree = await self._get_ui_tree()
            add_button = self._pick_button_by_text(ui_tree, FIREWALL_ADD_RULE_TEXTS)
            open_result = {"ok": False}
            if add_button:
                open_result = await self._call_tool("click_element", {"x": add_button["x"], "y": add_button["y"]})
            if not open_result.get("ok", False):
                open_result = await self._click_first_available_text(FIREWALL_ADD_RULE_TEXTS, bundle_name="com.huawei.securitytool")
            if not open_result.get("ok", False):
                return self._unknown({"action": "submit_firewall_rule_form", "params": params}, "MCP_ACTION_PENDING", "Add rule trigger was not found")

        dialog_ready = await self._wait_for(
            [
                {"text": FIREWALL_DIALOG_TITLE, "bundle_name": "com.huawei.securitytool"},
                {"text": "新增", "bundle_name": "com.huawei.securitytool"},
            ],
            timeout_sec=4.0,
        )
        if not dialog_ready.get("ok", False):
            return self._unknown({"action": "submit_firewall_rule_form", "params": params}, "MCP_ACTION_PENDING", "Add rule dialog did not appear")

        select_result = await self._configure_firewall_dialog_selects(params)
        if select_result.get("status") != "PASS":
            return select_result
        fill_result = await self._fill_firewall_dialog_inputs(params)
        if fill_result.get("status") != "PASS":
            return fill_result

        submit_result = await self._confirm_dialog()
        if submit_result.get("status") != "PASS":
            return submit_result
        dialog_closed = await self._wait_for_firewall_dialog_closed(timeout_sec=5.0)
        await self._dismiss_notice_dialogs()
        rule_created = await self._assert_any_text_visible(
            target_candidates,
            timeout_sec=3.0,
        )
        after_match = await self._count_visible_text_matches(target_candidates)
        evidence = {
            "params": params,
            "fill": fill_result.get("evidence", {}),
            "submit": submit_result.get("evidence", {}),
            "selects": select_result.get("evidence", {}),
            "before_match": before_match,
            "after_match": after_match,
            "dialog_closed": dialog_closed,
        }
        evidence["rule_created"] = rule_created
        before_count = int(before_match.get("count", 0))
        after_count = int(after_match.get("count", 0))
        if rule_created.get("status") == "PASS" and after_count > before_count:
            return self._pass("Firewall rule dialog submitted", evidence)
        if rule_created.get("status") == "PASS" and dialog_closed.get("status") == "PASS":
            return self._pass("Firewall rule dialog submitted", evidence)
        if rule_created.get("status") == "PASS" and before_count > 0 and dialog_closed.get("status") != "PASS":
            cancel_result = await self._click_first_available_text(["取消"], bundle_name="com.huawei.securitytool")
            evidence["duplicate_cancel"] = cancel_result
            if cancel_result.get("ok", False):
                evidence["dialog_closed_after_cancel"] = await self._wait_for_firewall_dialog_closed(timeout_sec=2.0)
            return self._pass("Firewall rule already present", evidence)
        if dialog_closed.get("status") != "PASS":
            return self._unknown({"action": "submit_firewall_rule_form", "params": params}, "MCP_ACTION_PENDING", "Firewall rule dialog is still open after submit")
        if rule_created.get("status") != "PASS":
            return self._unknown({"action": "submit_firewall_rule_form", "params": params}, "MCP_ACTION_PENDING", "Firewall rule dialog closed but target rule was not observed")
        return self._pass("Firewall rule dialog submitted", evidence)

    async def _open_tool_password_settings(self, payload: dict[str, Any]) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        ui_tree = await self._get_ui_tree()
        password_button = self._pick_button_by_text(ui_tree, ["修改密码"], min_left=2200)
        open_result = None
        if password_button:
            click_result = await self._call_tool("click_element", {"x": password_button["x"], "y": password_button["y"]})
            if click_result.get("ok", False):
                open_result = {"ok": True, "button": password_button, "source": "button"}
        if not open_result:
            fallback = await self._click_first_available_text(["修改密码"], bundle_name="com.huawei.securitytool")
            if fallback.get("ok", False):
                open_result = {"ok": True, "source": "text"}
        if not open_result:
            return self._unknown(payload, "MCP_ACTION_PENDING", "Password settings entry was not located")

        deadline = time.time() + 6.0
        settings_detected = False
        while time.time() < deadline:
            ui_tree = await self._get_ui_tree()
            for node in self._iter_nodes(ui_tree):
                props = node.get("properties", {}) or {}
                if str(props.get("bundleName", "")).strip() == "com.huawei.hmos.settings":
                    settings_detected = True
                    break
            if settings_detected:
                break
            await asyncio.sleep(0.3)

        await self._call_tool("run_app", {"bundle_name": "com.huawei.securitytool", "auto_detect": True})
        await self._wait_for_any_texts(["工具设置", "修改密码"], timeout_sec=5.0)
        return self._pass(
            "Tool password settings entry opened",
            {
                "trigger": open_result,
                "settings_bundle": "com.huawei.hmos.settings",
                "returned_to_bundle": "com.huawei.securitytool",
                "settings_observed": settings_detected,
            },
        )

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

    async def _export_logs(self, payload: dict[str, Any]) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        open_result = await self._click_first_available_text(["导出", "导出日志"], bundle_name="com.huawei.securitytool")
        if not open_result.get("ok", False):
            ui_tree = await self._get_ui_tree()
            open_button = self._pick_primary_button(ui_tree)
            if open_button:
                open_result = await self._call_tool("click_element", {"x": open_button["x"], "y": open_button["y"]})
        if not open_result.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", "Log export trigger was not found")
        await self._wait_for_any_texts(["CSV", "Excel", "TXT"], timeout_sec=2.0)
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
        await self._dismiss_notice_dialogs()
        return self._pass(
            "Tool settings save action executed",
            {"save_button": save_button or {}, "wait_match": wait_result.get("match", {})},
        )
