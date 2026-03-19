# Bridge Action Plans

This document lists the normalized UI actions expected by the HarmonyOS MCP bridge.

## `assert_text_visible`

- Goal: Assert that any one of the provided texts becomes visible.
- Required Params: candidates
- Suggested MCP Tools: wait_element
- Steps:
  - Try each candidate text in order.
  - Return the first successful match.

## `capture_screenshot`

- Goal: Capture a screenshot artifact for the current UI state.
- Required Params: name
- Suggested MCP Tools: screenshot
- Steps:
  - Generate a stable artifact path.
  - Capture the screenshot and return it as evidence.

## `change_any_policy`

- Goal: Apply one small policy change to generate a log event.
- Required Params: (none)
- Suggested MCP Tools: click_element, input_text, get_ui_tree
- Steps:
  - Navigate to a mutable policy page.
  - Apply one small policy change.
  - Save when required.

## `confirm_dialog`

- Goal: Confirm the currently visible dialog.
- Required Params: (none)
- Suggested MCP Tools: click_element, get_ui_tree
- Steps:
  - Locate the dialog confirm action.
  - Click the first matching confirm label.

## `delete_visible_rule`

- Goal: Delete a visible firewall rule by target text.
- Required Params: (none)
- Suggested MCP Tools: click_element, get_ui_tree
- Steps:
  - Focus the target rule if present.
  - Trigger the delete action.
  - Confirm the delete dialog.

## `execute_template_action`

- Goal: Execute an adapter-defined declarative template.
- Required Params: template_key
- Suggested MCP Tools: click_element, input_text, wait_element, get_ui_tree
- Steps:
  - Load the template from the adapter registry.
  - Resolve template variables from the operation payload.
  - Execute each declarative step in order.

## `export_logs`

- Goal: Run the log export flow.
- Required Params: (none)
- Suggested MCP Tools: click_element, wait_element, get_ui_tree
- Steps:
  - Open the export dialog.
  - Confirm the export action.
  - Wait for the export completion hint.

## `fill_inputs`

- Goal: Populate the visible text inputs with provided values.
- Required Params: values
- Suggested MCP Tools: input_text, get_ui_tree
- Steps:
  - Locate visible text inputs.
  - Fill them in order with the provided values.

## `fill_inputs_with_fallback_touch`

- Goal: Populate visible inputs, or fall back to identity page touch interactions.
- Required Params: values
- Suggested MCP Tools: input_text, click_element, get_ui_tree
- Steps:
  - Try to fill text inputs directly.
  - If direct input fails, fall back to touch-based interaction.

## `navigate_page`

- Goal: Open a page from the left navigation rail.
- Required Params: page_id
- Suggested MCP Tools: click_element, wait_element, get_ui_tree
- Steps:
  - Resolve the sidebar item and route container for the target page.
  - Click the sidebar item.
  - Wait for the route container or page-specific marker to appear.

## `open_browser_url`

- Goal: Open a URL in the system browser.
- Required Params: url
- Suggested MCP Tools: run_app, click_element, input_text, press_key
- Steps:
  - Bring the browser to the foreground.
  - Focus the address bar.
  - Input the target URL and confirm.

## `open_firewall_rules_page`

- Goal: Open the firewall rules detail page for a specific rule type.
- Required Params: rule_type
- Suggested MCP Tools: click_element, wait_element, get_ui_tree
- Steps:
  - Navigate to the firewall page if needed.
  - Open the rule type card.
  - Wait for the firewall rules detail page to appear.

## `open_named_dialog`

- Goal: Open a dialog by one of its known labels.
- Required Params: labels
- Suggested MCP Tools: click_element, wait_element, get_ui_tree
- Steps:
  - Try each known entry label.
  - Open the matching dialog.
  - Wait for the dialog to become visible.

## `open_top_menu`

- Goal: Open the top three-dot menu.
- Required Params: (none)
- Suggested MCP Tools: click_element, wait_element
- Steps:
  - Click the top menu trigger.
  - Wait for a known menu item to appear.

## `save_tool_settings`

- Goal: Save the tool settings form.
- Required Params: (none)
- Suggested MCP Tools: click_element, wait_element, get_ui_tree
- Steps:
  - Locate the save button.
  - Click save.
  - Wait for the page to remain stable after save.

## `select_indexed_option`

- Goal: Open a select control by index and choose one of the configured labels.
- Required Params: index, value, options
- Suggested MCP Tools: click_element, get_ui_tree
- Steps:
  - Locate select controls and choose one by index.
  - Open the select dropdown.
  - Choose a matching option label.

## `set_tool_password`

- Goal: Submit the tool password form.
- Required Params: (none)
- Suggested MCP Tools: input_text, click_element, get_ui_tree
- Steps:
  - Locate password form inputs.
  - Fill the password fields.
  - Submit the form and capture field-level evidence.

## `submit_firewall_rule_form`

- Goal: Submit the firewall rule creation dialog.
- Required Params: rule_type
- Suggested MCP Tools: click_element, input_text, wait_element, get_ui_tree
- Steps:
  - Open the add rule dialog if needed.
  - Configure select controls.
  - Fill dialog inputs and submit.

## `toggle_firewall`

- Goal: Toggle the firewall switch to the desired state.
- Required Params: target_state
- Suggested MCP Tools: click_element, get_ui_tree
- Steps:
  - Locate the firewall toggle on the firewall page.
  - Click the toggle and handle authentication if prompted.

## `toggle_first_on_page`

- Goal: Toggle the first visible switch on the current page.
- Required Params: page_text
- Suggested MCP Tools: click_element, get_ui_tree, wait_element
- Steps:
  - Verify the target page is visible.
  - Locate the first content toggle.
  - Click it and handle any auth prompt.

## `toggle_indexed_control`

- Goal: Toggle a control by type and index.
- Required Params: control_type, index
- Suggested MCP Tools: click_element, get_ui_tree
- Steps:
  - Locate controls by type.
  - Pick the requested index.
  - Click the chosen control.

## `wait_for_text`

- Goal: Wait for a target text to become visible.
- Required Params: text
- Suggested MCP Tools: wait_element
- Steps:
  - Wait until the target text appears in the target bundle.
