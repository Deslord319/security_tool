# SecurityTool

> HarmonyOS 安全管理中心 / Enterprise Security Center for HarmonyOS

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-6.0.2-blue)](https://developer.huawei.com/consumer/cn/)
[![ArkTS](https://img.shields.io/badge/Language-ArkTS-orange)](https://developer.huawei.com/consumer/cn/doc/)
[![Target](https://img.shields.io/badge/Device-2in1-0A84FF)](https://developer.huawei.com/consumer/cn/)
[![Version](https://img.shields.io/badge/Version-1.0.0-brightgreen)](#项目基线)

`SecurityTool` 是一个基于 ArkTS 的 HarmonyOS 企业安全管理工具，面向 `2in1` 设备，聚合安全总览、防火墙、日志管理、外设管控、身份鉴别和工具设置能力。应用主入口为 `pages/MainPage`，包名为 `com.huawei.securitytool`，当前应用版本为 `1.0.0`。

## 当前能力

| 模块 | 说明 | 路由 / 入口 |
| --- | --- | --- |
| 安全总览 | 安全态势卡片、快捷入口、模块概览 | `dashboard` |
| 防火墙管理 | 模式切换、规则详情、规则新增删除、用户分发控制 | `firewall` / `firewall-rules` |
| 日志管理 | 审计与崩溃日志采集、分页展示、详情查看、导出、存储设置 | `log-manage` |
| 外设管理 | USB/蓝牙接口控制、设备策略、连接记录 | `peripheral-manage` |
| 身份鉴别 | 启动认证相关策略与身份配置 | `identity` |
| 工具设置 | 启动认证、认证方式、系统设置相关项 | `tool-settings` |
| 帮助与反馈 | 帮助入口、关于信息 | 顶部菜单 `help-feedback` |

## 项目基线

| 项目 | 值 |
| --- | --- |
| 应用名称 | 安全管理中心 |
| 项目名称 | `SecurityTool` |
| 包名 | `com.huawei.securitytool` |
| 版本 | `1.0.0` (`versionCode: 1000000`) |
| 目标设备 | `2in1` |
| 语言 | ArkTS (ETS) |
| SDK 基线 | HarmonyOS `6.0.2` |
| 主入口页面 | `pages/MainPage` |
| unsigned HAP | `entry/build/default/outputs/default/entry-default-unsigned.hap` |
| signed HAP | `hapsigner/signApp.hap` |

## 总体设计

### 产品定位

项目定位不是系统设置页集合，而是一个可构建、可签名、可安装、可演示、可验收的本地安全管理中心，服务于 HarmonyOS `2in1` 设备上的企业安全管理场景。

当前对外交付的核心能力集中在六个方向：

1. 统一安全入口
2. 防火墙策略控制
3. 外设接口与设备管控
4. 身份与账户策略配置
5. 安全日志采集与审计导出
6. 工具自身的启动认证保护

### 页面与导航设计

应用统一从 `pages/MainPage` 进入，页面骨架为“侧边栏 + 顶部操作区 + 主内容区”。主路由常量集中在 `entry/src/main/ets/constants/RouteIds.ets`，当前主导航如下：

```text
MainPage
  -> dashboard
  -> firewall
  -> log-manage
  -> peripheral-manage
  -> identity
  -> tool-settings
  -> help-feedback
```

其中：

- 侧边栏负责核心业务模块切换
- 顶部菜单负责主题、关于、帮助与反馈等辅助入口
- 防火墙模块再细分为总览页和规则页两层

### 技术分层

项目当前按以下层次组织：

```text
Page -> ViewModel -> Service -> Repository / Store / Provider -> HarmonyOS API
```

各层职责如下：

| 层级 | 职责 |
| --- | --- |
| `pages/`、`views/` | 页面容器、模块页面、交互事件转发、弹窗与局部 UI 状态 |
| `viewmodels/` | 页面状态收口、初始化、刷新、保存、提交流程 |
| `services/` | 领域动作编排，封装模块级业务能力 |
| `repositories/stores/providers` | 系统能力访问、本地状态持久化、环境与上下文提供 |
| `utils/`、`constants/`、`theme/` | 通用工具、常量、日志封装、主题系统 |

分层约束：

- 页面层不直接拼接多个业务流程
- `MainPage` 只负责模块装配和路由切换，不承载模块内部业务
- 业务日志统一走 `LogUtils.ets`
- 模块状态尽量在 ViewModel 收口，不在子组件里维护镜像副本

### 模块设计概览

| 模块 | 设计目标 | 关键能力 |
| --- | --- | --- |
| 安全总览 | 作为统一入口和演示起点 | 状态摘要、快捷入口、管理员/防火墙/日志/外设状态回显 |
| 防火墙管理 | 体现网络访问控制能力 | 总开关、模式切换、自定义规则、用户级模式下发 |
| 日志管理 | 提供可审计与可导出闭环 | 采集状态、筛选、分页、详情、导出、存储设置 |
| 外设管理 | 体现终端设备侧控制能力 | 接口开关、连接记录、单设备策略 |
| 身份鉴别 | 提供账户安全基线设置 | 密码复杂度、有效期、管理员激活态感知 |
| 工具设置 | 保护工具自身访问入口 | 启动认证、认证方式选择、系统密码入口 |

## 源码结构

### 根目录

```text
security_tool/
├── AppScope/                      # 应用级配置与资源
├── entry/                         # 主模块与测试模块
├── hapsigner/                     # 签名工具链与签名模板
├── scripts/e2e/                   # E2E 测试框架与 case
├── docs/                          # 需求、总体设计、模块设计、测试文档
├── build_hap.bat                  # 本地构建并同步 unsigned HAP
├── AGENTS.md                      # 项目级开发与签名/测试规范
├── hvigorfile.ts                  # Hvigor 构建入口
├── oh-package.json5               # 依赖定义
└── README.md
```

### `entry/src/main/ets`

```text
entry/src/main/ets/
├── components/                    # 通用组件与模块子组件
│   ├── firewall/
│   ├── log-manage/
│   └── peripheral/
├── constants/                     # 路由、字符串、样式与模块常量
├── enterpriseadminability/        # 企业管理员扩展能力
├── entryability/                  # UIAbility 入口
├── entrybackupability/            # 备份扩展能力
├── models/                        # 页面和领域模型
├── pages/                         # 主页面入口容器
├── services/                      # 业务服务层
├── testrunner/                    # 主模块测试运行器
├── theme/                         # 主题定义与主题管理
├── utils/                         # 日志、弹窗、路径、表单等工具
├── viewmodels/                    # 页面状态与交互编排
└── views/                         # 各模块页面实现
```

### `views` 与 `viewmodels` 的模块映射

| 模块 | 页面目录 | ViewModel 目录 |
| --- | --- | --- |
| Dashboard | `views/dashboard/overview` | `viewmodels/dashboard/overview` |
| Firewall | `views/firewall/overview`、`views/firewall/rules` | `viewmodels/firewall/overview`、`viewmodels/firewall/rules`、`viewmodels/firewall/user-dispatch` |
| Log Manage | `views/log-manage/overview` | `viewmodels/log-manage/overview`、`viewmodels/log-manage/storage-settings` |
| Peripheral | `views/peripheral/overview` | `viewmodels/peripheral/overview`、`viewmodels/peripheral/interface-control`、`viewmodels/peripheral/connection-record`、`viewmodels/peripheral/device-policy` |
| Identity | `views/identity/settings` | `viewmodels/identity/settings` |
| Tool Settings | `views/tool-settings/system-settings` | `viewmodels/tool-settings/system-settings` |
| Help & Feedback | `views/help-feedback/overview` | 由页面直接承载，未单独拆分 ViewModel |

### `services` 领域划分

当前服务层按业务域组织，便于按模块演进：

```text
services/
├── admin/activation/              # 企业管理员激活能力
├── firewall/                      # 防火墙总服务、模式策略、规则、用户分发、状态存储
├── identity/                      # 认证服务与身份设置服务
├── log-manage/                    # 日志采集、导出、归一化、仓储、数据源
├── peripheral/                    # 外设接口、连接记录、设备策略
└── tool-settings/                 # 系统设置与工具设置持久化
```

### 测试与辅助目录

```text
entry/src/test/                    # 本地单元测试
entry/src/ohosTest/                # 设备侧测试 Ability 与测试用例
scripts/e2e/cases/                 # E2E 声明式 case
scripts/e2e/adapters/security_tool/# 当前项目的页面语义与 suite 配置
scripts/e2e/bridges/               # 运行时 bridge 与 HarmonyOS MCP 适配
docs/02-总体设计/                  # 总体设计与产品定义
docs/03-模块设计/                  # 各模块设计说明
docs/04-测试文档/                  # 手工测试与 E2E 设计
```

## 快速开始

### 环境要求

- DevEco Studio / HarmonyOS SDK `6.0.2`
- DevEco Studio 自带 JBR 或 Java `11+`，需能被 `hvigorw` 所在 shell 访问
- `hdc`
- Windows 本地开发推荐直接使用仓库脚本 `build_hap.bat`

`build_hap.bat` 按以下顺序定位 `hvigorw.bat`：

1. `DEVECOSTUDIO_HOME`
2. `C:\Program Files\Huawei\DevEco Studio`
3. `JAVA_HOME` 仅作为兜底

### 1. 构建 unsigned HAP

推荐：

```powershell
.\build_hap.bat
```

如果需要手动执行，确保 `hvigorw.bat` 已按上文规则可用：

```powershell
hvigorw assembleHap --mode module -p product=default -p module=entry@default
```

构建成功后，产物位于：

```text
entry/build/default/outputs/default/entry-default-unsigned.hap
```

### 2. 签名

```powershell
Copy-Item -LiteralPath 'entry\build\default\outputs\default\entry-default-unsigned.hap' -Destination 'hapsigner\entry-default-unsigned.hap' -Force
Push-Location 'hapsigner'
.\2-debug-sign.bat
Pop-Location
```

如果修改了 `hapsigner/UnsgnedDebugProfileTemplate.json` 的包名或权限，必须先重新生成 `p7b`：

```powershell
Push-Location 'hapsigner'
.\1-debug-p7b.bat
.\2-debug-sign.bat
Pop-Location
```

### 3. 安装并激活企业管理员

```powershell
hdc install hapsigner\signApp.hap
hdc shell edm enable-admin -n com.huawei.securitytool -a EnterpriseAdminAbility -t super
hdc shell aa start -a EntryAbility -b com.huawei.securitytool
```

## 一致性要求

包名和受限权限需要在以下三个位置保持一致：

| 文件 | 关键字段 |
| --- | --- |
| `AppScope/app.json5` | `app.bundleName` |
| `entry/src/main/module.json5` | `module.requestPermissions` |
| `hapsigner/UnsgnedDebugProfileTemplate.json` | `bundle-info.bundle-name`、`acls.allowed-acls`、`permissions.restricted-permissions` |

新增权限时，请同时更新 `module.json5` 与签名模板；如果签名模板发生变更，务必重新执行 `1-debug-p7b.bat` 后再签名。

## 测试

当前仓库中，按文件数统计包含：

- `76` 个本地单元测试文件：`entry/src/test/**/*.test.ets`
- `21` 个 `ohosTest` 设备侧测试文件：`entry/src/ohosTest/ets/test/**/*.test.ets`
- `45` 个 E2E case：`scripts/e2e/cases/**/*.json`

E2E case 以端到端功能闭环为主，覆盖规则创建/删除、日志筛选与存储设置保存、外设策略可逆变更、身份策略保存、工具设置系统入口跳转等场景。

常用命令：

```powershell
# 本地单元测试
hvigorw test --mode module -p product=default -p module=entry@default

# 编译 ohosTest
hvigorw test --mode module -p product=default -p module=entry@ohosTest

# 构建设备侧测试 HAP
hvigorw assembleHap --mode module -p product=default -p module=entry@ohosTest

# 安装主包与测试包
hdc install hapsigner/signApp.hap
hdc install entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap

# 默认设备冒烟
hdc shell aa test -b com.huawei.securitytool -m entry -s unittest OpenHarmonyTestRunner -w 60000

# 可选场景
hdc shell aa test -b com.huawei.securitytool -m entry -s unittest OpenHarmonyTestRunner -s mode route_action -w 60000
hdc shell aa test -b com.huawei.securitytool -m entry -s unittest OpenHarmonyTestRunner -s mode peripheral_contract -w 60000
hdc shell aa test -b com.huawei.securitytool -m entry -s unittest OpenHarmonyTestRunner -s mode theme_menu -w 60000
hdc shell aa test -b com.huawei.securitytool -m entry -s unittest OpenHarmonyTestRunner -s mode firewall_subroute -w 60000
```

E2E 测试入口：

```powershell
python scripts/e2e/run_e2e.py --adapter security_tool --list-suites
python scripts/e2e/run_e2e.py --adapter security_tool --suite smoke --dry-run
```

更多说明见 [scripts/e2e/README.md](scripts/e2e/README.md)。

## 目录结构

```text
security_tool/
├── AppScope/                      # 应用级配置
├── entry/
│   ├── src/main/ets/              # ArkTS 主代码与模块实现
│   ├── src/main/resources/        # 应用资源
│   ├── src/test/                  # 本地单元测试
│   └── src/ohosTest/              # 设备侧测试
├── hapsigner/                     # 签名工具、证书和模板
├── scripts/e2e/                   # E2E runner、bridge、case、reporter
├── docs/                          # PRD、总体设计、模块设计、测试文档
├── build_hap.bat                  # 本地构建脚本
├── AGENTS.md                      # 开发规范
└── README.md
```

## 关键文档

- [AGENTS.md](AGENTS.md)：开发规范、签名流程、权限一致性、测试基线
- [scripts/e2e/README.md](scripts/e2e/README.md)：E2E 测试框架与运行方式
- [docs/04-测试文档/DEVICE_TEST_FRAMEWORK.md](docs/04-测试文档/DEVICE_TEST_FRAMEWORK.md)：设备侧测试基线
- [docs/04-测试文档/e2e测试/端到端测试框架设计.md](docs/04-测试文档/e2e测试/端到端测试框架设计.md)：E2E 框架设计
- [docs/02-总体设计/总体设计RFC.md](docs/02-总体设计/总体设计RFC.md)：总体设计说明
- [docs/02-总体设计/PRD.md](docs/02-总体设计/PRD.md)：产品需求范围
- [docs/storage-architecture-standard.md](docs/storage-architecture-standard.md)：存储架构与迁移标准
- [docs/03-模块设计/安全总览组件设计说明.md](docs/03-模块设计/安全总览组件设计说明.md)：安全总览模块设计
- [docs/03-模块设计/防火墙管理组件设计说明.md](docs/03-模块设计/防火墙管理组件设计说明.md)：防火墙模块设计
- [docs/03-模块设计/外设管理组件设计说明.md](docs/03-模块设计/外设管理组件设计说明.md)：外设模块设计
- [docs/03-模块设计/身份鉴别组件设计说明.md](docs/03-模块设计/身份鉴别组件设计说明.md)：身份鉴别模块设计
- [docs/03-模块设计/日志管理组件设计说明.md](docs/03-模块设计/日志管理组件设计说明.md)：日志管理模块设计
- [docs/03-模块设计/工具设置组件设计说明.md](docs/03-模块设计/工具设置组件设计说明.md)：工具设置模块设计
- [docs/03-模块设计/帮助与反馈组件设计说明.md](docs/03-模块设计/帮助与反馈组件设计说明.md)：帮助与反馈辅助页设计
- [docs/01-UX设计/index.html](docs/01-UX设计/index.html)：UX 原型入口

## 常见问题

### 页面空白

检查 `EntryAbility.ets` 中是否仍然加载：

```ts
windowStage.loadContent('pages/MainPage', ...)
```

### 安装失败或签名错误

- 确认 `AppScope/app.json5` 与 `hapsigner/UnsgnedDebugProfileTemplate.json` 的包名一致
- 如果签名模板刚修改过，重新执行 `1-debug-p7b.bat` 和 `2-debug-sign.bat`

### MDM 能力调用失败

如果出现类似企业管理权限不足或错误码 `9200001`，先执行：

```powershell
hdc shell edm enable-admin -n com.huawei.securitytool -a EnterpriseAdminAbility -t super
```

### 找不到 `hvigorw`

优先检查：

1. `DEVECOSTUDIO_HOME` 是否已设置
2. `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat` 是否存在
3. 是否在 DevEco Studio 自带终端中执行

## 说明

- 业务日志统一通过 `entry/src/main/ets/utils/LogUtils.ets` 输出
- 含中文的代码、测试与文档文件应始终按 UTF-8 处理
- 查询 OpenHarmony / HarmonyOS 官方文档时，项目默认参考 `https://gitee.com/openharmony/docs/tree/master`
