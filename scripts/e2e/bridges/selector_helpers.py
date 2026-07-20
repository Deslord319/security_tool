from __future__ import annotations

from typing import Any

from scripts.e2e.adapters.security_tool.resolvers import (
    find_node_by_id as resolve_node_by_id,
    find_page_marker_node as resolve_page_marker_node,
    pick_sidebar_entry as resolve_sidebar_entry,
    resolve_dialog_descriptor,
    resolve_field_descriptor,
    resolve_option_descriptor,
)
from scripts.e2e.adapters.security_tool.strategies import (
    CONFIRM_DELETE_LABELS,
    CONFIRM_DIALOG_LABELS,
    FIREWALL_DIALOG_REGION,
)


class SelectorHelpersMixin:
    def _find_page_marker_node(self, ui_tree: dict[str, Any], *, marker_text: str, page_text: str) -> dict[str, Any] | None:
        return resolve_page_marker_node(
            ui_tree,
            marker_text=marker_text,
            page_text=page_text,
            iter_nodes=self._iter_nodes,
            nodes_by_type=self._nodes_by_type,
        )

    def _find_node_by_id(self, ui_tree: dict[str, Any], element_id: str) -> dict[str, Any] | None:
        return resolve_node_by_id(ui_tree, element_id, iter_nodes=self._iter_nodes, node_to_element=self._node_to_element)

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

    def _pick_tool_settings_save_button(self, ui_tree: dict[str, Any]) -> dict[str, Any] | None:
        explicit = self._pick_button_by_text(ui_tree, ["保存设置"], min_left=2200)
        if explicit:
            return explicit
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

    def _pick_sidebar_entry(self, ui_tree: dict[str, Any], page_id: str) -> dict[str, Any] | None:
        return resolve_sidebar_entry(
            ui_tree,
            page_id,
            iter_nodes=self._iter_nodes,
            node_to_element=self._node_to_element,
        )

    def _pick_top_menu_trigger(self, ui_tree: dict[str, Any]) -> dict[str, Any] | None:
        buttons = [
            node for node in self._nodes_by_type(ui_tree, "Button")
            if node.get("clickable")
            and (node.get("left") or 0) >= 2200
            and (node.get("top") or 0) <= 380
            and (node.get("width") or 0) <= 140
            and (node.get("height") or 0) <= 140
        ]
        if buttons:
            return min(buttons, key=lambda node: (node.get("top") or 0, -(node.get("left") or 0)))

        fallback: list[dict[str, Any]] = []
        for node in self._iter_nodes(ui_tree):
            props = node.get("properties", {})
            left = int(props.get("left", 0))
            top = int(props.get("top", 0))
            width = int(props.get("width", 0))
            height = int(props.get("height", 0))
            if not props.get("clickable"):
                continue
            if left < 2200 or top > 380 or width > 160 or height > 160:
                continue
            fallback.append(self._node_to_element(node))
        if not fallback:
            return None
        return min(fallback, key=lambda node: (node.get("top") or 0, -(node.get("left") or 0)))

    def _pick_toggle_node(self, ui_tree: dict[str, Any], *, text: str = "", element_id: str = "") -> dict[str, Any] | None:
        toggles = self._nodes_by_type(ui_tree, "Toggle")
        if not toggles:
            return None
        if not text and not element_id:
            return toggles[0]

        normalized_text = text.strip()
        for toggle in toggles:
            props = toggle.get("properties", {})
            if element_id and toggle.get("id") == element_id:
                return toggle
            if normalized_text and str(toggle.get("text", "")).strip() == normalized_text:
                return toggle
        for node in self._iter_nodes(ui_tree):
            props = node.get("properties", {})
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

    async def _open_named_dialog(self, payload: dict[str, Any], labels: list[str] | None = None, dialog_key: str = "") -> dict[str, Any]:
        dialog = resolve_dialog_descriptor(dialog_key) if dialog_key else None
        candidate_labels = labels or list(dialog.labels if dialog else [])
        open_result = await self._click_first_available_text(candidate_labels, bundle_name="com.huawei.securitytool")
        if not open_result.get("ok", False):
            return self._unknown(payload, "MCP_ACTION_PENDING", f"Dialog trigger was not found: {'/'.join(candidate_labels)}")
        return self._pass(
            "Dialog trigger clicked",
            {
                "labels": candidate_labels,
                "dialog_key": dialog_key,
                "dialog_region": dict(dialog.region) if dialog else {},
            },
        )

    async def _fill_text_inputs(self, values: list[str], *, field_group: str = "") -> dict[str, Any]:
        filtered_values = [value for value in values if value]
        if not filtered_values:
            return self._pass("No input values requested", {"filled_inputs": []})
        field_descriptor = resolve_field_descriptor(field_group) if field_group else None
        ui_tree = await self._get_ui_tree_for_bundle("com.huawei.securitytool")
        inputs = sorted(self._nodes_by_type(ui_tree, "TextInput"), key=lambda node: (node.get("top") or 0, node.get("left") or 0))
        if not inputs:
            return self._fail("MCP_EXECUTION_FAILED", "No text inputs were detected", {})
        filled: list[dict[str, Any]] = []
        field_keys = list(field_descriptor.field_keys if field_descriptor else ())
        for index, (node, value) in enumerate(zip(inputs, filtered_values, strict=False)):
            input_result = await self._input_text_with_commit(node["x"], node["y"], value, commit_enter=True)
            if not input_result.get("ok", False):
                return self._fail("MCP_EXECUTION_FAILED", "Failed to input text field", {"input_result": input_result, "node": node})
            filled.append({"node": node, "value": value, "field_key": field_keys[index] if index < len(field_keys) else ""})
        return self._pass(
            "Text inputs filled",
            {
                "filled_inputs": filled,
                "field_group": field_group,
                "field_keys": field_keys,
            },
        )

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

    def _find_first_child_toggle(self, node: dict[str, Any]) -> dict[str, Any] | None:
        queue = list(reversed(node.get("children", [])))
        while queue:
            current = queue.pop()
            if current.get("type") == "Toggle":
                return self._node_to_element(current)
            queue.extend(reversed(current.get("children", [])))
        return None

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
        if buttons:
            return max(buttons, key=lambda node: ((node.get("top") or 0), (node.get("left") or 0)))

        fallback_buttons: list[dict[str, Any]] = []
        for node in self._iter_nodes(ui_tree):
            props = node.get("properties", {})
            if not props.get("clickable"):
                continue
            left = int(props.get("left", 0))
            top = int(props.get("top", 0))
            width = int(props.get("width", 0))
            height = int(props.get("height", 0))
            if left < region["left_min"] or left > 2200:
                continue
            if top < region["top_min"] or top > 1850 or width <= 0 or height <= 0:
                continue
            if not self._collect_descendant_texts(node).intersection(wanted):
                continue
            fallback_buttons.append(self._node_to_element(node))
        if not fallback_buttons:
            return None
        return max(fallback_buttons, key=lambda node: ((node.get("top") or 0), (node.get("left") or 0)))

    def _resolve_option_labels(self, option_group: str, option_key: str, fallback: list[str] | None = None) -> list[str]:
        descriptor = resolve_option_descriptor(option_group, option_key)
        labels = list(descriptor.labels)
        if labels:
            return labels
        return list(fallback or [])
