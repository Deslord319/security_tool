# 防火墙架构重构唯一真相

> 状态：Draft  
> 日期：2026-04-16  
> 分支：`task/firewall-architecture-refactor-plan`  
> 独立 worktree：`D:\project\ai\security_tool-firewall-architecture-refactor-plan`  
> 适用范围：防火墙模块架构重构、旧链路清理、规则本地意图与系统下发映射重建  
> 唯一判定依据：本文档  

## 1. 文档目的

本文档记录当前已确认的防火墙模块重构方案。后续涉及防火墙架构、代码职责、函数边界、旧代码清理、失败处理、认证接入、模式切换、规则本地存储和系统规则下发的分析、实现、测试与评审，均以本文为唯一真相。

本文档取代此前防火墙重构主入口：

- `docs/refac/firewall/firewall-refactor-single-source-of-truth.md`

此前文档中仍有价值的历史背景、阶段拆分和旧实现分析可作为参考材料，但若与本文冲突，以本文为准。

## 2. 工作区与分支约束

本任务必须在独立分支与独立 worktree 内推进，不得直接在主 worktree 或 `master` 分支上分析、修改、构建、测试、签名或提交。

当前唯一允许的任务环境：

```text
branch: task/firewall-architecture-refactor-plan
worktree: D:\project\ai\security_tool-firewall-architecture-refactor-plan
```

执行任何后续命令前，必须确认：

```bash
git -C D:\project\ai\security_tool-firewall-architecture-refactor-plan branch --show-current
```

结果必须为：

```text
task/firewall-architecture-refactor-plan
```

如果工具或 shell 的 `workdir` 行为异常，必须显式使用 `git -C D:\project\ai\security_tool-firewall-architecture-refactor-plan ...` 或绝对路径，避免误操作 `D:\project\ai\security_tool` 主 worktree。

本轮实施计划按唯一 worktree 串行推进，不再派生子分支和子 worktree 并行执行。

如果未来重新启用并行 session、子分支或子 worktree，必须先更新本文档，再开始执行。

## 3. 架构目标

本轮重构目标如下：

1. 保持并收敛 MVVM 架构。
2. 减少防火墙模块文件数量，不再把职责拆成过多微文件。
3. 明确系统数据访问和本地数据访问边界。
4. 删除快照、失败回滚、restore 和 reapply 相关伪事务逻辑。
5. 删除防火墙专属 PIN 锁定状态。
6. 删除防火墙专属认证包装，直接复用项目公共认证组件。
7. 删除规则 `description` metadata 反查机制。
8. 删除“只删除本应用管理规则”的语义。
9. 删除旧的用户模式规则筛选、规则清理和规则重放链路。
10. 本地只记录自定义规则意图和成功的系统下发映射。

目标调用链：

```text
View
  -> ViewModel
    -> FirewallService
      -> FirewallSystemRepository
      -> FirewallLocalRepository
      -> FirewallModeStrategy
      -> FirewallRuleUtils
      -> SystemUserProvider
```

## 4. MVVM 边界

### 4.1 View

View 只负责 UI 展示、用户交互和事件转发。

包括：

- `entry/src/main/ets/views/firewall/overview/FirewallPage.ets`
- `entry/src/main/ets/views/firewall/rules/FirewallRulesPage.ets`
- `entry/src/main/ets/components/firewall/rules/AddRuleDialog.ets`
- `entry/src/main/ets/components/firewall/user-dispatch/UserFirewallControlDialog.ets`

View 不允许：

- 直接调用 `netFirewall`
- 直接读写 `Preferences`
- 直接调用 Repository
- 直接实现规则下发、策略写入和模式切换业务流程

### 4.2 ViewModel

ViewModel 负责页面状态、loading 状态、错误提示、用户动作转发和展示数据整理。

保留：

- `entry/src/main/ets/viewmodels/firewall/overview/FirewallOverviewViewModel.ets`
- `entry/src/main/ets/viewmodels/firewall/rules/FirewallRulesViewModel.ets`
- `entry/src/main/ets/viewmodels/firewall/user-dispatch/FirewallUserDispatchViewModel.ets`

`FirewallUserDispatchViewModel` 当前保留名称，后续可按专项改名为 `FirewallUserPolicyViewModel`。当前阶段只收紧职责，不强制改名。

ViewModel 不允许：

- 直接调用 `netFirewall`
- 直接读写 `Preferences`
- 维护系统规则 ID 下发细节
- 实现多用户规则下发循环

允许：

- 调用 `FirewallService` 执行业务写操作
- `FirewallUserDispatchViewModel` 直接调用 `SystemUserProvider.loadAvailableUserIds()` 读取用户列表

### 4.3 Service

`FirewallService` 是唯一业务编排入口。所有写系统防火墙或写防火墙本地数据的主流程都必须通过 `FirewallService`。

### 4.4 Repository

Repository 负责数据访问：

- `FirewallSystemRepository`：唯一系统防火墙 API 访问层
- `FirewallLocalRepository`：唯一防火墙本地 Preferences 访问层

### 4.5 Utils / Strategy / Provider

- `FirewallRuleUtils`：规则校验、构造、规范化、冲突判断等纯工具
- `FirewallModeStrategy`：只负责模式规则生成
- `SystemUserProvider`：只负责系统用户来源和用户 policy 摘要读取

`FirewallModeStrategy` 允许调用 `SystemUserProvider.loadAvailableUserIds()` 获取首页模式切换的目标用户列表。该调用只允许用于生成 `public/private` 模式的 `FirewallPreparedRule`，不得在 Strategy 中写 policy、写规则或写本地数据。

## 5. 最终核心文件

目标核心文件：

```text
entry/src/main/ets/services/firewall/FirewallService.ets
entry/src/main/ets/services/firewall/FirewallSystemRepository.ets
entry/src/main/ets/services/firewall/FirewallLocalRepository.ets
entry/src/main/ets/services/firewall/FirewallModeStrategy.ets
entry/src/main/ets/services/firewall/FirewallRuleUtils.ets
entry/src/main/ets/services/firewall/FirewallModels.ets
entry/src/main/ets/services/firewall/providers/SystemUserProvider.ets
```

保留 ViewModel：

```text
entry/src/main/ets/viewmodels/firewall/overview/FirewallOverviewViewModel.ets
entry/src/main/ets/viewmodels/firewall/rules/FirewallRulesViewModel.ets
entry/src/main/ets/viewmodels/firewall/user-dispatch/FirewallUserDispatchViewModel.ets
```

保留 View / Component：

```text
entry/src/main/ets/views/firewall/overview/FirewallPage.ets
entry/src/main/ets/views/firewall/rules/FirewallRulesPage.ets
entry/src/main/ets/components/firewall/rules/AddRuleDialog.ets
entry/src/main/ets/components/firewall/user-dispatch/UserFirewallControlDialog.ets
```

## 6. 核心模型

模型统一放入：

```text
entry/src/main/ets/services/firewall/FirewallModels.ets
```

`entry/src/main/ets/models/firewall/firewall_service_contracts.ets` 合并进 `FirewallModels.ets` 后删除。

### 6.1 FirewallRuleIntentMappingData

`FirewallRuleIntentMappingData` 是防火墙自定义规则本地持久化唯一结构。

它只记录自定义规则，不记录 `public/private` 模式生成规则。

```ts
export interface FirewallRuleIntentMappingData {
  version: number
  ruleIntents: FirewallRuleIntent[]
  ruleDeployments: FirewallRuleDeployment[]
}
```

### 6.2 FirewallRuleIntent

`FirewallRuleIntent` 表示一条本地业务规则意图。

```ts
export interface FirewallRuleIntent {
  localRuleId: string
  name: string
  type: number
  direction: number
  action: number
  isEnabled: boolean
  targetUserIds: number[]
  protocol?: number
  remoteIps?: netFirewall.NetFirewallIpParams[]
  localIps?: netFirewall.NetFirewallIpParams[]
  localPorts?: netFirewall.NetFirewallPortParams[]
  remotePorts?: netFirewall.NetFirewallPortParams[]
  domains?: netFirewall.NetFirewallDomainParams[]
  dns?: netFirewall.NetFirewallDnsParams
  createdAt: number
  updatedAt: number
}
```

`localRuleId` 由应用本地生成。建议格式：

```text
fw_rule_${Date.now()}_${generateRandomSuffix()}
```

系统真实规则 ID 由 `netFirewall.addNetFirewallRule` 返回，并写入 `FirewallRuleDeployment.systemRuleId`。

### 6.3 FirewallRuleDeployment

`FirewallRuleDeployment` 只记录成功下发的系统规则映射。

```ts
export interface FirewallRuleDeployment {
  localRuleId: string
  userId: number
  systemRuleId: number
}
```

不保存：

- `appliedAt`
- `status`
- `lastErrorCode`
- `lastErrorMessage`

失败只进入：

- `LogUtils.error`
- 操作结果 `failedItems`

不写入本地 deployment。

### 6.4 FirewallPreparedRule

`FirewallPreparedRule` 表示已经准备好下发到系统的一条规则。

```ts
export interface FirewallPreparedRule {
  localRuleId?: string
  userId: number
  rule: netFirewall.NetFirewallRule
}
```

`public/private` 模式生成的 `FirewallPreparedRule` 不携带 `localRuleId`。

`custom` 模式生成的 `FirewallPreparedRule` 必须携带 `localRuleId`。

`FirewallService` 下发成功后，仅对携带 `localRuleId` 的 `FirewallPreparedRule` 写入 `FirewallRuleDeployment`。

`public/private` 模式的 prepared rules 按首页模式切换语义面向所有可用用户生成。

`custom` 模式的 prepared rules 不按所有可用用户强制展开，而是按每条 `FirewallRuleIntent.targetUserIds` 生成。

## 7. FirewallSystemRepository

文件：

```text
entry/src/main/ets/services/firewall/FirewallSystemRepository.ets
```

职责：唯一系统防火墙 API 访问层。只允许它调用 `@kit.NetworkKit` 的防火墙系统接口。

### 7.1 函数清单

```ts
static async getPolicy(userId: number): Promise<netFirewall.NetFirewallPolicy | null>
```

读取指定 `userId` 的系统防火墙 policy。

来源：复用旧 `FirewallRepository.getFirewallPolicyByUserId`。

```ts
static async setPolicy(
  userId: number,
  policy: netFirewall.NetFirewallPolicy
): Promise<boolean>
```

写入指定 `userId` 的系统防火墙 policy。

来源：复用旧 `FirewallRepository.setFirewallPolicyByUserId`。

```ts
static async listRules(userId: number): Promise<netFirewall.NetFirewallRule[]>
```

分页查询指定 `userId` 下全部系统防火墙规则。

来源：改造旧 `FirewallRepository.getAllRules`。必须显式传入 `userId`，不再使用默认用户兜底。

```ts
static async addRule(rule: netFirewall.NetFirewallRule): Promise<number>
```

调用 `addNetFirewallRule` 添加一条系统规则。

来源：改造旧 `FirewallRepository.addRule`。`rule.userId` 必须由调用方提前写入。

```ts
static async removeRule(
  userId: number,
  systemRuleId: number
): Promise<boolean>
```

调用 `removeNetFirewallRule(userId, systemRuleId)` 删除规则。

来源：复用旧 `FirewallRepository.removeRuleByUserId`。

```ts
static async updateRule(rule: netFirewall.NetFirewallRule): Promise<boolean>
```

保留系统 `updateNetFirewallRule` 能力。

来源：复用旧 `FirewallRepository.updateRule`。

当前业务更新流程按“删除旧规则 + 新增新规则”实现，不依赖该函数。若后续确认无调用方，可删除。

```ts
static async clearRules(userId: number): Promise<FirewallBatchOperationResult>
```

删除指定 `userId` 下全部系统规则。

来源：改造旧 `FirewallRepository.clearAllRules`。

本模块接管设备防火墙规则。模式切换时允许清空目标 `userId` 下全部系统防火墙规则。

### 7.2 明确不提供

`FirewallSystemRepository` 不提供：

- `cloneRuleForCreate`
- `normalizeRuleForCreate`
- `getSystemRuleId`
- `clearManagedRules`
- `onlyManaged` 参数

说明：

- 新架构不需要 clone 旧规则对象。
- 从本地规则意图构造系统规则由 `FirewallRuleUtils.buildSystemRuleFromIntent` 完成。
- 创建前规范化由 `FirewallRuleUtils.normalizeRuleForCreate` 完成。
- 系统规则 ID 统一使用系统返回对象的 `id` 或 `addNetFirewallRule` 返回值，不考虑 `ruleId/id` 双字段兼容。
- 不再支持“只删除本应用管理规则”语义。

## 8. FirewallRuleUtils

文件：

```text
entry/src/main/ets/services/firewall/FirewallRuleUtils.ets
```

职责：防火墙规则纯工具。不访问 `netFirewall`，不访问 `Preferences`。

### 8.1 函数清单

```ts
static buildSystemRuleFromIntent(
  intent: FirewallRuleIntent,
  userId: number
): netFirewall.NetFirewallRule
```

根据本地规则意图和目标 `userId` 构造 `NetFirewallRule`。

来源：重新编写。

注意：只构造，不做 normalize。

系统 API 兼容约束：

- 构造出的 `NetFirewallRule` 不得携带值为 `undefined` 的可选字段。
- `cloneIpParams`、`clonePortParams`、`cloneDomainParams`、`cloneDnsParams` 返回 `undefined` 时，不得把对应字段写入 `NetFirewallRule`。
- 传给 `addNetFirewallRule` 的对象中，不允许出现 `localIps=undefined`、`localPorts=undefined`、`remotePorts=undefined`、`domains=undefined`、`dns=undefined`、`protocol=undefined` 等 key。
- 该约束由 `FirewallRuleUtils` 的规则构造和创建前规范化保证，不下沉到 `FirewallSystemRepository` 兜底修正。

```ts
static normalizeRuleForCreate(
  rule: netFirewall.NetFirewallRule
): netFirewall.NetFirewallRule
```

调用 `addNetFirewallRule` 前规范化系统规则参数。

来源：改造旧 `FirewallRepository.normalizeRuleForCreate`。

注意：不要和 `buildSystemRuleFromIntent` 合并。

注意：规范化后的对象仍需满足“只写入有效 optional 字段”的约束，不得在 clone 过程中重新写回 `undefined` key。

```ts
static validateRuleIntentInput(input: FirewallRuleIntentInput): FirewallRuleValidationResult
```

校验新增/编辑规则输入。

来源：重新编写，部分吸收 `AddRuleDialog` 当前校验逻辑。

```ts
static normalizeUserIds(userIds: number[]): number[]
```

用户 ID 去重、过滤、排序。

来源：改造复用当前 `normalizeFirewallRuleUserIds`。

```ts
static findRuleConflict(
  existingIntents: FirewallRuleIntent[],
  targetIntent: FirewallRuleIntent,
  excludeLocalRuleId?: string
): FirewallRuleConflictResult | null
```

基于本地规则意图判断重复/冲突。

来源：改造旧 `FirewallRulesService.findRuleConflict`。

```ts
static summarizeConflicts(intents: FirewallRuleIntent[]): FirewallConflictSummary
```

汇总规则冲突数量。

来源：改造旧 `FirewallRulesService.summarizeConflicts`。

```ts
static countByType(intents: FirewallRuleIntent[], type: number): number
```

按规则类型统计。

来源：复用旧 `countByType` 思路。

```ts
static countByDirection(intents: FirewallRuleIntent[], direction: number): number
```

按规则方向统计。

来源：复用旧 `countByDirection` 思路。

### 8.2 删除旧 metadata 逻辑

删除：

- `buildManagedRuleDescription`
- `parseManagedRuleDescription`
- `applyManagedRuleMetadata`

原因：

- 不再识别“本应用管理的规则”。
- 不再需要通过系统规则 `description` 反查本地规则关系。
- 不再需要识别系统规则属于 `public/private/custom` 模式。
- 本地与系统规则关系只由 `FirewallRuleIntentMappingData.ruleDeployments` 表达。

## 9. FirewallLocalRepository

文件：

```text
entry/src/main/ets/services/firewall/FirewallLocalRepository.ets
```

职责：唯一防火墙本地 Preferences 数据访问层。只允许它读写防火墙本地持久化数据。

### 9.1 函数清单

```ts
static async loadRuleIntentMappingData(context): Promise<FirewallRuleIntentMappingData>
```

读取本地规则意图和成功 deployments。

来源：重新编写。

```ts
static async saveRuleIntentMappingData(
  context,
  data: FirewallRuleIntentMappingData
): Promise<boolean>
```

保存完整本地规则映射数据。

来源：重新编写。

```ts
static async listRuleIntents(context): Promise<FirewallRuleIntent[]>
```

读取自定义规则意图列表。

来源：基于新 mapping data 重写。

```ts
static async getRuleIntent(
  context,
  localRuleId: string
): Promise<FirewallRuleIntent | null>
```

按 `localRuleId` 查询规则意图。

来源：重新编写。

```ts
static async saveRuleIntent(
  context,
  intent: FirewallRuleIntent
): Promise<boolean>
```

新增或更新本地规则意图。

来源：重新编写。

```ts
static async removeRuleIntent(
  context,
  localRuleId: string
): Promise<boolean>
```

删除本地规则意图。

来源：重新编写。

```ts
static async listRuleDeployments(
  context,
  localRuleId?: string
): Promise<FirewallRuleDeployment[]>
```

读取成功下发的系统规则映射。

来源：重新编写。

```ts
static async replaceRuleDeployments(
  context,
  localRuleId: string,
  deployments: FirewallRuleDeployment[]
): Promise<boolean>
```

替换某条规则的成功下发映射。

来源：重新编写。

```ts
static async removeRuleDeployments(
  context,
  localRuleId: string
): Promise<boolean>
```

删除某条规则的所有 deployments。

来源：重新编写。

```ts
static async clearAllRuleDeployments(context): Promise<boolean>
```

清空 `FirewallRuleIntentMappingData.ruleDeployments`。

只清 deployments，不清 `ruleIntents`。

使用场景：`switchMode` 调用 `FirewallSystemRepository.clearRules(userId)` 后，旧 deployments 对应的系统规则已经被删除或不再可信，必须同步清空本地 deployments。

来源：重新编写。

```ts
static async getCurrentMode(context): Promise<FirewallPresetMode>
```

读取当前 `public/private/custom` 模式。

来源：复用旧 `FirewallModeRepository`。

```ts
static async saveCurrentMode(
  context,
  mode: FirewallPresetMode
): Promise<boolean>
```

保存当前 `public/private/custom` 模式。

来源：复用旧 `FirewallModeRepository`。

```ts
static async getUserPolicyMode(
  context,
  userId: number
): Promise<FirewallUserPolicyMode | undefined>
```

读取用户黑/白名单模式记录。

来源：改造旧 `FirewallUserBindingsRepository.getBindingMode`。

```ts
static async saveUserPolicyMode(
  context,
  userId: number,
  mode: FirewallUserPolicyMode
): Promise<boolean>
```

保存用户黑/白名单模式记录。

来源：改造旧 `FirewallUserBindingsRepository.saveBindingMode`。

```ts
static async listUserPolicyModes(context): Promise<FirewallUserPolicyModeRecord[]>
```

读取所有用户黑/白名单模式记录。

来源：改造旧 `FirewallUserBindingsRepository.loadBindings`。

## 10. FirewallModeStrategy

文件：

```text
entry/src/main/ets/services/firewall/FirewallModeStrategy.ets
```

职责：只负责模式规则生成，不负责下发，不写本地数据。

### 10.1 函数清单

```ts
static async buildRulesForMode(
  context,
  mode: FirewallPresetMode
): Promise<FirewallPreparedRule[]>
```

根据模式生成要下发的系统规则。

来源：改造旧 `FirewallModeStrategyFactory`。

```ts
static async buildPublicRules(context): Promise<FirewallPreparedRule[]>
```

生成公共网络模式规则。

来源：改造旧 `FirewallModeRuleBuilder.buildPublicRules`。

```ts
static async buildPrivateRules(context): Promise<FirewallPreparedRule[]>
```

生成私有网络模式规则。

来源：改造旧 `FirewallModeRuleBuilder.buildPrivateRules`。

```ts
static async buildCustomRules(context): Promise<FirewallPreparedRule[]>
```

读取本地 `FirewallRuleIntent`，按每条规则自己的 `targetUserIds` 构造系统规则。

来源：重新编写。

```ts
static async loadPresetConfig(context): Promise<FirewallPresetConfig>
```

读取预设配置。

来源：复用旧 `FirewallPresetConfigReader`。

### 10.2 模式规则持久化边界

`public/private` 模式生成规则不写入 `FirewallRuleIntentMappingData`。

`custom` 模式规则来自 `FirewallRuleIntentMappingData`。

`custom` 模式下发时，以每条规则自己的 `targetUserIds` 为准，不强行给所有用户下发。

`public/private` 返回的 `FirewallPreparedRule` 不携带 `localRuleId`，下发成功后不写 deployments。

`custom` 返回的 `FirewallPreparedRule` 必须携带 `localRuleId`，下发成功后由 `FirewallService` 写入成功 deployments。

### 10.3 用户来源边界

首页模式切换已经确认针对所有用户。

`FirewallModeStrategy` 允许在生成 `public/private` 模式规则时调用 `SystemUserProvider.loadAvailableUserIds()`，并按所有可用用户生成 `FirewallPreparedRule`。

`custom` 模式不使用所有可用用户作为强制目标。`custom` 必须读取 `FirewallLocalRepository.listRuleIntents(context)`，并按每条 `FirewallRuleIntent.targetUserIds` 生成 `FirewallPreparedRule`。

该授权不改变 Strategy 边界：

- Strategy 不允许调用 `FirewallSystemRepository.addRule/removeRule/clearRules`。
- Strategy 不允许调用 `FirewallLocalRepository.save*` 写本地数据。
- Strategy 不允许写 policy。
- Strategy 只生成 prepared rules。

## 11. FirewallService

文件：

```text
entry/src/main/ets/services/firewall/FirewallService.ets
```

职责：唯一业务编排入口。

### 11.1 函数清单

```ts
static async loadOverviewState(context): Promise<FirewallOverviewState>
```

加载防火墙是否开启和当前模式。

来源：改造旧 `FirewallService.loadOverviewState`。

```ts
static async setFirewallEnabledForAllUsers(
  context,
  enabled: boolean
): Promise<FirewallBatchOperationResult>
```

PIN 认证后，为所有用户设置 `policy.isOpen`。

来源：改造旧 `toggleFirewall/applyHomeToggleForAllUsers`。

认证：直接调用 `AuthService.authenticate(AuthMethod.PIN)`。

```ts
static async switchMode(
  context,
  mode: FirewallPresetMode
): Promise<FirewallOperationResult>
```

切换 `public/private/custom`，不需要认证。

流程：

1. 读取用户列表。
2. 对每个目标 `userId` 调 `clearRules(userId)`。
3. 调 `FirewallLocalRepository.clearAllRuleDeployments(context)`，清空旧 deployments，不清 intents。
4. 调 `FirewallModeStrategy.buildRulesForMode(context, mode)`，得到 `FirewallPreparedRule[]`。
5. 逐条调用 `FirewallSystemRepository.addRule(prepared.rule)`。
6. 对携带 `localRuleId` 的 `FirewallPreparedRule`，系统下发成功后收集新的 `FirewallRuleDeployment`。
7. 如果存在新的 custom deployments，按 `localRuleId` 写回成功 deployments。
8. 无论是否存在 `failedItems`，都保存目标模式。
9. 失败只写日志和返回 `failedItems`，不回滚。

来源：改造旧 `FirewallModeStrategyFactory.switchMode`。

```ts
static async listRulesForDisplay(context): Promise<FirewallRuleDisplayItem[]>
```

从本地 `ruleIntents + deployments` 构建规则页展示数据。

来源：重新编写。

```ts
static async createRule(
  context,
  input: FirewallRuleIntentInput
): Promise<FirewallRuleMutationResult>
```

新增自定义规则，不需要认证。

已确认流程：

1. 校验 `input`。
2. 生成 `localRuleId`。
3. 构造 `intent`，但暂不保存。
4. 遍历 `targetUserIds`。
5. 调 `FirewallRuleUtils.buildSystemRuleFromIntent`。
6. 调 `FirewallRuleUtils.normalizeRuleForCreate`。
7. 调 `FirewallSystemRepository.addRule`。
8. 收集成功 deployments。
9. 全部失败：不保存 intent，不保存 deployments，只返回失败。
10. 部分或全部成功：保存 intent 和成功 deployments。
11. 本地保存失败：不回滚系统规则，只写日志并返回失败。

来源：重新编写。

```ts
static async updateRule(
  context,
  localRuleId: string,
  input: FirewallRuleIntentInput
): Promise<FirewallRuleMutationResult>
```

更新自定义规则，不需要认证。

已确认流程：

1. 查询旧 deployments。
2. 删除旧 deployments 对应系统规则。
3. 删除旧 deployments。
4. 按 `createRule` 的系统下发流程重新下发。
5. 保存新的 intent 和 deployments。
6. 失败不回滚。

来源：重新编写。

```ts
static async deleteRule(
  context,
  localRuleId: string
): Promise<FirewallRuleMutationResult>
```

删除自定义规则，不需要认证。

流程：

1. 查询 deployments。
2. 删除对应系统规则。
3. 删除 deployments。
4. 删除 intent。
5. 失败不回滚。

来源：重新编写。

```ts
static async applyUserPolicyMode(
  context,
  userId: number,
  mode: FirewallUserPolicyMode
): Promise<FirewallUserPolicyApplyResult>
```

PIN 认证后，为指定用户下发黑/白名单 `policy-only` 策略。

来源：改造旧 `FirewallStore.applyUserModeInternal`。

认证：直接调用 `AuthService.authenticate(AuthMethod.PIN)`。

```ts
static async loadUserPolicyState(
  context,
  userId: number
): Promise<FirewallUserPolicyStateResult>
```

读取用户当前 policy 摘要和本地黑/白名单模式记录。

来源：改造旧 `loadUserModeState`。

### 11.2 明确不保留

`FirewallService` 不保留：

- `loadUserOptions`
- `authenticatePinForProtectedAction`
- 旧 `applyUserMode` 规则筛选/重放语义
- 旧 `saveCustomRules` reapply 语义

## 12. SystemUserProvider

文件：

```text
entry/src/main/ets/services/firewall/providers/SystemUserProvider.ets
```

保留，但边界收紧。

允许：

- 读取系统用户列表。
- 输出用户选择项。
- 读取用户 policy 摘要。

不允许：

- 写 policy。
- 添加、删除或更新规则。
- 读写本地用户模式。
- 读写防火墙本地规则 mapping。

读取用户 policy 摘要时，应通过 `FirewallSystemRepository.getPolicy(userId)`，避免系统防火墙 API 入口扩散。

## 13. ViewModel 职责

### 13.1 FirewallOverviewViewModel

保留。

职责：

- 防火墙主页状态。
- 调用 `FirewallService.loadOverviewState`。
- 调用 `FirewallService.setFirewallEnabledForAllUsers`。
- 调用 `FirewallService.switchMode`。

### 13.2 FirewallRulesViewModel

保留。

职责：

- 规则页状态。
- 调用 `FirewallService.listRulesForDisplay`。
- 调用 `FirewallService.createRule`。
- 调用 `FirewallService.updateRule`。
- 调用 `FirewallService.deleteRule`。

### 13.3 FirewallUserDispatchViewModel

保留。

职责：

- 用户策略下发弹窗状态。
- 直接调用 `SystemUserProvider.loadAvailableUserIds`。
- 调用 `FirewallService.loadUserPolicyState`。
- 调用 `FirewallService.applyUserPolicyMode`。

后续可按专项改名为 `FirewallUserPolicyViewModel`，但本轮不强制。

## 14. 认证语义

删除：

- `entry/src/main/ets/services/firewall/auth/FirewallAuthService.ets`
- `entry/src/main/ets/services/firewall/stores/FirewallAuthStateStore.ets`

防火墙模块不再维护专属 PIN 失败次数和锁定状态。

需要 PIN 认证的操作：

- 防火墙总开关：`FirewallService.setFirewallEnabledForAllUsers`
- 用户黑/白名单 policy-only 下发：`FirewallService.applyUserPolicyMode`

不需要 PIN 认证的操作：

- `switchMode`
- `createRule`
- `updateRule`
- `deleteRule`

需要认证时，在业务函数中直接调用：

```ts
AuthService.authenticate(AuthMethod.PIN)
```

不新增 `authenticatePinForProtectedAction` 包装函数。

## 15. 黑/白名单 policy-only 语义

用户模式下发为 `policy-only`，不读取规则模板，不筛选规则，不清理规则，不重放规则。

按此前讨论确认的语义执行：

- 白名单模式：写入完整 `NetFirewallPolicy`
- 黑名单模式：写入完整 `NetFirewallPolicy`

具体 `inAction/outAction` 常量值以实现阶段的最终枚举映射为准，但不得重新引入“用户模式读取规则模板并筛选规则下发”的旧语义。

成功后保存本地：

```text
userId -> FirewallUserPolicyMode
```

## 16. 模式切换语义

模式切换接管目标用户的系统防火墙规则。

`switchMode` 时允许清空目标 `userId` 下全部系统防火墙规则。

模式切换时，`clearRules(userId)` 会使旧 deployments 失效。因此 `switchMode` 必须调用 `FirewallLocalRepository.clearAllRuleDeployments(context)` 清空本地 deployments，但不得清空 `ruleIntents`。

`public/private`：

- 由 `FirewallModeStrategy` 生成系统规则。
- `FirewallModeStrategy` 调用 `SystemUserProvider.loadAvailableUserIds()`，按所有可用用户生成 `FirewallPreparedRule`。
- 不写入 `FirewallRuleIntentMappingData`。
- 切换后 `ruleDeployments` 保持为空，除非后续又切回 `custom` 并成功下发自定义规则。
- 下发成功后不写 deployments。

`custom`：

- 从 `FirewallRuleIntentMappingData.ruleIntents` 读取本地自定义规则。
- 每条规则按自身 `targetUserIds` 下发。
- 不强行给所有用户下发。
- 下发成功后，只写入成功的 custom deployments。

失败处理：

- 写日志。
- 返回 `failedItems`。
- 不做快照。
- 不做回滚。
- 无论 `failedItems` 是否为空，都保存目标模式。

## 17. createRule 语义

`createRule` 采用“先尝试系统下发，再保存 intent 和成功 deployments”的流程。

流程：

1. 校验输入。
2. 生成 `localRuleId`。
3. 构造 `FirewallRuleIntent`，暂不保存。
4. 对每个 `targetUserId` 构造系统规则。
5. 调 `normalizeRuleForCreate`。
6. 调 `FirewallSystemRepository.addRule`。
7. 收集成功 deployments。
8. 全部失败时，不保存本地数据。
9. 部分或全部成功时，保存 intent 和成功 deployments。
10. 本地保存失败时，不回滚系统规则。

边界：

- 失败 deployment 不入库。
- 本地保存失败可能导致系统规则已生效但本地未记录，该风险由“不回滚”原则接受。

## 18. updateRule 语义

`updateRule` 采用简单流程：

1. 查询旧 deployments。
2. 删除旧 deployments 对应系统规则。
3. 删除旧 deployments。
4. 按新输入重新执行新增下发流程。
5. 保存新的 intent 和 deployments。
6. 失败不回滚。

若重新下发失败，旧规则可能已被删除。该边界由“不回滚”原则接受。

## 19. deleteRule 语义

`deleteRule` 流程：

1. 查询 deployments。
2. 删除 deployments 对应系统规则。
3. 删除 deployments。
4. 删除 intent。
5. 失败不回滚。

如果部分系统删除失败：

- 写日志。
- 返回 failedItems。
- 本地删除策略以实现阶段确定，但不得引入快照回滚。

## 20. 旧代码清理清单

### 20.1 直接删除

```text
entry/src/main/ets/services/firewall/auth/FirewallAuthService.ets
entry/src/main/ets/services/firewall/stores/FirewallAuthStateStore.ets
entry/src/main/ets/services/firewall/stores/FirewallStore.ets
entry/src/main/ets/services/firewall/user-dispatch/FirewallUserDispatchService.ets
entry/src/main/ets/models/firewall/firewall_service_contracts.ets
```

### 20.2 迁移后删除

```text
entry/src/main/ets/services/firewall/repositories/FirewallRepository.ets
entry/src/main/ets/services/firewall/repositories/FirewallCustomRulesRepository.ets
entry/src/main/ets/services/firewall/repositories/FirewallUserBindingsRepository.ets
entry/src/main/ets/services/firewall/repositories/FirewallModeRepository.ets
entry/src/main/ets/services/firewall/mode-strategies/FirewallModeStrategyFactory.ets
entry/src/main/ets/services/firewall/mode-strategies/FirewallModeStrategy.ets
entry/src/main/ets/services/firewall/mode-strategies/PresetModeStrategy.ets
entry/src/main/ets/services/firewall/mode-strategies/CustomModeStrategy.ets
entry/src/main/ets/services/firewall/mode-strategies/FirewallModeRuleBuilder.ets
entry/src/main/ets/services/firewall/mode-strategies/FirewallPresetConfigReader.ets
entry/src/main/ets/services/firewall/rules/FirewallRulesService.ets
```

`FirewallRulesService.ets` 的有效逻辑迁入：

```text
entry/src/main/ets/services/firewall/FirewallRuleUtils.ets
```

## 21. 腐败代码判定

重构完成后，下列代码视为腐败代码，必须删除：

1. `snapshot`、`rollback`、`restore` 相关逻辑。
2. `FirewallAuthService` 与 `FirewallAuthStateStore` 链路。
3. 用户模式中读取规则、筛选规则、清理规则、重放规则的旧逻辑。
4. 规则 `description` metadata 识别本应用规则的逻辑。
5. `onlyManaged` 与 `clearManagedRules` 语义。
6. 旧 `customRuleId-only` 本地模型作为主流程继续存在。
7. `public/private` 规则写入自定义规则本地 mapping 的逻辑。
8. 失败 deployment 入库逻辑。
9. 除 `FirewallSystemRepository` 之外调用 `netFirewall` 防火墙系统 API 的代码。
10. 除 `FirewallLocalRepository` 之外读写防火墙本地 Preferences 的代码。
11. 只为兼容旧目录存在且无长期职责的 wrapper 文件。

## 22. 验收信号

完成后应满足：

1. View 只依赖 ViewModel。
2. ViewModel 不直接调用 `netFirewall`。
3. ViewModel 不直接读写 `Preferences`。
4. 系统防火墙 API 只在 `FirewallSystemRepository`。
5. 防火墙本地 Preferences 只在 `FirewallLocalRepository`。
6. `FirewallAuthService` 已删除。
7. `FirewallAuthStateStore` 已删除。
8. `firewall_service_contracts.ets` 已删除。
9. `FirewallRuleDeployment` 不包含 `appliedAt`、`status`、`lastErrorCode`、`lastErrorMessage`。
10. `FirewallRuleUtils` 不包含 metadata 构造、解析和写入函数。
11. `switchMode` 不做快照和回滚。
12. `createRule/updateRule/deleteRule` 不做快照和回滚。
13. 用户黑/白名单下发为 `policy-only`，不再读取规则模板和重放规则。
14. `public/private` 模式规则不写入 `FirewallRuleIntentMappingData`。
15. `custom` 模式按每条规则自己的 `targetUserIds` 下发。
16. `FirewallModeStrategy` 返回 `FirewallPreparedRule[]`，不是裸 `NetFirewallRule[]`。
17. `custom` 模式生成的 `FirewallPreparedRule` 必须携带 `localRuleId`。
18. `public/private` 模式生成的 `FirewallPreparedRule` 不写 deployments。
19. `switchMode` 会调用 `FirewallLocalRepository.clearAllRuleDeployments(context)`。
20. `switchMode` 不管 `failedItems` 是否为空，都保存目标模式。
21. `public/private` 模式 prepared rules 按所有可用用户生成。
22. `custom` 模式 prepared rules 只按 intent 自身 `targetUserIds` 生成。
23. `FirewallModeStrategy` 不写系统规则、不写本地数据、不写 policy。

## 23. 后续更新规则

如果后续讨论改变以下内容，必须先更新本文档，再改代码：

1. 核心文件列表。
2. Repository 职责边界。
3. `FirewallRuleIntentMappingData` 结构。
4. `createRule/updateRule/deleteRule` 失败处理语义。
5. `switchMode` 是否允许清空目标用户全部规则。
6. 用户黑/白名单 policy-only 语义。
7. 是否恢复快照、回滚、metadata 或只删除本应用规则语义。

未经本文档更新，不得在实现中引入与本文冲突的第二套真相。
