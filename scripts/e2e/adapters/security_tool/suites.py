DASHBOARD_SUITE = [
    "dashboard/overview.json",
    "dashboard/summary_cards.json",
    "dashboard/quick_entries.json",
    "dashboard/admin_status.json",
]


SMOKE_SUITE = [
    "smoke/install_bootstrap.json",
    "smoke/admin_enable.json",
    "smoke/navigation_smoke.json",
]


NAVIGATION_SUITE = [
    *SMOKE_SUITE,
    "navigation/theme_menu.json",
    "navigation/help_feedback.json",
    "navigation/help_feedback_details.json",
    "navigation/about_dialog.json",
    "navigation/identity_page.json",
    "navigation/tool_settings_page.json",
    "navigation/log_page.json",
]


FIREWALL_SUITE = [
    "firewall/status_toggle.json",
    "firewall/mode_cards.json",
    "firewall/rule_create.json",
    "firewall/rule_delete.json",
    "firewall/rules_page_visible.json",
    "firewall/rules_tabs.json",
    "firewall/subroute_restore.json",
    "firewall/domain_browser.json",
]


PERIPHERAL_SUITE = [
    "peripheral/interfaces.json",
    "peripheral/interface_core_items.json",
    "peripheral/record_tab.json",
    "peripheral/policy_tab.json",
    "peripheral/policy_actions_visible.json",
    "peripheral/usb_policy.json",
    "peripheral/usb_whitelist.json",
    "peripheral/usb_blacklist.json",
]


IDENTITY_SUITE = [
    "identity/password_policy.json",
    "identity/complexity_requirements.json",
    "identity/domain_policy.json",
    "identity/validity_section.json",
]


TOOL_SETTINGS_SUITE = [
    "tool_settings/startup_auth.json",
    "tool_settings/auth_method.json",
    "tool_settings/password_flow.json",
    "tool_settings/password_entry_visible.json",
]


LOGS_SUITE = [
    "logs/export.json",
    "logs/page_details.json",
    "logs/filters_visible.json",
    "logs/storage_settings_visible.json",
    "logs/stats_visible.json",
    "logs/event_after_policy_change.json",
]


COMPLETENESS_SUITE = [
    *DASHBOARD_SUITE,
    *NAVIGATION_SUITE,
    *FIREWALL_SUITE,
    *LOGS_SUITE,
    *PERIPHERAL_SUITE,
    *IDENTITY_SUITE,
    *TOOL_SETTINGS_SUITE,
]


SUITES = {
    "dashboard": DASHBOARD_SUITE,
    "smoke": SMOKE_SUITE,
    "navigation": NAVIGATION_SUITE,
    "firewall": FIREWALL_SUITE,
    "peripheral": PERIPHERAL_SUITE,
    "identity": IDENTITY_SUITE,
    "tool_settings": TOOL_SETTINGS_SUITE,
    "logs": LOGS_SUITE,
    "completeness": COMPLETENESS_SUITE,
}
