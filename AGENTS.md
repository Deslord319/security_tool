# AGENTS.md - AI Coder 开发指南

本文档为 AI 编码助手（如 Qoder、Cursor、Copilot 等）提供本项目的关键开发规范和操作指南。

## 项目概述

- **项目名称**：SecurityTool（HarmonyOS 安全管理中心）
- **包名**：`com.huawei.securitytool`（不含下划线）
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

#### 步骤 5：激活企业管理员（MDM 功能必需）

```bash
hdc shell edm enable-admin -n com.huawei.securitytool -a EnterpriseAdminAbility -t super
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
ohos.permission.ENTERPRISE_MANAGE_WIFI
ohos.permission.ENTERPRISE_ADMIN_MANAGE
ohos.permission.ENTERPRISE_MANAGE_SECURITY
ohos.permission.ENTERPRISE_SET_ACCOUNT_POLICY
```

新增权限时，需要同时在 `module.json5` 的 `requestPermissions` 和 `UnsgnedDebugProfileTemplate.json` 的 `acls.allowed-acls` + `permissions.restricted-permissions` 中添加。

## 页面路由

| 路由 ID | 页面 | 说明 |
|---------|------|------|
| `dashboard` | DashboardPage | 安全总览 |
| `firewall` | FirewallPage | 防火墙管理 |
| `firewall-rules` | FirewallRulesPage | 防火墙规则详情 |
| `log-manage` | PlaceholderPage | 日志管理（待开发） |
| `peripheral-manage` | PeripheralPage | 外设管理（已完成） |
| `identity` | IdentityPage | 身份鉴别（已完成） |
| `tool-settings` | ToolSettingsPage | 工具设置（已完成） |

## 常见问题

1. **页面空白**：检查 `EntryAbility.ets` 中 `windowStage.loadContent` 的参数是否为 `'pages/MainPage'`。
2. **安装失败（签名错误）**：确认 `UnsgnedDebugProfileTemplate.json` 中 `bundle-name` 与 `app.json5` 中 `bundleName` 一致，并重新执行 p7b 生成 + 签名。
3. **权限不足**：确认权限同时声明在 `module.json5` 和签名模板的 `acls` + `permissions` 中。
4. **MDM 操作失败（错误码 9200001）**：表示应用未激活为企业管理员，执行 `edm enable-admin -n com.huawei.securitytool -a EnterpriseAdminAbility -t super` 后重试。
5. **构建路径错误**：MCP `build_app` 工具路径参数注意大小写，使用 `D:\lxl\ho_demo\SecurityTool`。

---

## CI/CD 自动化流程

### GitHub Actions 工作流

项目已配置完整的 CI/CD 流水线，自动化流程如下：

#### 触发条件

| 事件 | 分支/标签 | 执行流程 |
|------|----------|---------|
| Push | `develop` | 构建 + 测试 |
| Push | `main` | 构建 + 测试 + 签名 |
| Tag | `v*` | 构建 + 测试 + 签名 + GitHub Release |
| Pull Request | `main` | 构建 + 测试 |

#### 工作流说明

**Job 1: Build** - 构建验证
- 安装 HarmonyOS SDK 6.0.2
- 执行 `hvigorw assembleHap` 构建
- 生成未签名 HAP 包
- 上传为 Artifact（保留 7 天）

**Job 2: Test** - 组件测试
- 执行 `hvigorw :entry:test`
- 生成测试报告
- 测试报告上传为 Artifact

**Job 3: Sign** - 自动签名（仅 main/标签）
- 从 GitHub Secrets 读取签名密钥
- 执行 Java 签名命令
- 生成已签名 HAP 包
- 上传为 Artifact（保留 30 天）

**Job 4: Release** - 发布（仅标签）
- 创建 GitHub Release
- 自动上传已签名 HAP
- 生成发布说明

#### Secrets 配置

在 GitHub 仓库 Settings → Secrets and variables → Actions 配置以下密钥：

| Secret 名称 | 值 | 说明 |
|------------|-----|------|
| `SIGNING_KEYSTORE` | base64 编码的 `.p12` 文件 | 密钥库 |
| `SIGNING_KEYSTORE_PASSWORD` | `123456` | 密钥库密码 |
| `SIGNING_KEY_ALIAS` | `openharmony application release` | 密钥别名 |
| `SIGNING_KEY_PASSWORD` | `123456` | 密钥密码 |

配置指南详见：`.github/SECRETS_SETUP.md`

#### 本地调试 CI

```bash
# 1. 使用 act 工具在本地运行 GitHub Actions
npm install -g @act-js/cli

# 2. 运行构建作业
act push

# 3. 运行测试作业
act -j test
```

#### 状态徽章

添加到 README.md：

```markdown
[![CI/CD](https://github.com/Deslord319/security_tool/actions/workflows/ci.yml/badge.svg)](https://github.com/Deslord319/security_tool/actions/workflows/ci.yml)
```

---

## 附录：自动化脚本

### 一键构建 + 签名 + 安装（本地）

```bash
# Windows (PowerShell)
.\build_hap.bat && cd hapsigner && .\2-debug-sign.bat && hdc install signApp.hap

# Linux/Mac
./hvigorw assembleHap --mode module -p product=default -p module=entry && \
cd hapsigner && \
java -jar hap-sign-tool.jar sign-app \
  -keyAlias "openharmony application release" \
  -signAlg "SHA256withECDSA" \
  -mode "localSign" \
  -appCertFile "OpenHarmonyApplication.pem" \
  -profileFile "ohos_provision_debug.p7b" \
  -inFile "../entry/build/default/outputs/default/entry-default-unsigned.hap" \
  -keystoreFile "OpenHarmony.p12" \
  -outFile "signApp.hap" \
  -keyPwd "123456" \
  -keystorePwd "123456" && \
hdc install signApp.hap
```

---

*最后更新：2026-03-09 - 添加 CI/CD 自动化流程说明*
