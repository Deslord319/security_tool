# MCP Bridge 协议

本文档定义 E2E runner 与外部 HarmonyOS bridge 之间使用的最小 `stdin/stdout` 协议。

## 1. Action Payload

- 对应 schema：
  - [`mcp_bridge_action_schema.json`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/schemas/mcp_bridge_action_schema.json)
- 传输方式：
  - runner 向 bridge 的 `stdin` 写入一条 JSON

示例：

```json
{
  "type": "mcp_action",
  "action": "navigate_page",
  "params": {
    "page_id": "dashboard"
  },
  "expected": "进入安全总览页面"
}
```

## 2. Result Payload

- 对应 schema：
  - [`mcp_bridge_result_schema.json`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/schemas/mcp_bridge_result_schema.json)
- 传输方式：
  - bridge 向 `stdout` 写入一条 JSON

示例：

```json
{
  "status": "PASS",
  "failure_code": "",
  "message": "导航完成",
  "evidence": {
    "window_id": "12",
    "matched_text": "安全总览"
  }
}
```

## 3. 状态语义

- `PASS`
  - action 已执行成功，并且产出了预期状态或证据
- `FAIL`
  - action 已执行，但能够明确判定失败
- `UNKNOWN`
  - action 当前无法完成，或者当前轮次无法确认结果

常见原因：

- backend 尚未覆盖该动作
- 当前设备环境阻塞
- 证据不足

## 4. Bridge 约束

- 一次只读取一条 `stdin JSON`
- 一次只输出一条 `stdout JSON`
- 即使业务结果是 `FAIL` 或 `UNKNOWN`，bridge 进程也应返回 `0`
- 只有 bridge 本身崩溃或协议无法满足时，才返回非 `0`

## 5. 推荐返回字段

最小返回字段：

- `status`
- `failure_code`
- `message`
- `evidence`

推荐在 `evidence` 中附带：

- 命中的页面锚点
- 操作目标
- 截图路径
- 关键日志
- 窗口信息

## 6. 统一输入能力约定

涉及 `TextInput` 的业务动作，统一复用 backend 中的 `_input_text_with_commit(...)`，不允许每个 action 各自实现一套输入逻辑。

适用场景：

- 防火墙规则输入
- 浏览器地址栏输入
- 工具密码输入
- 启动认证密码输入

标准流程：

1. 点击目标 `TextInput`
2. 输入一次
3. 回读确认输入框中是否已有目标值
4. 如果回读为空，并且当前场景允许提交，则执行一次：
   - `hdc shell uinput -K -d 2054 -u 2054`
5. 再回读一次
6. 如果仍然为空，直接失败，不做二次重输

约束：

- bridge/backend 不允许对同一字段做隐式二次输入兜底
- 输入失败必须保留回读证据，便于定位“输入成功回执”和“字段实际值”不一致的问题

## 7. 参考实现

当前项目中的 bridge 相关实现：

- [`harmonyos_mcp_bridge.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/bridges/harmonyos_mcp_bridge.py)
- [`backend_template.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/bridges/backend_template.py)
- [`real_harmonyos_mcp_backend.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/bridges/real_harmonyos_mcp_backend.py)

## 8. Driver 私有动作约定

以下动作属于 Python driver 内部协议，不视为公共 MCP 能力：

- `__driver_get_toggle_state`
- `__driver_wait_element`
- `__driver_element_exists`
- `__driver_scroll_until_text`
- `__driver_wait_for_page`
- `__driver_input_password_if_prompted`
- `__driver_text_presence`

这些动作的目的只是让 driver 能通过 bridge 复用现有 HarmonyOS MCP 原子工具，不建议在 case、adapter flow 或外部文档中作为公共 action 使用。
