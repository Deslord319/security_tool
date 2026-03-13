# E2E Excel 映射说明

本文档说明一条测试用例如何从 Excel 行映射到当前 E2E 框架。

## 1. 映射链路

```text
Excel 行
  -> case JSON
    -> flow ref
      -> backend action
        -> MCP tool / HDC
```

## 2. 核心原则

- Excel 只描述业务步骤和关键参数
- case JSON 只描述测试意图和 flow
- adapter/flow 负责项目语义
- backend action 负责页面实现
- MCP tool 只负责原子操作

## 3. 推荐的 Excel 列

| Excel 列 | 必填 | 说明 |
| --- | --- | --- |
| `case_id` | 是 | 用例唯一标识 |
| `case_name` | 是 | 用例名称 |
| `module` | 是 | 模块名，如 `tool-settings` |
| `enabled` | 是 | 是否启用，建议 `Y/N` |
| `flow_1_ref` | 是 | 第一步 flow 名 |
| `flow_1_params` | 否 | 第一步参数，JSON 字符串 |
| `flow_2_ref` | 否 | 第二步 flow 名 |
| `flow_2_params` | 否 | 第二步参数，JSON 字符串 |
| `flow_3_ref` | 否 | 第三步 flow 名 |
| `flow_3_params` | 否 | 第三步参数，JSON 字符串 |
| `flow_4_ref` | 否 | 第四步 flow 名 |
| `flow_4_params` | 否 | 第四步参数，JSON 字符串 |
| `allow_unknown` | 否 | 是否允许 `UNKNOWN` |
| `stop_on_failure` | 否 | 是否失败即停 |
| `notes` | 否 | 备注 |

## 4. 示例

以“工具设置中打开启动认证并保存”为例：

| case_id | case_name | module | enabled | flow_1_ref | flow_1_params | flow_2_ref | flow_2_params | flow_3_ref | flow_3_params | flow_4_ref | flow_4_params |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `SET-STARTUP-001` | `Startup Auth Toggle` | `tool-settings` | `Y` | `app.launch` | `{"timeout_sec":20}` | `navigation.open_page` | `{"page_id":"tool-settings"}` | `tool_settings.toggle_startup_auth` | `{"target_state":"invert"}` | `tool_settings.save` | `{}` |

## 5. 对应的 case JSON

对应当前 case：

- [`startup_auth.json`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/cases/tool_settings/startup_auth.json)

核心结构是：

```json
{
  "case_id": "SET-STARTUP-001",
  "module": "tool-settings",
  "flow": [
    { "ref": "app.launch", "params": { "timeout_sec": 20 } },
    { "ref": "navigation.open_page", "params": { "page_id": "tool-settings" } },
    { "ref": "tool_settings.toggle_startup_auth", "params": { "target_state": "invert" } },
    { "ref": "tool_settings.save", "params": {} }
  ]
}
```

## 6. flow 层映射

| flow ref | 含义 |
| --- | --- |
| `app.launch` | 拉起应用 |
| `navigation.open_page` | 打开页面 |
| `tool_settings.toggle_startup_auth` | 切换启动认证开关 |
| `tool_settings.save` | 保存当前设置 |

flow 注册表在：

- [`registry.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/adapters/security_tool/flows/registry.py)

## 7. adapter 层映射

`navigation.open_page(page_id="tool-settings")` 不直接写死点击细节，而是通过 adapter：

1. 用 `page_id` 找页面标题
2. 用 `page_id` 找页面锚点

当前配置在：

- [`pages.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/adapters/security_tool/pages.py)

例如：

```python
PAGE_REGISTRY = {
    "tool-settings": "工具设置",
}

PAGE_MARKERS = {
    "tool-settings": "启动时身份校验",
}
```

## 8. backend action 映射

flow executor 不直接操作 UI，而是把 flow 转成 backend action。

当前实现：

- [`executor.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/adapters/security_tool/flows/executor.py)

对应关系：

| flow ref | backend action |
| --- | --- |
| `app.launch` | 直接走 HDC `aa start` |
| `navigation.open_page` | `navigate_page` |
| `tool_settings.toggle_startup_auth` | `toggle_startup_auth` |
| `tool_settings.save` | `save_tool_settings` |

## 9. 最终落到的 MCP tool

以这条 case 为例：

| backend action | 主要 MCP tool |
| --- | --- |
| `navigate_page` | `click_element`, `wait_element`, `get_ui_tree` |
| `toggle_startup_auth` | `get_ui_tree`, `click_element` |
| `save_tool_settings` | `get_ui_tree`, `click_element`, `wait_element` |

`app.launch` 不走 MCP，直接走 HDC。

## 10. 为什么不建议 Excel 直接写 MCP 参数

不建议这样设计：

| flow_1_ref | flow_1_params |
| --- | --- |
| `mcp.click_element` | `{"text":"工具设置"}` |

原因：

1. 页面改版后 Excel 会大面积失效
2. 业务维护成本高
3. case 和 UI 实现耦合过重

更合理的是：

| flow_1_ref | flow_1_params |
| --- | --- |
| `navigation.open_page` | `{"page_id":"tool-settings"}` |

## 11. 哪些情况可以带 MCP 参数

只建议两种场景：

### 11.1 断言层

例如：

```json
{
  "type": "mcp_wait_element",
  "params": {
    "text": "保存设置",
    "timeout_ms": 3000
  }
}
```

### 11.2 临时兜底

在 flow 尚未抽象完成前，可临时用 `mcp.raw`：

```json
{
  "ref": "mcp.raw",
  "params": {
    "tool": "wait_element",
    "args": {
      "text": "请输入锁屏密码",
      "state": "gone",
      "timeout_ms": 4000
    }
  }
}
```

但这只应该是兜底，不应成为主流写法。

## 12. 建议

如果后续真的要让 Excel 成为正式输入，建议顺序是：

1. 先冻结 Excel 列定义
2. 再做 `Excel -> case JSON` 转换脚本
3. 先拿 `tool-settings` 3 条 case 验证
4. 再扩到 `firewall / peripheral / identity / logs`
