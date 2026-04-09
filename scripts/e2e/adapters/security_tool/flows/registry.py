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
    "ui.click_text": {
        "description": "Click a visible text target in the current page.",
        "kind": "ui",
        "params": ["text", "bundle_name", "contains"],
    },
    "ui.scroll_until_text": {
        "description": "Scroll the current page until the target text becomes visible.",
        "kind": "ui",
        "params": ["text", "direction", "max_swipes", "timeout_ms"],
    },
    "entity.create": {
        "description": "Create a domain entity through adapter-backed declarative templates.",
        "kind": "ui",
        "params": ["domain", "entity", "variant", "data"],
    },
    "entity.update": {
        "description": "Update a domain entity through adapter-backed declarative templates.",
        "kind": "ui",
        "params": ["domain", "entity", "variant", "data"],
    },
    "entity.delete": {
        "description": "Delete a domain entity through adapter-backed declarative templates.",
        "kind": "ui",
        "params": ["domain", "entity", "variant", "data"],
    },
    "entity.toggle": {
        "description": "Toggle a domain entity through adapter-backed declarative templates.",
        "kind": "ui",
        "params": ["domain", "entity", "data"],
    },
    "entity.submit": {
        "description": "Submit a domain workflow through adapter-backed declarative templates.",
        "kind": "ui",
        "params": ["domain", "entity", "variant", "data"],
    },
    "firewall.toggle_status": {
        "description": "Toggle the firewall status switch from the firewall page.",
        "kind": "ui",
        "params": ["target_state"],
    },
    "browser.open_url": {
        "description": "Open a URL in the system browser or browser-like surface.",
        "kind": "ui",
        "params": ["url"],
    },
    "logs.export": {
        "description": "Trigger the log export flow.",
        "kind": "ui",
    },
    "logs.change_any_policy": {
        "description": "Apply one policy change to trigger a log event.",
        "kind": "ui",
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
