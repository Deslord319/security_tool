from __future__ import annotations

import asyncio
from collections import deque
from typing import Any

from fastmcp import Client  # type: ignore

from harmonyos_dev_mcp.server import mcp  # type: ignore

from scripts.e2e.bridges.action_plans import ACTION_PLANS
from scripts.e2e.core.utils import run_command


class UiRuntimeHelpersMixin:
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

    async def _wait_for_element(
        self,
        *,
        bundle_name: str = "com.huawei.securitytool",
        text: str = "",
        element_id: str = "",
        element_type: str = "",
        state: str = "found",
        timeout_sec: float = 5.0,
        interval_sec: float = 0.3,
    ) -> dict[str, Any]:
        query = {
            "bundle_name": bundle_name,
            "state": state,
        }
        if text:
            query["text"] = text
        if element_id:
            query["element_id"] = element_id
        if element_type:
            query["element_type"] = element_type
        return await self._wait_for([query], timeout_sec=timeout_sec, interval_sec=interval_sec)

    async def _wait_for_any_texts(
        self,
        texts: list[str],
        *,
        bundle_name: str = "com.huawei.securitytool",
        timeout_sec: float = 3.0,
        interval_sec: float = 0.3,
    ) -> dict[str, Any]:
        queries = [{"bundle_name": bundle_name, "text": text} for text in texts if text.strip()]
        return await self._wait_for(queries, timeout_sec=timeout_sec, interval_sec=interval_sec)

    async def _get_ui_tree(self) -> dict[str, Any]:
        result = await self._call_tool("get_ui_tree", {"bundle_name": "com.huawei.securitytool"})
        structured = result.get("result", result)
        ui_tree = structured.get("ui_tree", {}) if isinstance(structured, dict) else {}
        return self._filter_ui_tree_by_bundle(ui_tree, "com.huawei.securitytool")

    async def _get_ui_tree_for_bundle(self, bundle_name: str) -> dict[str, Any]:
        result = await self._call_tool("get_ui_tree", {"bundle_name": bundle_name})
        structured = result.get("result", result)
        ui_tree = structured.get("ui_tree", {}) if isinstance(structured, dict) else {}
        return self._filter_ui_tree_by_bundle(ui_tree, bundle_name)

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

    def _iter_nodes(self, ui_tree: dict[str, Any]):
        queue = deque(ui_tree.get("nodes", []))
        while queue:
            node = queue.popleft()
            yield node
            queue.extend(node.get("children", []))

    def _collect_descendant_texts(self, node: dict[str, Any]) -> set[str]:
        texts: set[str] = set()
        queue = deque([node])
        while queue:
            current = queue.popleft()
            props = current.get("properties", {})
            text = str(props.get("text", "")).strip()
            if text:
                texts.add(text)
            queue.extend(current.get("children", []))
        return texts

    def _filter_ui_tree_by_bundle(self, ui_tree: dict[str, Any], bundle_name: str) -> dict[str, Any]:
        if not isinstance(ui_tree, dict):
            return {}
        nodes = ui_tree.get("nodes", [])
        if not isinstance(nodes, list):
            return ui_tree
        filtered_nodes = []
        for node in nodes:
            props = node.get("properties", {}) or {}
            if str(props.get("bundleName", "")).strip() == bundle_name:
                filtered_nodes.append(node)
        if not filtered_nodes:
            return ui_tree
        return {**ui_tree, "nodes": filtered_nodes, "count": len(filtered_nodes)}

    def _node_to_element(self, node: dict[str, Any]) -> dict[str, Any]:
        props = node.get("properties", {})
        left = int(props.get("left", 0))
        top = int(props.get("top", 0))
        width = int(props.get("width", 0))
        height = int(props.get("height", 0))
        return {
            "type": node.get("type", ""),
            "text": props.get("text", ""),
            "id": props.get("id", "") or props.get("ID", ""),
            "x": left + width // 2,
            "y": top + height // 2,
            "left": left,
            "top": top,
            "width": width,
            "height": height,
            "checked": props.get("checked", False),
            "clickable": props.get("clickable", False),
            "properties": props,
        }

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
            matches.append(
                {
                    "type": node_type,
                    "text": props.get("text", ""),
                    "id": props.get("id", "") or props.get("ID", ""),
                    "x": int(left) + int(width) // 2,
                    "y": int(top) + int(height) // 2,
                    "left": int(left),
                    "top": int(top),
                    "width": int(width),
                    "height": int(height),
                    "checked": props.get("checked", False),
                    "clickable": props.get("clickable", False),
                    "properties": props,
                }
            )
        return matches

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
            enriched = dict(input_result)
            enriched.setdefault("result", {})
            enriched["result"]["verification"] = verify_result
            if enter_evidence:
                enriched["result"]["commit"] = enter_evidence
            return enriched
        verify_after_enter: dict[str, Any] = {}
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
            self.project_root,
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
                input_result = await self._input_text_with_commit(target_input["x"], target_input["y"], password, commit_enter=True)
                if input_result.get("ok", False):
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
                        gone_result = await self._wait_for_element(
                            text="请输入锁屏密码",
                            state="gone",
                            timeout_sec=4.0,
                        )
                        if gone_result.get("ok", False):
                            return

        buttons = [node for node in self._nodes_by_type(ui_tree, "Button") if node.get("clickable")]
        cancel_button = next((node for node in buttons if node.get("text") == "取消"), None)
        target = cancel_button or min(buttons, key=lambda node: (node.get("left") or 0), default=None)
        if not target:
            return
        await self._call_tool("click_element", {"x": target["x"], "y": target["y"]})
        await self._wait_for_element(text="请输入锁屏密码", state="gone", timeout_sec=1.2)

    async def _detect_auth_prompt(self) -> bool:
        ui_tree = await self._get_ui_tree()
        texts = {node.get("text", "") for node in self._nodes_by_type(ui_tree, "Text")}
        prompt_texts = {"请输入锁屏密码", "身份验证"}
        return not texts.isdisjoint(prompt_texts)
