from __future__ import annotations

import asyncio
import time
from typing import Any
from urllib.parse import urlparse

from scripts.e2e.adapters.security_tool.strategies import FIREWALL_DIALOG_REGION, FIREWALL_DIALOG_TITLE


class DialogBrowserHelpersMixin:
    async def _firewall_dialog_visible(self) -> bool:
        ui_tree = await self._get_ui_tree()
        title_nodes = [
            node
            for node in self._dialog_nodes_by_type(ui_tree, "Text")
            if str(node.get("text", "")).strip() == FIREWALL_DIALOG_TITLE
        ]
        if title_nodes:
            return True

        dialog_inputs = self._dialog_nodes_by_type(ui_tree, "TextInput")
        dialog_selects = self._dialog_nodes_by_type(ui_tree, "Select")
        dialog_texts = {str(node.get("text", "")).strip() for node in self._dialog_nodes_by_type(ui_tree, "Text")}
        dialog_buttons = [
            node
            for node in self._dialog_nodes_by_type(ui_tree, "Button")
            if str(node.get("text", "")).strip() in {"新增", "保存", "取消", "添加"}
        ]
        has_rule_dialog_labels = bool(dialog_texts.intersection({"目标用户", "目标模式", "规则名称", "域名", "IP 地址", "端口"}))
        return bool((dialog_inputs or has_rule_dialog_labels) and dialog_selects and dialog_buttons)

    async def _wait_for_firewall_dialog_closed(self, *, timeout_sec: float = 5.0) -> dict[str, Any]:
        deadline = time.time() + timeout_sec
        while time.time() < deadline:
            if not await self._firewall_dialog_visible():
                return self._pass("Firewall dialog closed", {"title": FIREWALL_DIALOG_TITLE})
            await asyncio.sleep(0.3)
        return self._unknown(
            {"action": "wait_for_firewall_dialog_closed", "params": {"timeout_sec": timeout_sec}},
            "MCP_ACTION_PENDING",
            "Firewall dialog is still visible",
        )

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

    async def _locate_browser_address_bar(self) -> dict[str, Any] | None:
        deadline = time.time() + 5.0
        while time.time() < deadline:
            tree = await self._get_ui_tree_for_bundle("com.huawei.hmos.browser")
            inputs = [
                node for node in self._nodes_by_type(tree, "TextInput")
                if node.get("clickable")
                and (node.get("top") or 0) <= 520
                and (node.get("left") or 0) >= 800
                and (node.get("width") or 0) >= 180
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
