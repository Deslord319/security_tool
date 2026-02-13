# HarmonyShield

**HarmonyOS 企业级安全管理中心**

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-5.0-blue)](https://developer.huawei.com/consumer/cn/harmonyos/)
[![ArkTS](https://img.shields.io/badge/Language-ArkTS-orange)](https://developer.huawei.com/consumer/cn/arkts/)
[![License](https://img.shields.io/badge/License-Apache%202.0-green)](LICENSE)

## 项目介绍

HarmonyShield 是一款基于 HarmonyOS/OpenHarmony 平台的企业级安全管理应用，专为企业 IT 管理员设计。应用提供防火墙管理、外设管控、审计日志、身份认证、安全总览及策略配置六大核心功能，支持 IP/域名/DNS 防火墙规则配置、USB/蓝牙/Wi-Fi 等外设接口的黑白名单管理、口令复杂度与有效期策略设置，以及实时安全事件监控与日志导出。产品深度集成 MDM Kit 与 netFirewall API，采用零信任安全架构，提供细粒度的访问控制能力和原生 HarmonyOS 体验。适用于企业 IT 管理、政府公共部门、医疗金融机构及工业制造等对安全有严格要求的场景，有效解决数据泄露、未授权设备接入、网络安全威胁、合规审计及弱身份认证等企业安全痛点，全面保障组织设备符合安全策略，守护敏感数据安全。

## 基本信息

| 项目 | 值 |
|------|------|
| 项目名称 | HarmonyShield |
| 包名 | `com.example.securitytool` |
| 目标设备 | 2in1 |
| SDK | HarmonyOS 5.0 |
| 语言 | ArkTS (ETS) |
| 入口 | `EntryAbility` -> `pages/MainPage` |

## 技术栈

| 类别 | 技术 |
|------|------|
| 开发框架 | HarmonyOS ArkTS |
| UI 框架 | ArkUI |
| 网络安全 | netFirewall API |
| 设备管理 | MDM Kit |
| 身份认证 | userAuth (userIAM) |
| 安全存储 | Asset Store Kit |
| 构建工具 | hvigor |

## 应用架构

```
┌─────────────────────────────────────────────────────────┐
│                      Entry (入口层)                      │
│                    EntryAbility.ets                      │
├─────────────────────────────────────────────────────────┤
│                      Pages (页面层)                       │
│  MainPage │ DashboardPage │ FirewallPage │ RulesPage    │
├─────────────────────────────────────────────────────────┤
│                   Components (组件层)                     │
│    SideBar │ StatCard │ RuleTable │ Modal │ Toast       │
├─────────────────────────────────────────────────────────┤
│                    Services (服务层)                      │
│         FirewallService │ AuthService │ LogService       │
├─────────────────────────────────────────────────────────┤
│                   Data Models (数据层)                    │
│       FirewallRule │ DeviceInfo │ AuditLog │ Policy      │
├─────────────────────────────────────────────────────────┤
│                   System APIs (系统接口)                  │
│    netFirewall │ MDM Kit │ userAuth │ Asset Store Kit    │
└─────────────────────────────────────────────────────────┘
```

## 功能模块

| 模块 | 功能描述 | 状态 |
|------|----------|------|
| 安全总览 (Dashboard) | 安全状态概览、统计卡片、快捷入口 | 已完成 |
| 防火墙管理 (Firewall) | 网络防火墙开关、规则类型管理、流量方向过滤 | 已完成 |
| 防火墙规则 (Rules) | IP/域名/DNS 规则的增删改查 | 已完成 |
| 外设管理 (Peripheral) | USB/蓝牙等外设管控、接口黑白名单 | 开发中 |
| 日志管理 (Log) | 安全日志审计、事件查询、日志导出 | 开发中 |
| 身份鉴别 (Identity) | 口令策略、身份认证管理 | 开发中 |
| 工具设置 (Settings) | 应用配置、启动认证 | 开发中 |

## 项目结构

```
HarmonyShield/
├── AppScope/                    # 应用级配置
│   └── app.json5                # 包名、版本等 (bundleName)
├── entry/src/main/
│   ├── ets/
│   │   ├── entryability/        # 应用入口 Ability
│   │   ├── pages/               # 页面 (MainPage)
│   │   ├── views/               # 视图组件 (Dashboard、Firewall 等)
│   │   ├── components/          # 通用组件 (SideBar、StatCard 等)
│   │   ├── constants/           # 常量定义 (路由、样式、颜色)
│   │   ├── models/              # 数据模型
│   │   └── services/            # 服务层 (FirewallService)
│   ├── resources/               # 资源文件
│   └── module.json5             # 模块配置 (权限声明)
├── hapsigner/                   # HAP 签名工具
├── security-app/                # UX 设计原型 (Web 版)
├── AGENTS.md                    # AI 开发助手指南
└── build-profile.json5          # 构建配置
```

## 快速开始

### 环境要求

- DevEco Studio 5.0+
- HarmonyOS SDK 5.0+
- Java 11+ (签名工具需要)

### 构建步骤

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd HarmonyShield
   ```

2. **打开项目**
   
   使用 DevEco Studio 打开项目目录。

3. **构建 HAP**
   
   使用 DevEco Studio 构建或命令行工具：
   ```bash
   hvigorw assembleHap
   ```
   
   构建产物位于：
   ```
   entry/build/default/outputs/default/entry-default-unsigned.hap
   ```

4. **签名 HAP**
   
   ```bash
   # 拷贝 unsigned HAP 到签名目录
   cp entry/build/default/outputs/default/entry-default-unsigned.hap hapsigner/
   
   # 签名 (如修改了权限或包名，先运行 1-debug-p7b.bat)
   cd hapsigner
   ./2-debug-sign.bat
   ```

5. **安装到设备**
   ```bash
   hdc install hapsigner/signApp.hap
   ```

## 签名说明

签名工具位于 `hapsigner/` 目录。详细签名流程请参考 [AGENTS.md](AGENTS.md)。

### 关键文件

| 文件 | 说明 |
|------|------|
| `hap-sign-tool.jar` | 签名工具主程序 |
| `UnsgnedDebugProfileTemplate.json` | 签名配置模板 (包名/权限) |
| `OpenHarmony.p12` | 密钥库文件 |
| `1-debug-p7b.bat` | 生成签名描述文件 |
| `2-debug-sign.bat` | 签名 HAP 包 |

### 一致性要求

以下三处配置必须保持一致：

| 文件 | 字段 |
|------|------|
| `AppScope/app.json5` | `bundleName` |
| `entry/src/main/module.json5` | `requestPermissions` |
| `hapsigner/UnsgnedDebugProfileTemplate.json` | `bundle-name`、`acls`、`permissions` |

## 权限列表

| 权限 | 用途 |
|------|------|
| `ohos.permission.MANAGE_NET_FIREWALL` | 管理网络防火墙规则 |
| `ohos.permission.GET_NET_FIREWALL` | 读取防火墙状态和规则 |
| `ohos.permission.ENTERPRISE_MANAGE_NETWORK` | 企业网络管理 |
| `ohos.permission.ENTERPRISE_MANAGE_USB` | USB 外设管控 |
| `ohos.permission.ENTERPRISE_MANAGE_RESTRICTIONS` | 设备限制策略 |
| `ohos.permission.ENTERPRISE_MANAGE_BLUETOOTH` | 蓝牙设备管控 |
| `ohos.permission.ENTERPRISE_GET_DEVICE_INFO` | 获取设备信息 |

## API 接口参考

| 模块 | API |
|------|-----|
| 防火墙管理 | `netFirewall` - `@ohos.net.netFirewall` |
| 外设接口管控 | `restrictions.setDisallowedPolicy` - `@ohos.enterprise.restrictions` |
| USB 黑白名单 | `usbManager.addAllowedUsbDevices` - `@kit.MDMKit` |
| 蓝牙白名单 | `bluetoothManager.addAllowedBluetoothDevices` - `@kit.MDMKit` |
| 口令策略 | `securityManager.setPasswordPolicy` - `@ohos.enterprise.securityManager` |
| 启动认证 | `userAuth.getUserAuthInstance` - `@ohos.userIAM.userAuth` |
| 安全存储 | `asset.add/query/update` - `@ohos.security.asset` |

## UX 设计原型

`security-app/` 目录包含 Web 版 UX 设计原型，可直接用浏览器打开 `security-app/index.html` 预览。

### 设计规范

- **布局**：左侧 200px 固定导航栏 + 右侧自适应内容区
- **配色**：品牌色 `#0A84FF`、确认色 `#34C759`、警告色 `#FF9500`、危险色 `#FF3B30`
- **圆角**：4px / 8px / 12px / 16px
- **响应式**：768px / 1024px / 1200px 断点

## 页面路由

| 路由 ID | 页面 | 说明 |
|---------|------|------|
| `dashboard` | DashboardPage | 安全总览 |
| `firewall` | FirewallPage | 防火墙管理 |
| `firewall-rules` | FirewallRulesPage | 防火墙规则详情 |
| `log-manage` | PlaceholderPage | 日志管理 (待开发) |
| `peripheral-manage` | PlaceholderPage | 外设管理 (待开发) |
| `identity` | PlaceholderPage | 身份鉴别 (待开发) |
| `tool-settings` | PlaceholderPage | 工具设置 (待开发) |

## 常见问题

**Q: 页面空白怎么办？**

检查 `EntryAbility.ets` 中 `windowStage.loadContent` 的参数是否为 `'pages/MainPage'`。

**Q: 安装失败（签名错误）怎么办？**

确认 `UnsgnedDebugProfileTemplate.json` 中 `bundle-name` 与 `app.json5` 中 `bundleName` 一致，并重新执行 p7b 生成 + 签名。

**Q: 权限不足怎么办？**

确认权限同时声明在 `module.json5` 和签名模板的 `acls` + `permissions` 中。

## 相关文档

- [AGENTS.md](AGENTS.md) - AI 开发助手指南 (详细签名流程)
- [security-app/about.html](security-app/about.html) - 项目介绍页面
- [security-app/index.html](security-app/index.html) - UX 设计原型

## License

Apache License 2.0
