# HarmonyOS E2E 测试框架

当前目录保存 `SecurityTool` 项目的 E2E 测试实现，但结构已经按可抽离的通用框架方向整理。

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
  schemas/
  docs/
  results/
  artifacts/
  metadata/
  tools/
```

## 设计边界

- `core/` 负责 runner、contract、标准化和结果模型
- `drivers/` 负责 HDC 和 MCP 的通用组合能力
- `adapters/security_tool/` 负责项目页面语义、operation 绑定、template 和 suite
- `bridges/` 负责 runner 与 HarmonyOS MCP runtime 之间的执行边界
- `cases/` 只保留当前主执行路径使用的 case

## 当前主链

当前运行时主链已经收敛为：

```text
case -> entity.* -> execute_template_action -> backend step runtime
```

支持的通用 operation：

- `entity.create`
- `entity.update`
- `entity.delete`
- `entity.toggle`
- `entity.submit`

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

如果环境里没有 MCP 包：

```powershell
pip install harmonyos_dev_mcp
```

## 本地运行时配置

复制：

- `scripts/e2e/adapters/security_tool/local_config.template.py`

为：

- `scripts/e2e/adapters/security_tool/local_config.py`

当前本地配置主要包含：

- `TOOL_PASSWORD`

环境变量也可以覆盖本地配置：

- `HARMONYOS_E2E_TOOL_PASSWORD`

## 统一输入能力

当前 framework 已把输入类交互收敛到统一入口：

- [real_harmonyos_mcp_backend.py](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/bridges/real_harmonyos_mcp_backend.py) 中的 `_input_text_with_commit(...)`

这套策略适用于：

- 防火墙规则输入
- 浏览器地址栏输入
- 工具密码输入
- 启动认证密码输入

统一规则：

1. 点击目标 `TextInput`
2. 输入一次
3. 回读确认输入框中是否已有目标值
4. 如果回读为空且当前场景允许提交，则执行一次 `hdc shell uinput -K -d 2054 -u 2054`
5. 再回读一次
6. 如果仍为空，则直接失败，不做二次重输

## 当前契约

主契约文件：

- [`case_schema.json`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/schemas/case_schema.json)
- [`result_schema.json`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/schemas/result_schema.json)

bridge 契约：

- [`MCP_BRIDGE_PROTOCOL.md`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/docs/MCP_BRIDGE_PROTOCOL.md)
- [`mcp_bridge_action_schema.json`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/schemas/mcp_bridge_action_schema.json)
- [`mcp_bridge_result_schema.json`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/schemas/mcp_bridge_result_schema.json)

## 当前约束

- case 只接受 `flow + assertions` 声明式结构，不再支持历史 `steps`
- metadata 和 coverage 只统计当前 case 目录中的主链资产
