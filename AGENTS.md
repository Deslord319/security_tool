# AGENTS.md - AI Coder 开发指南

本文档为 AI 编码助手（如 Qoder、Cursor、Copilot 等）提供本项目的关键开发规范和操作指南。

常见开发任务的具体读法、实施顺序和验证矩阵见 `docs/05-AI开发/AI常见任务手册.md`。

## 项目概述

- **项目名称**：SecurityTool（HarmonyOS 安全管理中心）
- **包名**：`com.huawei.securitytool`（不含下划线）
- **入口页面**：`pages/MainPage`（非 pages/Index）
- **目标设备**：2in1
- **语言**：ArkTS (ETS)

## AI 执行原则（必读）

本项目的 AI 编码执行原则见 `docs/05-AI开发/AI执行原则.md`。

执行非平凡开发任务前，必须先按该文档明确影响面、最小改动范围和验证闭环。涉及模块行为、状态流、页面交互、权限、系统能力调用、数据模型或模块级验收口径变化时，必须继续遵循本文档的“模块设计先行规则”。

该原则用于约束 AI 的工作方式，不替代构建、签名、权限、日志、编码、测试和 CI/CD 等项目硬规则；当规则存在重叠时，以更具体的项目规则为准。

## 构建与签名流程（必读）

### 构建

构建产物位于：
```
entry/build/default/outputs/default/entry-default-unsigned.hap
```

本地执行 `build_hap.bat`、`hvigorw assembleHap` 或测试链路中需要调用 `hvigorw` 时，查找规则固定如下：

1. 优先使用环境变量 `DEVECOSTUDIO_HOME`
2. 若未设置，则优先检查 `C:\Program Files\Huawei\DevEco Studio`
3. 定位到 IDE 根目录后，统一从 `tools\hvigor\bin\hvigorw.bat` 获取 `hvigorw`
4. `JAVA_HOME` 仅作为兜底，不应再在脚本或测试命令中写死本机绝对路径

测试、构建或子 agent 验证时，如果出现“找不到 `hvigorw`”或 `spawn java ENOENT`，默认先按以上顺序排查，不要直接假设系统全局 `PATH` 已配置，也不要在脚本或测试命令中写死本机绝对路径。

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

## 日志约定

- 主线业务代码统一通过 `entry/src/main/ets/utils/LogUtils.ets` 输出日志，不要在业务文件中直接引入或调用 `hilog`
- 每个文件只定义一个 `TAG`，`domain` 由 `LogUtils` 统一封装；不要再在业务文件里声明独立 `DOMAIN`
- 新增日志优先保留错误、告警和关键流程结论，避免重复的 start/success/info 噪音日志
- 如果后续需要对测试日志做统一封装，沿用同样思路，不要继续扩散裸 `hilog`

## 编码约定

- 含中文的代码、测试、文档文件必须按 UTF-8 处理；修改后必须回读验证，禁止提交乱码、`?`、`�`、异常转码文本
- 在 Windows / PowerShell 环境中，禁止使用默认编码不明确的批量文本链路改写含中文文件，例如裸 `Get-Content` / `Set-Content`、`Out-File`、重定向 `>` / `>>`、管道拼接整文件内容
- 需要批量修改含中文文件时，必须显式指定 UTF-8 读写，且先抽样校验再全量执行；如果链路不能证明编码安全，优先改用 `apply_patch` 或放弃批量改写

## 模块设计先行规则

后续涉及任一业务模块的功能新增、行为调整、状态流变更、页面交互变化、服务/仓储职责调整、模块级验收口径变化时，必须先更新对应 `docs/03-模块设计/*.md` 模块设计文档，再实施代码或测试改动。

### 适用模块与设计文档

| 模块/路由 | 模块名称 | 设计文档 |
|---|---|---|
| `dashboard` | 安全总览 | `docs/03-模块设计/安全总览组件设计说明.md` |
| `firewall` / `firewall-rules` | 防火墙管理 | `docs/03-模块设计/防火墙管理组件设计说明.md` |
| `log-manage` | 日志管理 | `docs/03-模块设计/日志管理组件设计说明.md` |
| `peripheral-manage` | 外设管理 | `docs/03-模块设计/外设管理组件设计说明.md` |
| `permission-manage` | 权限管理 | `docs/03-模块设计/权限管理组件设计说明.md` |
| `identity` | 身份鉴别 | `docs/03-模块设计/身份鉴别组件设计说明.md` |
| `tool-settings` | 工具设置 | `docs/03-模块设计/工具设置组件设计说明.md` |
| `help-feedback` | 帮助与反馈 | `docs/03-模块设计/帮助与反馈组件设计说明.md` |

### 必须先更新模块设计文档的场景

以下任一情况发生时，必须先更新对应模块设计文档：

1. 新增、删除或调整模块功能。
2. 修改页面布局、交互流程、弹窗、Toast、空态、错误态或加载态。
3. 修改页面路由、页面跳转、模块入口或导航行为。
4. 修改 ViewModel、Service、Repository、Provider、Adapter 等职责边界。
5. 修改系统能力调用、MDM 能力、权限、签名权限或企业管理员依赖。
6. 修改数据模型、持久化结构、缓存策略、状态字段或状态流转。
7. 修改错误码、错误处理、异常兜底或用户可见失败提示。
8. 修改模块级验收口径，包括新增/删除验收场景、调整手工测试/UT/ohosTest 的覆盖边界，或改变某个模块行为是否需要被测试覆盖的结论。
9. 修复会改变用户可见行为、模块业务规则或系统调用结果的缺陷。
10. 引入跨模块依赖、共享组件复用或公共工具行为变化，并影响某个模块的设计边界。

### 可不更新模块设计文档的场景

以下改动通常不需要更新模块设计文档，但最终说明中应简要说明“无需更新模块设计文档”的原因：

1. 纯格式化、空行、缩进、拼写修正。
2. 注释补充或日志文案调整，且不改变业务行为。
3. 测试文件重命名、测试描述修正、mock/fake 优化、测试代码重构或 flaky test 修复，且不改变模块级验收口径。
4. 构建脚本、CI、签名脚本、开发工具配置调整，且不影响模块行为。
5. 删除已确认过期的过程文档、草稿文档或历史计划文档。
6. 仅修复明显错别字、链接路径或目录索引，且不改变设计结论。
7. 依赖版本或工具链调整，但不影响模块功能、权限、状态流或验收口径。

### 模块设计文档更新要求

更新模块设计文档时，必须保持既有模板结构完整，不得只在文件末尾追加零散说明。根据改动影响范围，同步检查并更新以下内容：

1. 模块目标与范围。
2. 页面入口、路由、导航关系。
3. 页面结构、主要交互、弹窗、Toast、空态、错误态。
4. 状态模型、状态字段、状态流转。
5. 数据模型、持久化结构、缓存策略。
6. ViewModel / Service / Repository / Provider / Adapter 职责边界。
7. 系统能力调用、权限、MDM、企业管理员依赖。
8. 错误处理、异常兜底、降级策略。
9. 非目标范围和明确不做的行为。
10. 测试覆盖、手工验收点、UT/ohosTest 覆盖边界。
11. 与其他模块、公共组件或工具类的依赖关系。

### 执行顺序

模块级改动必须按以下顺序执行：

1. 先阅读对应模块设计文档。
2. 判断本次改动是否触发模块设计文档更新。
3. 如触发，先修改模块设计文档，并确保内容符合模板结构。
4. 再实施代码、测试或配置改动。
5. 修改后回读模块设计文档，确认 UTF-8 正常、无乱码、无 `�`、无异常 `?`。
6. 最终回复、提交说明或 PR 描述中必须说明：
   - 已更新的模块设计文档；或
   - 未更新模块设计文档的原因。

### 合入前自检要求

提交或推送前必须自检以下事项：

1. 如果模块行为、状态、交互、服务职责或模块级验收口径发生变化，确认已更新对应模块设计文档。
2. 如果没有更新模块设计文档，确认本次改动属于“可不更新模块设计文档的场景”，并在最终说明、提交说明或 PR 描述中写明原因。
3. 如果多个模块受影响，确认已分别更新对应模块设计文档。
4. 确认模块设计文档没有破坏既有模板结构。
5. 确认模块设计文档与代码、测试、验收说明一致。
6. 确认中文文档按 UTF-8 回读正常，无乱码、无 `�`、无异常 `?`。
7. 运行 `python scripts/check_docs_consistency.py`，确认路由、权限、测试路径、模块设计索引、AI 开发手册入口和乱码检查通过。

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
ohos.permission.PREPARE_APP_TERMINATE
ohos.permission.ENTERPRISE_MANAGE_NETWORK
ohos.permission.ENTERPRISE_MANAGE_USB
ohos.permission.ENTERPRISE_MANAGE_RESTRICTIONS
ohos.permission.ENTERPRISE_MANAGE_BLUETOOTH
ohos.permission.ACCESS_BLUETOOTH
ohos.permission.PERSISTENT_BLUETOOTH_PEERS_MAC
ohos.permission.ENTERPRISE_GET_DEVICE_INFO
ohos.permission.ENTERPRISE_MANAGE_WIFI
ohos.permission.ENTERPRISE_ADMIN_MANAGE
ohos.permission.ENTERPRISE_SUBSCRIBE_MANAGED_EVENT
ohos.permission.START_PROVISIONING_MESSAGE
ohos.permission.ENTERPRISE_MANAGE_SECURITY
ohos.permission.ENTERPRISE_SET_ACCOUNT_POLICY
ohos.permission.ENTERPRISE_MANAGE_APPLICATION
ohos.permission.ENTERPRISE_GET_ALL_BUNDLE_INFO
ohos.permission.ENTERPRISE_SET_BUNDLE_INSTALL_POLICY
ohos.permission.GET_BUNDLE_INFO
ohos.permission.ENTERPRISE_MANAGE_USER_GRANT_PERMISSION
ohos.permission.ACCESS_BIOMETRIC
ohos.permission.QUERY_AUDIT_EVENT
ohos.permission.GET_LOCAL_ACCOUNTS
ohos.permission.MANAGE_LOCAL_ACCOUNTS
ohos.permission.PRIVACY_WINDOW
```

新增权限时，需要同时在 `module.json5` 的 `requestPermissions` 和 `UnsgnedDebugProfileTemplate.json` 的 `acls.allowed-acls` + `permissions.restricted-permissions` 中添加。

## 页面路由

| 路由 ID | 页面 | 说明 |
|---------|------|------|
| `dashboard` | DashboardPage | 安全总览 |
| `firewall` | FirewallPage | 防火墙管理 |
| `firewall-rules` | FirewallRulesPage | 防火墙规则详情 |
| `log-manage` | LogManagePage | 日志管理（已完成） |
| `peripheral-manage` | PeripheralPage | 外设管理（已完成） |
| `permission-manage` | PermissionPage | 权限管理（首版只读骨架） |
| `identity` | IdentityPage | 身份鉴别（已完成） |
| `tool-settings` | ToolSettingsPage | 工具设置（已完成） |
| `help-feedback` | HelpFeedbackPage | 帮助与反馈 |

## 常见问题

1. **页面空白**：检查 `EntryAbility.ets` 中 `windowStage.loadContent` 的参数是否为 `'pages/MainPage'`。
2. **安装失败（签名错误）**：确认 `UnsgnedDebugProfileTemplate.json` 中 `bundle-name` 与 `app.json5` 中 `bundleName` 一致，并重新执行 p7b 生成 + 签名。
3. **权限不足**：确认权限同时声明在 `module.json5` 和签名模板的 `acls` + `permissions` 中。
4. **MDM 操作失败（错误码 9200001）**：表示应用未激活为企业管理员，执行 `edm enable-admin -n com.huawei.securitytool -a EnterpriseAdminAbility -t super` 后重试。
5. **构建路径错误**：MCP `build_app` 工具路径参数注意大小写，使用 `D:\project\ai\security_tool`。

---

## CI/CD 自动化流程

### GitHub Actions 工作流

项目已配置完整的 CI/CD 流水线，自动化流程如下：

#### 触发条件

| 事件 | 分支/标签 | 执行流程 |
|------|----------|---------|
| Push | `main` / `master` / `develop` / `codex/**` | 仓库检查 + 测试清单；启用自托管 Runner 时执行单元测试、构建和签名 |
| Tag | `v*` | 仓库检查 + 测试清单；启用自托管 Runner 时执行单元测试、构建和签名 |
| Pull Request | `main` / `master` | 仓库检查 + 测试清单；启用自托管 Runner 时执行单元测试 |

#### 工作流说明

**Job 1: Repository Checks** - 仓库基础检查
- 在 GitHub 托管 runner 上检出代码，准备 Node.js / Java
- 说明 GitHub 托管 runner 不提供 HarmonyOS SDK，真实构建测试由自托管 `windows,harmonyos` runner 执行

**Job 2: List Test Cases** - 测试清单
- 统计 `entry/src/test/**/*.test.ets`
- 生成并上传 `test-report.txt`，该 job 不执行 HarmonyOS 单元测试

**Job 3: Run entry@default Unit Tests** - 自托管单元测试
- 仅当仓库变量 `HARMONYOS_CI_ENABLED == 'true'` 且存在自托管 `windows,harmonyos` runner 时执行
- 按本文件前述 DevEco Studio / `hvigorw.bat` 查找规则解析工具链
- 执行 `hvigorw test --mode module -p product=default -p module=entry@default`
- 上传 `entry-default-unit-test-report`（保留 7 天）

**Job 4: Build entry@default HAP** - 自托管构建与签名
- 仅 Push 事件执行，且要求 `HARMONYOS_CI_ENABLED == 'true'`
- 使用自托管 runner 上的 DevEco Studio / SDK / ohpm / Java
- 构建 `entry-default-unsigned.hap`
- 将 unsigned HAP 同步到 `hapsigner/`，使用仓库内 `hapsigner` 工具链生成 `signApp.hap`
- 上传 Artifact `entry-default-hap`（保留 7 天）

当前 `.github/workflows/ci.yml` 没有启用 GitHub Release job，也没有从 GitHub Secrets 动态解码签名密钥；若后续改为 Secrets 签名或标签发布，必须同步更新本文档和 `.github/` 下相关说明。

#### Actions 变量

在 GitHub 仓库 Settings → Secrets and variables → Actions 中配置仓库变量：

| Variable 名称 | 值 | 说明 |
|------------|-----|------|
| `HARMONYOS_CI_ENABLED` | `true` | 启用自托管 HarmonyOS 单元测试、构建和签名 job |

#### 本地调试 CI

```bash
# 1. 使用 act 工具在本地运行 GitHub Actions
npm install -g @act-js/cli

# 2. 查看可运行 job
act -l

# 3. 运行托管 runner 上可执行的检查类 job
act -j checks
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
hvigorw assembleHap --mode module -p product=default -p module=entry && \
cp entry/build/default/outputs/default/entry-default-unsigned.hap hapsigner/ && \
cd hapsigner && .\2-debug-sign.bat && hdc install signApp.hap

# Linux/Mac
./hvigorw assembleHap --mode module -p product=default -p module=entry && \
cp entry/build/default/outputs/default/entry-default-unsigned.hap hapsigner/ && \
cd hapsigner && \
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
  -keystorePwd "123456" && \
hdc install signApp.hap
```

## 官方文档来源约定

- 以后查询 **OpenHarmony / HarmonyOS 官方文档** 时，默认优先使用：`https://gitee.com/openharmony/docs/tree/master`
- 默认以该仓库的 `master` 分支内容作为官方文档参考基线。
- 本规则**仅适用于官方文档检索**，不影响代码仓库、Issue、README、社区帖子、博客或其他第三方资料的查找。
- 如果用户在当前任务中明确指定了其他文档来源、其他分支或其他站点，则以用户指令为准。

*最后更新：2026-03-18 - 新增鸿蒙官方文档默认来源约定*

---

## Test Framework Baseline

```bash
# local unit tests
hvigorw test --mode module -p product=default -p module=entry@default

# compile ohosTest
hvigorw test --mode module -p product=default -p module=entry@ohosTest

# build the device-side test hap
hvigorw assembleHap --mode module -p product=default -p module=entry@ohosTest

# install both signed packages before aa test
hdc install hapsigner/signApp.hap
hdc install entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap

# default device smoke
hdc shell aa test -b com.huawei.securitytool -m entry -s unittest OpenHarmonyTestRunner -w 60000

# optional scenarios
hdc shell aa test -b com.huawei.securitytool -m entry -s unittest OpenHarmonyTestRunner -s mode route_action -w 60000
hdc shell aa test -b com.huawei.securitytool -m entry -s unittest OpenHarmonyTestRunner -s mode peripheral_contract -w 60000
hdc shell aa test -b com.huawei.securitytool -m entry -s unittest OpenHarmonyTestRunner -s mode theme_menu -w 60000
hdc shell aa test -b com.huawei.securitytool -m entry -s unittest OpenHarmonyTestRunner -s mode firewall_subroute -w 60000
```
