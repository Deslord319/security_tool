# HarmonyOS E2E 测试框架

当前目录保存 `SecurityTool` 项目内的 E2E 测试框架实现，但目录结构已经按未来可独立抽离的通用框架组织。

## 目录结构

```text
scripts/e2e/
  run_e2e.py
  core/
  drivers/
  assertions/
  reporters/
  adapters/security_tool/
  bridges/
  cases/
    smoke/
    navigation/
    dashboard/
    firewall/
    peripheral/
    identity/
    tool_settings/
    logs/
    legacy/
  schemas/
  docs/
  results/
  artifacts/
```

## 设计边界

- `core/` 负责 runner、contract、兼容层和结果模型。
- `drivers/` 负责 HDC 和 MCP 的通用组合能力。
- `adapters/security_tool/` 只保存当前项目的页面语义、flow 和 suite。
- `bridges/` 负责 runner 与 HarmonyOS MCP runtime 之间的执行边界。
- `cases/legacy/` 只做历史兼容，当前主路径已经切到声明式 case。

## 常用命令

列出 suite：

```powershell
python scripts/e2e/run_e2e.py --adapter security_tool --list-suites
```

运行 smoke：

```powershell
python scripts/e2e/run_e2e.py --adapter security_tool --suite smoke --dry-run
```

运行指定 suite：

```powershell
python scripts/e2e/run_e2e.py --adapter security_tool --suite tool_settings
```

运行单条 case：

```powershell
python scripts/e2e/run_e2e.py --adapter security_tool --case scripts/e2e/cases/firewall/domain_browser.json
```

## Bridge 运行方式

使用 mock bridge：

```powershell
$env:HARMONYOS_E2E_MCP_BRIDGE="python scripts\\e2e\\bridges\\mock_bridge.py"
python scripts/e2e/run_e2e.py --adapter security_tool --suite smoke
```

使用真实 HarmonyOS MCP bridge：

```powershell
$env:HARMONYOS_E2E_MCP_BRIDGE="python scripts\\e2e\\bridges\\harmonyos_mcp_bridge.py"
$env:HARMONYOS_E2E_MCP_BACKEND_MODULE="scripts\\e2e\\bridges\\real_harmonyos_mcp_backend.py"
python scripts/e2e/run_e2e.py --adapter security_tool --suite smoke
```

## 本地运行时配置

复制：

- `scripts/e2e/adapters/security_tool/local_config.template.py`

为：

- `scripts/e2e/adapters/security_tool/local_config.py`

这个本地文件不会提交到 Git，目前主要保存：

- `TOOL_PASSWORD`
- `SKIP_STARTUP_AUTH`

环境变量也可以覆盖本地文件：

- `HARMONYOS_E2E_TOOL_PASSWORD`
- `HARMONYOS_E2E_SKIP_STARTUP_AUTH`

## 统一输入能力

当前 framework 已经把输入类交互固化为统一能力，入口在：

- `scripts/e2e/bridges/real_harmonyos_mcp_backend.py`
  - `_input_text_with_commit(...)`

这套策略适用于：

- 防火墙规则输入
- 浏览器地址栏输入
- 工具密码输入
- 启动认证密码输入

统一规则：

1. 点击目标 `TextInput`
2. 输入一次
3. 回读确认输入框中是否已有目标值
4. 如果回读为空，并且当前场景允许提交，则执行一次：
   - `hdc shell uinput -K -d 2054 -u 2054`
5. 再回读一次
6. 如果仍然为空，直接失败，不做二次重输

约束：

- 不允许为同一个字段做隐式二次输入兜底
- 失败必须保留回读证据，便于定位“输入成功回执”和“字段实际值”不一致的问题

## 当前契约

主契约文件：

- [`case_schema.json`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/schemas/case_schema.json)
- [`result_schema.json`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/schemas/result_schema.json)

bridge 契约：

- [`MCP_BRIDGE_PROTOCOL.md`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/docs/MCP_BRIDGE_PROTOCOL.md)
- [`mcp_bridge_action_schema.json`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/schemas/mcp_bridge_action_schema.json)
- [`mcp_bridge_result_schema.json`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/schemas/mcp_bridge_result_schema.json)

## 兼容模式

当前框架仍兼容历史 case 中的：

- `steps`
- `notes`

兼容转换入口在：

- [`compat.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/core/compat.py)

但 `legacy/` 目录中的 case 已归档，不再作为主执行路径。
