# Bridge Action 覆盖情况

本文档用于说明当前 `security_tool` E2E 框架中，哪些声明式 flow 已经映射到 bridge action，以及这些 action 在脚本化 backend 中的覆盖状态。

## 字段说明

- `Flow Ref`
  - case 中使用的 flow 引用名
- `Kind`
  - 动作类别，当前主要分为 `system` 和 `ui`
- `Bridge Action`
  - flow executor 最终下发给 bridge 的标准动作名
- `Action Plan`
  - 是否已经存在对应的动作计划文档
- `Scripted Coverage`
  - 脚本化 backend 是否已经为该动作提供覆盖
- `Scripted Status`
  - 在脚本化 backend 下的预期执行结果

## 覆盖表

| Flow Ref | Kind | Bridge Action | Action Plan | Scripted Coverage | Scripted Status |
| --- | --- | --- | --- | --- | --- |
| `app.launch` | `system` | `-` | `否` | `默认` | `N/A` |
| `browser.open_url` | `ui` | `open_browser_url` | `是` | `默认` | `UNKNOWN` |
| `firewall.add_rule` | `ui` | `add_firewall_rule` | `是` | `默认` | `UNKNOWN` |
| `firewall.delete_rule` | `ui` | `delete_firewall_rule` | `是` | `默认` | `UNKNOWN` |
| `firewall.find_rule` | `ui` | `find_firewall_rule` | `是` | `默认` | `UNKNOWN` |
| `firewall.open_rules` | `ui` | `open_firewall_rules` | `是` | `默认` | `UNKNOWN` |
| `firewall.toggle_status` | `ui` | `toggle_firewall` | `是` | `已配置` | `PASS` |
| `identity.update_domain_policy` | `ui` | `update_domain_account_policy` | `是` | `默认` | `UNKNOWN` |
| `identity.update_password_policy` | `ui` | `update_password_policy` | `是` | `默认` | `UNKNOWN` |
| `logs.change_any_policy` | `ui` | `change_any_policy` | `是` | `默认` | `UNKNOWN` |
| `logs.export` | `ui` | `export_logs` | `是` | `默认` | `UNKNOWN` |
| `navigation.open_page` | `ui` | `navigate_page` | `是` | `已配置` | `PASS` |
| `peripheral.add_bluetooth_whitelist` | `ui` | `add_bluetooth_whitelist` | `是` | `默认` | `UNKNOWN` |
| `peripheral.add_usb_blacklist` | `ui` | `add_usb_blacklist` | `是` | `默认` | `UNKNOWN` |
| `peripheral.add_usb_whitelist` | `ui` | `add_usb_whitelist` | `是` | `默认` | `UNKNOWN` |
| `peripheral.open_bluetooth_whitelist_dialog` | `ui` | `open_bluetooth_whitelist_dialog` | `是` | `默认` | `UNKNOWN` |
| `peripheral.open_usb_blacklist_dialog` | `ui` | `open_usb_blacklist_dialog` | `是` | `默认` | `UNKNOWN` |
| `peripheral.open_usb_whitelist_dialog` | `ui` | `open_usb_whitelist_dialog` | `是` | `默认` | `UNKNOWN` |
| `peripheral.select_usb_storage_policy` | `ui` | `select_usb_storage_policy` | `是` | `默认` | `UNKNOWN` |
| `peripheral.toggle_interface` | `ui` | `toggle_peripheral_interface` | `是` | `默认` | `UNKNOWN` |
| `theme_menu.open` | `ui` | `open_top_menu` | `是` | `已配置` | `PASS` |
| `tool_settings.save` | `ui` | `save_tool_settings` | `是` | `已配置` | `PASS` |
| `tool_settings.select_auth_method` | `ui` | `select_auth_method` | `是` | `默认` | `UNKNOWN` |
| `tool_settings.set_password` | `ui` | `set_tool_password` | `是` | `默认` | `UNKNOWN` |
| `tool_settings.toggle_startup_auth` | `ui` | `toggle_startup_auth` | `是` | `已配置` | `PASS` |
| `ui.capture_screenshot` | `ui` | `capture_screenshot` | `是` | `已配置` | `PASS` |

## 说明

- `已配置` 表示脚本化 backend 已经为该动作提供了明确的返回结果或行为模拟。
- `默认` 表示当前仅有兜底处理，尚未为该动作提供专门的脚本化覆盖。
- 这里的 `PASS / UNKNOWN` 仅表示脚本化 backend 的覆盖状态，不代表真机执行结果。
- 真机执行能力是否完整，以 bridge 实际 backend 和 suite 运行结果为准。
