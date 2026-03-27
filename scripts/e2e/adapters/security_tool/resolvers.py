from __future__ import annotations

from typing import Any

from scripts.e2e.core.resolver_contracts import DialogDescriptor, FieldDescriptor, OptionDescriptor, PageDescriptor
from scripts.e2e.adapters.security_tool.strategies import DIALOG_STRATEGIES, FIELD_GROUP_STRATEGIES, OPTION_GROUP_STRATEGIES, PAGE_STRATEGIES


PAGE_REGISTRY = {page_id: config["page_text"] for page_id, config in PAGE_STRATEGIES.items()}
PAGE_MARKERS = {page_id: config["marker_text"] for page_id, config in PAGE_STRATEGIES.items()}


def get_page_text(page_id: str) -> str:
    return PAGE_REGISTRY.get(page_id, "")


def get_page_marker(page_id: str) -> str:
    return PAGE_MARKERS.get(page_id, get_page_text(page_id))


def resolve_page_descriptor(page_id: str) -> PageDescriptor:
    return PageDescriptor(
        page_id=page_id,
        page_text=get_page_text(page_id),
        marker_text=get_page_marker(page_id),
    )


def resolve_dialog_descriptor(dialog_key: str) -> DialogDescriptor:
    dialog = DIALOG_STRATEGIES.get(dialog_key, {})
    labels = tuple(dialog.get("labels", []))
    region = dict(dialog.get("region", {}))
    return DialogDescriptor(dialog_key=dialog_key, labels=labels, region=region)


def resolve_option_descriptor(option_group: str, option_key: str) -> OptionDescriptor:
    labels = OPTION_GROUP_STRATEGIES.get(option_group, {}).get(option_key, [])
    return OptionDescriptor(option_group=option_group, option_key=option_key, labels=tuple(labels))


def resolve_field_descriptor(field_group: str) -> FieldDescriptor:
    field_keys = tuple(FIELD_GROUP_STRATEGIES.get(field_group, []))
    return FieldDescriptor(field_group=field_group, field_keys=field_keys)


def list_registered_pages() -> list[str]:
    return list(PAGE_REGISTRY.keys())


def find_page_marker_node(ui_tree: dict[str, Any], *, marker_text: str, page_text: str, iter_nodes: Any, nodes_by_type: Any) -> dict[str, Any] | None:
    candidate_texts = [marker_text] if marker_text else [page_text] if page_text else []
    if not candidate_texts:
        return None
    for node in nodes_by_type(ui_tree, "Text"):
        text = str(node.get("text", "")).strip()
        if text not in candidate_texts:
            continue
        if (node.get("left") or 0) < 380:
            continue
        return node
    return None


def find_node_by_id(ui_tree: dict[str, Any], element_id: str, *, iter_nodes: Any, node_to_element: Any) -> dict[str, Any] | None:
    wanted = str(element_id).strip()
    if not wanted:
        return None
    for node in iter_nodes(ui_tree):
        props = node.get("properties", {})
        if props.get("id") == wanted:
            return node_to_element(node)
    return None


def pick_sidebar_entry(ui_tree: dict[str, Any], page_id: str, *, nodes_by_type: Any) -> dict[str, Any] | None:
    target_text = get_page_text(page_id)
    sidebar_nodes = [
        node for node in nodes_by_type(ui_tree, "Text")
        if (node.get("left") or 0) <= 700 and 120 <= (node.get("top") or 0) <= 900
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
