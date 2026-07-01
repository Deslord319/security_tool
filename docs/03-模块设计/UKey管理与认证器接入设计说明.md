---
module: "ukey-custom-auth"
title: "UKey 管理与认证器核心接入"
architecture: "Standalone System App + DDK Backend + CustomAuth Core"
status: "active"
last_updated: "2026-07-01"
version: "2.1.9"
---

# UKey 管理与认证器核心接入设计说明

## 0. 文档契约与状态 (Document Contract)

- **描述对象**:
  - [x] 当前已落地代码 (As-Is)
  - [x] 目标架构设计 (To-Be)
  - [x] 重构中过渡方案 (WIP)
- **维护规则**: 本文档描述 `ukey/` 独立系统应用内的 UKey 设备管理、DDK 接入、CustomAuth 核心执行逻辑和系统凭据注入/删除链路。修改 UKey 插拔策略、凭据生命周期、CustomAuth 协议接入、DDK 权限、系统应用签名或验收口径时，必须同步更新本文档。
- **一致性原则**: UKey 能力不再放在 SecurityTool 主应用内。SecurityTool 只保留身份鉴别口令策略和通用 PIN/指纹认证能力，不再声明 CustomAuthenticator appService，不再读取 UKey，不再保存 UKey 绑定或 UKEY解锁凭据。
- **裁剪原则**: `ukey/` 工程只承载生产需要的 UKey 管理和 CustomAuth 执行端能力，不迁入测试 HAP 页面、调试按钮、AppStorage fake UKey 切换、模拟换新和无关资源。

## 1. 业务概述与对外接口 (Overview & Public Interfaces)

- **核心目标**: `ukey/` 作为独立系统应用管理 UKey 插拔、首把绑定、系统 CustomAuth 凭据注入/删除和认证器执行端。该应用按系统应用签名，获得身份凭据管理、PIN token、CustomAuth appService 和 DDK 访问权限。
- **入口路由 (Route Entry)**: `ukey/entry/src/main/ets/pages/Index.ets`。页面只提供本应用内的 UKey 锁屏认证开关、UKey设备和 UKEY解锁凭据查询，不承载测试 HAP 的调试按钮、模拟换新或 fake UKey 切换。应用中文显示名统一为 `ukey解锁工具`。
- **对外暴露能力 (Public APIs)**:
  - `ICustomAuthenticatorV1` appService: 系统身份认证服务回调入口，`pluginInfo` 指向 `com.ukey.pin`。
  - `LockScreenCustomAuthEnrollmentService`: 当前承接 UKey 插入、首把绑定、UKEY解锁凭据注入、拔出删除和启动对账编排。
  - `DdkLockScreenUKeyDeviceService`: 当前默认 UKey 设备发现后端，基于 `@kit.DriverDevelopmentKit.deviceManager.queryDevices(BusType.USB)` 枚举 USB 设备，并用 `usbManager.getDevices()` 补充详情。
  - `OsAccountCustomAuthCredentialManager`: 对齐测试 HAP，按 `openSession -> PINAuth.registerInputer -> UserAuth.authUser(PIN, ATL2) -> addCredential/delCred -> closeSession` 添加或删除 CustomAuth 凭据。
  - `CustomAuthenticatorService`: 裁剪后的 CustomAuth IPC、密码学、SecurityAsset 和认证状态机核心。
  - `AuthenticatorUKeyProvider`: CustomAuth 执行端 UKey 判断入口，认证时只匹配首把绑定，第二把 UKey 不能 fallback 成功。
  - `StatusBarUtil` + `BackGroundAbility`: 将 `ukey解锁工具` 注册到状态栏托盘；点击托盘图标恢复主窗口，点击窗口 X 时隐藏窗口而不是退出后台运行时。应用整体关闭由 `EntryAbilityStage.onPrepareTermination()` 放行，不新增托盘菜单。
- **业务边界**:
  - ✅ **包含**: UKey 设备发现；首把 UKey 绑定；UKEY解锁凭据注入和删除；启动对账；CustomAuth appService；CustomAuth 核心协议、IPC、密码学和 SecurityAsset 存储；第二把 UKey 严格失败规则。
  - ❌ **不包含**: SecurityTool 页面开关；SecurityTool 外设流水线 consumer；SecurityTool 口令策略；SystemUI 锁屏页面改造；多把 UKey 管理界面；UKey 换新流程；测试 HAP 页面和调试状态。

主链路:

```text
ukey 系统应用启动或 USB attach / detach 事件
  -> UKey 设备发现
  -> 首把绑定/第二把拒绝
  -> 获取 PIN token
  -> UserIdentityManager.addCredential / delCred
  -> ICustomAuthenticatorV1 appService
  -> CustomAuth 核心保存/删除模板密钥和 UKey 模板绑定
```

系统锁屏链路由系统侧后续调度:

```text
SystemUI / UserAuth
  -> CustomAuth 系统服务
  -> com.ukey.pin / ICustomAuthenticatorV1
  -> AuthenticatorUKeyProvider 匹配当前 UKey
```

## 2. 状态与数据流 (Data Flow & State)

> **设计原则**: `ukey/` 应用自管 UKey 状态和系统凭据生命周期；SecurityTool 不参与该状态流。

- **核心业务状态 (Core Business State)**:
  - `ukeyUnlockEnabled: boolean`: UKey 认证管理是否启用，默认 `true`。该开关只在 `ukey/` 独立应用页面展示和持久化，不在 SecurityTool 展示。
  - `trustedBinding: LockScreenUKeyBinding | null`: 首把可信 UKey 绑定。绑定建立后保留，不因拔出而删除。
  - `activeCredential: LockScreenUKeyActiveCredential | null`: 当前系统侧已注入的 UKEY解锁凭据。UKey 拔出时删除该凭据，但保留首把绑定；代码内部沿用 `activeCredential` 命名，页面展示名统一为 `UKEY解锁凭据`。
  - `currentDevices: LockScreenUKeyDevice[]`: 页面实时识别到的候选 UKey，只用于管理页展示和诊断，不代表已经绑定成功。优先使用 DDK 查询结果；若 DDK 服务异常，页面允许使用 `usbManager.getDevices()` 兜底展示。用户可见文案统一为 `UKey设备`，不展示 DDK/USB 来源、fingerprint、deviceId 或弱标识类型。页面前台运行时周期刷新，避免 UKey 拔出后保留旧显示。
  - `templateBinding[templateId]: fingerprint`: CustomAuth 模板到首把 UKey fingerprint 的绑定。
  - `presenceState: absent / present / multiple / backend_error`: 最近一次 UKey 后端判断结果。
- **关键流转路径**:
  - 应用启动 -> `UKeyRuntimeManager.start()` -> 订阅 USB attach / detach common event -> 读取开关、首把绑定和 UKEY解锁凭据 -> 枚举当前 UKey -> 首把在场且无 UKEY解锁凭据时补注入；首把不在场且有 UKEY解锁凭据时删除 stale 凭据。
  - 应用启动 -> `EntryAbility.initStatusBar()` -> 注册状态栏图标 -> 启动隐藏的 `BackGroundAbility` 绑定托盘；窗口 X 关闭触发 `onPrepareToTerminate()`，调用 `hideAbility()` 并保持 UKey 运行时继续工作。
  - 状态栏图标左键点击 -> `EntryAbility.showAbility()` -> 恢复 `ukey解锁工具` 管理窗口。
  - 用户从 dock / system tray 执行应用关闭 -> 系统调用 `EntryAbilityStage.onPrepareTermination()` -> 返回 `TERMINATE_IMMEDIATELY`，真实退出应用。
  - 页面进入 -> 加载 `ukeyUnlockEnabled`、实时 `currentDevices`、`activeCredential` -> 展示开关、UKey设备、当前 UKEY解锁凭据和刷新入口。
  - 页面关闭开关 -> 保存 `ukeyUnlockEnabled=false` -> 主动删除当前 UKEY解锁凭据 -> 后续启动和 USB 插拔均不注册新凭据；页面重新加载 UKey设备和 UKEY解锁凭据状态。
  - 页面打开开关 -> 保存 `ukeyUnlockEnabled=true` -> 触发一次启动对账，若首把在场且 UKEY解锁凭据缺失则补注入。
  - USB attach -> `UKeyRuntimeManager` -> 读取开关 -> `LockScreenCustomAuthEnrollmentService.onUKeyAttached()` -> 无绑定时只接受唯一 UKey 并注册；已有绑定时只允许首把补注入。
  - USB detach -> `UKeyRuntimeManager` -> 读取开关 -> `LockScreenCustomAuthEnrollmentService.onUKeyDetached()` -> 首把不在场且存在 UKEY解锁凭据时删除系统凭据。
  - 首次发现唯一 UKey -> 生成 fingerprint -> 调用 `addCredential` -> 保存 `trustedBinding` 与 `activeCredential`。
  - 已有首把绑定且同一把在场 -> 若 UKEY解锁凭据缺失则补注入；若已存在 UKEY解锁凭据则不重复注册。
  - 已有首把绑定后发现第二把 -> 不调用 `addCredential`，不覆盖首把绑定。
  - 首把拔出 -> 若存在对应 UKEY解锁凭据，调用 `delCred` 删除系统凭据，成功后清空 `activeCredential`，保留 `trustedBinding`。
  - CustomAuth `endEnroll` -> 保存模板密钥并记录 `templateId -> fingerprint`。
  - CustomAuth `beginAuthenticate` -> 只选择当前首把 UKey 匹配的 templateId；无匹配直接失败。

## 3. 核心功能场景 (Core Functional Scenarios)

- **首把绑定**: 无绑定且当前只有一把候选 UKey 时建立首把绑定并注入 CustomAuth 凭据。
- **第二把拒绝**: 已有首把绑定后，后续其它 UKey 不注册、不替换、不参与认证成功路径。
- **拔出删除 UKEY解锁凭据**: 首把不在场时删除当前 UKEY解锁凭据，避免 UKey 不在场但系统仍保留可认证凭据。
- **启动对账**: 应用或设备重启后根据当前 UKey 在场状态收敛 UKEY解锁凭据。
- **系统应用权限闭环**: `ukey/` 必须按系统应用签名并获得 PIN token、User IDM、CustomAuth 和 DDK 权限；若安装后 `bm dump` 未显示系统应用级别，不视为验收通过。
- **本地管理页**: 页面只提供一个 `UKey 锁屏认证` 开关、`UKey设备` 查询，并以 `UKEY解锁凭据` 展示系统凭据注入状态。UKey设备来自实时设备枚举，识别到设备只显示设备名称和 Serial；不向用户展示 DDK/USB 来源、fingerprint、deviceId 或弱标识类型；未识别到设备时展示未识别状态。首把绑定仍由服务层维护，但不作为独立卡片展示。
- **托盘化运行**: `ukey解锁工具` 启动后进入系统状态栏；用户点击窗口 X 时只隐藏窗口，UKey 插拔监听和 CustomAuth appService 不因普通关闭动作退出。用户执行应用级关闭时允许真实退出。

## 4. 模块结构与组件设计 (Module Components)

### 【核心层】(Core Domain Layers)

- `ukey/entry/src/main/ets/models/identity/lockscreen-auth/LockScreenAuthModels.ets`
  - 保存 UKey 开关、设备、首把绑定、UKEY解锁凭据和 `pluginInfo` 模型；内部模型名仍为 `activeCredential`。
  - `pluginInfo` 的 `customAuthenticatorBundleName` 必须指向 `com.ukey.pin`。
- `ukey/entry/src/main/ets/services/identity/lockscreen-auth/LockScreenUKeyDeviceService.ets`
  - 负责 DDK USB 设备发现和 USB 详情增强。
- `ukey/entry/src/main/ets/services/identity/lockscreen-auth/LockScreenUKeyBindingRepository.ets`
  - 保存首把绑定、UKEY解锁凭据和模板绑定，不依赖 SecurityTool 数据。
- `ukey/entry/src/main/ets/services/identity/lockscreen-auth/LockScreenCustomAuthEnrollmentService.ets`
  - 负责编排添加/删除系统 CustomAuth 凭据。
- `ukey/entry/src/main/ets/services/identity/custom-auth-core/**`
  - 裁剪后的认证器核心协议、IPC、密码学和 SecurityAsset 存储。
- `ukey/entry/src/main/ets/extensionability/CustomAuthExtAbility.ets`
  - `ICustomAuthenticatorV1` appService 入口。
- `ukey/entry/src/main/ets/runtime/UKeyRuntimeManager.ets`
  - 独立运行时入口，应用启动后订阅 USB attach / detach common event，启动时执行一次对账，插入事件触发注册/补注入，拔出事件触发 UKEY解锁凭据删除。
- `ukey/entry/src/main/ets/entryability/EntryAbilityStage.ets`
  - AbilityStage 入口。实现 `onPrepareTermination()`，用于区分应用整体关闭和窗口 X 关闭；应用整体关闭返回 `TERMINATE_IMMEDIATELY`。
- `ukey/entry/src/main/ets/utils/StatusBarUtil.ets`
  - 负责加载托盘图标、注册状态栏条目，并用隐藏的 `BackGroundAbility` 持有状态栏生命周期。
- `ukey/entry/src/main/ets/backgroundability/BackGroundAbility.ets`
  - 状态栏生命周期辅助 Ability；当后台托盘能力被终止时发布内部事件，EntryAbility 收到后移除状态栏条目并退出。
- `ukey/entry/src/main/ets/pages/Index.ets`
  - UKey 本地管理页。页面读取 `PreferencesLockScreenAuthRepository`、`PreferencesLockScreenUKeyActiveCredentialRepository` 和实时 UKey 设备提供器，提供启用开关、刷新按钮、UKey设备和 UKEY解锁凭据状态。
  - 页面前台运行时定时刷新 UKey设备，`aboutToDisappear()` 停止刷新；UKey 拔出后 UKey设备区域应自动回到未识别状态。
  - 实时 UKey 展示优先使用 `DdkLockScreenUKeyDeviceService`；DDK 服务异常时使用 `UsbLockScreenUKeyDeviceService` 兜底展示，但页面不展示 DDK/USB 来源文案。
  - UI 结构沿用 SecurityTool 设置页规范，使用 `SectionCard`、`SectionToggleRow`、`SectionActionRow`、`AppColors` 和 `AppStyles`，不单独设计一套视觉语言。

## 5. 异常处理与系统依赖 (Dependencies & Errors)

- **关键系统 API**:
  - `@kit.DriverDevelopmentKit.deviceManager.queryDevices`
  - `@kit.BasicServicesKit.commonEventManager`
  - `@kit.BasicServicesKit.usbManager.getDevices`
  - `@ohos.account.osAccount.UserIdentityManager.openSession/addCredential/delCred/closeSession`
  - `@ohos.account.osAccount.UserAuth.authUser`
  - `@ohos.account.osAccount.PINAuth.registerInputer/unregisterInputer`
  - `@ohos.security.asset`
- **系统权限**:
  - `ohos.permission.PREPARE_APP_TERMINATE`
  - `ohos.permission.ACCESS_EXTENSIONAL_DEVICE_DRIVER`
  - `ohos.permission.MANAGE_USER_IDM`
  - `ohos.permission.USE_USER_IDM`
  - `ohos.permission.ACCESS_USER_AUTH_INTERNAL`
  - `ohos.permission.ACCESS_PIN_AUTH`
  - `ohos.permission.ACCESS_CUSTOM_AUTHENTICATOR`
- **签名要求**:
  - `ukey/` 应单独生成系统应用签名 HAP。
  - `app-distribution-type` 使用 `os_integration`，对齐系统应用定位；UKey 不是企业管理员/MDM 应用。系统能力由 `bundle-info.apl=system_core`、`app-feature=hos_system_app` 和系统集成分发类型共同承载。
  - 安装后 `bm dump -n com.ukey.pin` 应能看到系统应用权限/等级，至少要达到测试 HAP 调用 PIN token 和 User IDM 所需级别。
  - SecurityTool 主应用不再因为 UKey 能力额外申请 User IDM、PINAuth、CustomAuthenticator 或 DDK 权限。
- **异常兜底策略**:
  - DDK 枚举失败、无 UKey、多 UKey 时不注入凭据。
  - PIN token 获取失败或 `addCredential` 返回非 0 时不保存 UKEY解锁凭据。
  - 删除凭据失败时保留失败状态，后续对账重试。
  - 第二把 UKey 不替换首把绑定。
  - CustomAuth 无匹配 UKey 时直接失败，不顺序 fallback。

### 5.1 实施步骤与测试验收 (Implementation & Acceptance)

- **实施步骤**:
  1. 将 SecurityTool 中的 UKey 设备发现、绑定仓储、凭据管理和 CustomAuth 核心迁入 `ukey/`。
  2. 修改 `pluginInfo` 和 appService 包名为 `com.ukey.pin`。
  3. 给 `ukey/` 增加系统权限、`ICustomAuthenticatorV1` appService 和系统签名模板。
  4. 从 SecurityTool 移除 UKey 页面入口、运行时 consumer、CustomAuth appService、UKey 服务/模型/权限。
  5. 分别构建 SecurityTool 和 `ukey/`，确认 SecurityTool 不再出现 UKey systemapi warning，`ukey/` 作为系统应用承接相关 warning/权限。
- **测试覆盖**:
  - SecurityTool UT/构建: 身份鉴别页仍可配置口令策略，且不再引用 UKey 模块。
  - `ukey/` 构建: 编译通过，`UserAuth is system api` warning 只出现在 `ukey/`。
  - 设备手工: 安装 `ukey/` 系统签名 HAP 后，第一把 UKey 可注册，第二把不注册，拔出首把删除 UKEY解锁凭据。
- **验收口径**:
  - `security_tool/entry/src/main/ets` 下不再存在 `lockscreen-auth`、`custom-auth-core` 或 `CustomAuthExtAbility`。
  - SecurityTool `module.json5` 不再定义 `ACCESS_CUSTOM_AUTHENTICATOR`，不再声明 UKey 凭据链路权限。
  - `ukey/` `module.json5` 声明 `ICustomAuthenticatorV1` appService 和 UKey 所需权限。
  - `ukey/` `pluginInfo` 指向 `com.ukey.pin`。
  - `ukey/` 自己订阅 USB attach / detach，不依赖 SecurityTool 外设运行时事件管线。
  - `ukey/` 页面只有一个 UKey 锁屏认证开关、`UKey设备` 和 `UKEY解锁凭据` 状态；打开开关会触发一次对账，刷新按钮能展示当前 UKey设备与 UKEY解锁凭据。
  - `ukey/` 安装后显示名为 `ukey解锁工具`；状态栏出现托盘入口，左键点击可恢复窗口。
  - `ukey/` 声明并签入 `ohos.permission.PREPARE_APP_TERMINATE`；主窗口点击 X 后应用不退出，窗口隐藏，UKey 运行时仍保持订阅和对账能力。
  - `ukey/` 实现 `EntryAbilityStage.onPrepareTermination()`；应用级关闭能真实退出，不被窗口 X 关闭隐藏逻辑拦截。
  - SecurityTool 构建、文档一致性检查通过。

## 6. 变更日志 (Changelog)

| 版本 | 日期 | 修改人 | 核心设计变更内容 |
|---|---|---|---|
| 2.1.9 | 2026-07-01 | Codex | 管理页移除“当前绑定 Key”卡片；“当前识别 UKey”统一改为 `UKey设备`，用户可见文案不再展示 DDK/USB 来源。 |
| 2.1.8 | 2026-07-01 | Codex | 收敛管理页展示字段：不再展示 fingerprint、deviceId 和弱标识类型；页面前台周期刷新当前识别 UKey，避免拔出后保留旧数据。 |
| 2.1.7 | 2026-07-01 | Codex | 管理页新增“当前识别 UKey”展示：实时枚举候选 UKey，DDK 异常时允许 USB 兜底展示，避免未绑定或凭据注入失败时页面看不到已插入设备。 |
| 2.1.6 | 2026-07-01 | Codex | 调整管理页用户可见文案：原“活动凭据”统一展示为 `UKEY解锁凭据`，内部 `activeCredential` 数据模型保持不变。 |
| 2.1.5 | 2026-07-01 | Codex | 修正关闭区分实现：移除自定义托盘右键退出菜单，新增 `EntryAbilityStage.onPrepareTermination()` 放行应用整体关闭；窗口 X 仍由 `EntryAbility.onPrepareToTerminate()` 转为隐藏。 |
| 2.1.3 | 2026-07-01 | Codex | 为 `ukey/` 补充 `ohos.permission.PREPARE_APP_TERMINATE` 运行权限和签名 ACL，保证窗口 X 关闭前触发 `onPrepareToTerminate()` 并转为隐藏窗口。 |
| 2.1.2 | 2026-07-01 | Codex | `ukey/` 应用显示名统一为 `ukey解锁工具`；接入状态栏托盘，支持点击托盘恢复窗口、点击窗口 X 时隐藏而非退出。 |
| 2.1.1 | 2026-06-30 | Codex | 调整 `ukey/` 签名 profile 分发类型为 `os_integration`；UKey 作为系统认证器应用，系统等级由 `system_core`、`hos_system_app` 和系统集成分发类型共同保证。 |
| 2.1.0 | 2026-06-30 | Codex | 为 `ukey/` 独立系统应用增加本地管理页：提供 UKey 锁屏认证开关、当前绑定 Key 查询和 UKEY解锁凭据状态展示；开关只保存在 `ukey/` 本应用内，不回流 SecurityTool。 |
| 2.0.1 | 2026-06-30 | Codex | `ukey/` 运行时独立订阅 USB attach / detach：启动时对账，插入触发首把注册/补注入，拔出触发 UKEY解锁凭据删除，不再依赖 SecurityTool 外设事件管线。 |
| 2.0.0 | 2026-06-30 | Codex | UKey 能力从 SecurityTool 主应用迁出到 `ukey/` 独立系统应用；SecurityTool 不再承载 UKey 开关、DDK、凭据注入、CustomAuth appService 或 UKey 持久化状态。 |
| 1.0.15 | 2026-06-30 | Codex | 接入 `osAccount.UserIdentityManager` 凭据注册/删除执行链路：注册和删除均先通过 `PINAuth` + `UserAuth.authUser(PIN, ATL2)` 获取 PIN token，再调用 `addCredential/delCred`，当前联调 PIN 沿用测试 HAP 默认 `111111`。 |
