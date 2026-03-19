SMOKE_SUITE = [
    "smoke/install_bootstrap.json",
    "smoke/admin_enable.json",
    "smoke/navigation_smoke.json",
]


NAVIGATION_SUITE = [
    *SMOKE_SUITE,
    "navigation/theme_menu.json",
]


FIREWALL_SUITE = [
    "firewall/status_toggle.json",
    "firewall/rule_create.json",
    "firewall/rule_delete.json",
    "firewall/domain_browser.json",
]


PERIPHERAL_SUITE = [
    "peripheral/interfaces.json",
    "peripheral/usb_policy.json",
    "peripheral/usb_whitelist.json",
    "peripheral/bt_whitelist.json",
    "peripheral/usb_blacklist.json",
]


IDENTITY_SUITE = [
    "identity/password_policy.json",
    "identity/domain_policy.json",
]


TOOL_SETTINGS_SUITE = [
    "tool_settings/startup_auth.json",
    "tool_settings/auth_method.json",
    "tool_settings/password_flow.json",
]


LOGS_SUITE = [
    "logs/export.json",
    "logs/event_after_policy_change.json",
]


COMPLETENESS_SUITE = [
    *NAVIGATION_SUITE,
    *FIREWALL_SUITE,
    *LOGS_SUITE,
    *PERIPHERAL_SUITE,
    *IDENTITY_SUITE,
    *TOOL_SETTINGS_SUITE,
]


SUITES = {
    "smoke": SMOKE_SUITE,
    "navigation": NAVIGATION_SUITE,
    "firewall": FIREWALL_SUITE,
    "peripheral": PERIPHERAL_SUITE,
    "identity": IDENTITY_SUITE,
    "tool_settings": TOOL_SETTINGS_SUITE,
    "logs": LOGS_SUITE,
    "completeness": COMPLETENESS_SUITE,
}
