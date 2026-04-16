# 防火墙架构重构实施计划

> 状态：Draft  
> 日期：2026-04-16  
> 规格来源：`docs/refac/firewall/firewall-architecture-refactor-single-source-of-truth.md`  
> 分支：`task/firewall-architecture-refactor-plan`  
> 独立 worktree：`D:\project\ai\security_tool-firewall-architecture-refactor-plan`  
> 执行方式：唯一 worktree 串行推进，不派生子分支，不派生子 worktree，不多 session 并行改代码  

## 1. 工作区与分支

唯一允许工作环境：

```text
worktree: D:\project\ai\security_tool-firewall-architecture-refactor-plan
branch: task/firewall-architecture-refactor-plan
SSOT: docs/refac/firewall/firewall-architecture-refactor-single-source-of-truth.md
```

执行前必须确认：

```powershell
git -C D:\project\ai\security_tool-firewall-architecture-refactor-plan branch --show-current
git -C D:\project\ai\security_tool-firewall-architecture-refactor-plan status --short --branch
```

必须满足：

```text
branch = task/firewall-architecture-refactor-plan
working tree clean 或只有当前步骤预期变更
```

## 2. 背景

当前防火墙模块存在以下问题：

1. `FirewallStore` 混合本地存储、系统调用、用户模式下发和快照回滚。
2. 旧 `repositories` / `mode-strategies` 文件过多，职责交叉。
3. 用户黑/白名单模式残留规则筛选、规则清理和规则重放旧语义。
4. `description` metadata 反查本应用规则属于过度设计。
5. `snapshot` / `rollback` / `restore` / `reapply` 形成伪事务。
6. `FirewallAuthService` / `FirewallAuthStateStore` 与项目公共 PIN 认证能力重复。

## 3. 目的

本轮实施目标：

1. 建立 `FirewallSystemRepository` 作为唯一系统防火墙 API 入口。
2. 建立 `FirewallLocalRepository` 作为唯一防火墙本地 Preferences 入口。
3. 建立 `FirewallRuleIntentMappingData`，保存自定义规则 intent 和成功 deployments。
4. 建立 `FirewallPreparedRule`，保留模式下发时的 `localRuleId` 上下文。
5. 重建 `createRule` / `updateRule` / `deleteRule`。
6. 重建 `switchMode`：清系统规则、清 deployments、生成 prepared rules、下发、写回 custom deployments、保存目标模式。
7. 删除快照、回滚、restore、reapply。
8. 删除 `FirewallAuthService` / `FirewallAuthStateStore`。
9. 删除 metadata 反查逻辑。
10. 删除旧用户模式规则筛选/重放逻辑。

## 4. 修改代码文件范围

### 4.1 新增文件

```text
entry/src/main/ets/services/firewall/FirewallModels.ets
entry/src/main/ets/services/firewall/FirewallSystemRepository.ets
entry/src/main/ets/services/firewall/FirewallLocalRepository.ets
entry/src/main/ets/services/firewall/FirewallModeStrategy.ets
entry/src/main/ets/services/firewall/FirewallRuleUtils.ets
```

### 4.2 修改文件

```text
entry/src/main/ets/services/firewall/FirewallService.ets
entry/src/main/ets/services/firewall/providers/SystemUserProvider.ets
entry/src/main/ets/viewmodels/firewall/overview/FirewallOverviewViewModel.ets
entry/src/main/ets/viewmodels/firewall/rules/FirewallRulesViewModel.ets
entry/src/main/ets/viewmodels/firewall/user-dispatch/FirewallUserDispatchViewModel.ets
entry/src/main/ets/views/firewall/overview/FirewallPage.ets
entry/src/main/ets/views/firewall/rules/FirewallRulesPage.ets
entry/src/main/ets/components/firewall/rules/AddRuleDialog.ets
entry/src/main/ets/components/firewall/user-dispatch/UserFirewallControlDialog.ets
entry/src/main/ets/constants/modules/FirewallStrings.ets
entry/src/main/ets/models/DataModels.ets
```

### 4.3 删除文件

```text
entry/src/main/ets/services/firewall/auth/FirewallAuthService.ets
entry/src/main/ets/services/firewall/stores/FirewallAuthStateStore.ets
entry/src/main/ets/services/firewall/stores/FirewallStore.ets
entry/src/main/ets/services/firewall/user-dispatch/FirewallUserDispatchService.ets
entry/src/main/ets/models/firewall/firewall_service_contracts.ets
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

### 4.4 测试文件范围

```text
entry/src/test/firewall/service.test.ets
entry/src/test/firewall/rules-service.test.ets
entry/src/test/firewall/auth-service.test.ets
entry/src/test/firewall/auth-state-store.test.ets
entry/src/test/firewall/user-dispatch.test.ets
entry/src/test/firewall/strategy-factory.test.ets
entry/src/test/firewall/mode-rule-builder.test.ets
entry/src/test/firewall/custom-mode-strategy.test.ets
entry/src/test/firewall/models.test.ets
entry/src/test/firewall/strings.test.ets
entry/src/test/firewall/__mocks__/MockNetFirewall.ets
entry/src/test/__fakes__/FakeFirewallPort.ets
```

## 5. Step 0：环境确认

### 输入

```text
SSOT
唯一 worktree
```

### 输出

```text
确认当前在 task/firewall-architecture-refactor-plan
```

### 验收标准

```text
branch --show-current 输出 task/firewall-architecture-refactor-plan
status 无非预期变更
```

### 并行性

不可并行。

## 6. Step 1：落地 FirewallModels

### 输入

```text
SSOT 第 6 节
旧 firewall_service_contracts.ets
DataModels 中防火墙相关旧类型
```

### 输出

```text
新增 FirewallModels.ets
迁入服务结果类型
新增 FirewallRuleIntentMappingData
新增 FirewallRuleIntent
新增 FirewallRuleDeployment
新增 FirewallPreparedRule
新增批处理结果类型
```

### 验收标准

```text
FirewallRuleDeployment 不包含 appliedAt/status/lastErrorCode/lastErrorMessage
FirewallPreparedRule 包含 localRuleId?: string、userId、rule
firewall_service_contracts.ets 中类型已有替代
```

### 伪代码

```ts
export interface FirewallRuleIntentMappingData {
  version: number
  ruleIntents: FirewallRuleIntent[]
  ruleDeployments: FirewallRuleDeployment[]
}

export interface FirewallRuleDeployment {
  localRuleId: string
  userId: number
  systemRuleId: number
}

export interface FirewallPreparedRule {
  localRuleId?: string
  userId: number
  rule: netFirewall.NetFirewallRule
}
```

### 腐败代码处理

```text
firewall_service_contracts.ets 标记为待删除
DataModels 不再新增防火墙新模型，只做旧模型收口
```

## 7. Step 2：落地 FirewallSystemRepository

### 输入

```text
旧 FirewallRepository.ets
SSOT 第 7 节
```

### 输出

```text
新增 FirewallSystemRepository.ets
系统防火墙 API 访问能力迁入
```

### 验收标准

```text
不读写 Preferences
不包含 cloneRuleForCreate
不包含 normalizeRuleForCreate
不包含 getSystemRuleId
不包含 clearManagedRules / onlyManaged
listRules 必须显式 userId
clearRules 删除 userId 下全部规则
```

### 伪代码

```ts
export class FirewallSystemRepository {
  static async listRules(userId: number): Promise<netFirewall.NetFirewallRule[]> {
    const allRules: netFirewall.NetFirewallRule[] = []
    let page = 1
    while (true) {
      const result = await netFirewall.getNetFirewallRules(userId, buildRequest(page))
      const rules = result.data ?? []
      allRules.push(...rules)
      if (rules.length < 50) {
        break
      }
      page++
    }
    return allRules
  }

  static async clearRules(userId: number): Promise<FirewallBatchOperationResult> {
    const rules = await this.listRules(userId)
    const failedItems: FirewallBatchFailedItem[] = []
    for (const rule of rules) {
      const success = await this.removeRule(userId, rule.id)
      if (!success) {
        failedItems.push({ userId, systemRuleId: rule.id })
      }
    }
    return buildBatchResult(rules.length - failedItems.length, failedItems)
  }
}
```

### 腐败代码处理

```text
旧 FirewallRepository.ets 迁完后删除
除 FirewallSystemRepository 外不得调用 netFirewall 防火墙 API
```

## 8. Step 3：落地 FirewallRuleUtils

### 输入

```text
旧 FirewallRulesService.ets
旧 FirewallRepository.normalizeRuleForCreate
Ipv4Utils
```

### 输出

```text
新增 FirewallRuleUtils.ets
规则构造、规范化、校验、冲突判断迁入
metadata 函数不迁入
```

### 验收标准

```text
不访问 netFirewall 系统 API
不访问 Preferences
buildSystemRuleFromIntent 只构造，不 normalize
normalizeRuleForCreate 单独存在
不包含 buildManagedRuleDescription / parseManagedRuleDescription / applyManagedRuleMetadata
```

### 伪代码

```ts
export class FirewallRuleUtils {
  static buildSystemRuleFromIntent(intent: FirewallRuleIntent, userId: number): netFirewall.NetFirewallRule {
    return {
      userId,
      name: intent.name,
      type: intent.type,
      direction: intent.direction,
      action: intent.action,
      isEnabled: intent.isEnabled,
      protocol: intent.protocol,
      remoteIps: cloneIpParams(intent.remoteIps),
      localIps: cloneIpParams(intent.localIps),
      localPorts: clonePortParams(intent.localPorts),
      remotePorts: clonePortParams(intent.remotePorts),
      domains: cloneDomainParams(intent.domains),
      dns: cloneDnsParams(intent.dns)
    }
  }

  static normalizeRuleForCreate(rule: netFirewall.NetFirewallRule): netFirewall.NetFirewallRule {
    return normalizeCreatePayload(rule)
  }
}
```

### 腐败代码处理

```text
metadata 相关函数删除
旧 FirewallRulesService.ets 迁完后删除
```

## 9. Step 4：落地 FirewallLocalRepository

### 输入

```text
旧 FirewallCustomRulesRepository.ets
旧 FirewallUserBindingsRepository.ets
旧 FirewallModeRepository.ets
PreferencesAccessor
```

### 输出

```text
新增 FirewallLocalRepository.ets
本地 Preferences 数据访问收口
新增 clearAllRuleDeployments
```

### 验收标准

```text
不调用 netFirewall
clearAllRuleDeployments 只清 deployments，不清 intents
规则本地持久化只使用 FirewallRuleIntentMappingData
失败 deployment 不入库
```

### 伪代码

```ts
export class FirewallLocalRepository {
  static async clearAllRuleDeployments(context): Promise<boolean> {
    const data = await this.loadRuleIntentMappingData(context)
    data.ruleDeployments = []
    return this.saveRuleIntentMappingData(context, data)
  }

  static async replaceRuleDeployments(context, localRuleId, deployments): Promise<boolean> {
    const data = await this.loadRuleIntentMappingData(context)
    data.ruleDeployments = data.ruleDeployments.filter(item => item.localRuleId !== localRuleId)
    data.ruleDeployments.push(...deployments)
    return this.saveRuleIntentMappingData(context, data)
  }
}
```

### 腐败代码处理

```text
FirewallCustomRulesRepository / FirewallUserBindingsRepository / FirewallModeRepository 迁完后删除
旧 customRuleId-only 模型不得继续作为主链路
```

## 10. Step 5：落地 FirewallModeStrategy

### 输入

```text
FirewallPreparedRule
FirewallLocalRepository
FirewallRuleUtils
SystemUserProvider
旧 mode-strategies 目录
```

### 输出

```text
新增 FirewallModeStrategy.ets
buildRulesForMode 返回 FirewallPreparedRule[]
public/private 内部调用 SystemUserProvider.loadAvailableUserIds
public/private 按所有可用用户生成 prepared rules
public/private prepared rule 不带 localRuleId
custom 读取 ruleIntents，按 intent.targetUserIds 生成 prepared rules
custom prepared rule 必须带 localRuleId
```

### 验收标准

```text
FirewallModeStrategy 不调用 FirewallSystemRepository.addRule/removeRule/clearRules
FirewallModeStrategy 不写本地数据
FirewallModeStrategy 不写 policy
public/private 不写 deployments
custom 只生成带 localRuleId 的 prepared rules
```

### 伪代码

```ts
export class FirewallModeStrategy {
  static async buildRulesForMode(context, mode): Promise<FirewallPreparedRule[]> {
    if (mode === 'public') {
      return this.buildPublicRules(context)
    }
    if (mode === 'private') {
      return this.buildPrivateRules(context)
    }
    return this.buildCustomRules(context)
  }

  static async buildPublicRules(context): Promise<FirewallPreparedRule[]> {
    const users = await SystemUserProvider.loadAvailableUserIds()
    const templates = await buildPublicRuleTemplates(context)
    return expandTemplatesForUsers(templates, users)
  }

  static async buildCustomRules(context): Promise<FirewallPreparedRule[]> {
    const intents = await FirewallLocalRepository.listRuleIntents(context)
    const prepared: FirewallPreparedRule[] = []
    for (const intent of intents) {
      for (const userId of intent.targetUserIds) {
        const rule = FirewallRuleUtils.buildSystemRuleFromIntent(intent, userId)
        prepared.push({
          localRuleId: intent.localRuleId,
          userId,
          rule: FirewallRuleUtils.normalizeRuleForCreate(rule)
        })
      }
    }
    return prepared
  }
}
```

### 腐败代码处理

```text
旧 mode-strategies 目录迁完后删除
不得保留 StrategyFactory wrapper
```

## 11. Step 6：重构 FirewallService 主流程

### 输入

```text
FirewallSystemRepository
FirewallLocalRepository
FirewallModeStrategy
FirewallRuleUtils
SystemUserProvider
AuthService
```

### 输出

```text
FirewallService 成为唯一业务编排入口
实现 loadOverviewState
实现 setFirewallEnabledForAllUsers
实现 switchMode
实现 listRulesForDisplay
实现 createRule/updateRule/deleteRule
实现 applyUserPolicyMode/loadUserPolicyState
```

### 验收标准

```text
不直接调用 netFirewall
不直接读写 Preferences
不依赖 FirewallAuthService
不依赖 FirewallStore
不依赖 FirewallUserDispatchService
switchMode 调 clearAllRuleDeployments
switchMode 无论 failedItems 是否为空都 saveCurrentMode
createRule 先系统下发，再保存 intent 和成功 deployments
custom switchMode 下发成功后写回 deployments
```

### 伪代码

```ts
static async switchMode(context, mode): Promise<FirewallOperationResult> {
  const users = await SystemUserProvider.loadAvailableUserIds()
  const failedItems: FirewallBatchFailedItem[] = []

  for (const user of users) {
    const clearResult = await FirewallSystemRepository.clearRules(user.userId)
    failedItems.push(...clearResult.failedItems)
  }

  await FirewallLocalRepository.clearAllRuleDeployments(context)

  const preparedRules = await FirewallModeStrategy.buildRulesForMode(context, mode)
  const deploymentsByRuleId = new Map<string, FirewallRuleDeployment[]>()

  for (const prepared of preparedRules) {
    const systemRuleId = await FirewallSystemRepository.addRule(prepared.rule)
    if (systemRuleId > 0) {
      if (prepared.localRuleId !== undefined) {
        appendDeployment(deploymentsByRuleId, prepared.localRuleId, {
          localRuleId: prepared.localRuleId,
          userId: prepared.userId,
          systemRuleId
        })
      }
      continue
    }
    failedItems.push({ localRuleId: prepared.localRuleId, userId: prepared.userId })
  }

  for (const [localRuleId, deployments] of deploymentsByRuleId.entries()) {
    await FirewallLocalRepository.replaceRuleDeployments(context, localRuleId, deployments)
  }

  await FirewallLocalRepository.saveCurrentMode(context, mode)

  return {
    success: failedItems.length === 0,
    failedItems
  }
}
```

```ts
static async createRule(context, input): Promise<FirewallRuleMutationResult> {
  const validation = FirewallRuleUtils.validateRuleIntentInput(input)
  if (!validation.success) {
    return validation
  }

  const localRuleId = generateLocalRuleId()
  const intent = buildIntent(localRuleId, input)
  const deployments: FirewallRuleDeployment[] = []
  const failedItems: FirewallBatchFailedItem[] = []

  for (const userId of intent.targetUserIds) {
    const rule = FirewallRuleUtils.buildSystemRuleFromIntent(intent, userId)
    const normalized = FirewallRuleUtils.normalizeRuleForCreate(rule)
    const systemRuleId = await FirewallSystemRepository.addRule(normalized)
    if (systemRuleId > 0) {
      deployments.push({ localRuleId, userId, systemRuleId })
    } else {
      LogUtils.error(TAG, `createRule addRule failed: localRuleId=${localRuleId}, userId=${userId}`)
      failedItems.push({ localRuleId, userId })
    }
  }

  if (deployments.length === 0) {
    return { success: false, failedItems }
  }

  const intentSaved = await FirewallLocalRepository.saveRuleIntent(context, intent)
  const deploymentsSaved = await FirewallLocalRepository.replaceRuleDeployments(context, localRuleId, deployments)

  if (!intentSaved || !deploymentsSaved) {
    LogUtils.error(TAG, `createRule local save failed: localRuleId=${localRuleId}`)
    return { success: false, failedItems }
  }

  return {
    success: failedItems.length === 0,
    partialSuccess: failedItems.length > 0,
    failedItems
  }
}
```

### 腐败代码处理

```text
删除 snapshot / rollback / restore / reapply
删除旧用户模式规则筛选/重放
删除 FirewallAuthService 调用
```

## 12. Step 7：收紧 SystemUserProvider

### 输入

```text
FirewallSystemRepository
```

### 输出

```text
SystemUserProvider 保留，但 policy 摘要读取依赖 FirewallSystemRepository
```

### 验收标准

```text
不写 policy
不增删改规则
不读写本地用户模式
不读写规则 mapping
```

### 伪代码

```ts
static async getPolicy(userId: number): Promise<UserPolicySummary> {
  const policy = await FirewallSystemRepository.getPolicy(userId)
  return toPolicySummary(userId, policy)
}
```

### 腐败代码处理

```text
SystemUserProvider 中直接调用 netFirewall policy API 的逻辑迁出
```

## 13. Step 8：ViewModel / View 适配

### 输入

```text
稳定后的 FirewallService API
SystemUserProvider
```

### 输出

```text
ViewModel 改走新调用链
View 和组件仅必要适配
```

### 验收标准

```text
FirewallOverviewViewModel 调 loadOverviewState/setFirewallEnabledForAllUsers/switchMode
FirewallRulesViewModel 调 listRulesForDisplay/createRule/updateRule/deleteRule
FirewallUserDispatchViewModel 直接调 SystemUserProvider.loadAvailableUserIds
FirewallUserDispatchViewModel 调 loadUserPolicyState/applyUserPolicyMode
View 不直接调用 Repository
```

### 伪代码

```ts
async applySelectedMode(): Promise<boolean> {
  const result = await FirewallService.applyUserPolicyMode(
    this.context,
    this.selectedUserId,
    this.getSelectedMode()
  )
  this.lastApplyResult = result
  return result.success
}
```

### 腐败代码处理

```text
移除 ViewModel 对 FirewallUserDispatchService、FirewallStore、FirewallAuthService、旧 StrategyFactory 的引用
```

## 14. Step 9：删除腐败代码

### 输入

```text
Step 1-8 完成
无生产引用旧文件
```

### 输出

```text
旧文件删除
旧链路无残留
```

### 验收标准

```text
rg "FirewallAuthService|FirewallAuthStateStore|FirewallStore|FirewallUserDispatchService" entry/src/main/ets 无命中
rg "FirewallModeStrategyFactory|PresetModeStrategy|CustomModeStrategy|FirewallModeRuleBuilder|FirewallPresetConfigReader" entry/src/main/ets 无命中
rg "buildManagedRuleDescription|parseManagedRuleDescription|applyManagedRuleMetadata" entry/src/main/ets 无命中
rg "snapshot|rollback|restoreManaged|reapply" entry/src/main/ets/services/firewall 无命中
```

### 腐败代码删除

```text
FirewallAuthService.ets
FirewallAuthStateStore.ets
FirewallStore.ets
FirewallUserDispatchService.ets
firewall_service_contracts.ets
旧 repositories/*
旧 mode-strategies/*
FirewallRulesService.ets
```

## 15. Step 10：测试迁移

### 输入

```text
新架构
旧测试
MockNetFirewall
```

### 输出

```text
测试覆盖新主链路
旧测试引用删除文件的部分被迁移或删除
```

### 验收标准

```text
createRule：全部失败不保存 intent/deployments
createRule：部分成功保存 intent 和成功 deployments
switchMode：调用 clearAllRuleDeployments
switchMode：失败也保存目标模式
switchMode public/private：按所有可用用户生成 prepared rules，不写 deployments
switchMode custom：按 intent.targetUserIds 生成 prepared rules，成功后写回 deployments
applyUserPolicyMode：直接 AuthService.authenticate + setPolicy + saveUserPolicyMode
不存在测试引用已删除生产文件
```

### 伪代码

```ts
it('switchMode public should create prepared rules for all available users and not save deployments', async () => {
  seedUsers([100, 101])
  await FirewallService.switchMode(context, 'public')
  expect(MockNetFirewall.addedRulesForUsers()).assertDeepEquals([100, 101])
  expect(await FirewallLocalRepository.listRuleDeployments(context)).assertDeepEquals([])
})
```

```ts
it('switchMode custom should replace deployments for successful prepared rules', async () => {
  await seedIntent(context, intentForUsers('rule_a', [100, 101]))
  MockNetFirewall.failAddRuleForUserIds = [101]

  await FirewallService.switchMode(context, 'custom')

  const deployments = await FirewallLocalRepository.listRuleDeployments(context, 'rule_a')
  expect(deployments.length).assertEqual(1)
  expect(deployments[0].userId).assertEqual(100)
})
```

### 腐败代码处理

```text
auth-state-store.test.ets 删除
auth-service.test.ets 删除或改测 FirewallService 认证路径
rules-service.test.ets 改为 FirewallRuleUtils 测试
strategy-factory.test.ets 改为 FirewallModeStrategy 测试
```

## 16. Step 11：集成验证

### 输入

```text
Step 1-10 完成
```

### 输出

```text
构建、测试、腐败代码扫描结果
```

### 验收标准

```text
git status 只包含预期变更或干净
单元测试通过
assembleHap 通过
腐败代码扫描无命中
SSOT 未被违反
```

### 验证命令

```powershell
git -C D:\project\ai\security_tool-firewall-architecture-refactor-plan status --short --branch

git -C D:\project\ai\security_tool-firewall-architecture-refactor-plan grep -n "FirewallAuthService\|FirewallAuthStateStore\|FirewallStore\|FirewallUserDispatchService" -- entry/src/main/ets

git -C D:\project\ai\security_tool-firewall-architecture-refactor-plan grep -n "buildManagedRuleDescription\|parseManagedRuleDescription\|applyManagedRuleMetadata" -- entry/src/main/ets

git -C D:\project\ai\security_tool-firewall-architecture-refactor-plan grep -n "snapshot\|rollback\|restoreManaged\|reapply" -- entry/src/main/ets/services/firewall
```

构建测试：

```powershell
hvigorw test --mode module -p product=default -p module=entry@default
hvigorw assembleHap --mode module -p product=default -p module=entry
```

## 17. 串行顺序

必须串行：

```text
Step 0 -> Step 1 -> Step 2 -> Step 3 -> Step 4 -> Step 5 -> Step 6 -> Step 7 -> Step 8 -> Step 9 -> Step 10 -> Step 11
```

不并行：

```text
不派生子分支
不派生子 worktree
不多 session 同步改代码
```

## 18. SSOT 与实施计划一致性

当前实施计划与 SSOT 匹配，无已知偏差。

核对点：

```text
唯一 worktree 串行推进：匹配
核心文件列表：匹配
FirewallPreparedRule：匹配
public/private 按所有可用用户生成 prepared rules：匹配
custom 按 intent.targetUserIds 生成 prepared rules：匹配
public/private 不写 deployments：匹配
custom 成功下发后写 deployments：匹配
switchMode 调 clearAllRuleDeployments：匹配
switchMode 无论 failedItems 是否为空都保存目标模式：匹配
createRule 先系统下发再保存本地：匹配
失败不回滚，不保存失败 deployment：匹配
删除 FirewallAuthService / FirewallAuthStateStore：匹配
删除 metadata / snapshot / rollback / reapply：匹配
```

实施时必须注意：

```text
FirewallModeStrategy 可以调用 SystemUserProvider.loadAvailableUserIds，但只允许用于 public/private 生成 prepared rules。
FirewallModeStrategy 不能下发规则，不能写 Preferences，不能写 policy。
```
