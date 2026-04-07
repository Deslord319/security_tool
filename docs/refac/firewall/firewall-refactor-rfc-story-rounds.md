# RFC v1：防火墙管理模块重构 Story / Round 设计

> 状态：Draft
> 日期：2026-04-07
> SSOT：`docs/refac/firewall/firewall-refactor-single-source-of-truth.md`
> 本文定位：执行层 RFC，不承担总纲职责；唯一总纲仍为 SSOT
> 本文目标：把 SSOT Step 1-7 细化为可并行执行的 story、依赖图、round、文件白名单与接口约束

## 1. 对齐声明

- 本文不替代 SSOT，也不重复 SSOT 中的背景、原则、完成判定。
- 目录结构、命名规则、阶段顺序、旧类复用策略均以 SSOT 为准。
- 本文只补执行层细化内容：
  - story 拆分
  - story 依赖
  - round 切分
  - session 并行约束
  - 建议接口与文件白名单

## 2. 背景与目标

当前防火墙模块的主要问题不是“业务不能用”，而是：

- UI 层仍然直接依赖多组旧 service；
- 防火墙模式、规则、用户下发、认证保护等职责分散；
- `MainPage`、页面、弹窗共同承担业务编排，导致入口不唯一；
- 目录结构尚未形成对人和 LLM 友好的唯一收口面。

本 RFC 的目标是：

1. 不改变业务真相的前提下，先落新骨架与新入口。
2. 把 SSOT 中的 Step 级计划细化到可直接派发给多个 session 的 story。
3. 给出每个 story 的依赖、白名单文件、验收口径与 round 边界。

## 3. 范围

### 2.1 In Scope

- `entry/src/main/ets/pages/MainPage.ets`
- `entry/src/main/ets/views/firewall/overview/FirewallPage.ets`
- `entry/src/main/ets/views/firewall/rule-management/FirewallRulesPage.ets`
- `entry/src/main/ets/components/firewall/policy/UserFirewallControlDialog.ets`
- `entry/src/main/ets/viewmodels/firewall/**`
- `entry/src/main/ets/services/firewall/**`
- `entry/src/main/ets/models/firewall/**`

### 2.2 Out of Scope

- `AddRuleDialog.ets` 的交互重做或视觉改版
- 防火墙业务规则语义调整
- 权限清单调整
- 签名模板调整
- 非防火墙模块的 MVVM 改造

## 4. 代码文件说明

### 3.1 当前直接依赖旧 service 的文件

| 文件路径 | 角色 | 说明 | 变更类型 |
|---|---|---|---|
| `entry/src/main/ets/pages/MainPage.ets` | 路由页 | 当前加载防火墙状态并直接切模式 | 更新 |
| `entry/src/main/ets/views/firewall/overview/FirewallPage.ets` | 概览页 | 当前直接执行受保护开关操作 | 更新 |
| `entry/src/main/ets/views/firewall/rule-management/FirewallRulesPage.ets` | 规则页 | 当前直接管理规则模板、冲突检测、系统下发、用户重下发 | 更新 |
| `entry/src/main/ets/components/firewall/policy/UserFirewallControlDialog.ets` | 用户下发弹窗 | 当前直接读取用户、读取状态、执行受保护下发 | 更新 |

### 3.2 当前旧真相来源文件

| 文件路径 | 角色 | 说明 | 变更类型 |
|---|---|---|---|
| `entry/src/main/ets/services/firewall/policy/FirewallService.ets` | 旧系统规则服务 | 系统防火墙 API、规则冲突、批量下发 | 复用后续迁移 |
| `entry/src/main/ets/services/firewall/mode-control/FirewallModeService.ets` | 旧模式入口 | 当前模式初始化、切换、自定义规则应用 | 复用后续迁移 |
| `entry/src/main/ets/services/firewall/rule-management/FirewallCustomRuleService.ets` | 旧自定义规则模板 | 规则模板持久化和模板转规则 | 复用后续迁移 |
| `entry/src/main/ets/services/firewall/mode-control/UserFirewallModeService.ets` | 旧用户级下发 | 用户绑定与按用户下发 | 复用后续迁移 |
| `entry/src/main/ets/services/firewall/policy/UserFirewallPolicyService.ets` | 旧系统用户来源 | 用户列表与用户当前策略 | 复用后续迁移 |
| `entry/src/main/ets/services/firewall/auth-state/FirewallToggleAuthService.ets` | 旧认证门面 | 防火墙开关和用户模式应用认证 | 复用后续迁移 |
| `entry/src/main/ets/services/firewall/auth-state/FirewallAuthStateRepository.ets` | 旧锁定状态存储 | 认证失败次数和锁定窗口存储 | 复用后续迁移 |
| `entry/src/main/ets/services/firewall/preset/FirewallPresetService.ets` | 旧预设规则构造 | `public/private` 规则构造 | 复用后续迁移 |

### 3.3 本轮建议新增文件

| 文件路径 | 角色 | 说明 | 变更类型 |
|---|---|---|---|
| `entry/src/main/ets/services/firewall/FirewallService.ets` | 新主服务 | 防火墙业务唯一门面 | 新增 |
| `entry/src/main/ets/services/firewall/index.ets` | barrel | 对外统一导出服务入口 | 新增 |
| `entry/src/main/ets/services/firewall/repositories/FirewallRepository.ets` | 仓储包装层 | 包装旧系统规则 service | 新增 |
| `entry/src/main/ets/services/firewall/stores/FirewallStore.ets` | 存储包装层 | 包装模式 / 自定义规则 / 用户绑定持久化 | 新增 |
| `entry/src/main/ets/services/firewall/stores/FirewallAuthStateStore.ets` | 认证状态存储 | 包装旧锁定状态 repository | 新增 |
| `entry/src/main/ets/services/firewall/providers/SystemUserProvider.ets` | 用户来源 | 包装旧用户策略查询 service | 新增 |
| `entry/src/main/ets/services/firewall/auth/FirewallAuthService.ets` | 认证服务 | 包装旧认证 service | 新增 |
| `entry/src/main/ets/services/firewall/mode-strategies/FirewallModeStrategy.ets` | 策略抽象 | 模式差异统一协议 | 新增 |
| `entry/src/main/ets/services/firewall/mode-strategies/PublicModeStrategy.ets` | 公网策略 | 包装旧 `FirewallPresetService` | 新增 |
| `entry/src/main/ets/services/firewall/mode-strategies/PrivateModeStrategy.ets` | 内网策略 | 包装旧 `FirewallPresetService` | 新增 |
| `entry/src/main/ets/services/firewall/mode-strategies/CustomModeStrategy.ets` | 自定义策略 | 包装旧 `FirewallCustomRuleService` | 新增 |
| `entry/src/main/ets/services/firewall/mode-strategies/FirewallModeStrategyFactory.ets` | 策略工厂 | 模式到策略实现的唯一映射 | 新增 |
| `entry/src/main/ets/models/firewall/firewall_service_contracts.ets` | 共享类型 | ViewModel / Service 返回结构 | 新增 |
| `entry/src/main/ets/viewmodels/firewall/overview/FirewallOverviewViewModel.ets` | 概览 VM | 概览页状态与交互用例 | 新增 |
| `entry/src/main/ets/viewmodels/firewall/rules/FirewallRulesViewModel.ets` | 规则 VM | 规则列表/规则编辑/规则保存用例 | 新增 |
| `entry/src/main/ets/viewmodels/firewall/user-dispatch/FirewallUserDispatchViewModel.ets` | 用户下发 VM | 用户列表、用户状态、受保护下发用例 | 新增 |

## 5. 模块设计

### 4.1 固定调用链

```text
MainPage / View / Dialog
  -> ViewModel
    -> services/firewall/FirewallService
      -> Strategy / Repository / Store / Provider / Auth
        -> 旧 firewall services（阶段 A 仅包装复用）
```

### 4.2 新 `FirewallService` 最小职责

第一阶段只做统一门面，不重写旧实现。建议服务面向 VM 暴露以下能力：

```ts
export interface FirewallOverviewState {
  enabled: boolean
  currentMode: FirewallPresetMode
}

export interface FirewallOperationResult {
  success: boolean
  errorCode?: number
  errorMessage?: string
}

export class FirewallService {
  async loadOverviewState(context: common.UIAbilityContext): Promise<FirewallOverviewState>
  async toggleFirewall(
    context: common.UIAbilityContext,
    currentEnabled: boolean,
    targetEnabled: boolean
  ): Promise<FirewallOperationResult>
  async switchMode(
    context: common.UIAbilityContext,
    targetMode: FirewallPresetMode
  ): Promise<FirewallOperationResult>
  async listCustomRules(context: common.UIAbilityContext): Promise<netFirewall.NetFirewallRule[]>
  async saveCustomRules(
    context: common.UIAbilityContext,
    nextRules: netFirewall.NetFirewallRule[]
  ): Promise<FirewallOperationResult>
  async loadUserOptions(): Promise<UserFirewallOption[]>
  async loadUserModeState(
    context: common.UIAbilityContext,
    userId: number
  ): Promise<FirewallUserModeStateResult>
  async applyUserMode(
    context: common.UIAbilityContext,
    userId: number,
    mode: FirewallUserApplyMode
  ): Promise<FirewallUserApplyResult>
}
```

说明：

- `toggleFirewall` 第一阶段内部转调旧 `FirewallToggleAuthService.executeToggle(...)`
- `switchMode` 第一阶段内部转调旧 `FirewallModeService.switchMode(...)`
- `saveCustomRules` 第一阶段内部仍可复用旧 `FirewallModeService.applyCustomRules(...)`、`FirewallCustomRuleService.replaceAllRules(...)`、`UserFirewallModeService.reapplyBindings(...)`
- `applyUserMode` 第一阶段内部仍可复用旧 `FirewallCustomRuleService.buildRulesForApply(...)`、`FirewallToggleAuthService.executeUserModeApply(...)`、`UserFirewallModeService.applyMode(...)`

### 4.3 三个 ViewModel 建议边界

#### FirewallOverviewViewModel

- 负责：
  - 初始读取 `enabled/currentMode`
  - 处理开关认证流
  - 处理模式切换流
- 不负责：
  - 规则列表 CRUD
  - 用户级下发

#### FirewallRulesViewModel

- 负责：
  - 加载自定义规则
  - 新增/编辑/删除前冲突检测
  - 保存规则并处理回滚 / 用户重下发摘要
- 不负责：
  - 认证密码逻辑
  - 用户列表读取

#### FirewallUserDispatchViewModel

- 负责：
  - 读取用户列表
  - 读取当前用户模式状态
  - 执行用户模式受保护下发
- 不负责：
  - 规则页列表展示

### 4.4 关键状态放置建议

- `MainPage` 保留路由状态，但不再直接编排防火墙业务。
- `FirewallPage` 保留纯展示态，例如 hover / dialog controller / loading runner。
- 业务态下沉至 VM：
  - overview VM：`enabled/currentMode/isToggleProcessing/isModeProcessing`
  - rules VM：`rules/conflictNotice/isLoading`
  - user-dispatch VM：`users/selectedUserId/selectedMode/isLoading/isSubmitting/currentPolicyText`

## 6. 系统模块接口

| 系统模块/API | 用途 | 调用位置 | 权限/约束 | 备注 |
|---|---|---|---|---|
| `@kit.NetworkKit netFirewall` | 系统防火墙规则读写与策略操作 | 旧 `policy/FirewallService.ets`，后续迁入 `repositories/` | 依赖防火墙相关企业权限 | 第一阶段不改调用真相 |
| `@kit.AbilityKit common.UIAbilityContext` | 读取应用上下文、偏好存储与业务 service 调用上下文 | `MainPage`、各 VM、新 `FirewallService` | 页面/VM 调用前需拿到 UIAbilityContext | 建议在 VM 层统一传入 |

## 7. 风险与待确认

### 6.1 已知风险

- `MainPage` 当前持有 `firewallEnabled/firewallPresetMode` 状态；overview VM 接入后，页面与路由页之间的状态同步边界需要一次性定清。
- `FirewallRulesPage` 目前同时承担“规则编辑”和“打开用户控制弹窗”的责任；若 VM 边界设计不清，容易出现规则 VM 与用户下发 VM 交叉引用。
- `saveCustomRules(...)` 第一阶段需要兼顾“系统应用成功、本地模板保存失败时回滚”的现有语义，不能被简化丢失。

### 6.2 待确认

- `MainPage` 是否需要长期持有 firewall overview 状态缓存，还是只负责初始化并把状态交给 `FirewallOverviewViewModel`。
- 阶段 B 迁移时，`services/firewall/rules/` 与 `services/firewall/user-dispatch/` 的最终文件粒度是否需要继续细分。

## 8. 迁移与删除原则

- “骨架稳定后，再逐块迁移旧逻辑”对应的执行区间是：
  - `S15`：迁移 Strategy 内部真相
  - `S16`：迁移 Repository + `rules/` 真相
  - `S17`：迁移 Store 真相
  - `S18`：迁移 `user-dispatch/` 真相
  - `S19`：迁移 auth 真相
  - `S20`：兼容层收口与旧引用扫描
- 其中 `S15-S19` 是“迁移生产职责”的 story，`S20` 是“迁移完成后的删除/收口” story。
- 每迁完一块，必须判断对应旧实现属于以下哪类：
  - 仍被新链路依赖的 compat 包装层：允许保留，但要缩减为薄包装。
  - 已无新链路依赖的腐败代码/死代码：必须在当前 story 或紧随其后的 `S20` 删除。
- 禁止把“已被新目录替代、且已无调用方”的旧实现继续长期保留在主干分支。
- 删除旧代码时必须同时提供证据：
  - 新链路替代位置
  - 旧引用扫描结果
  - 删除后构建结果

## 9. Git 管理原则

- 本 RFC 默认要求本地处于 git 管理下执行，小步修改必须落为可追溯提交。
- 每个 story 至少对应一个独立提交；禁止把多个 story 混在同一个提交里。
- 提交说明必须显式包含 story 编号，例如：`Story: S13 migrate FirewallRulesPage to FirewallRulesViewModel`
- 同一 round 的并行 session 只能在各自 story 白名单文件内提交，便于后续 cherry-pick / rebase / blame 追溯。
- 在进入下一 round 前，上一 round 的 story 提交必须已经：
  - 有明确 commit id
  - 能单独说明改动目的
  - 能通过最小构建或扫描验证
- 若某 story 只完成了一半，不允许把“进行中工作树”当作 round 完成物；必须收敛为可解释的 git 提交，或回退到上一个稳定提交继续拆分。

## 10. PR 拆 Story

## PR-1：新骨架与 contracts

### Story S1：建立 firewall 新目录和 barrel `index.ets`

- 目标：
  - 建立 `viewmodels/firewall/`、`services/firewall/`、`models/firewall/` 及其子目录
  - 每个子目录补 `index.ets`
- 白名单文件：
  - `entry/src/main/ets/viewmodels/firewall/**`
  - `entry/src/main/ets/services/firewall/**`
  - `entry/src/main/ets/models/firewall/**`
- 验收：
  - 仅新增目录和导出文件
  - 旧页面行为不变
- 依赖：无

### Story S2：建立共享 contracts 文件

- 目标：
  - 抽出 VM / Service 共享返回结构与基础 state 类型
- 白名单文件：
  - `entry/src/main/ets/models/firewall/firewall_service_contracts.ets`
  - `entry/src/main/ets/models/firewall/index.ets`
- 建议内容：

```ts
export interface FirewallOperationResult {
  success: boolean
  errorCode?: number
  errorMessage?: string
}

export interface FirewallOverviewState {
  enabled: boolean
  currentMode: FirewallPresetMode
}
```

- 验收：
  - 只新增类型，不改变业务行为
- 依赖：S1

## PR-2：新主服务门面

### Story S3：建立新 `services/firewall/FirewallService.ets`

- 目标：
  - 新建唯一门面，先统一 API 命名
  - 内部直接转调旧 service
- 白名单文件：
  - `entry/src/main/ets/services/firewall/FirewallService.ets`
  - `entry/src/main/ets/services/firewall/index.ets`
- 关键要求：
  - 不能在该 story 重写旧业务逻辑
  - 统一成功/失败返回结构
- 验收：
  - 新 service 可独立被后续 VM 调用
  - 旧业务行为保持不变
- 依赖：S2

## PR-3：Repository / Store / Provider / Auth 包装层

### Story S4：建立 `repositories/providers/auth` 包装层

- 目标：
  - 建立角色边界清晰的基础设施包装层
- 白名单文件：
  - `entry/src/main/ets/services/firewall/repositories/FirewallRepository.ets`
  - `entry/src/main/ets/services/firewall/providers/SystemUserProvider.ets`
  - `entry/src/main/ets/services/firewall/auth/FirewallAuthService.ets`
  - 对应 `index.ets`
- 包装来源：
  - `policy/FirewallService.ets`
  - `policy/UserFirewallPolicyService.ets`
  - `auth-state/FirewallToggleAuthService.ets`
- 验收：
  - 仅建立新角色，不迁内部真相
- 依赖：S3

### Story S5：建立 `stores` 包装层

- 目标：
  - 把“模式、自定义规则模板、用户绑定、认证锁定状态”统一归入 store 语义
- 白名单文件：
  - `entry/src/main/ets/services/firewall/stores/FirewallStore.ets`
  - `entry/src/main/ets/services/firewall/stores/FirewallAuthStateStore.ets`
  - 对应 `index.ets`
- 包装来源：
  - `mode-control/FirewallModeService.ets`
  - `rule-management/FirewallCustomRuleService.ets`
  - `mode-control/UserFirewallModeService.ets`
  - `auth-state/FirewallAuthStateRepository.ets`
- 验收：
  - 新 store 命名成立
  - 仍然通过旧实现完成读写
- 依赖：S3

## PR-4：Strategy 层

### Story S6：建立 `PublicModeStrategy` / `PrivateModeStrategy`

- 目标：
  - 把 `public/private` 的模式差异从页面和旧 mode service 中语义抽离出来
- 白名单文件：
  - `entry/src/main/ets/services/firewall/mode-strategies/FirewallModeStrategy.ets`
  - `entry/src/main/ets/services/firewall/mode-strategies/PublicModeStrategy.ets`
  - `entry/src/main/ets/services/firewall/mode-strategies/PrivateModeStrategy.ets`
- 包装来源：
  - `preset/FirewallPresetService.ets`
- 验收：
  - 模式差异在新目录表达
  - 规则构造真相仍来自旧 preset service
- 依赖：S4

### Story S7：建立 `CustomModeStrategy`

- 目标：
  - 把自定义规则模板读取/构造的模式差异抽离为单独策略
- 白名单文件：
  - `entry/src/main/ets/services/firewall/mode-strategies/CustomModeStrategy.ets`
  - `entry/src/main/ets/services/firewall/mode-strategies/index.ets`
- 包装来源：
  - `rule-management/FirewallCustomRuleService.ets`
  - `stores/FirewallStore.ets`
- 验收：
  - `custom` 模式不再只由页面语义识别
- 依赖：S5

### Story S8：建立 `FirewallModeStrategyFactory` 并接入新主服务

- 目标：
  - 建立模式到策略的唯一映射
  - 在新主服务中使用工厂，而不是由页面推断模式语义
- 白名单文件：
  - `entry/src/main/ets/services/firewall/mode-strategies/FirewallModeStrategyFactory.ets`
  - `entry/src/main/ets/services/firewall/FirewallService.ets`
  - `entry/src/main/ets/services/firewall/mode-strategies/index.ets`
- 验收：
  - `public/private/custom` 的策略入口唯一
- 依赖：S6、S7

## PR-5：ViewModel 层

### Story S9：建立 `FirewallOverviewViewModel`

- 目标：
  - 抽离 overview 状态读取、开关认证流、模式切换流
- 白名单文件：
  - `entry/src/main/ets/viewmodels/firewall/overview/FirewallOverviewViewModel.ets`
  - `entry/src/main/ets/viewmodels/firewall/overview/index.ets`
- 验收：
  - VM 只依赖新 `services/firewall/FirewallService.ets`
- 依赖：S8

### Story S10：建立 `FirewallRulesViewModel`

- 目标：
  - 抽离规则列表、冲突提示、规则保存与回滚摘要
- 白名单文件：
  - `entry/src/main/ets/viewmodels/firewall/rules/FirewallRulesViewModel.ets`
  - `entry/src/main/ets/viewmodels/firewall/rules/index.ets`
- 验收：
  - VM 不直接依赖旧 `FirewallModeService` / `UserFirewallModeService`
- 依赖：S8

### Story S11：建立 `FirewallUserDispatchViewModel`

- 目标：
  - 抽离用户列表、状态读取、受保护用户模式下发
- 白名单文件：
  - `entry/src/main/ets/viewmodels/firewall/user-dispatch/FirewallUserDispatchViewModel.ets`
  - `entry/src/main/ets/viewmodels/firewall/user-dispatch/index.ets`
- 验收：
  - VM 不直接依赖旧 `UserFirewallPolicyService` / `UserFirewallModeService`
- 依赖：S8

## PR-6：页面迁移

### Story S12：`MainPage` + `FirewallPage` 切换到 `FirewallOverviewViewModel`

- 目标：
  - `MainPage` 退出直接编排防火墙初始化和模式切换
  - `FirewallPage` 不再直接调用旧认证 service
- 白名单文件：
  - `entry/src/main/ets/pages/MainPage.ets`
  - `entry/src/main/ets/views/firewall/overview/FirewallPage.ets`
  - `entry/src/main/ets/viewmodels/firewall/overview/FirewallOverviewViewModel.ets`
- 验收：
  - `MainPage` 不再直接调用旧 `FirewallModeService.switchMode(...)`
  - `FirewallPage` 不再直接 import 旧 `FirewallToggleAuthService`
- 依赖：S9

### Story S13：`FirewallRulesPage` 切换到 `FirewallRulesViewModel`

- 目标：
  - 规则页退出旧 service 直连
- 白名单文件：
  - `entry/src/main/ets/views/firewall/rule-management/FirewallRulesPage.ets`
  - `entry/src/main/ets/viewmodels/firewall/rules/FirewallRulesViewModel.ets`
- 验收：
  - 页面不再直接 import 旧 `FirewallService` / `FirewallCustomRuleService` / `FirewallModeService` / `UserFirewallModeService`
- 依赖：S10、S12

### Story S14：`UserFirewallControlDialog` 切换到 `FirewallUserDispatchViewModel`

- 目标：
  - 用户下发弹窗退出旧 service 直连
- 白名单文件：
  - `entry/src/main/ets/components/firewall/policy/UserFirewallControlDialog.ets`
  - `entry/src/main/ets/viewmodels/firewall/user-dispatch/FirewallUserDispatchViewModel.ets`
- 验收：
  - 弹窗不再直接 import 旧 `FirewallCustomRuleService` / `FirewallToggleAuthService` / `UserFirewallModeService` / `UserFirewallPolicyService`
- 依赖：S11、S13

## PR-7：骨架稳定后迁真相

### Story S15：迁移 Strategy 内部真相

- 目标：
  - 把 `public/private/custom` 规则构造逐步迁入新策略目录
- 白名单文件：
  - `entry/src/main/ets/services/firewall/mode-strategies/**`
  - `entry/src/main/ets/services/firewall/FirewallService.ets`
- 验收：
  - 新策略目录承担生产职责
  - 旧 `preset/`、`rule-management/` 对应引用减少
- 依赖：S14

### Story S16：迁移 Repository + `rules/` 真相

- 目标：
  - 把系统规则 API 与冲突判断相关实现迁入新目录
- 白名单文件：
  - `entry/src/main/ets/services/firewall/repositories/**`
  - `entry/src/main/ets/services/firewall/rules/**`
  - `entry/src/main/ets/services/firewall/FirewallService.ets`
- 验收：
  - 新 `repositories/` 与 `rules/` 承担生产职责
- 依赖：S15

### Story S17：迁移 Store 真相

- 目标：
  - 把当前模式、自定义模板、用户绑定、认证状态存储逐步迁入新 store
- 白名单文件：
  - `entry/src/main/ets/services/firewall/stores/**`
  - `entry/src/main/ets/services/firewall/FirewallService.ets`
- 验收：
  - `stores/` 成为唯一持久化入口
- 依赖：S16

### Story S18：迁移 `user-dispatch/` 真相

- 目标：
  - 用户绑定、按用户下发、模板变更后的重下发迁入新目录
- 白名单文件：
  - `entry/src/main/ets/services/firewall/user-dispatch/**`
  - `entry/src/main/ets/services/firewall/FirewallService.ets`
- 验收：
  - 旧 `UserFirewallModeService` 退化为 compat
- 依赖：S17

### Story S19：迁移 auth 真相

- 目标：
  - 把认证流程与锁定状态逻辑迁入新 `auth/` + `stores/`
- 白名单文件：
  - `entry/src/main/ets/services/firewall/auth/**`
  - `entry/src/main/ets/services/firewall/stores/**`
  - `entry/src/main/ets/services/firewall/FirewallService.ets`
- 验收：
  - 旧 `FirewallToggleAuthService` 退化为 compat
- 依赖：S18

### Story S20：兼容层收口与旧引用扫描

- 目标：
  - 收窄 compat 层职责
  - 清理新 UI / VM 中残留的旧依赖
- 白名单文件：
  - `entry/src/main/ets/pages/MainPage.ets`
  - `entry/src/main/ets/views/firewall/**`
  - `entry/src/main/ets/components/firewall/**`
  - `entry/src/main/ets/viewmodels/firewall/**`
  - `entry/src/main/ets/services/firewall/**`
- 验收：
  - 关键 `rg` 扫描符合 SSOT
- 依赖：S19

### Story S21：最终 fresh verify

- 目标：
  - 提供构建、签名、安装、启动和最小业务冒烟证据
- 白名单文件：
  - 文档 / 测试证据 / 构建产物，不要求生产代码改动
- 验收：
  - fresh build / sign / install / run / smoke 结果齐全
- 依赖：S20

## 11. 依赖图

```text
S1 -> S2 -> S3 -> (S4 || S5) -> (S6 || S7) -> S8
   -> (S9 || S10 || S11)
   -> S12 -> S13 -> S14
   -> S15 -> S16 -> S17 -> S18 -> S19 -> S20 -> S21
```

可并行结论：

- 可以并行：
  - `S4` 与 `S5`
  - `S6` 与 `S7`
  - `S9` / `S10` / `S11`
- 不建议并行：
  - `S12` / `S13` / `S14`
  - `S15` 之后的内部迁真相阶段

## 12. Round 切分

## Round 1

- Session A：S1
- Session B：S2
- Exit：
  - 新目录与共享 contracts 已落地
  - 编译通过

## Round 2

- Session A：S3
- Exit：
  - 新 `FirewallService` 门面定型

## Round 3

- Session A：S4
- Session B：S5
- Exit：
  - Repository / Provider / Auth / Store 包装层全部到位

## Round 4

- Session A：S6
- Session B：S7
- Exit：
  - 三种模式已在 `mode-strategies/` 语义表达

## Round 5

- Session A：S8
- Exit：
  - Strategy Factory 落地
  - 新主服务接上策略入口

## Round 6

- Session A：S9
- Session B：S10
- Session C：S11
- Exit：
  - 三个 VM 均可独立工作
  - VM 只依赖新 `FirewallService`

## Round 7

- Session A：S12
- Exit：
  - overview 链路完成迁移

## Round 8

- Session A：S13
- Exit：
  - 规则页完成迁移

## Round 9

- Session A：S14
- Exit：
  - 用户下发弹窗完成迁移

## Round 10

- Session A：S15
- Exit：
  - Strategy 真相开始迁入新目录
  - 已替代且无引用的旧 Strategy 腐败代码进入删除清单

## Round 11

- Session A：S16
- Exit：
  - Repository + `rules/` 真相迁入新目录
  - 已替代且无引用的旧系统规则辅助代码进入删除清单

## Round 12

- Session A：S17
- Exit：
  - Store 真相迁入新目录
  - 已替代且无引用的旧持久化包装进入删除清单

## Round 13

- Session A：S18
- Exit：
  - `user-dispatch/` 真相迁入新目录
  - 已替代且无引用的旧用户下发实现进入删除清单

## Round 14

- Session A：S19
- Exit：
  - auth 真相迁入新目录
  - 已替代且无引用的旧认证实现进入删除清单

## Round 15

- Session A：S20
- Session B：S21
- Exit：
  - 兼容层收口完成
  - 已确认无引用的腐败代码/死代码删除完成
  - fresh verify 证据完整

## 13. session 并行硬约束

- 每个 session 只认领一个 story，只改 story 白名单文件。
- `entry/src/main/ets/services/firewall/FirewallService.ets` 属于主枢纽文件：
  - Round 2 只允许 S3 修改
  - Round 5 只允许 S8 修改
  - Round 10-14 只允许对应迁移 story 修改
- `MainPage.ets` 只允许 S12 修改。
- `FirewallRulesPage.ets` 只允许 S13 修改。
- `UserFirewallControlDialog.ets` 只允许 S14 修改。
- 如 `firewall_service_contracts.ets` 字段变化影响同 round 其他 session，必须先发 contract sync commit，再让其他 session rebase。
- Round 6 结束前禁止提前修改 UI 层文件。
- Round 15 是唯一允许“代码收口 + fresh verify 并行”的 round；此前 round 不允许跨轮直接并线。
- 每个 session 在提交前必须执行 `git status --short`，确保工作树只包含本 story 范围内改动。

## 14. 与 SSOT 的一致性声明

- 本 RFC 不改变 SSOT 的阶段顺序，只把 Step 级计划细化到 story / round。
- SSOT 中“Step 级串行”仍然成立；本文允许的并行，仅发生在同一步内且写集不冲突的 story 之间。
- 第一阶段所有 story 都以“包装旧实现、保持行为不变”为约束，不引入第二真相。

## 15. 关联文档

- `docs/refac/firewall/firewall-refactor-single-source-of-truth.md`
