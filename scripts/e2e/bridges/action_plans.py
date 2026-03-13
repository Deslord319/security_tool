from __future__ import annotations


ACTION_PLANS = {
    "navigate_page": {
        "goal": "Open a page from the left navigation rail.",
        "required_params": ["page_id"],
        "mcp_tools": ["find_element", "click_element", "wait_element"],
        "steps": [
            "Resolve the target page title from the adapter page registry.",
            "Find the navigation item by text or stable page locator.",
            "Click the navigation item.",
            "Wait for the page title or a page-specific anchor text to appear.",
        ],
    },
    "open_top_menu": {
        "goal": "Open the top three-dot menu.",
        "required_params": [],
        "mcp_tools": ["find_element", "click_element", "wait_element"],
        "steps": [
            "Find the top menu trigger.",
            "Click the trigger.",
            "Wait for one of the known menu items to appear.",
        ],
    },
    "capture_screenshot": {
        "goal": "Capture a screenshot artifact for the current UI state.",
        "required_params": ["name"],
        "mcp_tools": ["screenshot"],
        "steps": [
            "Generate a stable artifact file name.",
            "Capture a screenshot through the HarmonyOS screenshot tool.",
            "Return the artifact path as evidence.",
        ],
    },
    "toggle_firewall": {
        "goal": "Toggle the firewall switch to the desired state.",
        "required_params": ["target_state"],
        "mcp_tools": ["find_element", "click_element", "get_ui_tree"],
        "steps": [
            "Locate the firewall toggle.",
            "Read the current toggle state.",
            "Click only if the current state differs from the target state.",
            "Read the toggle state again and return the final state.",
        ],
    },
    "open_firewall_rules": {
        "goal": "Open a firewall rule detail page for a specific rule type.",
        "required_params": ["rule_type"],
        "mcp_tools": ["find_element", "click_element", "wait_element"],
        "steps": [
            "Locate the rule type card or list item.",
            "Click the rule type.",
            "Wait for the rules detail page title or add button.",
        ],
    },
    "add_firewall_rule": {
        "goal": "Create a firewall rule from the rule detail page.",
        "required_params": [],
        "mcp_tools": ["find_element", "click_element", "input_text", "wait_element"],
        "steps": [
            "Open the add rule dialog.",
            "Fill the fields required by the rule type.",
            "Submit the dialog.",
            "Wait for the dialog to disappear or a success hint to appear.",
        ],
    },
    "find_firewall_rule": {
        "goal": "Find a firewall rule in the current rule list.",
        "required_params": [],
        "mcp_tools": ["find_element", "scroll_until_text"],
        "steps": [
            "Find the target rule text in the current list.",
            "If needed, scroll until the target text becomes visible.",
        ],
    },
    "delete_firewall_rule": {
        "goal": "Delete a firewall rule from the current rule list.",
        "required_params": [],
        "mcp_tools": ["find_element", "click_element", "wait_until_gone"],
        "steps": [
            "Locate the target rule entry.",
            "Trigger delete from the rule row or detail dialog.",
            "Confirm the deletion if a dialog appears.",
            "Wait until the target rule disappears.",
        ],
    },
    "open_browser_url": {
        "goal": "Open a URL in the system browser.",
        "required_params": ["url"],
        "mcp_tools": ["run_app", "find_element", "input_text", "press_key"],
        "steps": [
            "Bring the browser to the foreground.",
            "Focus the address bar.",
            "Input the target URL.",
            "Press Enter or the equivalent confirm key.",
        ],
    },
    "toggle_peripheral_interface": {
        "goal": "Toggle one interface in the peripheral management page.",
        "required_params": ["feature", "target_state"],
        "mcp_tools": ["find_element", "click_element", "get_ui_tree"],
        "steps": [
            "Locate the target peripheral interface row.",
            "Read the current switch state.",
            "Click only when a state change is required.",
            "Read the resulting state and return it.",
        ],
    },
    "select_usb_storage_policy": {
        "goal": "Change the USB storage policy from the select control.",
        "required_params": ["policy"],
        "mcp_tools": ["find_element", "click_element", "wait_element"],
        "steps": [
            "Open the USB storage policy select control.",
            "Choose the target option.",
            "Wait for the selected value to be visible in the control.",
        ],
    },
    "open_usb_whitelist_dialog": {
        "goal": "Open the USB whitelist dialog.",
        "required_params": [],
        "mcp_tools": ["find_element", "click_element", "wait_element"],
        "steps": [
            "Locate the USB whitelist entry point.",
            "Open the add dialog.",
            "Wait for the dialog title or confirm button.",
        ],
    },
    "add_usb_whitelist": {
        "goal": "Add an item to the USB whitelist.",
        "required_params": [],
        "mcp_tools": ["find_element", "input_text", "click_element", "wait_element"],
        "steps": [
            "Fill the USB whitelist fields.",
            "Submit the dialog.",
            "Wait for the new item text or a success hint.",
        ],
    },
    "open_bluetooth_whitelist_dialog": {
        "goal": "Open the Bluetooth whitelist dialog.",
        "required_params": [],
        "mcp_tools": ["find_element", "click_element", "wait_element"],
        "steps": [
            "Locate the Bluetooth whitelist entry point.",
            "Open the add dialog.",
            "Wait for the dialog contents.",
        ],
    },
    "add_bluetooth_whitelist": {
        "goal": "Add an item to the Bluetooth whitelist.",
        "required_params": [],
        "mcp_tools": ["find_element", "input_text", "click_element", "wait_element"],
        "steps": [
            "Fill the Bluetooth whitelist fields.",
            "Submit the dialog.",
            "Wait for the new item or a success hint.",
        ],
    },
    "open_usb_blacklist_dialog": {
        "goal": "Open the USB blacklist dialog.",
        "required_params": [],
        "mcp_tools": ["find_element", "click_element", "wait_element"],
        "steps": [
            "Locate the USB blacklist entry point.",
            "Open the add dialog.",
            "Wait for the dialog to be visible.",
        ],
    },
    "add_usb_blacklist": {
        "goal": "Add an item to the USB blacklist.",
        "required_params": [],
        "mcp_tools": ["find_element", "input_text", "click_element", "wait_element"],
        "steps": [
            "Fill the blacklist form.",
            "Submit the dialog.",
            "Wait for the new item or a success hint.",
        ],
    },
    "update_password_policy": {
        "goal": "Update the identity password policy form.",
        "required_params": [],
        "mcp_tools": ["find_element", "input_text", "click_element"],
        "steps": [
            "Locate the password policy form controls.",
            "Update each configured field.",
            "Return field-level evidence for later save/verification.",
        ],
    },
    "update_domain_account_policy": {
        "goal": "Update the identity domain account policy form.",
        "required_params": [],
        "mcp_tools": ["find_element", "input_text", "click_element"],
        "steps": [
            "Locate the domain policy controls.",
            "Update the configured fields.",
            "Return field-level evidence for later verification.",
        ],
    },
    "export_logs": {
        "goal": "Run the log export flow.",
        "required_params": [],
        "mcp_tools": ["find_element", "click_element", "wait_element"],
        "steps": [
            "Open the export dialog.",
            "Choose the export format when required.",
            "Confirm export.",
            "Wait for the export completion hint.",
        ],
    },
    "change_any_policy": {
        "goal": "Apply one policy change to generate a log event.",
        "required_params": [],
        "mcp_tools": ["find_element", "click_element", "input_text"],
        "steps": [
            "Navigate to one mutable policy surface.",
            "Apply one small policy change.",
            "Save if required.",
        ],
    },
    "toggle_startup_auth": {
        "goal": "Toggle startup authentication in tool settings.",
        "required_params": ["target_state"],
        "mcp_tools": ["find_element", "click_element", "get_ui_tree"],
        "steps": [
            "Locate the startup authentication toggle.",
            "Read the current state.",
            "Click only when a state change is required.",
            "Read the resulting state.",
        ],
    },
    "select_auth_method": {
        "goal": "Select an authentication method in tool settings.",
        "required_params": ["method"],
        "mcp_tools": ["find_element", "click_element", "wait_element"],
        "steps": [
            "Open the authentication method selector.",
            "Choose the target method.",
            "Wait for the selected method to be visible.",
        ],
    },
    "set_tool_password": {
        "goal": "Submit the tool password form.",
        "required_params": [],
        "mcp_tools": ["find_element", "input_text", "click_element", "wait_element"],
        "steps": [
            "Fill the password form fields.",
            "Submit the form.",
            "Wait for a success or validation hint.",
        ],
    },
    "save_tool_settings": {
        "goal": "Save the tool settings form.",
        "required_params": [],
        "mcp_tools": ["find_element", "click_element", "wait_element"],
        "steps": [
            "Locate the save button.",
            "Click save.",
            "Wait for the saved confirmation hint.",
        ],
    },
}
