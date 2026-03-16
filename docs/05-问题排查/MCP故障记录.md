# MCP Failure Log

This document records local MCP failure cases for troubleshooting and service optimization.

## Execution Policy

- Prefer MCP tools first.
- Fall back to shell commands only when MCP does not cover the action or MCP execution fails.
- Every local MCP failure (including `isError=true`, `ok=false`, `status=missing`, or equivalent unavailable status) must be appended here.

## Entry Template

```markdown
### [YYYY-MM-DD HH:mm:ss +08:00] <Short title>
- Context:
- MCP tool:
- Parameters:
- Raw result:
- Failure signal:
- Impact:
- Root cause:
- Fix / workaround:
- Follow-up:
- Status: open | closed
```

## Entries

### [2026-03-11 16:20:48 +08:00] MCP resource discovery returned empty lists
- Context: User asked why many local MCP services were not used.
- MCP tool: `list_mcp_resources` and `list_mcp_resource_templates`
- Parameters: none
- Raw result:
  - `{"resources":[]}`
  - `{"resourceTemplates":[]}`
- Failure signal: No discoverable resources/templates in current session.
- Impact: Cannot rely on resource/template introspection to enumerate available MCP capabilities.
- Root cause: Inference: current MCP services are tool-only or do not expose resource endpoints.
- Fix / workaround: Probe MCP service availability by direct tool call (`mcp__harmonyos__list_devices`, `mcp__harmonyos-compile__check_wsl`).
- Follow-up: If resource discovery is expected, check MCP server-side `resources`/`resourceTemplates` implementation and client wiring.
- Status: closed

### [2026-03-11 16:20:48 +08:00] WSL prerequisite missing for harmonyos-compile MCP
- Context: Runtime MCP health probe for local compile environment.
- MCP tool: `mcp__harmonyos-compile__check_wsl`
- Parameters: none
- Raw result:
  - `{"status":"missing","message":"Windows 系统检测不到 WSL，请先安装 WSL 环境后再进行鸿蒙化交叉编译","can_compile":false,"action":"install_wsl"}`
- Failure signal: `status=missing` and `can_compile=false`.
- Impact: WSL-dependent cross-compilation path is unavailable on current machine.
- Root cause: Local environment does not have WSL installed/configured.
- Fix / workaround: Install WSL (`wsl --install`) and re-run MCP check.
- Follow-up: After installing WSL, rerun `mcp__harmonyos-compile__check_wsl` and update this entry.
- Status: open

### [2026-03-11 16:36:16 +08:00] build_app MCP failed due to missing DevEco Studio path
- Context: Validate peripheral connection record fixes with MCP-first build flow.
- MCP tool: `mcp__harmonyos__build_app`
- Parameters:
  - `{"project_path":"D:\\project\\ai\\security_tool"}`
- Raw result:
  - `{"ok":false,"error":{"code":"BUILD_ERROR","detail":"未找到 DevEco Studio 安装路径。请设置环境变量 DEVECO_STUDIO_PATH 或安装 DevEco Studio"}}`
- Failure signal: `isError=true`, `ok=false`, `code=BUILD_ERROR`.
- Impact: Cannot use MCP build pipeline on current host configuration.
- Root cause: MCP runtime cannot discover local DevEco Studio location from environment.
- Fix / workaround: Set `DEVECO_STUDIO_PATH` and retry MCP; temporary fallback to `hvigorw.bat assembleHap`.
- Follow-up: Align MCP runtime env with existing shell build env, then close this entry.
- Status: open

### [2026-03-11 16:40:27 +08:00] build_app MCP failed during install-run workflow
- Context: User requested "安装运行"; MCP-first build attempt before local fallback.
- MCP tool: `mcp__harmonyos__build_app`
- Parameters:
  - `{"project_path":"D:\\project\\ai\\security_tool"}`
- Raw result:
  - `{"ok":false,"error":{"code":"BUILD_ERROR","detail":"未找到 DevEco Studio 安装路径。请设置环境变量 DEVECO_STUDIO_PATH 或安装 DevEco Studio"}}`
- Failure signal: `isError=true`, `ok=false`, `code=BUILD_ERROR`.
- Impact: MCP build stage is blocked, cannot continue install-run purely through MCP.
- Root cause: DevEco Studio path is unavailable in MCP runtime environment.
- Fix / workaround: Fallback to local shell build/sign/install chain in workspace.
- Follow-up: Set `DEVECO_STUDIO_PATH` for MCP host process and revalidate `build_app`.
- Status: open
