# AGENTS.md - AI Coder 开发指南

本文档为 AI 编码助手（如 Qoder、Cursor、Copilot 等）提供本项目的关键开发规范和操作指南。

## 项目概述

- **项目名称**：SecurityTool（HarmonyOS 安全管理中心）
- **包名**：`com.example.securitytool`（不含下划线）
- **入口页面**：`pages/MainPage`（非 pages/Index）
- **目标设备**：2in1
- **语言**：ArkTS (ETS)

## 构建与签名流程（必读）

### 构建

使用 `build_app` MCP 工具构建项目时，路径参数必须使用正确的大小写：

```
项目路径：D:\lxl\ho_demo\SecurityTool
```

构建产物位于：
```
entry/build/default/outputs/default/entry-default-unsigned.hap
```

### 签名（重要）

签名工具位于项目根目录 `hapsigner/` 下。完整签名流程如下：

#### 步骤 1：拷贝 unsigned HAP

将构建产物拷贝到签名目录：
```bash
cp entry/build/default/outputs/default/entry-default-unsigned.hap hapsigner/entry-default-unsigned.hap
```

#### 步骤 2：生成签名描述文件（p7b）

**仅在修改了 `hapsigner/UnsgnedDebugProfileTemplate.json` 后需要执行此步骤。**

修改场景包括：更改包名、新增/删除权限。

```bash
cd hapsigner && ./1-debug-p7b.bat
```

或使用 Java 命令：
```bash
cd hapsigner
java -jar hap-sign-tool.jar sign-profile \
  -mode "localSign" \
  -keyAlias "OpenHarmony Application Profile Debug" \
  -keyPwd "123456" \
  -inFile "UnsgnedDebugProfileTemplate.json" \
  -outFile "ohos_provision_debug.p7b" \
  -keystoreFile "OpenHarmony.p12" \
  -keystorePwd "123456" \
  -signAlg "SHA256withECDSA" \
  -profileCertFile "OpenHarmonyProfileDebug.pem"
```

#### 步骤 3：签名 HAP

```bash
cd hapsigner && ./2-debug-sign.bat
```

或使用 Java 命令：
```bash
cd hapsigner
java -jar hap-sign-tool.jar sign-app \
  -keyAlias "openharmony application release" \
  -signAlg "SHA256withECDSA" \
  -mode "localSign" \
  -appCertFile "OpenHarmonyApplication.pem" \
  -profileFile "ohos_provision_debug.p7b" \
  -inFile "entry-default-unsigned.hap" \
  -keystoreFile "OpenHarmony.p12" \
  -outFile "signApp.hap" \
  -keyPwd "123456" \
  -keystorePwd "123456"
```

#### 步骤 4：安装到设备

```bash
hdc install hapsigner/signApp.hap
```

## 关键一致性规则

以下三个位置的包名和权限必须保持一致，修改任一处时必须同步其余两处：

| 文件 | 字段 |
|------|------|
| `AppScope/app.json5` | `bundleName` |
| `entry/src/main/module.json5` | `requestPermissions` |
| `hapsigner/UnsgnedDebugProfileTemplate.json` | `bundle-name`、`acls.allowed-acls`、`permissions.restricted-permissions` |

**修改 `UnsgnedDebugProfileTemplate.json` 后，必须重新执行步骤 2（生成 p7b），再执行步骤 3（签名）。**

## 签名密钥别名速查

| 用途 | Key Alias |
|------|-----------|
| 签名描述文件 (p7b) | `OpenHarmony Application Profile Debug` |
| 签名应用 (HAP) | `openharmony application release` |
| 密钥库/密钥密码 | `123456` |

## 当前权限列表

```
ohos.permission.MANAGE_NET_FIREWALL
ohos.permission.GET_NET_FIREWALL
ohos.permission.ENTERPRISE_MANAGE_NETWORK
ohos.permission.ENTERPRISE_MANAGE_USB
ohos.permission.ENTERPRISE_MANAGE_RESTRICTIONS
ohos.permission.ENTERPRISE_MANAGE_BLUETOOTH
ohos.permission.ENTERPRISE_GET_DEVICE_INFO
```

新增权限时，需要同时在 `module.json5` 的 `requestPermissions` 和 `UnsgnedDebugProfileTemplate.json` 的 `acls.allowed-acls` + `permissions.restricted-permissions` 中添加。

## 页面路由

| 路由 ID | 页面 | 说明 |
|---------|------|------|
| `dashboard` | DashboardPage | 安全总览 |
| `firewall` | FirewallPage | 防火墙管理 |
| `firewall-rules` | FirewallRulesPage | 防火墙规则详情 |
| `log-manage` | PlaceholderPage | 日志管理（待开发） |
| `peripheral-manage` | PlaceholderPage | 外设管理（待开发） |
| `identity` | PlaceholderPage | 身份鉴别（待开发） |
| `tool-settings` | PlaceholderPage | 工具设置（待开发） |

## 常见问题

1. **页面空白**：检查 `EntryAbility.ets` 中 `windowStage.loadContent` 的参数是否为 `'pages/MainPage'`。
2. **安装失败（签名错误）**：确认 `UnsgnedDebugProfileTemplate.json` 中 `bundle-name` 与 `app.json5` 中 `bundleName` 一致，并重新执行 p7b 生成 + 签名。
3. **权限不足**：确认权限同时声明在 `module.json5` 和签名模板的 `acls` + `permissions` 中。
4. **构建路径错误**：MCP `build_app` 工具路径参数注意大小写，使用 `D:\lxl\ho_demo\SecurityTool`。
