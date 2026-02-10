# SecurityTool - HarmonyOS 安全管理中心

基于 OpenHarmony/HarmonyOS 的企业级安全管理工具应用，提供防火墙管理、外设管控、日志审计等功能。

## 基本信息

| 项目 | 值 |
|------|------|
| 包名 | `com.example.securitytool` |
| 目标设备 | 2in1 |
| SDK | HarmonyOS |
| 入口 | `EntryAbility` -> `pages/MainPage` |

## 功能模块

- **总览 (Dashboard)** - 安全状态概览、统计卡片
- **防火墙 (Firewall)** - 网络防火墙开关、规则类型管理、流量方向过滤
- **防火墙规则 (Firewall Rules)** - IP/域名/DNS 规则的增删改查
- **日志管理** - 安全日志审计（开发中）
- **外设管理** - USB/蓝牙等外设管控（开发中）
- **身份鉴别** - 身份认证管理（开发中）
- **工具设置** - 应用配置（开发中）

## 项目结构

```
SecurityTool/
├── AppScope/                    # 应用级配置
│   └── app.json5                # 包名、版本等（bundleName 在此定义）
├── entry/src/main/
│   ├── ets/
│   │   ├── entryability/        # 应用入口 Ability
│   │   ├── pages/               # 页面（MainPage）
│   │   ├── views/               # 视图组件（Dashboard、Firewall 等）
│   │   ├── components/          # 通用组件（SideBar、StatCard 等）
│   │   ├── constants/           # 常量定义（路由、样式、颜色）
│   │   ├── models/              # 数据模型
│   │   └── services/            # 服务层（FirewallService）
│   ├── resources/               # 资源文件
│   └── module.json5             # 模块配置（权限声明在此）
├── hapsigner/                   # HAP 签名工具（见下方签名章节）
└── build-profile.json5          # 构建配置
```

## 权限列表

本应用使用以下系统权限（需在 `module.json5` 和签名模板中同步配置）：

| 权限 | 用途 |
|------|------|
| `ohos.permission.MANAGE_NET_FIREWALL` | 管理网络防火墙规则 |
| `ohos.permission.GET_NET_FIREWALL` | 读取防火墙状态和规则 |
| `ohos.permission.ENTERPRISE_MANAGE_NETWORK` | 企业网络管理 |
| `ohos.permission.ENTERPRISE_MANAGE_USB` | USB 外设管控 |
| `ohos.permission.ENTERPRISE_MANAGE_RESTRICTIONS` | 设备限制策略 |
| `ohos.permission.ENTERPRISE_MANAGE_BLUETOOTH` | 蓝牙设备管控 |
| `ohos.permission.ENTERPRISE_GET_DEVICE_INFO` | 获取设备信息 |

## 构建与签名

### 1. 构建

使用 HarmonyOS 命令行工具或 DevEco Studio 构建项目，生成 unsigned HAP：

```
entry/build/default/outputs/default/entry-default-unsigned.hap
```

### 2. 签名流程

签名工具位于项目根目录 `hapsigner/` 下。

#### 关键文件说明

| 文件 | 说明 |
|------|------|
| `hap-sign-tool.jar` | 签名工具主程序 |
| `UnsgnedDebugProfileTemplate.json` | 签名配置模板（包含包名和权限声明） |
| `OpenHarmony.p12` | 密钥库文件 |
| `OpenHarmonyApplication.pem` | 应用证书 |
| `OpenHarmonyProfileDebug.pem` | Debug 描述文件证书 |
| `1-debug-p7b.bat` | 步骤1：生成签名描述文件 (.p7b) |
| `2-debug-sign.bat` | 步骤2：签名 HAP 包 |

#### 签名步骤

**步骤 1**：将编译产物 `entry-default-unsigned.hap` 拷贝到 `hapsigner/` 目录。

**步骤 2**：如果修改了 `UnsgnedDebugProfileTemplate.json`（如更改包名或权限），必须先运行 `1-debug-p7b.bat` 重新生成 `.p7b` 文件：

```bash
cd hapsigner
1-debug-p7b.bat
```

**步骤 3**：运行 `2-debug-sign.bat` 对 HAP 进行签名：

```bash
cd hapsigner
2-debug-sign.bat
```

签名后的文件为 `hapsigner/signApp.hap`。

### 3. 安装到设备

```bash
hdc install hapsigner/signApp.hap
```

### 注意事项

- **包名一致性**：`app.json5` 中的 `bundleName`、`module.json5` 中的模块配置、以及 `UnsgnedDebugProfileTemplate.json` 中的 `bundle-name` 必须保持一致，均为 `com.example.securitytool`。
- **权限一致性**：`module.json5` 中的 `requestPermissions` 和 `UnsgnedDebugProfileTemplate.json` 中的 `acls.allowed-acls` / `permissions.restricted-permissions` 必须保持同步。
- **修改模板后必须重新生成 p7b**：每次修改 `UnsgnedDebugProfileTemplate.json` 后，必须重新执行 `1-debug-p7b.bat`，否则签名会使用旧的配置。
