from __future__ import annotations


ACTION_PLANS = {
    "navigate_page": {
        "goal": "Open a page from the left navigation rail.",
        "required_params": ["page_id"],
        "mcp_tools": ["click_element", "wait_element", "get_ui_tree"],
        "steps": [
            "Resolve the sidebar item and route container for the target page.",
            "Click the sidebar item.",
            "Wait for the route container or page-specific marker to appear.",
        ],
    },
    "open_top_menu": {
        "goal": "Open the top three-dot menu.",
        "required_params": [],
        "mcp_tools": ["click_element", "wait_element"],
        "steps": [
            "Click the top menu trigger.",
            "Wait for a known menu item to appear.",
        ],
    },
    "capture_screenshot": {
        "goal": "Capture a screenshot artifact for the current UI state.",
        "required_params": ["name"],
        "mcp_tools": ["screenshot"],
        "steps": [
            "Generate a stable artifact path.",
            "Capture the screenshot and return it as evidence.",
        ],
    },
    "execute_template_action": {
        "goal": "Execute an adapter-defined declarative template.",
        "required_params": ["template_key"],
        "mcp_tools": ["click_element", "input_text", "wait_element", "get_ui_tree"],
        "steps": [
            "Load the template from the adapter registry.",
            "Resolve template variables from the operation payload.",
            "Execute each declarative step in order.",
        ],
    },
    "toggle_firewall": {
        "goal": "Toggle the firewall switch to the desired state.",
        "required_params": ["target_state"],
        "mcp_tools": ["click_element", "get_ui_tree"],
        "steps": [
            "Locate the firewall toggle on the firewall page.",
            "Click the toggle and handle authentication if prompted.",
        ],
    },
    "save_tool_settings": {
        "goal": "Save the tool settings form.",
        "required_params": [],
        "mcp_tools": ["click_element", "wait_element", "get_ui_tree"],
        "steps": [
            "Locate the save button.",
            "Click save.",
            "Wait for the page to remain stable after save.",
        ],
    },
    "set_tool_password": {
        "goal": "Submit the tool password form.",
        "required_params": [],
        "mcp_tools": ["input_text", "click_element", "get_ui_tree"],
        "steps": [
            "Locate password form inputs.",
            "Fill the password fields.",
            "Submit the form and capture field-level evidence.",
        ],
    },
    "open_browser_url": {
        "goal": "Open a URL in the system browser.",
        "required_params": ["url"],
        "mcp_tools": ["run_app", "click_element", "input_text", "press_key"],
        "steps": [
            "Bring the browser to the foreground.",
            "Focus the address bar.",
            "Input the target URL and confirm.",
        ],
    },
    "export_logs": {
        "goal": "Run the log export flow.",
        "required_params": [],
        "mcp_tools": ["click_element", "wait_element", "get_ui_tree"],
        "steps": [
            "Open the export dialog.",
            "Confirm the export action.",
            "Wait for the export completion hint.",
        ],
    },
    "change_any_policy": {
        "goal": "Apply one small policy change to generate a log event.",
        "required_params": [],
        "mcp_tools": ["click_element", "input_text", "get_ui_tree"],
        "steps": [
            "Navigate to a mutable policy page.",
            "Apply one small policy change.",
            "Save when required.",
        ],
    },
    "toggle_first_on_page": {
        "goal": "Toggle the first visible switch on the current page.",
        "required_params": ["page_text"],
        "mcp_tools": ["click_element", "get_ui_tree", "wait_element"],
        "steps": [
            "Verify the target page is visible.",
            "Locate the first content toggle.",
            "Click it and handle any auth prompt.",
        ],
    },
    "open_firewall_rules_page": {
        "goal": "Open the firewall rules detail page for a specific rule type.",
        "required_params": ["rule_type"],
        "mcp_tools": ["click_element", "wait_element", "get_ui_tree"],
        "steps": [
            "Navigate to the firewall page if needed.",
            "Open the rule type card.",
            "Wait for the firewall rules detail page to appear.",
        ],
    },
    "open_named_dialog": {
        "goal": "Open a dialog by one of its known labels.",
        "required_params": ["dialog_key|labels"],
        "mcp_tools": ["click_element", "wait_element", "get_ui_tree"],
        "steps": [
            "Resolve the dialog descriptor or use inline labels.",
            "Open the matching dialog.",
            "Wait for the dialog to become visible.",
        ],
    },
    "fill_inputs": {
        "goal": "Populate the visible text inputs with provided values.",
        "required_params": ["values", "field_group?"],
        "mcp_tools": ["input_text", "get_ui_tree"],
        "steps": [
            "Locate visible text inputs.",
            "Optionally resolve the field descriptor for evidence ordering.",
            "Fill inputs in order with the provided values.",
        ],
    },
    "fill_inputs_with_fallback_touch": {
        "goal": "Populate visible inputs, or fall back to identity page touch interactions.",
        "required_params": ["values", "field_group?"],
        "mcp_tools": ["input_text", "click_element", "get_ui_tree"],
        "steps": [
            "Try to fill text inputs directly.",
            "If direct input fails, fall back to touch-based interaction.",
        ],
    },
    "confirm_dialog": {
        "goal": "Confirm the currently visible dialog.",
        "required_params": [],
        "mcp_tools": ["click_element", "get_ui_tree"],
        "steps": [
            "Locate the dialog confirm action.",
            "Click the first matching confirm label.",
        ],
    },
    "submit_firewall_rule_form": {
        "goal": "Submit the firewall rule creation dialog.",
        "required_params": ["rule_type"],
        "mcp_tools": ["click_element", "input_text", "wait_element", "get_ui_tree"],
        "steps": [
            "Open the add rule dialog if needed.",
            "Configure select controls.",
            "Fill dialog inputs and submit.",
        ],
    },
    "toggle_indexed_control": {
        "goal": "Toggle a control by type and index.",
        "required_params": ["control_type", "index"],
        "mcp_tools": ["click_element", "get_ui_tree"],
        "steps": [
            "Locate controls by type.",
            "Pick the requested index.",
            "Click the chosen control.",
        ],
    },
    "select_indexed_option": {
        "goal": "Open a select control by index and choose labels resolved from the option strategy.",
        "required_params": ["index", "value", "option_group|options"],
        "mcp_tools": ["click_element", "find_element", "get_ui_tree"],
        "steps": [
            "Locate select controls by MCP query or UI tree and choose one by index.",
            "Open the select dropdown.",
            "Resolve candidate labels from the option strategy and choose one.",
        ],
    },
    "wait_for_text": {
        "goal": "Wait for a target text to become visible.",
        "required_params": ["text"],
        "mcp_tools": ["wait_element"],
        "steps": [
            "Wait until the target text appears in the target bundle.",
        ],
    },
    "assert_text_visible": {
        "goal": "Assert that any one of the provided texts becomes visible.",
        "required_params": ["candidates"],
        "mcp_tools": ["wait_element"],
        "steps": [
            "Try each candidate text in order.",
            "Return the first successful match.",
        ],
    },
    "delete_visible_rule": {
        "goal": "Delete a visible firewall rule by target text.",
        "required_params": [],
        "mcp_tools": ["click_element", "get_ui_tree"],
        "steps": [
            "Focus the target rule if present.",
            "Trigger the delete action.",
            "Confirm the delete dialog.",
        ],
    },
}
