from __future__ import annotations

from typing import Any

from scripts.e2e.adapters.security_tool.resolvers import resolve_page_descriptor
from scripts.e2e.adapters.security_tool.strategies import FIREWALL_DIALOG_TITLE, TOP_MENU_VISIBLE_TEXT


class NavigationRuntimeMixin:
    async def _navigate_page(self, params: dict[str, Any]) -> dict[str, Any]:
        page_id = params.get("page_id", "")
        if not page_id:
            return self._fail("MCP_EXECUTION_FAILED", "page_id is required for navigate_page", {})
        target_view = str(params.get("target_view", "") or params.get("view", "")).strip().lower()
        require_firewall_main = page_id == "firewall" and target_view in {"main", "root", "default"}
        await self._ensure_auth_dialog_cleared()
        await self._dismiss_notice_dialogs()
        await self._dismiss_firewall_rule_dialog()
        await self._dismiss_delete_confirmation_dialog()
        await self._dismiss_top_menu_overlay()
        page = resolve_page_descriptor(page_id)
        page_text = page.page_text
        marker_text = page.marker_text
        route_id = f"route-page-{page_id}"
        sidebar_id = f"sidebar-nav-{page_id}"

        existing_marker = await self._wait_for_page_marker(
            page_id=page_id,
            route_element_id=route_id,
            marker_text=marker_text,
            page_text=page_text,
            timeout_sec=2.0,
        )
        if require_firewall_main and existing_marker.get("ok", False):
            return self._pass(
                "Already on target page",
                {
                    "page_id": page_id,
                    "sidebar_id": sidebar_id,
                    "route_id": route_id,
                    "marker_text": marker_text,
                    "page_text": page_text,
                    "target_view": "main",
                    "page_marker": existing_marker.get("match", {}),
                },
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

        if page_id == "firewall-rules":
            return await self._open_firewall_rules_page(str(params.get("rule_type", "domain") or "domain"))

        if page_id == "log-manage":
            log_result = await self._open_log_list({"action": "open_log_list", "params": params})
            if log_result.get("status") == "PASS":
                evidence = dict(log_result.get("evidence", {}))
                evidence.update(
                    {
                        "page_id": page_id,
                        "sidebar_id": sidebar_id,
                        "route_id": route_id,
                        "marker_text": marker_text,
                        "page_text": page_text,
                    }
                )
                return self._pass("Navigation completed", evidence)

        if page_id == "help-feedback":
            return await self._navigate_help_feedback(page_id, page_text, marker_text, route_id)

        click_result = {"ok": False}
        ui_tree = await self._get_ui_tree()
        sidebar_node = self._pick_sidebar_entry(ui_tree, page_id)
        if sidebar_node:
            click_result = await self._call_tool(
                "click_element",
                {"x": sidebar_node["x"], "y": sidebar_node["y"]},
            )
        if not click_result.get("ok", False):
            click_result = await self._click_first_available_text([page_text], bundle_name="com.huawei.securitytool")
        if not click_result.get("ok", False):
            click_result = await self._call_tool(
                "click_element",
                {"element_id": sidebar_id, "bundle_name": "com.huawei.securitytool"},
            )
        if not click_result.get("ok", False):
            return self._fail(
                "MCP_EXECUTION_FAILED",
                f"Failed to click sidebar item {sidebar_id}",
                {"click_result": click_result, "page_text": page_text, "marker_text": marker_text, "sidebar_node": sidebar_node or {}},
            )

        marker_result = await self._wait_for_page_marker(
            page_id=page_id,
            route_element_id=route_id,
            marker_text=marker_text,
            page_text=page_text,
            timeout_sec=14.0,
        )
        if page_id == "dashboard" and not marker_result.get("ok", False):
            ui_tree = await self._get_ui_tree()
            back_buttons = [
                node for node in self._nodes_by_type(ui_tree, "Button")
                if node.get("clickable")
                and 640 <= (node.get("left") or 0) <= 820
                and 360 <= (node.get("top") or 0) <= 520
                and (node.get("width") or 0) <= 120
                and (node.get("height") or 0) <= 120
            ]
            if back_buttons:
                back_button = min(back_buttons, key=lambda node: ((node.get("top") or 0), (node.get("left") or 0)))
                back_click = await self._call_tool("click_element", {"x": back_button["x"], "y": back_button["y"]})
                if back_click.get("ok", False):
                    marker_result = await self._wait_for_page_marker(
                        page_id=page_id,
                        route_element_id=route_id,
                        marker_text=marker_text,
                        page_text=page_text,
                        timeout_sec=5.0,
                    )
        if page_id == "firewall" and not marker_result.get("ok", False):
            if require_firewall_main:
                marker_result = await self._restore_firewall_main_page(marker_text=marker_text, page_text=page_text)
            else:
                ui_tree = await self._get_ui_tree()
                fallback = self._find_any_text_node(ui_tree, ["防火墙规则", FIREWALL_DIALOG_TITLE])
                if fallback:
                    marker_result = {"ok": True, "match": {"query": {"page_id": page_id, "text": "防火墙规则"}, "element": fallback}}
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
                "target_view": target_view,
                "page_marker": marker_result.get("match", {}),
            },
        )

    async def _restore_firewall_main_page(self, *, marker_text: str, page_text: str) -> dict[str, Any]:
        for _ in range(2):
            ui_tree = await self._get_ui_tree()
            marker_node = self._find_any_text_node(ui_tree, [marker_text])
            if marker_node:
                return {"ok": True, "match": {"query": {"page_id": "firewall", "text": marker_text}, "element": marker_node}}

            rules_marker = self._find_any_text_node(ui_tree, [FIREWALL_DIALOG_TITLE, "新增规则"])
            back_button = self._pick_firewall_subroute_back_button(ui_tree) if rules_marker else None
            if back_button:
                click_result = await self._call_tool("click_element", {"x": back_button["x"], "y": back_button["y"]})
                if not click_result.get("ok", False):
                    return {"ok": False, "click_result": click_result, "back_button": back_button}
            elif rules_marker:
                key_result = await self._call_tool("press_key", {"key": "BACK"})
                if not key_result.get("ok", False):
                    return {"ok": False, "press_key": key_result}
            else:
                return {"ok": False, "reason": "firewall rules page marker was not found"}

            restored = await self._wait_for_page_marker(
                page_id="firewall",
                route_element_id="route-page-firewall",
                marker_text=marker_text,
                page_text=page_text,
                timeout_sec=5.0,
            )
            if restored.get("ok", False):
                return restored
        return {"ok": False, "reason": "firewall main page did not restore"}

    def _pick_firewall_subroute_back_button(self, ui_tree: dict[str, Any]) -> dict[str, Any] | None:
        candidates = [
            node
            for node in self._nodes_by_type(ui_tree, "Button")
            if node.get("clickable")
            and 700 <= (node.get("left") or 0) <= 880
            and 420 <= (node.get("top") or 0) <= 540
            and (node.get("width") or 0) <= 120
            and (node.get("height") or 0) <= 120
        ]
        if not candidates:
            return None
        return min(candidates, key=lambda node: ((node.get("left") or 0), (node.get("top") or 0)))

    async def _navigate_help_feedback(
        self,
        page_id: str,
        page_text: str,
        marker_text: str,
        route_id: str,
    ) -> dict[str, Any]:
        menu_result = await self._open_top_menu({})
        if menu_result.get("status") != "PASS":
            return menu_result

        click_result = await self._click_first_available_text([page_text], bundle_name="com.huawei.securitytool")
        if not click_result.get("ok", False):
            return self._fail(
                "MCP_EXECUTION_FAILED",
                f"Failed to click help menu item {page_text}",
                {"menu_result": menu_result},
            )

        marker_result = await self._wait_for_page_marker(
            page_id=page_id,
            route_element_id=route_id,
            marker_text=marker_text,
            page_text=page_text,
            timeout_sec=5.0,
        )
        if not marker_result.get("ok", False):
            return self._unknown(
                {"action": "navigate_page", "params": {"page_id": page_id}},
                "MCP_ACTION_PENDING",
                "Help feedback menu item clicked but page marker did not resolve",
            )

        return self._pass(
            "Navigation completed",
            {
                "page_id": page_id,
                "sidebar_id": "",
                "route_id": route_id,
                "marker_text": marker_text,
                "page_text": page_text,
                "page_marker": marker_result.get("match", {}),
                "menu_match": menu_result.get("evidence", {}).get("menu_match", {}),
            },
        )

    async def _open_top_menu(self, params: dict[str, Any]) -> dict[str, Any]:
        await self._ensure_auth_dialog_cleared()
        await self._dismiss_notice_dialogs()
        if await self._is_top_menu_visible():
            return self._pass("Top menu opened", {"menu_match": {"query": {"text": "关于/跟随系统"}}})
        ui_tree = await self._get_ui_tree()
        menu_trigger = self._pick_top_menu_trigger(ui_tree)
        click_result = {"ok": False}
        if menu_trigger:
            click_result = await self._call_tool(
                "click_element",
                {"x": menu_trigger["x"], "y": menu_trigger["y"]},
            )
        if not click_result.get("ok", False):
            click_result = await self._call_tool(
                "click_element",
                {"element_id": "top-menu-trigger", "bundle_name": "com.huawei.securitytool"},
            )
        if not click_result.get("ok", False):
            return self._fail(
                "MCP_EXECUTION_FAILED",
                "Failed to click top menu trigger",
                {"click_result": click_result, "menu_trigger": menu_trigger or {}},
            )

        wait_result = await self._wait_for_any_texts(
            [TOP_MENU_VISIBLE_TEXT, "关于", "跟随系统"],
            timeout_sec=3.0,
        )
        if not wait_result.get("ok", False):
            return self._unknown(
                {"action": "open_top_menu", "params": params},
                "MCP_ACTION_PENDING",
                "Top menu trigger clicked but menu items were not detected",
            )

        return self._pass(
            "Top menu opened",
            {"menu_match": wait_result.get("match", {}), "menu_trigger": menu_trigger or {}},
        )

    async def _dismiss_notice_dialogs(self) -> None:
        for _ in range(2):
            close_result = await self._click_first_available_text(["我知道了", "知道了"], bundle_name="com.huawei.securitytool")
            if close_result.get("ok", False):
                continue
            break

    async def _dismiss_delete_confirmation_dialog(self) -> None:
        ui_tree = await self._get_ui_tree()
        if not self._find_any_text_node(ui_tree, ["确认删除这条规则吗？", "删除规则"]):
            return
        cancel_button = self._pick_button_by_text(ui_tree, ["取消"], min_left=800)
        if cancel_button:
            click_result = await self._call_tool("click_element", {"x": cancel_button["x"], "y": cancel_button["y"]})
            if click_result.get("ok", False):
                return
        await self._click_first_available_text(["取消"], bundle_name="com.huawei.securitytool")

    async def _dismiss_firewall_rule_dialog(self) -> None:
        if not await self._firewall_dialog_visible():
            return
        cancel_result = await self._click_first_available_text(["取消"], bundle_name="com.huawei.securitytool")
        if cancel_result.get("ok", False):
            await self._wait_for_firewall_dialog_closed(timeout_sec=2.0)

    async def _is_top_menu_visible(self) -> bool:
        wait_result = await self._wait_for_any_texts(["关于", "跟随系统"], timeout_sec=0.6, interval_sec=0.2)
        return wait_result.get("ok", False)

    async def _dismiss_top_menu_overlay(self) -> None:
        if not await self._is_top_menu_visible():
            return
        ui_tree = await self._get_ui_tree()
        menu_trigger = self._pick_top_menu_trigger(ui_tree)
        if not menu_trigger:
            return
        await self._call_tool("click_element", {"x": menu_trigger["x"], "y": menu_trigger["y"]})

    async def _driver_wait_for_page(self, payload: dict[str, Any]) -> dict[str, Any]:
        params = payload.get("params", {})
        page_id = str(params.get("page_id", ""))
        route_element_id = str(params.get("route_element_id", ""))
        marker_text = str(params.get("marker_text", ""))
        page_text = str(params.get("page_text", ""))
        timeout_sec = max(int(params.get("timeout_ms", 5000)) / 1000.0, 1.0)
        wait_result = await self._wait_for_page_marker(
            page_id=page_id,
            route_element_id=route_element_id,
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
