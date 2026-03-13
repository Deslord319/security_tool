from __future__ import annotations

import json
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.e2e.bridges.action_plans import ACTION_PLANS


FLOW_TO_ACTION = {
    "navigation.open_page": "navigate_page",
    "theme_menu.open": "open_top_menu",
    "ui.capture_screenshot": "capture_screenshot",
    "firewall.toggle_status": "toggle_firewall",
    "firewall.open_rules": "open_firewall_rules",
    "firewall.add_rule": "add_firewall_rule",
    "firewall.find_rule": "find_firewall_rule",
    "firewall.delete_rule": "delete_firewall_rule",
    "browser.open_url": "open_browser_url",
    "peripheral.toggle_interface": "toggle_peripheral_interface",
    "peripheral.select_usb_storage_policy": "select_usb_storage_policy",
    "peripheral.open_usb_whitelist_dialog": "open_usb_whitelist_dialog",
    "peripheral.add_usb_whitelist": "add_usb_whitelist",
    "peripheral.open_bluetooth_whitelist_dialog": "open_bluetooth_whitelist_dialog",
    "peripheral.add_bluetooth_whitelist": "add_bluetooth_whitelist",
    "peripheral.open_usb_blacklist_dialog": "open_usb_blacklist_dialog",
    "peripheral.add_usb_blacklist": "add_usb_blacklist",
    "identity.update_password_policy": "update_password_policy",
    "identity.update_domain_policy": "update_domain_account_policy",
    "logs.export": "export_logs",
    "logs.change_any_policy": "change_any_policy",
    "tool_settings.toggle_startup_auth": "toggle_startup_auth",
    "tool_settings.select_auth_method": "select_auth_method",
    "tool_settings.set_password": "set_tool_password",
    "tool_settings.save": "save_tool_settings",
}


def load_flow_registry(project_root: Path) -> dict:
    namespace: dict = {}
    registry_file = project_root / "scripts/e2e/adapters/security_tool/flows/registry.py"
    exec(registry_file.read_text(encoding="utf-8"), namespace)  # noqa: S102
    return namespace["FLOW_REGISTRY"]


def load_scripted_results(project_root: Path) -> dict:
    result_file = project_root / "scripts/e2e/bridges/scripted_results.sample.json"
    return json.loads(result_file.read_text(encoding="utf-8"))


def build_rows(flow_registry: dict, scripted_results: dict) -> list[dict]:
    rows: list[dict] = []
    default_status = scripted_results.get("default", {}).get("status", "UNKNOWN")
    for flow_ref, meta in sorted(flow_registry.items()):
        action = FLOW_TO_ACTION.get(flow_ref, "")
        configured = action in scripted_results
        status = scripted_results.get(action, {}).get("status", default_status) if action else "N/A"
        rows.append(
            {
                "flow_ref": flow_ref,
                "kind": meta.get("kind", ""),
                "bridge_action": action,
                "has_action_plan": "yes" if action in ACTION_PLANS else "no",
                "scripted_coverage": "configured" if configured else "default",
                "scripted_status": status,
            }
        )
    return rows


def write_markdown(project_root: Path, rows: list[dict]) -> Path:
    target = project_root / "scripts/e2e/docs/BRIDGE_ACTION_COVERAGE.md"
    lines = [
        "# Bridge Action Coverage",
        "",
        "| Flow Ref | Kind | Bridge Action | Action Plan | Scripted Coverage | Scripted Status |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for row in rows:
        lines.append(
            f"| `{row['flow_ref']}` | `{row['kind']}` | `{row['bridge_action'] or '-'}` | "
            f"`{row['has_action_plan']}` | "
            f"`{row['scripted_coverage']}` | `{row['scripted_status']}` |"
        )
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return target


def main() -> int:
    project_root = Path(__file__).resolve().parents[3]
    flow_registry = load_flow_registry(project_root)
    scripted_results = load_scripted_results(project_root)
    rows = build_rows(flow_registry, scripted_results)
    target = write_markdown(project_root, rows)
    print(target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
