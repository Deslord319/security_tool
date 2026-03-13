# HarmonyOS MCP Bridge 接入说明

bridge 是 Python E2E runner 与真实 HarmonyOS UI 执行后端之间的运行时边界。

## 1. 相关文件

- [`harmonyos_mcp_bridge.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/bridges/harmonyos_mcp_bridge.py)
- [`action_plans.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/bridges/action_plans.py)
- [`backend_template.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/bridges/backend_template.py)
- [`scripted_backend.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/bridges/scripted_backend.py)
- [`real_harmonyos_mcp_backend.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/bridges/real_harmonyos_mcp_backend.py)
- [`MCP_BRIDGE_PROTOCOL.md`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/docs/MCP_BRIDGE_PROTOCOL.md)

## 2. 为什么需要 bridge

runner 已经知道：

- case contract
- suite
- flow ref
- result policy

缺的是一层“把标准 action 落到真实 HarmonyOS backend”的运行时边界。  
bridge 的作用就是把这层隔离出去，而不是把运行时逻辑塞进 runner。

## 3. 环境变量

指定 bridge 命令：

```powershell
$env:HARMONYOS_E2E_MCP_BRIDGE="python scripts\\e2e\\bridges\\harmonyos_mcp_bridge.py"
```

指定 backend 模块：

```powershell
$env:HARMONYOS_E2E_MCP_BACKEND_MODULE="scripts\\e2e\\bridges\\real_harmonyos_mcp_backend.py"
```

如果要用 scripted backend：

```powershell
$env:HARMONYOS_E2E_MCP_BACKEND_MODULE="scripts\\e2e\\bridges\\scripted_backend.py"
$env:HARMONYOS_E2E_SCRIPTED_RESULTS="scripts\\e2e\\bridges\\scripted_results.sample.json"
```

## 4. Backend 契约

backend 模块必须导出：

```python
BACKEND.handle_action(payload: dict) -> dict
```

返回值应符合：

- [`mcp_bridge_result_schema.json`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/schemas/mcp_bridge_result_schema.json)

最小键：

- `status`
- `failure_code`
- `message`
- `evidence`

## 5. 推荐实现顺序

建议优先实现这些 action：

1. `navigate_page`
2. `open_top_menu`
3. `capture_screenshot`
4. `toggle_firewall`
5. `toggle_startup_auth`
6. `save_tool_settings`

原因：

- 这批 action 已经被 adapter flow 用到
- 足够让 smoke 和部分 completeness case 从结构化 `UNKNOWN` 变成真实执行

## 6. 当前默认行为

如果没有配置 backend：

- `status = UNKNOWN`
- `failure_code = MCP_BACKEND_NOT_CONFIGURED`

如果配置了 backend，但某个 action 未实现：

- `status = UNKNOWN`
- `failure_code = MCP_ACTION_PENDING`

这样可以在 bridge 未完全实现前，保持 runner 的结果模型稳定。

## 7. 辅助文档

动作到 bridge 的覆盖关系：

- [`BRIDGE_ACTION_COVERAGE.md`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/docs/BRIDGE_ACTION_COVERAGE.md)

动作执行计划：

- [`BRIDGE_ACTION_PLANS.md`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/docs/BRIDGE_ACTION_PLANS.md)
