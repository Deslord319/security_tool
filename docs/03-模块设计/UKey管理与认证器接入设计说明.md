---
module: "ukey-custom-auth"
title: "UKey 管理与认证器核心接入"
architecture: "Standalone System App + DDK Backend + CustomAuth Core"
status: "active"
last_updated: "2026-07-14"
version: "2.2.34"
---

# UKey 管理与认证器核心接入设计说明

## 0. 文档契约与状态 (Document Contract)

- **描述对象**:
  - [x] 当前已落地代码 (As-Is)
  - [x] 目标架构设计 (To-Be)
  - [x] 重构中过渡方案 (WIP)
- **维护规则**: 本文档描述 `ukey/` 独立系统应用内的 UKey 设备管理、DDK 接入、CustomAuth 核心执行逻辑和系统凭据注入/删除链路。修改 UKey 插拔策略、凭据生命周期、CustomAuth 协议接入、DDK 权限、系统应用签名或验收口径时，必须同步更新本文档。面向测试执行的规格、用例和结果判定统一维护在 `docs/04-测试文档/手工测试用例/UKey解锁工具规格与测试说明.md`；两份文档冲突时，先以本文档和当前生产代码核准设计结论，再同步修正测试说明。
- **一致性原则**: UKey 能力不再放在 SecurityTool 主应用内。SecurityTool 只保留身份鉴别口令策略和通用 PIN/指纹认证能力，不再声明 CustomAuthenticator appService，不再读取 UKey，不再保存 UKey 绑定或 UKEY解锁凭据。
- **裁剪原则**: `ukey/` 工程只承载生产需要的 UKey 管理和 CustomAuth 执行端能力，不迁入测试 HAP 页面、调试按钮、AppStorage fake UKey 切换、模拟换新和无关资源。

## 1. 业务概述与对外接口 (Overview & Public Interfaces)

- **核心目标**: `ukey/` 作为独立系统应用管理 UKey 插拔、首把绑定、系统 CustomAuth 凭据注入/删除和认证器执行端。该应用按系统应用签名，获得身份凭据管理、PIN token、CustomAuth appService 和 DDK 访问权限；添加凭据必须由用户在管理页输入系统 PIN 和 UKey 密码后触发，不允许 USB attach 或启动对账在后台使用固定 PIN 自动改写系统凭据。
- **入口路由 (Route Entry)**: `ukey/entry/src/main/ets/pages/Index.ets`。页面提供本应用内的 UKey 锁屏认证开关、UKey设备、UKEY解锁凭据查询、凭据添加/删除和凭据认证验证，不承载测试 HAP 的调试按钮、模拟换新或 fake UKey 切换。应用中文显示名统一为 `ukey解锁工具`，首页标题左侧展示应用启动图标作为视觉识别。页面固定使用应用内浅色调色板，不跟随系统深色模式动态切换。
- **对外暴露能力 (Public APIs)**:
  - `ICustomAuthenticatorV1` appService: 系统身份认证服务回调入口，`pluginInfo` 指向 `com.ukey.pin`。
  - `LockScreenCustomAuthEnrollmentService`: 当前承接首把绑定、UKEY解锁凭据注入/删除和启动/插拔对账编排。凭据注入必须携带用户输入的系统 PIN 和 UKey 密码；凭据删除必须携带用户输入的系统 PIN。
  - `DdkLockScreenUKeyDeviceService`: 当前默认 UKey 设备发现后端，基于 `@kit.DriverDevelopmentKit.deviceManager.queryDevices(BusType.USB)` 枚举 USB 设备，并用 `usbManager.getDevices()` 补充详情。设备 fingerprint 优先使用 SN 稳定标识（`SN:SERIAL`），只比较 SN，不带 VID/PID 前缀；当 serial 为空时生成弱指纹（`VID:xxxx PID:xxxx|WEAK:PRODUCTNAME|DESCRIPTION`），弱指纹只用于精确字符串比较，不做同 VID/PID 放行。候选过滤必须排除 USB Hub、HID Boot 键盘/鼠标以及名称明确为键盘/鼠标/触控板的普通输入外设，避免键鼠被当作 UKey 阻塞凭据注入。
  - `PreferencesLockScreenUKeyBindingRepository`: 首次凭据添加成功后持久化可信 UKey 绑定。已存在绑定的 `fingerprint`、`deviceId`、`deviceName`、`boundAt` 和 `stableIdentifier` 视为不可变身份；后续只允许更新其 `userCredentials`。凭据删除、认证失败、锁定、插拔、启动对账和重新添加凭据均不得删除、替换或降级首次绑定，只有卸载或显式清除应用数据可重置绑定。Repository 必须拒绝以不同 fingerprint 覆盖已有绑定，业务层重建绑定记录时也必须沿用既有身份字段。
  - `OsAccountCustomAuthCredentialManager`: 对齐测试 HAP，按 `UserIdentityManager.getAuthInfo(CUSTOM_AUTH=128)` 查询系统 CustomAuth 凭据、credentialId 和 templateId，templateId 的 8 字节原始值按 little-endian 解码为十进制字符串；当该查询返回 `12300002 Parameter invalid` 且用于列出现有 CUSTOM_AUTH 凭据时，按当前没有 CUSTOM_AUTH 凭据处理为空列表，不阻断添加或对账。按 `openSession -> PINAuth.registerInputer -> UserAuth.authUser(PIN, ATL3) -> addCredential/delCred -> closeSession` 添加或删除 CustomAuth 凭据。添加凭据前若系统侧已有 CUSTOM_AUTH 凭据，先按本地当前 `trustedBinding.fingerprint + activeCredential.userCredentials[].credentialIdHex/templateId` 判断是否属于当前目标 UKey；属于自己的恢复为 active，不属于当前目标 UKey 的使用本次输入的系统 PIN 静默删除。
  - `OsAccountUKeyUserProvider`: 通过 `osAccount.getAccountManager().getOsAccountLocalIds()` 枚举本机所有 OS 账户 ID，供 UKEY解锁凭据注册和补注入使用。
  - `OsAccountCustomAuthCredentialVerifier`: 页面凭据认证验证入口。验证前由页面传入 UKey 密码，验证器临时注册 `companionDeviceAuth.registerPasscodePromptCallback`，在系统 CustomAuth prompt 触发时提交该 UKey 密码，再对当前已保存的 UKEY解锁凭据逐用户调用 `UserAuth.authUser(userId, challenge, CUSTOM(128), ATL3)`，验证系统能否通过 `com.ukey.pin` CustomAuth 认证器返回认证 token；验证结束后必须注销 passcode prompt 回调。该能力不调用 `addCredential`，不新增、覆盖或删除凭据。
  - `CustomAuthenticatorService`: 裁剪后的 CustomAuth IPC、密码学、SecurityAsset 和认证状态机核心。
  - `AuthenticatorUKeyProvider`: CustomAuth 执行端 UKey 判断入口，认证时只匹配首把绑定，第二把 UKey 不能 fallback 成功；同时维护 UKey 密码错误次数和锁定状态，解锁认证必须先通过系统 `onPrompt` 回调输入 UKey 密码。执行端先确认当前在位 UKey 指纹等于首把绑定指纹，再使用该指纹下保存的 `activeCredential.userCredentials[].credentialIdHex/templateId` pair 约束候选模板，最后只从 SecurityAsset 当前持有模板候选里选择命中的 templateId。若当前只有其它 UKey 在位，指纹不匹配时不得继续凭据 ID 匹配；该设计不得重新引入独立 `templateBinding` 或在目标 UKey 缺席时重建模板归属。
  - `StatusBarUtil` + `BackGroundAbility`: 将 `ukey解锁工具` 注册到状态栏托盘；点击托盘图标恢复主窗口，点击窗口 X 时隐藏窗口而不是退出后台运行时。应用整体关闭由 `EntryAbilityStage.onPrepareTermination()` 放行，不新增托盘菜单。
- **业务边界**:
  - ✅ **包含**: UKey 设备发现；首把 UKey 绑定；UKEY解锁凭据注入和删除；启动对账；CustomAuth appService；CustomAuth 核心协议、IPC、密码学和 SecurityAsset 存储；UKey 密码校验与 5 次锁定；第二把 UKey 严格失败规则。
  - ❌ **不包含**: SecurityTool 页面开关；SecurityTool 外设流水线 consumer；SecurityTool 口令策略；SystemUI 锁屏页面改造；多把 UKey 管理界面；UKey 换新流程；测试 HAP 页面和调试状态。

- **可信绑定不变量**:
  - 首次成功添加系统 CustomAuth 凭据时写入唯一可信绑定；仅检测到设备、输入密码失败或凭据下发失败不得建立绑定。
  - 已有可信绑定时，所有保存路径必须保留原 fingerprint 和设备身份字段，只能增删或更新凭据列表。
  - 删除 UKEY 解锁凭据后保留空 `userCredentials` 的可信绑定，不提供应用内换绑、解绑或自动覆盖入口。
  - Preferences 读取失败不得解释为允许换绑；即使上层错误地提交不同 fingerprint，Repository 仍必须拒绝覆盖。

- **启动识别兜底**:
  - 机器重启后的首次启动对账必须考虑 USB/DDK 和 USB 详情中的 SN 尚未就绪；第一次未枚举到可信绑定不得立即将凭据降为 inactive。
  - 启动对账按 0.5 秒间隔最多执行 3 次设备查询，任一次精确匹配可信 fingerprint 即保持或恢复 active；仅连续 3 次查询成功但均未匹配时才写入 inactive。
  - 查询接口异常时保留原凭据生命周期并返回读取失败，不把基础设施暂时异常解释为 UKey 已拔出。
  - 明确收到 USB detach 事件时继续沿用实时处理，不套用启动重试窗口。

主链路:

```text
ukey 系统应用启动或 USB attach / detach 事件
  -> UKey 设备发现
  -> 首把在位/第二把拒绝/状态对账

管理页添加或删除凭据
  -> 用户输入系统 PIN
  -> 添加时额外校验 UKey 密码和目标 UKey 在位
  -> 查询系统侧已有 CUSTOM_AUTH 凭据
  -> 自己的恢复为 active，不是当前目标 UKey 的静默删除
  -> 获取 PIN token
  -> UserIdentityManager.addCredential / delCred
  -> ICustomAuthenticatorV1 appService
  -> CustomAuth 核心保存/删除模板密钥
```

系统锁屏链路由系统侧后续调度:

```text
SystemUI / UserAuth
  -> CustomAuth 系统服务
  -> com.ukey.pin / ICustomAuthenticatorV1
  -> AuthenticatorUKeyProvider 匹配当前 UKey
  -> onPrompt 输入 UKey 密码
  -> 目标 UKey 仍在位后返回 onAuthResult
```

## 2. 状态与数据流 (Data Flow & State)

> **设计原则**: `ukey/` 应用自管 UKey 状态和系统凭据生命周期；SecurityTool 不参与该状态流。

- **核心业务状态 (Core Business State)**:
  - `ukeyUnlockEnabled: boolean`: UKey 认证管理是否启用，默认 `true`。该开关只在 `ukey/` 独立应用页面展示和持久化，不在 SecurityTool 展示。
  - `trustedBinding: LockScreenUKeyBinding | null`: 首把可信 UKey 绑定。绑定建立后保留，不因拔出而删除。用户输入系统 PIN 删除 UKEY解锁凭据后仍保留 `fingerprint/deviceId/deviceName/boundAt`，但必须清空 `userCredentials`，不得残留已删除的 credentialId/templateId。
  - `activeCredential: LockScreenUKeyActiveCredential | null`: 当前系统侧已注入的 UKEY解锁凭据集合。每个 OS 账户各保存一条 CustomAuth 凭据记录；用户输入系统 PIN 删除凭据时逐个删除这些记录，但保留首把绑定。代码内部沿用 `activeCredential` 命名，页面展示名统一为 `UKEY解锁凭据`。本地状态必须包含 `userCredentials`，不做旧单用户状态兼容；缺失该字段视为无有效 active 凭据。USB 拔出、页面自动同步或插拔对账读不到匹配的系统凭据时不得清空该状态，只有用户输入系统 PIN 删除凭据或添加凭据流程重建当前目标 UKey 凭据时才允许清理。目标 UKey 在位时状态为 `active`；目标 UKey 拔出但凭据仍保留时状态为 `inactive`，页面继续展示凭据但禁用认证验证。
  - `fingerprintCredentialBinding`: UKey 解锁归属关系只由 `trustedBinding.fingerprint` 与 `activeCredential.userCredentials[].credentialIdHex/templateId` 共同表达，等价于 `fingerprint -> [credentialId, templateId]`。credentialId 是系统凭据归属锚点，templateId 是同一条凭据记录的 CustomAuth 执行匹配字段；代码不再维护 CustomAuth 模板到 UKey 指纹的独立 `templateBinding`，也不得在目标 UKey 缺席时用当前插入的其它 UKey 重建归属。新写入的本地用户凭据必须同时包含非空 credentialId 和 templateId；删除凭据后该映射为空，但首把 UKey 指纹仍保留。
  - `credentialAuthVerificationState`: 页面凭据认证验证状态只通过按钮触发，结果回写到页面“当前状态”行。该状态只验证已存在凭据对应的认证能力，不触发凭据下发，不在凭据认证验证卡片内展示 provider、CustomAuth 类型、认证信任等级、challenge、token 长度或逐用户明细。
  - `currentDevices: LockScreenUKeyDevice[]`: 页面实时识别到的候选 UKey，只用于管理页展示和诊断，不代表已经绑定成功。优先使用 DDK 查询结果；若 DDK 服务异常，页面允许使用 `usbManager.getDevices()` 兜底展示。候选设备优先使用 SN 生成稳定指纹（`SN:SERIAL`），只比较 SN；当 serial 为空时生成弱指纹（`VID:xxxx PID:xxxx|WEAK:PRODUCTNAME|DESCRIPTION`），绑定匹配只做精确指纹字符串比较，不做同 VID/PID 放行。DDK `deviceId` 与 `usbManager.USBDevice.deviceId` 属于不同层的 ID 空间，不得用于互相精确匹配；DDK 条目补充 USB 详情时仅在 VID/PID 唯一时允许使用 `usbManager` 详情，多把同 VID/PID 设备在场时不得复用任意一条 USB detail 的 serial/fingerprint，最多只合并所有匹配项一致的 class/name 等非身份属性用于过滤，指纹必须退回 DDK 描述生成弱指纹。候选集合不包含键盘、鼠标、触控板和 USB Hub 等普通外设。用户可见文案统一为 `UKey设备`，不展示 DDK/USB 来源、fingerprint、deviceId 或弱标识类型。页面前台不轮询，也不提供手动刷新按钮；本机 SDK 的 DDK `deviceManager` 仅提供 `queryDevices` 和绑定后的断开回调，不提供插入回调，因此页面进入、开关打开、凭据操作结果和 USB 插拔事件触发 DDK 重新查询，USB attach 后按短延迟窗口复查，避免插入事件早于 DDK 设备枚举完成；延迟刷新必须保存 timer handle 并在页面销毁时取消。
  - `ukeyPasswordState[fingerprint]`: UKey 密码错误次数和锁定状态。当前阶段 UKey 密码使用固定值实现，但所有添加凭据和解锁认证都必须走同一校验入口；连续错误 5 次后该 fingerprint 进入 locked，添加凭据和解锁认证均返回锁定/失败，不允许继续尝试。
  - `presenceState: absent / present / multiple / backend_error`: 最近一次 UKey 后端判断结果。
  - `customAuthKeyMaterial`: 每个 CustomAuth 模板在 SecurityAsset 中保存 `sharedKey(32B) || authenticatorSecret(32B) || authenticatorSecretSeq(4B LE)`，总长 68B。`authenticatorSecretSeq` 为 u32，录入初值为 `1`，每次轮换从磁盘最新值自增后与新 `authenticatorSecret` 在同一次 `asset.updateSync` 中提交。
  - `legacyCustomAuthKeyMaterial`: 兼容旧版本 72B 记录 `sharedKey(32B) || authenticatorSecret(32B) || seq(8B BE)`。首次读取旧记录且 seq 不超过 u32 上限时，原子改写为 68B 新格式；seq 超出 u32 或记录长度异常时按损坏记录处理，不参与认证成功路径。
- **关键流转路径**:
  - 应用启动 -> `UKeyRuntimeManager.start()` -> 订阅 USB attach / detach common event -> 读取开关、首把绑定和 UKEY解锁凭据 -> 枚举当前 UKey -> 只做状态对账和日志收敛，不在缺少用户输入的后台链路中添加或删除系统凭据。USB common event 订阅创建和 `subscribe` 同步异常必须被捕获并返回明确失败，不允许 `start()` Promise 永久悬挂；订阅失败时必须记录启动降级日志，不能当作订阅成功处理。
  - 应用启动 -> `EntryAbility.initStatusBar()` -> 注册状态栏图标 -> 启动隐藏的 `BackGroundAbility` 绑定托盘；窗口 X 关闭触发 `onPrepareToTerminate()`，调用 `hideAbility()` 并保持 UKey 运行时继续工作。
  - 状态栏图标左键点击 -> `EntryAbility.showAbility()` -> 恢复 `ukey解锁工具` 管理窗口。
  - 用户从 dock / system tray 执行应用关闭 -> 系统调用 `EntryAbilityStage.onPrepareTermination()` -> 返回 `TERMINATE_IMMEDIATELY`，真实退出应用。
  - 页面进入 -> 加载 `ukeyUnlockEnabled`、实时 `currentDevices`、`activeCredential` -> 展示开关、UKey设备、凭据操作、当前 UKEY解锁凭据主 ID、创建时间和状态；没有 active UKEY解锁凭据、仅存在 failed 残留或未识别到 UKey 时对应卡片内容为空白，不额外展示提示文案。
  - 页面进入或自动状态同步 -> 若已有 `trustedBinding`，服务读取系统侧 CUSTOM_AUTH 凭据及 `credentialId/templateId` -> 用本地当前 `trustedBinding.fingerprint + activeCredential.userCredentials[].credentialIdHex/templateId` 与系统 credentialId 对账；匹配本地当前凭据 ID 的系统凭据用系统侧 templateId 刷新本地 pair，并根据目标 UKey 在位状态保存为 active 或 inactive；若本地已有凭据但本次系统查询暂时无匹配，则保留本地凭据，并按目标 UKey 是否在位更新 active/inactive；没有 `trustedBinding` 时不允许仅凭当前插入的一把 UKey 和系统残留 CUSTOM_AUTH 凭据建立绑定，若本地仍有 activeCredential 残留则压成 inactive，仅允许用户输入系统 PIN 删除。页面处于添加/删除凭据提交态、页面已销毁或已有刷新进行中时，USB 延迟刷新不得触发新的对账。
  - 页面点击添加凭据 -> 用户输入系统 PIN 和 UKey 密码，添加按钮仅在目标 UKey 可操作且两个输入均非空时可点 -> 服务确认当前目标 UKey 在位且未锁定；若已存在首把绑定但该 UKey 不在位，直接失败，不用当前插入的其它 UKey 重新绑定 -> UKey 密码正确后枚举所有 OS 账户 -> 通过 `getAuthInfo(CUSTOM_AUTH=128)` 查询系统侧已有 CUSTOM_AUTH 凭据；若系统返回 `12300002 Parameter invalid`，按该用户当前没有 CUSTOM_AUTH 凭据继续；credentialId 命中本地当前目标 UKey 凭据的记录用系统侧 templateId 刷新后恢复为 active 并复用，归属判断同时读取 `trustedBinding.userCredentials` 与 `activeCredential.userCredentials`，其它记录使用本次系统 PIN 静默 `delCred` 删除 -> 对缺失用户逐个获取 PIN token 并调用 `addCredential`，添加成功后必须解析到对应 templateId 才写入本地凭据 -> 保存 `trustedBinding` 与包含多用户凭据记录的 `activeCredential`。添加流程结束后页面必须清空凭据操作区的系统 PIN 和 UKey 密码输入框。
  - 页面点击删除凭据 -> 用户输入系统 PIN，删除按钮仅在存在可见 UKEY解锁凭据且系统 PIN 非空时可点 -> 按本地 `activeCredential.userCredentials` 对每个用户获取 PIN token 并调用 `delCred` -> 全部成功后清空 `activeCredential`，并同步清空 `trustedBinding.userCredentials`，只保留首把 UKey 绑定指纹和 UKey 密码锁定状态。删除仍不要求 UKey 密码、凭据 active、UKey 在位或认证开关打开。删除流程结束后页面必须清空凭据操作区输入框。
  - 页面点击凭据认证验证按钮 -> 要求用户先在 `凭据认证验证` 卡片内的 UKey 密码输入框输入密码 -> 读取当前已保存的 `activeCredential.userCredentials` -> 为每个用户生成 challenge -> 验证器注册一次 passcode prompt 回调并调用 `UserAuth.authUser(userId, challenge, CUSTOM(128), ATL3)` -> 系统进入 `ICustomAuthenticatorV1.beginAuthenticate` -> `AuthenticatorUKeyProvider` 先匹配首把 UKey 指纹，再用该指纹下同一用户的 credentialId/templateId pair 约束候选 templateId -> 系统通过 prompt 要求 UKey 密码 -> 回调用验证卡片输入的 UKey 密码提交 -> 页面“当前状态”行展示认证成功/失败结论和成功用户数；失败时展示失败用户数或错误信息。
  - 页面关闭开关 -> 保存 `ukeyUnlockEnabled=false` -> CustomAuth 执行端后续认证直接失败；已存在的 UKEY解锁凭据不会在缺少系统 PIN 的情况下被后台删除，用户需要通过删除凭据按钮清理。
  - 页面打开开关 -> 保存 `ukeyUnlockEnabled=true` -> 触发一次启动对账，仅同步 UKey 在位和凭据状态，不自动补注入。
  - USB attach -> `UKeyRuntimeManager` -> 短延迟后读取开关 -> `LockScreenCustomAuthEnrollmentService.onUKeyAttached()` -> 只确认唯一/首把在位状态；不调用 `addCredential`。延迟仅用于等待 DDK `queryDevices` 枚举结果稳定，不作为周期轮询。
  - USB detach -> `UKeyRuntimeManager` -> 短延迟后读取开关 -> `LockScreenCustomAuthEnrollmentService.onUKeyDetached()` -> 只确认首把是否仍在位；不调用 `delCred`，不清空本地凭据，若目标 UKey 不在位则把本地凭据状态改为 inactive。系统中保留的凭据在认证执行端仍必须满足目标 UKey 在位和 UKey 密码正确，不能因拔出后留存凭据而认证成功。
  - 首次发现唯一 UKey -> 仅作为添加凭据按钮的候选；只有系统 PIN 和 UKey 密码均校验成功时才建立首把绑定并下发凭据。
  - 已有首把绑定且同一把在场 -> 添加凭据按钮可补齐缺失 OS 账户；若所有当前用户均已有 active 凭据则不重复注册。
  - 已有首把绑定后发现第二把 -> 不调用 `addCredential`，不覆盖首把绑定。
  - CustomAuth `endEnroll` -> 内层 AEAD JSON 使用十进制字符串 `template_id` 与明文参数对账；只保存 68B 模板密钥。
  - 首把拔出 -> 不后台删除系统凭据，不清空本地凭据；本地凭据状态改为 inactive，后续认证在 `beginAuthenticate` 或 `submitPasscode` 中因目标 UKey 不在位失败，删除凭据必须由用户在管理页输入系统 PIN 后触发。首把重新插入并被 DDK 识别后状态恢复 active。
  - CustomAuth `beginAuthenticate` -> 使用当前 userId 下本地保存的 credentialId/templateId pair，只选择该 templateId 命中的 SecurityAsset 候选；同时输出系统 `getAuthInfo` 的 credentialId/templateId 对账日志，发现 templateId 不一致只记录差异，不用系统值覆盖当次认证候选。无匹配、开关关闭或 UKey 已锁定直接失败/锁定。
  - CustomAuth `submitPasscode` -> 拒绝空 passcode；RSA 解密得到 UKey 密码后校验目标 UKey 未锁定且在位；密码错误累加失败次数，达到 5 次返回 `LOCKED`；密码正确后清空失败次数，并在 `finishAuth` 前再次按本地 credentialId/templateId pair 确认同一目标 UKey 仍在位。
  - CustomAuth `finishAuth` -> `onAuthResult` 内层 AEAD JSON 以原始 JSON number 返回 u32 `auth_secret_seq`，不再使用 base64(8B BE) 编码；认证过程中若连接断开或 Ability 销毁，清理所有未完成会话和内存 key buffer。

## 3. 核心功能场景 (Core Functional Scenarios)

- **首把绑定**: 无绑定且当前只有一把候选 UKey 时，用户在管理页输入系统 PIN 和 UKey 密码后建立首把绑定，并为枚举到的所有 OS 账户注入 CustomAuth 凭据。键盘、鼠标、触控板和 USB Hub 不进入候选集合，不能导致“多把 UKey”拒绝注册。
- **残留凭据处理**: 添加凭据不再因为本地存在 failed/active 残留而提示用户先删除。服务层会先按当前 OS 账户集合调用 `getAuthInfo(CUSTOM_AUTH=128)` 查询系统凭据；若系统返回 `12300002 Parameter invalid`，按空 CUSTOM_AUTH 凭据集合处理并继续注册；credentialId 命中本地当前目标 UKey 凭据集合的视为自己的凭据，并使用系统侧 templateId 刷新本地 pair 后恢复为 active，不匹配的视为非当前目标 UKey 凭据并用本次输入的系统 PIN 静默删除；随后只补注册缺失用户。
- **第二把拒绝**: 已有首把绑定后，后续其它 UKey 不注册、不替换、不参与认证成功路径，也不能在绑定 UKey 不在位时通过添加凭据流程自动重绑。
- **UKey 密码与锁定**: 添加凭据和解锁认证均要求目标 UKey 在位并校验 UKey 密码；当前阶段 UKey 密码固定实现，连续错误 5 次后锁定该 UKey fingerprint，锁定后不允许继续添加凭据或解锁认证。
- **凭据删除**: 删除 UKEY解锁凭据只需要系统 PIN，不需要 UKey 密码，也不要求目标 UKey 在位；删除成功只清空 active 凭据，保留首把绑定。
- **凭据操作输入态**: 添加凭据按钮必须等待系统 PIN 与 UKey 密码均非空后启用；删除凭据按钮必须等待存在可见凭据且系统 PIN 非空后启用。凭据操作结束后页面清理对应输入框，避免敏感输入残留在可见控件中。
- **启动对账**: 应用或设备重启后根据当前 UKey 在场状态收敛展示和运行态，不在后台自动添加或删除系统凭据。
- **系统应用权限闭环**: `ukey/` 必须按系统应用签名并获得 PIN token、User IDM、CustomAuth 和 DDK 权限；若安装后 `bm dump` 未显示系统应用级别，不视为验收通过。
- **本地管理页**: 页面提供一个 `UKey 锁屏认证` 开关、凭据操作区、凭据认证验证按钮卡片、`UKey设备` 查询，并以 `UKEY解锁凭据` 展示主凭据 ID、创建时间和状态；没有 active UKEY解锁凭据、仅存在 failed 残留或未识别到 UKey 时内容为空白。UKey设备来自实时设备枚举，识别到设备只显示设备名称和 Serial；不向用户展示 DDK/USB 来源、fingerprint、deviceId 或弱标识类型。首把绑定仍由服务层维护，但不作为独立卡片展示。凭据认证验证卡片只展示一个验证按钮，只调用 `authUser(CUSTOM)` 验证已存在凭据的认证能力，不执行凭据下发。
- **托盘化运行**: `ukey解锁工具` 启动后进入系统状态栏；用户点击窗口 X 时只隐藏窗口，UKey 插拔监听和 CustomAuth appService 不因普通关闭动作退出。用户执行应用级关闭时允许真实退出。
- **CustomAuth 协议兼容**: 当前 CustomAuth 核心对齐新系统侧协议：`template_id` 为十进制字符串，`auth_secret_seq` 为 u32 JSON number，SecurityAsset 新记录为 68B；历史 72B 记录仅在读取时做一次性迁移，不新增用户可见迁移入口。

## 4. 模块结构与组件设计 (Module Components)

### 【核心层】(Core Domain Layers)

- `ukey/entry/src/main/ets/models/identity/lockscreen-auth/LockScreenAuthModels.ets`
  - 保存 UKey 开关、设备、首把绑定、按用户记录的 UKEY解锁凭据集合、UKey 密码锁定状态和 `pluginInfo` 模型；内部模型名仍为 `activeCredential`，`userCredentials` 为必需字段，不兼容旧单用户状态。
  - `pluginInfo` 的 `customAuthenticatorBundleName` 必须指向 `com.ukey.pin`。
- `ukey/entry/src/main/ets/services/identity/lockscreen-auth/LockScreenUKeyDeviceService.ets`
  - 负责 DDK USB 设备发现、USB 详情增强和候选 UKey 过滤；过滤规则排除 Hub、HID Boot 键盘/鼠标和名称明确匹配普通键鼠输入外设的设备。
- `ukey/entry/src/main/ets/services/identity/lockscreen-auth/LockScreenUKeyBindingRepository.ets`
  - 保存首把绑定和 UKEY解锁凭据，不依赖 SecurityTool 数据。
- `ukey/entry/src/main/ets/services/identity/lockscreen-auth/LockScreenCustomAuthEnrollmentService.ets`
  - 负责编排添加/删除系统 CustomAuth 凭据。
  - 添加凭据由管理页传入系统 PIN 和 UKey 密码；系统 PIN 由 `PINAuth.registerInputer` 注入以换取 PIN token，UKey 密码由 `AuthenticatorUKeyProvider` 校验并累计错误次数。
  - 添加凭据前按当前 OS 账户集合读取系统侧已有 CUSTOM_AUTH 凭据，复用 credentialId 命中本地当前目标 UKey 凭据集合的记录，并用系统侧 templateId 刷新本地 pair；归属判断同时读取 `trustedBinding` 和 `activeCredential`，删除旧 failed 凭据、测试 HAP 凭据或非当前目标 UKey 凭据。
  - 删除凭据由管理页传入系统 PIN；不要求 UKey 密码或 UKey 在位。凭据删除按已保存的用户凭据记录逐个执行，成功后必须清空 binding 内的用户凭据映射。
  - 添加、删除、启动对账、页面对账和 USB 插拔对账共享服务层串行入口；当已有操作进行中时，后续调用必须等待前序操作完成后执行自己的 `taskFactory`，不得直接返回或复用首个操作结果。
  - `OsAccountUKeyUserProvider` 自动枚举所有 OS 账户 ID；注册和补注入均以全量用户集合为目标，但只允许在用户点击添加凭据并输入必要凭据后执行。
  - `OsAccountCustomAuthCredentialVerifier` 专用于页面认证验证，按已保存用户凭据逐个执行 `authUser(CUSTOM, ATL3)`，不调用 `addCredential`。
- `ukey/entry/src/main/ets/services/identity/custom-auth-core/**`
  - 裁剪后的认证器核心协议、IPC、密码学和 SecurityAsset 存储。
  - `PASSCODE_PROMPT_ENABLED` 必须启用；`beginAuthenticate` 只建立待输入 UKey 密码的会话，不允许直接 `finishAuth`。
  - `CustomAuthJsonPayloadCodec` 负责 AEAD 内层 JSON 编解码和严格字段校验，支持 `template_id` 十进制字符串字段。
  - `CustomAuthKeyStore` 负责 68B 密钥材料读写、旧 72B 记录迁移、孤立模板对账和删除。
  - `CustomAuthCryptoEngine` 负责 ECDH / HKDF / AES-GCM / RSA-OAEP，随机数失败必须返回失败结果，不得用空数组继续执行密码学流程。
- `ukey/entry/src/main/ets/extensionability/CustomAuthExtAbility.ets`
  - `ICustomAuthenticatorV1` appService 入口。连接断开或 Ability 销毁时调用 stub 清理未完成会话。
- `ukey/entry/src/main/ets/runtime/UKeyRuntimeManager.ets`
  - 独立运行时入口，应用启动后订阅 USB attach / detach common event，启动和插拔事件只触发状态对账，不在后台自动注册、补注入或删除 UKEY解锁凭据。DDK 没有插入回调，attach common event 只作为触发源，实际设备列表仍在延迟后通过 DDK `queryDevices` 获取。订阅失败必须返回明确结果并输出降级日志，不能让 `start()` 挂起。
- `ukey/entry/src/main/ets/entryability/EntryAbilityStage.ets`
  - AbilityStage 入口。实现 `onPrepareTermination()`，用于区分应用整体关闭和窗口 X 关闭；应用整体关闭返回 `TERMINATE_IMMEDIATELY`。
- `ukey/entry/src/main/ets/utils/StatusBarUtil.ets`
  - 负责加载托盘图标、注册状态栏条目，并用隐藏的 `BackGroundAbility` 持有状态栏生命周期。
- `ukey/entry/src/main/ets/backgroundability/BackGroundAbility.ets`
  - 状态栏生命周期辅助 Ability；当后台托盘能力被终止时发布内部事件，EntryAbility 收到后移除状态栏条目并退出。
- `ukey/entry/src/main/ets/pages/Index.ets`
  - UKey 本地管理页。页面读取 `PreferencesLockScreenAuthRepository`、`PreferencesLockScreenUKeyActiveCredentialRepository` 和实时 UKey 设备提供器，提供启用开关、凭据添加/删除按钮、凭据认证验证按钮、UKey设备和 UKEY解锁凭据状态；不提供手动刷新按钮。
  - 首页标题区展示 `startIcon` 图标和 `ukey解锁工具` 标题，图标仅作应用识别，不增加新的交互入口。
  - 凭据操作区提供系统 PIN 和 UKey 密码输入；添加凭据要求两者都非空且目标 UKey 在位，删除凭据只要求系统 PIN 非空和存在可见 UKEY解锁凭据，inactive 凭据也允许删除。
  - `凭据认证验证` 卡片展示一个验证专用 UKey 密码输入框和一个验证按钮；点击后对当前已保存的 UKEY解锁凭据逐用户执行 `authUser(CUSTOM)`，并通过 `companionDeviceAuth` passcode prompt 回调提交该输入框里的 UKey 密码；认证状态和成功/失败结论只回写到“当前状态”行。
  - `UKEY解锁凭据` 卡片有 active 或 inactive 凭据时只展示主凭据 ID、创建时间和状态；无凭据或只有 failed 残留时内容为空白。内部仍按所有 OS 账户保存用户凭据记录，供删除凭据和认证验证使用；凭据认证验证按钮仅在状态为 active 时可用。页面进入、USB 插拔、开关变更、添加、删除和认证验证后，页面必须把仓储读取到的 `activeCredential` 同步到独立的可见凭据状态字段，卡片直接绑定这些字段，避免对象状态已更新但卡片文本仍显示旧生命周期。
  - 页面前台运行时不轮询；`aboutToAppear()` 订阅 USB 插拔事件，事件触发后使用 DDK 重新读取 UKey设备和本地凭据状态，`aboutToDisappear()` 取消订阅。USB attach 后按短延迟窗口多次触发 DDK 读取，解决设备刚插入时 DDK 枚举尚未完成导致页面暂时拿不到设备的问题。
  - 页面 USB 延迟刷新必须记录所有 `setTimeout` handle，在 `aboutToDisappear()` 统一取消；刷新执行前检查页面是否仍 active、是否已有刷新进行中以及是否处于添加/删除凭据提交态，避免页面销毁后访问 `getPageContext()` 或与凭据操作并发。
  - 实时 UKey 展示优先使用 `DdkLockScreenUKeyDeviceService`；DDK 服务异常时使用 `UsbLockScreenUKeyDeviceService` 兜底展示，但页面不展示 DDK/USB 来源文案；未识别到 UKey 时内容为空白，只在插入后展示识别到的设备信息。
  - UI 结构沿用 SecurityTool 设置页规范，使用 `SectionCard`、`SectionToggleRow`、`SectionLabel`、`AppColors` 和 `AppStyles`，不单独设计一套视觉语言。
## 5. 异常处理与系统依赖 (Dependencies & Errors)

- **关键系统 API**:
  - `@kit.DriverDevelopmentKit.deviceManager.queryDevices`
  - `@kit.BasicServicesKit.commonEventManager`
  - `@kit.BasicServicesKit.usbManager.getDevices`
  - `@ohos.account.osAccount.UserIdentityManager.getAuthInfo/openSession/addCredential/delCred/closeSession`
  - `@ohos.account.osAccount.AccountManager.getOsAccountLocalIds`
  - `@ohos.account.osAccount.UserAuth.authUser`
  - `@ohos.account.osAccount.PINAuth.registerInputer/unregisterInputer`
  - `@ohos.security.asset`
- **系统权限**:
  - `ohos.permission.PREPARE_APP_TERMINATE`
  - `ohos.permission.ACCESS_EXTENSIONAL_DEVICE_DRIVER`
  - `ohos.permission.MANAGE_LOCAL_ACCOUNTS`
  - `ohos.permission.GET_LOCAL_ACCOUNT_IDENTIFIERS`
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
  - DDK 枚举失败、无候选 UKey、多候选 UKey 时不注入凭据；键盘、鼠标、触控板和 USB Hub 不计入候选数量。
  - DDK 与 USB 详情无法唯一匹配时不复用其它同 VID/PID 设备的 SN；没有精确详情时按 DDK 描述生成弱指纹。
  - OS 账户枚举失败或枚举结果为空时不注入凭据。
  - `getAuthInfo(CUSTOM_AUTH=128)` 列出现有系统 CustomAuth 凭据时返回 `12300002 Parameter invalid`，按当前没有可列出的 CustomAuth 凭据处理为空列表；其它系统错误仍按读取失败处理。
  - 系统 PIN 为空、PIN token 获取失败或 UKey 密码校验失败时不保存 UKEY解锁凭据。
  - 本地已存在 active/failed UKEY解锁凭据或系统侧已有 CUSTOM_AUTH 凭据时，添加凭据先读取系统凭据；属于当前目标 UKey 的恢复 active，非当前目标 UKey 的用本次系统 PIN 静默清理；清理失败时本次添加失败并保留日志，不提示用户先手动删除。
  - UKey 密码连续错误 5 次后返回锁定状态；锁定后添加凭据和解锁认证均失败，不再继续累加失败次数。
  - `addCredential` 非 0 返回不保存 UKEY解锁凭据，不做历史残留凭据兼容清理或重试。
  - 某个用户凭据注册失败时保留已成功用户的凭据记录，页面展示部分失败；后续对账只补缺失或失败用户。
  - 删除任一用户凭据失败时保留失败状态，后续用户再次输入系统 PIN 删除时重试；全部删除成功后清空 active 凭据和 binding 内 credentialId/templateId 映射；detach 事件中设备枚举异常不触发后台删除。
  - 服务层串行入口遇到并发调用时串行排队执行各自任务；页面和运行时不得把 USB 对账结果当作用户添加/删除结果复用。
  - 凭据认证验证失败不改变绑定和 active 凭据状态，只展示结果码和失败用户数。
  - 第二把 UKey 不替换首把绑定。
  - CustomAuth 无匹配 UKey、开关关闭、空 passcode、UKey 密码错误、UKey 已锁定或提交密码后目标 UKey 不在位时直接失败，不顺序 fallback。
  - CustomAuth 旧 72B 密钥记录迁移失败、记录长度异常、随机数生成失败、HKDF 参数非法或 RSA 公钥编码异常时返回 `GENERAL_ERROR` 或对应失败结果，不伪装认证成功。

### 5.1 实施步骤与测试验收 (Implementation & Acceptance)

- **实施步骤**:
  1. 将 SecurityTool 中的 UKey 设备发现、绑定仓储、凭据管理和 CustomAuth 核心迁入 `ukey/`。
  2. 修改 `pluginInfo` 和 appService 包名为 `com.ukey.pin`。
  3. 给 `ukey/` 增加系统权限、`ICustomAuthenticatorV1` appService 和系统签名模板。
  4. 从 SecurityTool 移除 UKey 页面入口、运行时 consumer、CustomAuth appService、UKey 服务/模型/权限。
  5. CustomAuth 核心协议随系统侧升级时，先更新本文档，再同步 `custom-auth-core` 的 JSON 字段、SecurityAsset 格式、旧记录迁移和生命周期清理逻辑；不得迁入测试 HAP 的 fake UKey、模拟换新或调试页面。
  6. 分别构建 SecurityTool 和 `ukey/`，确认 SecurityTool 不再出现 UKey systemapi warning，`ukey/` 作为系统应用承接相关 warning/权限。
  7. 修改 UKey 凭据生命周期时，先确认添加凭据需要系统 PIN + UKey 密码，删除凭据只需要系统 PIN，运行时后台插拔事件不绕过用户输入。
- **测试覆盖**:
  - 专项手工测试入口: `docs/04-测试文档/手工测试用例/UKey解锁工具规格与测试说明.md`。测试必须区分干净安装、保留数据升级和日常回归三类基线，并记录设备版本、HAP 哈希、当前系统 PIN、UKey SN、系统选中的 CustomAuth bundle/templateId 和关键日志。
  - 测试输入必须区分系统 PIN 与 UKey 密码：系统 PIN 使用被测 OS 账户的真实 PIN；当前开发阶段 UKey 密码固定为 `666666`。二者即使在实验设备上取值相同，也必须按两个独立输入和两条独立校验链路执行。
  - 同机安装多个 CustomAuthenticator HAP 时，只有系统日志或 `sensorInfo` 明确显示 `customAuthenticatorBundleName=com.ukey.pin` 的结果才计入本工具验收；其它 bundle 的成功或失败只作为环境信息，不得代替本工具结论。
  - SecurityTool UT/构建: 身份鉴别页仍可配置口令策略，且不再引用 UKey 模块。
  - `ukey/` 构建: 编译通过，`UserAuth is system api` warning 只出现在 `ukey/`。
  - `ukey/` CustomAuth 验证: 覆盖 `template_id` 十进制字符串、`auth_secret_seq` u32 JSON number、68B 新记录读写和 72B 旧记录迁移。
  - `ukey/` CustomAuth 验证: 覆盖 `PASSCODE_PROMPT_ENABLED=true`、页面验证凭据前必须输入 UKey 密码、passcode prompt 回调用页面输入的密码提交、空 passcode 失败、错误 UKey 密码失败、连续 5 次错误锁定、锁定后返回 `LOCKED`、提交密码后目标 UKey 被拔出失败。
  - 设备手工: 安装 `ukey/` 系统签名 HAP 后，第一把 UKey 在管理页输入系统 PIN 和 UKey 密码后可为所有 OS 账户注册凭据，第二把不注册；拔出首把不自动删除凭据，但认证失败；输入系统 PIN 后可删除全部已保存的 UKEY解锁凭据。
  - UT: 覆盖 UKey 设备候选过滤，确保键盘、鼠标、触控板和 USB Hub 不进入候选集合，不会把唯一真实 UKey 误判为“多把 UKey”。
- **验收口径**:
  - 发布前 P0 阻断项至少包括：系统应用签名/权限不满足、首把绑定失败、正确 UKey 密码无法完成有效 Model B 认证、错误密码未失败、连续 5 次错误未锁定、第二把 UKey 可替换或认证、目标 UKey 拔出后仍可认证、删除凭据后系统或本地仍残留可用凭据。
  - “正确密码认证成功”必须同时满足：系统选中 `com.ukey.pin`、触发 `onPrompt/submitPasscode`、认证器解密明文为 ASCII `666666`（字节码 `54,54,54,54,54,54`）、provider 匹配成功且最终 `onResult=0`。只看到 SceneBoard 打印字符串或其它认证器直接完成，不能判定本工具密码链路通过。
  - 若认证器解密得到 `0,0,0,0,0,0`，该值表示六个 NUL 字节而非字符串 `000000`；应按 passcode 传输链路故障处理，结合 SceneBoard 实际 `Uint8Array`、NAPI 深拷贝和 CDA RSA 加密输入定位，不得归类为用户输入了错误密码或两个认证器串用密钥。
  - `security_tool/entry/src/main/ets` 下不再存在 `lockscreen-auth`、`custom-auth-core` 或 `CustomAuthExtAbility`。
  - SecurityTool `module.json5` 不再定义 `ACCESS_CUSTOM_AUTHENTICATOR`，不再声明 UKey 凭据链路权限。
  - `ukey/` `module.json5` 声明 `ICustomAuthenticatorV1` appService 和 UKey 所需权限。
  - `ukey/` `pluginInfo` 指向 `com.ukey.pin`。
  - `ukey/` 自己订阅 USB attach / detach，不依赖 SecurityTool 外设运行时事件管线。
  - `ukey/` 页面只有一个 UKey 锁屏认证开关、凭据操作区、凭据认证验证按钮卡片、`UKey设备` 和 `UKEY解锁凭据` 状态；页面不提供手动刷新按钮，打开开关、页面进入、USB 插拔和凭据操作会触发状态同步，展示当前 UKey设备，以及 active/inactive UKEY解锁凭据的主 ID、创建时间和状态；无 UKey、无凭据或只有 failed 残留时对应内容为空白。
  - `ukey/` 凭据认证验证卡片只展示一个验证按钮，点击后对当前 active 凭据逐用户执行一次 `authUser(CUSTOM)`；成功、失败、结果码或错误信息只通过“当前状态”行反馈；该操作不得新增、删除或覆盖 UKEY解锁凭据。
  - `ukey/` 页面和注册链路不得把键盘、鼠标、触控板、USB Hub 展示或统计为 UKey；插入一把 UKey 且同时连接键盘/鼠标时，输入系统 PIN 和 UKey 密码后应按单把 UKey 注入 UKEY解锁凭据。
  - `ukey/` 安装后显示名为 `ukey解锁工具`；状态栏出现托盘入口，左键点击可恢复窗口。
  - `ukey/` 声明并签入 `ohos.permission.PREPARE_APP_TERMINATE`；主窗口点击 X 后应用不退出，窗口隐藏，UKey 运行时仍保持订阅和对账能力。
  - `ukey/` 实现 `EntryAbilityStage.onPrepareTermination()`；应用级关闭能真实退出，不被窗口 X 关闭隐藏逻辑拦截。
  - `ukey/` CustomAuth 不引入 `UKeySimulator`、模拟换新按钮或无匹配模板 fallback；第二把 UKey 仍不能认证成功。
  - `ukey/` CustomAuth 解锁认证必须走 `onPrompt` 输入 UKey 密码；目标 UKey 不在位、空密码、错误密码或 5 次锁定后不得返回认证成功。
  - `ukey/` CustomAuth 新录入模板以 68B SecurityAsset 记录保存；旧 72B 记录首次读取后迁移为 68B，迁移失败时不认证成功。
  - SecurityTool 构建、文档一致性检查通过。

## 6. 变更日志 (Changelog)

| 版本 | 日期 | 修改人 | 核心设计变更内容 |
|---|---|---|---|
| 2.2.34 | 2026-07-14 | Codex | 增加 UKey 解锁工具专项测试说明入口和发布阻断口径；明确系统 PIN 与固定 UKey 密码 `666666` 的独立语义、多认证器环境只认 `com.ukey.pin`，以及 Model B 成功和六个 NUL 字节故障的判定标准。 |
| 2.2.33 | 2026-07-14 | Codex | 增加重启启动识别兜底：启动对账首次未匹配绑定 UKey 时不立即将凭据降为 inactive，按 0.5 秒间隔最多查询 3 次；查询异常保留原状态，仅连续成功查询且均未匹配时才降级。 |
| 2.2.32 | 2026-07-14 | Codex | 将首次成功绑定的 UKey 设备身份设为不可变可信绑定：删除凭据、失败、锁定、插拔、重启和重新添加均只允许更新凭据列表；业务构造沿用旧身份字段，Repository 拒绝不同 fingerprint 覆盖，应用内不提供解绑或换绑入口。 |
| 2.2.31 | 2026-07-08 | Codex | 收紧管理页凭据操作输入态：添加按钮要求系统 PIN 和 UKey 密码均已输入，删除按钮要求系统 PIN 已输入；操作结束后显式清理对应输入框。 |
| 2.2.30 | 2026-07-06 | Codex | 修正空 CUSTOM_AUTH 凭据列表处理：`getAuthInfo(CUSTOM_AUTH=128)` 返回 `12300002 Parameter invalid` 时按无现有凭据继续添加/对账，不再直接阻断凭据注册。 |
| 2.2.28 | 2026-07-04 | Codex | 移除管理页手动刷新按钮和对应 ActionRow 样式逻辑；状态同步只由页面进入、USB 插拔、开关变更、凭据操作和认证验证触发，操作状态保留为纯文本展示。 |
| 2.2.27 | 2026-07-04 | Codex | 收紧系统残留恢复边界：没有 `trustedBinding` 时不得仅凭当前插入的一把 UKey 重建绑定；添加前清理系统凭据时同时使用 `trustedBinding.userCredentials` 和 `activeCredential.userCredentials` 判断自己的凭据。管理页固定使用应用内浅色调色板。 |
| 2.2.26 | 2026-07-04 | Codex | 将 templateId 作为同一条用户凭据的执行字段随 credentialId 一起绑定，形成 `fingerprint -> [credentialId, templateId]`；修正 `getAuthInfo().templateId` 按 little-endian 解码，避免系统候选 templateId 与本地解析值字节序相反导致认证失败。 |
| 2.2.25 | 2026-07-04 | Codex | 修正执行端候选含义：`beginAuthenticate` 的候选来自 SecurityAsset templateId，执行端需先按首把 fingerprint + 本地 credentialId 约束，再通过系统 `getAuthInfo` 临时解析 credentialId 对应 templateId 后返回，不恢复持久化模板绑定。 |
| 2.2.24 | 2026-07-04 | Codex | 移除独立模板归属映射设计；UKey 解锁归属统一收敛为首把 UKey fingerprint 与本地 credentialId 的一对多关系，添加、刷新和认证均按该关系判断归属。 |
| 2.2.23 | 2026-07-04 | Codex | 修正验证凭据的执行端匹配规则：认证先匹配首把 UKey fingerprint，再用该 fingerprint 下保存的 credentialId 约束候选 key；多把 UKey 指纹不匹配时不能解锁。 |
| 2.2.22 | 2026-07-04 | Codex | 修正 `UKEY解锁凭据` 卡片状态绑定：页面将 `activeCredential` 同步为独立可见状态字段，卡片直接绑定凭据 ID、创建时间和生命周期，避免 preferences 已恢复 active 但卡片仍显示旧 inactive。 |
| 2.2.21 | 2026-07-04 | Codex | 简化 UKey 指纹方案：优先 SN（`SN:SERIAL`，只比较 SN 不带 VID/PID 前缀），无 SN 时生成弱指纹（`VID:xxxx PID:xxxx|WEAK:PRODUCTNAME|DESCRIPTION`）；绑定匹配只做精确指纹字符串比较，移除 sysfs 补读和同 VID/PID 放行兜底。 |
| 2.2.20 | 2026-07-04 | Codex | 修复旧模板归属导致输入验证失败的设计：基于本地当前凭据 ID 与系统 credentialId 对账，安全修复缺失或过期的模板归属信息。 |
| 2.2.18 | 2026-07-04 | Codex | 凭据认证验证卡片新增独立 UKey 密码输入框，验证流程只读取该输入框，不再复用凭据操作区的 UKey 密码输入。 |
| 2.2.17 | 2026-07-04 | Codex | 修正管理页凭据认证验证链路：验证按钮必须使用页面输入的 UKey 密码，临时注册 `companionDeviceAuth` passcode prompt 回调提交密码，避免用户无法输入导致验证失败。 |
| 2.2.16 | 2026-07-04 | Codex | 增加 `inactive` 凭据状态：目标 UKey 拔出后保留凭据但状态不再显示 active，重新插入目标 UKey 后恢复 active；认证验证仅 active 可用。 |
| 2.2.15 | 2026-07-04 | Codex | 修正拔出/刷新对账语义：读不到匹配系统凭据时保留本地 active 凭据，不因 USB detach 或页面刷新清空 UKEY解锁凭据展示；删除仍只能由用户输入系统 PIN 触发。 |
| 2.2.14 | 2026-07-04 | Codex | 明确 DDK `deviceManager` 无插入回调，USB attach 事件后使用短延迟 DDK 复查刷新页面和运行态，避免插入后立即查询拿不到设备；仍不恢复周期轮询。 |
| 2.2.13 | 2026-07-04 | Codex | 收紧首把绑定安全边界：已有绑定后不允许当前唯一插入的其它 UKey 自动重绑；添加凭据必须要求已绑定 UKey 在位。 |
| 2.2.12 | 2026-07-04 | Codex | 系统凭据读取增加 `templateId` 归属判断：属于当前目标 UKey 的恢复为 active，非当前目标 UKey 的在添加流程中静默删除；页面取消轮询，改为 USB 插拔事件触发 DDK 刷新。 |
| 2.2.11 | 2026-07-04 | Codex | 添加凭据前静默枚举并删除系统侧已有 CUSTOM_AUTH 凭据，清空本地 failed/active 残留后重新注册当前目标 UKey；空设备/空凭据状态不再展示多余提示文案。 |
| 2.2.10 | 2026-07-04 | Codex | 补充残留 active/failed UKEY解锁凭据处理：添加前若已有本地凭据则提示先删除，不再重复调用 `addCredential`。 |
| 2.2.9 | 2026-07-04 | Codex | 启用 CustomAuth UKey 密码 prompt；添加凭据要求系统 PIN + UKey 密码 + 目标 UKey 在位，删除凭据只要求系统 PIN；UKey 密码连续 5 次错误锁定，后台插拔事件不再绕过用户输入自动添加或删除凭据。 |
| 2.2.8 | 2026-07-03 | Codex | 首页凭据认证验证卡片收敛为单按钮；`UKEY解锁凭据` 无数据时不再显示空态文案，保持内容空白。 |
| 2.2.7 | 2026-07-03 | Codex | UKey 凭据注册和删除链路使用的固定 PIN 从 `111111` 调整为 `666666`。 |
| 2.2.6 | 2026-07-03 | Codex | 注册、删除和凭据认证验证统一使用 `ATL3`；移除 `addCredential` 满额后的历史残留凭据清理重试；首页 `UKEY解锁凭据` 卡片精简为主凭据 ID、创建时间和状态，凭据认证验证不再展示 challenge、token 长度或逐用户明细。 |
| 2.2.5 | 2026-07-03 | Codex | 首页新增凭据认证验证卡片，仅通过 `authUser(CUSTOM=128)` 验证已存在凭据认证能力；补强 UKey detach 删除兜底，并明确不兼容旧单用户 active 状态。 |
| 2.2.4 | 2026-07-03 | Codex | UKEY解锁凭据改为自动枚举所有 OS 账户并逐个下发；PIN 固定输入由注册链路维护，插入和启动对账负责补齐所有用户的缺失凭据。 |
| 2.2.3 | 2026-07-03 | Codex | 首页标题左侧增加应用启动图标展示，作为 `ukey解锁工具` 管理页的视觉识别，不新增交互或系统能力。 |
| 2.2.2 | 2026-07-03 | Codex | 曾补充系统侧残留 CustomAuth 凭据恢复策略；当前版本已移除该兼容重试，`addCredential` 非 0 直接失败。 |
| 2.2.1 | 2026-07-03 | Codex | 收紧 UKey 设备候选过滤：排除 USB Hub、HID Boot 键盘/鼠标和名称明确为普通键鼠输入外设的设备，避免键鼠被误识别为 UKey 并阻塞凭据注入。 |
| 2.2.0 | 2026-07-01 | Codex | CustomAuth 核心协议对齐新系统侧格式：`template_id` 改为十进制字符串，`auth_secret_seq` 改为 u32 JSON number，SecurityAsset 新记录改为 68B，并对旧 72B 记录做读取时迁移；连接断开时清理未完成会话。 |
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
| 1.0.15 | 2026-06-30 | Codex | 接入 `osAccount.UserIdentityManager` 凭据注册/删除执行链路：注册和删除均先通过 `PINAuth` + `UserAuth.authUser(PIN, ATL3)` 获取 PIN token，再调用 `addCredential/delCred`。 |
