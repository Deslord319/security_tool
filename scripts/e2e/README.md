# HarmonyOS E2E 测试框架

当前目录保存 `SecurityTool` 项目内的 E2E 框架实现，但目录结构已经按未来可抽离的独立仓库组织。

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
    legacy/
  schemas/
  docs/
  results/
  artifacts/
```

## 设计意图

- `core/` 必须保持项目无关
- `drivers/`、`assertions/`、`reporters/` 属于未来通用核心
- `adapters/security_tool/` 保存当前项目的配置和页面语义
- `bridges/` 保存 runner 与 HarmonyOS MCP 之间的运行时边界
- `cases/legacy/` 仅用于历史兼容
- 默认执行路径已经切换到声明式 case

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
python scripts/e2e/run_e2e.py --case scripts/e2e/cases/smoke/install_bootstrap.json
```

## Bridge 运行方式

使用 mock bridge：

```powershell
$env:HARMONYOS_E2E_MCP_BRIDGE="python scripts\\e2e\\bridges\\mock_bridge.py"
python scripts/e2e/run_e2e.py --adapter security_tool --suite smoke
```

使用 HarmonyOS MCP bridge：

```powershell
$env:HARMONYOS_E2E_MCP_BRIDGE="python scripts\\e2e\\bridges\\harmonyos_mcp_bridge.py"
$env:HARMONYOS_E2E_MCP_BACKEND_MODULE="scripts\\e2e\\bridges\\real_harmonyos_mcp_backend.py"
python scripts/e2e/run_e2e.py --adapter security_tool --suite smoke
```

## 本地运行时配置

复制：

- `scripts/e2e/adapters/security_tool/local_config.template.py`

到：

- `scripts/e2e/adapters/security_tool/local_config.py`

这个本地文件不会提交到 Git，可保存：

- `TOOL_PASSWORD`
- `SKIP_STARTUP_AUTH`

推荐用法：

- `TOOL_PASSWORD` 既用于启动认证/锁屏解锁，也用于应用内工具密码
- 正常 E2E 保持 `SKIP_STARTUP_AUTH=False`

环境变量也可以覆盖本地文件：

- `HARMONYOS_E2E_TOOL_PASSWORD`
- `HARMONYOS_E2E_SKIP_STARTUP_AUTH`

## 当前契约

当前主契约文件：

- [`case_schema.json`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/schemas/case_schema.json)
- [`result_schema.json`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/schemas/result_schema.json)

bridge 契约：

- [`MCP_BRIDGE_PROTOCOL.md`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/docs/MCP_BRIDGE_PROTOCOL.md)
- [`mcp_bridge_action_schema.json`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/schemas/mcp_bridge_action_schema.json)
- [`mcp_bridge_result_schema.json`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/schemas/mcp_bridge_result_schema.json)

## 兼容模式

当前框架仍支持历史 case 文件中的：

- `steps`
- `notes`

兼容转换入口在：

- [`compat.py`](/C:/Users/mu/Desktop/code/security_tool/scripts/e2e/core/compat.py)

当前 `legacy/` 目录中的 case 已归档，不再作为主执行路径。
