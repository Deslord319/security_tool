from __future__ import annotations

import asyncio
import time
from typing import Any
from urllib.parse import urlparse

from scripts.e2e.adapters.security_tool.strategies import FIREWALL_DIALOG_REGION, FIREWALL_DIALOG_TITLE


class DialogBrowserHelpersMixin:
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
