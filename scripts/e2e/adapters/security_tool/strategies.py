from __future__ import annotations


PAGE_STRATEGIES = {
    "dashboard": {"page_text": "安全总览", "marker_text": "快捷方式"},
    "firewall": {"page_text": "防火墙管理", "marker_text": "公共网络模式"},
    "firewall-rules": {"page_text": "自定义模式", "marker_text": "新增规则"},
    "log-manage": {"page_text": "日志管理", "marker_text": "导出日志"},
    "peripheral-manage": {"page_text": "外设管理", "marker_text": "接口管控"},
    "identity": {"page_text": "身份鉴别", "marker_text": "口令复杂度策略"},
    "tool-settings": {"page_text": "工具设置", "marker_text": "启动时身份校验"},
    "help-feedback": {"page_text": "帮助与反馈", "marker_text": "使用指南"},
}

TOP_MENU_VISIBLE_TEXT = "跟随系统"
TOOL_SETTINGS_PAGE_TEXT = "工具设置"
TOOL_SETTINGS_SAVE_TEXT = "保存设置"
TOOL_SETTINGS_STARTUP_AUTH_TEXT = "启动时身份校验"

FIREWALL_PAGE_TEXT = "防火墙管理"
FIREWALL_CUSTOM_RULE_TEXT = "规则页"
FIREWALL_DIALOG_TITLE = "新增规则"
FIREWALL_ADD_RULE_TEXTS = ["+ 新增规则", "新增规则", "+ 添加规则", "添加规则"]

DIALOG_REGION_PRESETS = {
    "firewall": {
        "left_min": 900,
        "left_max": 2100,
        "top_min": 500,
        "top_max": 1750,
    },
}

FIREWALL_DIALOG_REGION = DIALOG_REGION_PRESETS["firewall"]

DELETE_ACTION_LABELS = ["删除规则", "删除", "移除"]
CONFIRM_DIALOG_LABELS = ["确定", "确认", "保存", "提交", "添加", "新增"]
CONFIRM_DELETE_LABELS = ["确定", "确认", "删除", "移除"]

FIREWALL_RULE_TYPE_LABELS = {
    "ip": "IP 规则",
    "domain": "域名规则",
    "dns": "DNS 规则",
}

FIREWALL_POLICY_OPTION_LABELS = {
    "deny": ["阻止", "拒绝", "禁止"],
    "allow": ["允许", "放行"],
}

FIREWALL_DIRECTION_OPTION_LABELS = {
    "in": ["入站"],
    "out": ["出站"],
}

FIREWALL_PROTOCOL_OPTION_LABELS = {
    "tcp": ["TCP"],
    "udp": ["UDP"],
}

AUTH_METHOD_OPTION_LABELS = {
    "pin": ["PIN 码", "PIN"],
    "password": ["密码"],
    "fingerprint": ["指纹"],
    "face": ["人脸识别"],
}

PERIPHERAL_USB_POLICY_OPTION_LABELS = {
    "read_only": ["只读", "仅读"],
    "disabled": ["禁用", "禁止"],
    "allow": ["允许", "可读写", "读写"],
}

LOG_MAX_ENTRIES_OPTION_LABELS = {
    "5000": ["5000"],
    "10000": ["10000"],
    "20000": ["20000"],
    "50000": ["50000"],
    "100000": ["100000"],
}

DIALOG_STRATEGIES = {
    "firewall.rule.create": {
        "labels": FIREWALL_ADD_RULE_TEXTS,
        "region": DIALOG_REGION_PRESETS["firewall"],
    },
    "peripheral.whitelist.create.usb": {
        "labels": ["USB白名单", "添加 USB 设备白名单", "添加白名单"],
        "region": {},
    },
    "peripheral.whitelist.create.bluetooth": {
        "labels": ["蓝牙白名单", "添加蓝牙白名单", "添加白名单"],
        "region": {},
    },
    "peripheral.blacklist.create.usb": {
        "labels": ["USB黑名单", "添加 USB 设备黑名单", "添加黑名单"],
        "region": {},
    },
}

OPTION_GROUP_STRATEGIES = {
    "auth_method": AUTH_METHOD_OPTION_LABELS,
    "peripheral_usb_policy": PERIPHERAL_USB_POLICY_OPTION_LABELS,
    "firewall_policy": FIREWALL_POLICY_OPTION_LABELS,
    "firewall_direction": FIREWALL_DIRECTION_OPTION_LABELS,
    "firewall_protocol": FIREWALL_PROTOCOL_OPTION_LABELS,
    "log_max_entries": LOG_MAX_ENTRIES_OPTION_LABELS,
}

FIELD_GROUP_STRATEGIES = {
    "identity.password_policy": ["min_length"],
    "identity.domain_policy": ["password_max_age_days", "expiration_notify_days", "auth_validity_minutes"],
    "firewall.rule.domain": ["name", "domain", "port"],
    "peripheral.whitelist.usb": ["device_id"],
    "peripheral.whitelist.bluetooth": ["device_id"],
    "peripheral.blacklist.usb": ["device_id"],
}
