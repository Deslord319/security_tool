from __future__ import annotations

from scripts.e2e.adapters.security_tool.strategies import TOOL_SETTINGS_PAGE_TEXT


ACTION_TEMPLATES = {
    "firewall.rule.create.domain": {
        "description": "Create a firewall domain rule via declarative firewall steps.",
        "sequence": [
            {"type": "open_firewall_rules_page", "params": {"rule_type": "domain"}},
            {
                "type": "submit_firewall_rule_form",
                "params": {
                    "rule_type": "domain",
                    "domain": "${data.domain}",
                    "direction": "${data.direction}",
                    "policy": "${data.policy}",
                    "protocol": "${data.protocol}",
                    "port": "${data.port}",
                    "name": "${data.name}",
                },
            },
        ],
    },
    "firewall.rule.delete.domain": {
        "description": "Delete a firewall domain rule via declarative firewall steps.",
        "sequence": [
            {"type": "open_firewall_rules_page", "params": {"rule_type": "domain"}},
            {"type": "assert_text_visible", "params": {"candidates": ["${data.name}", "${data.domain}"], "timeout_sec": 2.5}},
            {"type": "delete_visible_rule", "params": {"target": "${data.name}", "fallback_target": "${data.domain}"}},
        ],
    },
    "tool_settings.startup_auth.toggle": {
        "description": "Toggle startup authentication and persist the settings.",
        "sequence": [
            {
                "type": "toggle_first_on_page",
                "params": {
                    "page_text": TOOL_SETTINGS_PAGE_TEXT,
                    "target_state": "${data.target_state}",
                },
            },
            {"type": "save_tool_settings"},
        ],
    },
    "tool_settings.auth_method.update": {
        "description": "Update the auth method and persist the settings.",
        "sequence": [
            {"type": "select_indexed_option", "params": {"index": 0, "value": "${data.method}", "option_group": "auth_method"}},
            {"type": "save_tool_settings"},
        ],
    },
    "peripheral.interface.toggle.usb": {
        "description": "Toggle the USB interface through generic control steps.",
        "sequence": [
            {"type": "toggle_indexed_control", "params": {"control_type": "Select", "index": 0, "feature": "usb", "target_state": "${data.target_state}"}},
        ],
    },
    "peripheral.interface.toggle.bluetooth": {
        "description": "Toggle the Bluetooth interface through generic control steps.",
        "sequence": [
            {"type": "toggle_indexed_control", "params": {"control_type": "Select", "index": 2, "feature": "bluetooth", "target_state": "${data.target_state}"}},
        ],
    },
    "peripheral.interface.toggle.wifi": {
        "description": "Toggle the Wi-Fi interface through generic control steps.",
        "sequence": [
            {"type": "toggle_indexed_control", "params": {"control_type": "Select", "index": 3, "feature": "wifi", "target_state": "${data.target_state}"}},
        ],
    },
    "peripheral.interface.toggle.hdc": {
        "description": "Toggle the HDC interface through generic control steps.",
        "sequence": [
            {"type": "toggle_indexed_control", "params": {"control_type": "Select", "index": 4, "feature": "hdc", "target_state": "${data.target_state}"}},
        ],
    },
    "peripheral.usb_storage_policy.update": {
        "description": "Update the USB storage policy through generic select steps.",
        "sequence": [
            {"type": "select_indexed_option", "params": {"index": 0, "value": "${data.policy}", "option_group": "peripheral_usb_policy"}},
        ],
    },
    "logs.storage_settings.update": {
        "description": "Update the log storage max-entry setting through generic select steps.",
        "sequence": [
            {"type": "select_indexed_option", "params": {"index": 0, "value": "${data.max_entries}", "option_group": "log_max_entries"}},
        ],
    },
    "peripheral.whitelist.create.usb": {
        "description": "Add a USB device to the peripheral whitelist.",
        "sequence": [
            {"type": "open_named_dialog", "params": {"dialog_key": "peripheral.whitelist.create.usb"}},
            {"type": "fill_inputs", "params": {"field_group": "peripheral.whitelist.usb", "values": ["${data.device_id}"]}},
            {"type": "confirm_dialog", "params": {"allow_cancel": False}},
        ],
    },
    "peripheral.whitelist.create.bluetooth": {
        "description": "Add a Bluetooth device to the peripheral whitelist.",
        "sequence": [
            {"type": "open_named_dialog", "params": {"dialog_key": "peripheral.whitelist.create.bluetooth"}},
            {"type": "fill_inputs", "params": {"field_group": "peripheral.whitelist.bluetooth", "values": ["${data.device_id}"]}},
            {"type": "confirm_dialog", "params": {"allow_cancel": False}},
        ],
    },
    "peripheral.blacklist.create.usb": {
        "description": "Add a USB device to the peripheral blacklist.",
        "sequence": [
            {"type": "open_named_dialog", "params": {"dialog_key": "peripheral.blacklist.create.usb"}},
            {"type": "fill_inputs", "params": {"field_group": "peripheral.blacklist.usb", "values": ["${data.device_id}"]}},
            {"type": "confirm_dialog", "params": {"allow_cancel": False}},
        ],
    },
    "identity.password_policy.update": {
        "description": "Update the identity password policy through generic form steps.",
        "sequence": [
            {"type": "fill_inputs_with_fallback_touch", "params": {"field_group": "identity.password_policy", "values": ["${data.min_length}"]}},
        ],
    },
    "identity.domain_policy.update": {
        "description": "Update the identity domain policy through generic form steps.",
        "sequence": [
            {
                "type": "fill_inputs_with_fallback_touch",
                "params": {
                    "field_group": "identity.domain_policy",
                    "values": ["${data.password_max_age_days}", "${data.expiration_notify_days}", "${data.auth_validity_minutes}"],
                },
            },
        ],
    },
}
