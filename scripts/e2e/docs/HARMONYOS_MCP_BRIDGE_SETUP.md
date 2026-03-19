# HarmonyOS MCP Bridge 接入说明

bridge 是 Python E2E runner 和 HarmonyOS MCP UI 执行环境之间的运行时边界。

## 1. 相关文件

- [`harmonyos_mcp_bridge.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/bridges/harmonyos_mcp_bridge.py)
- [`action_plans.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/bridges/action_plans.py)
- [`backend_template.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/bridges/backend_template.py)
- [`scripted_backend.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/bridges/scripted_backend.py)
- [`real_harmonyos_mcp_backend.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/bridges/real_harmonyos_mcp_backend.py)
- [`MCP_BRIDGE_PROTOCOL.md`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/docs/MCP_BRIDGE_PROTOCOL.md)

## 2. 为什么需要 bridge

runner 已经负责：

- case contract
- suite 归类
- flow ref 调度
- result policy

bridge 负责把标准化 action 落到真实 HarmonyOS UI 后端执行，避免把设备交互细节塞回 runner。

## 3. 环境变量

指定 bridge 命令：

```powershell
$env:HARMONYOS_E2E_MCP_BRIDGE="python scripts\\e2e\\bridges\\harmonyos_mcp_bridge.py"
```

指定 real backend：

```powershell
$env:HARMONYOS_E2E_MCP_BACKEND_MODULE="scripts\\e2e\\bridges\\real_harmonyos_mcp_backend.py"
```

如果当前环境里没有 MCP 包，直接安装：

```powershell
pip install harmonyos_dev_mcp
```

如果要使用 scripted backend：

```powershell
$env:HARMONYOS_E2E_MCP_BACKEND_MODULE="scripts\\e2e\\bridges\\scripted_backend.py"
$env:HARMONYOS_E2E_SCRIPTED_RESULTS="scripts\\e2e\\bridges\\scripted_results.sample.json"
```

## 4. Backend 契约

backend 模块必须导出：

```python
BACKEND.handle_action(payload: dict) -> dict
```

返回值至少包含：

- `status`
- `failure_code`
- `message`
- `evidence`

完整结构见 [`mcp_bridge_result_schema.json`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/schemas/mcp_bridge_result_schema.json)

## 5. 当前推荐实现顺序

优先保证这些动作可用：

1. `navigate_page`
2. `execute_template_action`
3. `open_top_menu`
4. `capture_screenshot`
5. `toggle_firewall`
6. `save_tool_settings`

原因：

- 当前主链已经收敛到 `case -> entity.* -> execute_template_action`
- `navigation`、`template runtime`、`save` 是大多数业务场景的基础能力

## 6. 默认行为

如果没有配置 backend：

- `status = UNKNOWN`
- `failure_code = MCP_BACKEND_NOT_CONFIGURED`

如果配置了 backend，但动作还未实现：

- `status = UNKNOWN`
- `failure_code = MCP_ACTION_PENDING`

这样可以在 bridge 未完全实现时，保持 runner 的结果模型稳定。

## 7. 辅助文档

- Bridge 覆盖关系：[`BRIDGE_ACTION_COVERAGE.md`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/docs/BRIDGE_ACTION_COVERAGE.md)
- Bridge 动作计划：[`BRIDGE_ACTION_PLANS.md`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/docs/BRIDGE_ACTION_PLANS.md)
