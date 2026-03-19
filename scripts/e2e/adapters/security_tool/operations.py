from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from scripts.e2e.adapters.security_tool.strategies import FIREWALL_PAGE_TEXT, TOOL_SETTINGS_STARTUP_AUTH_TEXT


PERIPHERAL_TOGGLE_PROBE_TEXT = {
    "usb": "USB",
    "bluetooth": "蓝牙",
    "wifi": "Wi-Fi",
    "hdc": "HDC",
}


@dataclass(frozen=True)
class OperationBinding:
    bridge_action: str
    expected: str
    params: dict[str, Any]
    toggle_probe: dict[str, Any] | None = None


def resolve_operation_binding(flow_ref: str, params: dict[str, Any] | None = None) -> OperationBinding | None:
    params = dict(params or {})
    if flow_ref not in {"entity.create", "entity.update", "entity.delete", "entity.toggle", "entity.submit"}:
        return None

    normalized = dict(params)
    normalized.setdefault("data", {})
    return _bind_template_operation(flow_ref, normalized)


def _bind_template_operation(flow_ref: str, params: dict[str, Any]) -> OperationBinding:
    domain = str(params.get("domain", "")).strip()
    entity = str(params.get("entity", "")).strip()
    action = str(params.get("action", flow_ref.split(".")[-1])).strip()
    variant = str(params.get("variant", "")).strip().lower()
    data = dict(params.get("data", {}))

    if not domain or not entity or not action:
        return OperationBinding(
            bridge_action="execute_template_action",
            expected="Template-backed action is executed",
            params={
                "template_key": "",
                "operation_ref": flow_ref,
                "domain": domain,
                "entity": entity,
                "action": action,
                "variant": variant,
                "data": data,
            },
        )

    template_key = ".".join(part for part in (domain, entity, action, variant) if part)
    expected = f"{domain} {entity} {action}"
    if variant:
        expected = f"{expected} ({variant})"

    toggle_probe = None
    if (domain, entity, action) == ("tool_settings", "startup_auth", "toggle"):
        toggle_probe = {"text": TOOL_SETTINGS_STARTUP_AUTH_TEXT}
    elif (domain, entity, action) == ("firewall", "status", "toggle"):
        toggle_probe = {"text": FIREWALL_PAGE_TEXT}
    elif (domain, entity, action) == ("peripheral", "interface", "toggle"):
        toggle_probe = {"text": PERIPHERAL_TOGGLE_PROBE_TEXT.get(variant, "")}

    return OperationBinding(
        bridge_action="execute_template_action",
        expected=expected,
        params={
            "template_key": template_key,
            "operation_ref": flow_ref,
            "domain": domain,
            "entity": entity,
            "action": action,
            "variant": variant,
            "data": data,
        },
        toggle_probe=toggle_probe,
    )
