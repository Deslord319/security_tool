from __future__ import annotations

from typing import Any

from scripts.e2e.adapters.security_tool.resolvers import resolve_page_descriptor
from scripts.e2e.adapters.security_tool.strategies import FIREWALL_DIALOG_TITLE, TOP_MENU_VISIBLE_TEXT


class NavigationRuntimeMixin:
    async def _navigate_page(self, params: dict[str, Any]) -> dict[str, Any]:
        page_id = params.get("page_id", "")
        if not page_id:
            return self._fail("MCP_EXECUTION_FAILED", "page_id is required for navigate_page", {})
        await self._ensure_auth_dialog_cleared()
        sidebar_id = f"sidebar-nav-{page_id}"
        route_id = f"route-page-{page_id}"
        page = resolve_page_descriptor(page_id)
        page_text = page.page_text
        marker_text = page.marker_text

        existing_marker = await self._wait_for_page_marker(
            page_id=page_id,
            route_element_id=route_id,
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
            timeout_sec=5.0,
        )
        if page_id == "firewall" and not marker_result.get("ok", False):
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
