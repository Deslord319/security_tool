# OpenCode HarmonyOS MCP 配置指南

本文档指导你如何在 OpenCode 中配置和使用 HarmonyOS MCP Server。

---

## 📋 什么是 HarmonyOS MCP？

**HarmonyOS MCP** (Model Context Protocol) 是一个用于自动化 HarmonyOS 应用开发的工具协议，提供：

- ✅ 自动构建 HAP
- ✅ 自动安装到设备
- ✅ 自动运行应用
- ✅ 设备管理
- ✅ 日志查看

---

## 🔧 安装 HarmonyOS MCP Server

### 方式 1: 使用 npm 安装（推荐）

```bash
# 全局安装
npm install -g @harmonyos/mcp-server

# 或安装到项目
npm install @harmonyos/mcp-server
```

### 方式 2: 从源码安装

```bash
# 克隆仓库
git clone https://github.com/harmonyos/harmonyos-mcp.git
cd harmonyos-mcp

# 安装依赖
npm install

# 构建
npm run build
```

---

## ⚙️ 配置 OpenCode MCP

### 步骤 1: 创建 MCP 配置文件

在 OpenCode 配置目录创建 `mcp-config.json`：

**Windows**:
```
%APPDATA%\OpenCode\mcp-config.json
```

**macOS/Linux**:
```
~/.config/OpenCode/mcp-config.json
```

### 步骤 2: 添加 HarmonyOS MCP 配置

```json
{
  "mcpServers": {
    "harmonyos": {
      "command": "npx",
      "args": ["-y", "@harmonyos/mcp-server"],
      "env": {
        "HDC_PATH": "C:\\Huawei\\Sdk\\toolchains\\hdc.exe",
        "PROJECT_PATH": "C:\\Users\\mu\\Desktop\\code\\security_tool"
      },
      "disabled": false,
      "autoApprove": ["build_app", "install_app", "run_app"]
    }
  }
}
```

### 步骤 3: 重启 OpenCode

保存配置后，重启 OpenCode 使配置生效。

---

## 🚀 使用 HarmonyOS MCP 工具

### 1. 构建应用

```typescript
// 在 OpenCode 中调用
harmonyos_build_app({
  project_path: "C:\\Users\\mu\\Desktop\\code\\security_tool",
  build_mode: "debug",
  module: "entry"
})
```

**返回**:
```json
{
  "success": true,
  "output_path": "entry\\build\\default\\outputs\\default\\entry-default-unsigned.hap",
  "build_time": "2.3s"
}
```

---

### 2. 签名应用

```typescript
harmonyos_sign_app({
  hap_path: "entry\\build\\default\\outputs\\default\\entry-default-unsigned.hap",
  keystore_path: "hapsigner\\OpenHarmony.p12",
  keystore_password: "123456",
  key_alias: "openharmony application release",
  key_password: "123456",
  profile_path: "hapsigner\\ohos_provision_debug.p7b"
})
```

**返回**:
```json
{
  "success": true,
  "signed_path": "hapsigner\\signApp.hap",
  "sign_time": "1.2s"
}
```

---

### 3. 列出设备

```typescript
harmonyos_list_devices()
```

**返回**:
```json
{
  "devices": [
    {
      "id": "3XB0124805000101",
      "type": "usb",
      "status": "online",
      "model": "HWI-AL00"
    }
  ]
}
```

---

### 4. 安装应用

```typescript
harmonyos_install_app({
  hap_path: "hapsigner\\signApp.hap",
  device_id: "3XB0124805000101"
})
```

**返回**:
```json
{
  "success": true,
  "install_time": "3.5s",
  "message": "安装成功"
}
```

---

### 5. 运行应用

```typescript
harmonyos_run_app({
  bundle_name: "com.huawei.securitytool",
  ability_name: "EntryAbility",
  device_id: "3XB0124805000101"
})
```

**返回**:
```json
{
  "success": true,
  "message": "应用已启动"
}
```

---

### 6. 查看日志

```typescript
harmonyos_get_logs({
  device_id: "3XB0124805000101",
  bundle_name: "com.huawei.securitytool",
  lines: 100
})
```

**返回**:
```json
{
  "logs": [
    "03-09 10:30:00.123 12345/12345 I/SecurityTool: Application started",
    "03-09 10:30:00.456 12345/12345 I/SecurityTool: Loading main page",
    ...
  ]
}
```

---

### 7. 卸载应用

```typescript
harmonyos_uninstall_app({
  bundle_name: "com.huawei.securitytool",
  device_id: "3XB0124805000101"
})
```

**返回**:
```json
{
  "success": true,
  "message": "应用已卸载"
}
```

---

## 🔍 完整工作流示例

### 一键构建 → 签名 → 安装 → 运行

```typescript
// 1. 构建
const buildResult = await harmonyos_build_app({
  project_path: "C:\\Users\\mu\\Desktop\\code\\security_tool",
  build_mode: "debug"
})

if (!buildResult.success) {
  console.error('构建失败')
  return
}

// 2. 签名
const signResult = await harmonyos_sign_app({
  hap_path: buildResult.output_path,
  keystore_path: "hapsigner\\OpenHarmony.p12",
  keystore_password: "123456",
  key_alias: "openharmony application release",
  key_password: "123456",
  profile_path: "hapsigner\\ohos_provision_debug.p7b"
})

if (!signResult.success) {
  console.error('签名失败')
  return
}

// 3. 列出设备
const devices = await harmonyos_list_devices()
if (devices.devices.length === 0) {
  console.error('未检测到设备')
  return
}

const deviceId = devices.devices[0].id

// 4. 安装
const installResult = await harmonyos_install_app({
  hap_path: signResult.signed_path,
  device_id: deviceId
})

if (!installResult.success) {
  console.error('安装失败')
  return
}

// 5. 运行
const runResult = await harmonyos_run_app({
  bundle_name: "com.huawei.securitytool",
  ability_name: "EntryAbility",
  device_id: deviceId
})

if (runResult.success) {
  console.log('应用已成功启动！')
}
```

---

## ⚙️ 高级配置

### 环境变量配置

在 MCP 配置中添加环境变量：

```json
{
  "mcpServers": {
    "harmonyos": {
      "command": "npx",
      "args": ["-y", "@harmonyos/mcp-server"],
      "env": {
        "HDC_PATH": "C:\\Huawei\\Sdk\\toolchains\\hdc.exe",
        "PROJECT_PATH": "C:\\Users\\mu\\Desktop\\code\\security_tool",
        "KEYSTORE_PATH": "hapsigner\\OpenHarmony.p12",
        "KEYSTORE_PASSWORD": "123456",
        "KEY_ALIAS": "openharmony application release",
        "KEY_PASSWORD": "123456"
      }
    }
  }
}
```

### 自动批准配置

配置自动批准某些操作，避免每次确认：

```json
{
  "mcpServers": {
    "harmonyos": {
      "autoApprove": [
        "build_app",
        "install_app",
        "run_app",
        "list_devices",
        "get_logs"
      ]
    }
  }
}
```

---

## 🔧 常见问题

### Q1: MCP Server 未响应

**解决方案**:
1. 检查 Node.js 是否安装：`node --version`
2. 检查 MCP Server 是否安装：`npm list -g @harmonyos/mcp-server`
3. 重启 OpenCode
4. 查看 OpenCode 日志

---

### Q2: 找不到 HDC 工具

**错误**: `Error: hdc not found`

**解决方案**:
1. 确认 DevEco Studio 已安装
2. 配置 HDC_PATH 环境变量
3. 将 HDC 添加到系统 PATH:
   ```
   C:\Huawei\Sdk\toolchains\hdc.exe
   ```

---

### Q3: 构建失败

**错误**: `Build failed: hvigorw not found`

**解决方案**:
1. 检查项目路径是否正确
2. 确认 hvigorw 文件存在
3. 检查 Node.js 版本（推荐 18+）

---

### Q4: 安装失败

**错误**: `Install failed: device not found`

**解决方案**:
1. 检查设备连接：`hdc list targets`
2. 确保 USB 调试已开启
3. 重新授权电脑
4. 重启 HDC 服务：`hdc kill && hdc start`

---

### Q5: 签名失败

**错误**: `Sign failed: keystore not found`

**解决方案**:
1. 检查密钥库路径
2. 确认密码正确
3. 确认 p7b 文件存在
4. 重新生成签名配置

---

## 📖 相关资源

- [HarmonyOS MCP GitHub](https://github.com/harmonyos/harmonyos-mcp)
- [OpenCode MCP 文档](https://openai.com/index/mcp/)
- [DevEco Studio 下载](https://developer.huawei.com/consumer/cn/deveco-studio/)
- [HDC 工具文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-helpers/ hdc-0000001050064312)

---

## 🎯 快速验证

配置完成后，运行以下命令验证：

```bash
# 1. 测试 MCP Server
npx @harmonyos/mcp-server --version

# 2. 测试 HDC
hdc version

# 3. 列出设备
hdc list targets

# 4. 在 OpenCode 中测试
harmonyos_list_devices()
```

如果都正常，说明配置成功！✅

---

*最后更新：2026-03-09*
