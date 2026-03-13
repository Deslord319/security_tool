FLOW_REGISTRY = {
    "app.launch": {
        "description": "Launch SecurityTool into the foreground.",
        "kind": "system",
    },
    "navigation.open_page": {
        "description": "Navigate to a page using the project page registry.",
        "kind": "ui",
        "params": ["page_id"],
    },
    "theme_menu.open": {
        "description": "Open the three-dot theme and settings menu.",
        "kind": "ui",
    },
    "ui.capture_screenshot": {
        "description": "Capture a screenshot artifact through the MCP bridge.",
        "kind": "ui",
        "params": ["name"],
    },
    "firewall.toggle_status": {
        "description": "Toggle the firewall status switch from the firewall page.",
        "kind": "ui",
        "params": ["target_state"],
    },
    "firewall.open_rules": {
        "description": "Open firewall rules detail page for a specific rule type.",
        "kind": "ui",
        "params": ["rule_type"],
    },
    "firewall.add_rule": {
        "description": "Create a firewall rule from the rules detail page.",
        "kind": "ui",
    },
    "firewall.find_rule": {
        "description": "Locate a firewall rule in the rule list.",
        "kind": "ui",
    },
    "firewall.delete_rule": {
        "description": "Delete a firewall rule from the rule list.",
        "kind": "ui",
    },
    "browser.open_url": {
        "description": "Open a URL in the system browser or browser-like surface.",
        "kind": "ui",
        "params": ["url"],
    },
    "peripheral.toggle_interface": {
        "description": "Toggle a peripheral interface switch.",
        "kind": "ui",
        "params": ["feature", "target_state"],
    },
    "peripheral.select_usb_storage_policy": {
        "description": "Select a USB storage policy option.",
        "kind": "ui",
        "params": ["policy"],
    },
    "peripheral.open_usb_whitelist_dialog": {
        "description": "Open the USB whitelist dialog.",
        "kind": "ui",
    },
    "peripheral.add_usb_whitelist": {
        "description": "Add an item to the USB whitelist.",
        "kind": "ui",
    },
    "peripheral.open_bluetooth_whitelist_dialog": {
        "description": "Open the Bluetooth whitelist dialog.",
        "kind": "ui",
    },
    "peripheral.add_bluetooth_whitelist": {
        "description": "Add an item to the Bluetooth whitelist.",
        "kind": "ui",
    },
    "peripheral.open_usb_blacklist_dialog": {
        "description": "Open the USB blacklist dialog.",
        "kind": "ui",
    },
    "peripheral.add_usb_blacklist": {
        "description": "Add an item to the USB blacklist.",
        "kind": "ui",
    },
    "identity.update_password_policy": {
        "description": "Update the identity password policy form.",
        "kind": "ui",
    },
    "identity.update_domain_policy": {
        "description": "Update the identity domain policy form.",
        "kind": "ui",
    },
    "logs.export": {
        "description": "Trigger the log export flow.",
        "kind": "ui",
    },
    "logs.change_any_policy": {
        "description": "Apply one policy change to trigger a log event.",
        "kind": "ui",
    },
    "tool_settings.toggle_startup_auth": {
        "description": "Toggle startup authentication inside tool settings.",
        "kind": "ui",
        "params": ["target_state"],
    },
    "tool_settings.select_auth_method": {
        "description": "Select an authentication method in tool settings.",
        "kind": "ui",
        "params": ["method"],
    },
    "tool_settings.set_password": {
        "description": "Submit the tool password form.",
        "kind": "ui",
    },
    "tool_settings.save": {
        "description": "Save the current tool settings form.",
        "kind": "ui",
    },
}
