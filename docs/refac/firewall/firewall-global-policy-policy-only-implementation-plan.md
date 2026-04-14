# 防火墙全局策略 policy-only 实施计划

> 状态：Draft  
> 日期：2026-04-14  
> 工作区：`D:\project\ai\security_tool-firewall-global-policy-chain`  
> 工作分支：`task/firewall-global-policy-chain`  
> 规格来源：`docs/refac/firewall/firewall-global-policy-policy-only-single-source-of-truth.md`

## 0. 背景

当前防火墙模块已经支持“规则按用户生效”，规则本身通过 `userIds` 表达作用用户。

但“全局策略 / 用户模式切换”仍沿用旧规格，实际仍在做：

1. 读取共享规则模板
2. 按模式筛选规则
3. 清理旧规则
4. 重新下发规则
5. 规则模板变更后联动重放用户模式

这与 `policy-only` 新规格冲突，并造成双重真相：

1. 一套用户作用域在规则 `userIds`
2. 一套用户作用域在全局策略链路的二次筛选

## 1. 目的

将“全局策略 / 用户模式切换”改造成 `policy-only` 链路：

1. 切换前做 PIN 认证
2. 只设置目标用户完整 `NetFirewallPolicy`
3. 成功后保存本地 `userId -> mode`
4. 删除旧规格残留腐败代码
5. 不影响以下能力：
   - 首页三种模式切换
   - 防火墙开关切换后重新下发历史规则
   - 自定义模式规则新增 / 删除 / 更新

## 2. 修改代码文件范围

本轮严格只修改以下文件：

1. `entry/src/main/ets/services/firewall/user-dispatch/FirewallUserDispatchService.ets`
2. `entry/src/main/ets/services/firewall/stores/FirewallStore.ets`
3. `entry/src/main/ets/services/firewall/FirewallService.ets`
4. `entry/src/main/ets/services/firewall/repositories/FirewallUserBindingsRepository.ets`
5. `entry/src/main/ets/models/DataModels.ets`
6. `entry/src/test/firewall/service.test.ets`
7. `entry/src/test/firewall/user-dispatch.test.ets`
8. `entry/src/test/firewall/auth-service.test.ets`
9. `docs/refac/firewall/firewall-global-policy-policy-only-single-source-of-truth.md`
10. `docs/refac/firewall/firewall-global-policy-policy-only-implementation-plan.md`

## 3. 腐败代码清单

### 3.1 必须删除的腐败代码

#### 文件：`entry/src/main/ets/services/firewall/user-dispatch/FirewallUserDispatchService.ets`

1. `applyUserMode(...)` 中读取共享规则模板的代码

```ts
let sharedRules = await FirewallModeStrategyFactory.buildCustomRulesForApply(context)
return FirewallStore.applyUserMode(context, userId, mode, sharedRules)
```

删除依据：

- 与 SSOT 冲突：用户模式切换必须是 `policy-only`
- 当前代码仍把用户模式切换实现成规则式模式切换

2. `reapplyUserBindings(...)` 整个方法

删除依据：

- 与 SSOT 冲突：历史模式记录不再驱动规则模板联动重放

#### 文件：`entry/src/main/ets/services/firewall/stores/FirewallStore.ets`

1. `applyUserMode(...)` 的 `sharedRules` 入参

删除依据：

- 与 SSOT 冲突：用户模式切换不应再接收规则输入

2. `applyUserModeInternal(...)` 中以下规则式模式切换逻辑

```ts
let snapshotRules = await FirewallStore.getManagedRules(userId)
let targetRules = FirewallStore.buildRulesForMode(userId, mode, sharedRules)

if (!await FirewallStore.clearManagedRules(userId)) { ... }

if (!await FirewallStore.setPolicy(userId, targetPolicy)) {
  await FirewallStore.restoreManagedRules(userId, snapshotRules)
  ...
}

if (!await FirewallStore.addRules(targetRules)) {
  await FirewallStore.restoreManagedRulesAndPolicy(userId, originalPolicy, snapshotRules)
  ...
}
```

删除依据：

- 与 SSOT 冲突：用户模式切换只允许设置完整 policy
- 当前代码仍在执行删规则 / 改 policy / 加规则 / 规则回滚

3. `buildRulesForMode(...)` 整个函数

删除依据：

- 与 SSOT 冲突：白名单 / 黑名单不再是规则筛选语义

4. `reapplyUserBindings(...)` 整个函数

删除依据：

- 与 SSOT 冲突：不再允许规则模板变更后重放用户模式

#### 文件：`entry/src/main/ets/services/firewall/FirewallService.ets`

1. `saveCustomRules(...)` 中：

```ts
let reapplySummary = await FirewallUserDispatchService.reapplyUserBindings(context, nextRules)
```

删除依据：

- 与 SSOT 冲突：规则模板保存后，不再联动用户模式链路

### 3.2 保留但改语义的代码

#### 文件：`entry/src/main/ets/services/firewall/repositories/FirewallUserBindingsRepository.ets`

保留原因：

- `userId -> mode` 历史模式记录仍然是新规格要求

新职责：

1. 保存用户历史模式记录
2. 为后续全局防火墙重新开启时恢复完整 policy 提供输入

明确禁止：

1. 继续作为规则模板联动 binding 使用

## 3.3 本轮日志增强

本轮额外增加一项轻量实现：

1. 在 `FirewallStore.applyUserModeInternal(...)` 中
2. 于 `setPolicy(...)` 调用前
3. 打印即将下发的 policy payload

日志字段固定为：

- `userId`
- `mode`
- `isOpen`
- `inAction`
- `outAction`

目的：

1. 提高全局策略模式切换的运行期可观测性
2. 便于排查“模式选择 -> policy 下发参数”是否符合预期
3. 为后续按历史模式恢复完整 policy 提供运行证据

## 4. 实施步骤

### Step 1：固定领域模型和历史模式记录语义

输入：

1. SSOT
2. `DataModels.ets`
3. `FirewallUserBindingsRepository.ets`

输出：

1. `userId -> mode` 被明确为历史模式记录
2. 不再表达规则 binding / 模板联动语义

伪代码：

```ts
type FirewallUserApplyMode = 'allowlist' | 'denylist'

interface UserFirewallModeBinding {
  userId: number
  mode: FirewallUserApplyMode
  // 注释更新为：历史模式记录
}
```

```ts
loadBindings(context): Promise<UserFirewallModeBinding[]>
saveBindingMode(context, userId, mode): Promise<boolean>
getBindingMode(context, userId): Promise<FirewallUserApplyMode | undefined>
```

验收标准：

1. 注释和职责说明中不再出现“规则重下发 binding”
2. 数据结构可供后续全局重新开启时恢复历史模式使用

并行性：

- 可与 Step 2 并行

### Step 2：改造用户模式切换入口为 policy-only

输入：

1. `FirewallUserDispatchService.ets`
2. `FirewallService.ets`
3. SSOT

输出：

1. 用户模式切换不再读取 custom rules
2. 用户模式切换只通过 auth + store 进入 policy-only 主链路

伪代码：

```ts
static async applyUserMode(context, userId, mode): Promise<FirewallUserApplyResult> {
  return FirewallAuthService.executeUserModeApply(
    context,
    userId,
    mode,
    async (): Promise<FirewallUserApplyResult> => {
      return FirewallStore.applyUserMode(context, userId, mode)
    }
  )
}
```

```ts
static async applyUserMode(context, userId, mode) {
  return FirewallUserDispatchService.applyUserMode(context, userId, mode)
}
```

验收标准：

1. `applyUserMode` 链路里不存在 `sharedRules`
2. `applyUserMode` 链路里不存在 `buildCustomRulesForApply`

并行性：

- 可与 Step 1 并行

### Step 3：重写 store 的用户模式切换实现

输入：

1. `FirewallStore.ets`
2. `FirewallUserBindingsRepository.ets`
3. SSOT

输出：

1. 新的 `policy-only` store 主链路

伪代码：

```ts
static async applyUserMode(context, userId, mode): Promise<UserFirewallModeApplyResult> {
  let result = await FirewallStore.applyUserModeInternal(userId, mode)
  if (!result.success) {
    return result
  }

  let saved = await FirewallUserBindingsRepository.saveBindingMode(context, userId, mode)
  if (!saved) {
    return {
      success: false,
      userId,
      mode,
      appliedRuleCount: 0,
      errorMessage: '保存历史模式失败'
    }
  }

  return result
}
```

```ts
private static async applyUserModeInternal(userId, mode): Promise<UserFirewallModeApplyResult> {
  let currentPolicy = await SystemUserProvider.getPolicy(userId)
  if (currentPolicy.errorCode !== undefined) {
    return {
      success: false,
      userId,
      mode,
      appliedRuleCount: 0,
      errorCode: currentPolicy.errorCode,
      errorMessage: currentPolicy.message
    }
  }

  let targetPolicy: netFirewall.NetFirewallPolicy = {
    isOpen: currentPolicy.isOpen,
    inAction: mode === 'allowlist'
      ? netFirewall.FirewallRuleAction.RULE_ALLOW
      : netFirewall.FirewallRuleAction.RULE_DENY,
    outAction: mode === 'allowlist'
      ? netFirewall.FirewallRuleAction.RULE_ALLOW
      : netFirewall.FirewallRuleAction.RULE_DENY
  }

  let success = await FirewallStore.setPolicy(userId, targetPolicy)
  if (!success) {
    return {
      success: false,
      userId,
      mode,
      appliedRuleCount: 0,
      errorMessage: '设置防火墙策略失败'
    }
  }

  return {
    success: true,
    userId,
    mode,
    appliedRuleCount: 0
  }
}
```

验收标准：

1. `applyUserModeInternal(...)` 不再接收规则数组
2. 不再调用规则筛选、规则清理、规则写入、规则回滚
3. 成功后保存 `userId -> mode`

并行性：

- 不建议并行，单 session 独占 `FirewallStore.ets`

### Step 4：删除规则模板联动用户模式的桥接代码

输入：

1. `FirewallService.ets`
2. `FirewallUserDispatchService.ets`
3. `FirewallStore.ets`

输出：

1. 规则模板保存链路与用户模式链路彻底解耦

伪代码：

```ts
static async saveCustomRules(context, nextRules): Promise<FirewallRulesSaveResult> {
  // 保留规则模板保存和规则主链路应用
  // 删除 reapplyUserBindings(...)
  return {
    success: true,
    appliedRuleCount: nextRules.length,
    reapplyTotalUsers: 0,
    reapplySuccessCount: 0,
    reapplyFailedCount: 0,
    failedUsers: []
  }
}
```

```ts
// 删除整个 reapplyUserBindings 方法
```

验收标准：

1. 自定义规则保存后不再进入用户模式链路
2. 工程中无 `reapplyUserBindings(` 活跃调用

并行性：

- 可与 Step 5 并行

### Step 5：删除仅服务旧用户模式链路的腐败代码

输入：

1. `FirewallStore.ets`
2. 调用关系检查结果

输出：

1. 用户模式切换链路中的腐败代码完全退出
2. 不误伤规则主链路

伪代码：

```ts
// buildRulesForMode(...) => delete

if (onlyUsedByUserModeChain) {
  delete function
} else {
  keep function
  remove user-mode call sites
}
```

优先删除对象：

1. `buildRulesForMode(...)`

条件删除对象：

1. `getManagedRules(...)`
2. `clearManagedRules(...)`
3. `addRules(...)`
4. `restoreManagedRules(...)`
5. `restoreManagedRulesAndPolicy(...)`

验收标准：

1. `applyUserMode` 链路中已无规则函数调用
2. 首页主模式切换、自定义规则保存链路仍完整

并行性：

- 与 Step 4 理论可并行，但同文件冲突高
- 建议与 Step 3 合并到同一 session

### Step 6：测试收口

输入：

1. 新实现
2. 现有 firewall 单测

输出：

1. 与 SSOT 一致的测试基线

需要删除的旧断言：

1. allowlist 只下发 `ALLOW` 规则
2. denylist 只下发 `DENY` 规则
3. 规则模板变化后自动重放用户模式

需要新增的断言：

```ts
test('allowlist should set full allow policy only')
test('denylist should set full deny policy only')
test('pin auth failure should not write policy')
test('success should persist user mode record')
test('saveCustomRules should not trigger user-mode reapply')
```

伪代码：

```ts
expect(setNetFirewallPolicy).toHaveBeenCalledWith(userId, {
  isOpen: currentOpenState,
  inAction: RULE_ALLOW,
  outAction: RULE_ALLOW
})
expect(addNetFirewallRule).not.toHaveBeenCalled()
expect(removeNetFirewallRule).not.toHaveBeenCalled()
```

验收标准：

1. 单测不再依赖规则式模式切换语义
2. 新增测试明确验证“不操作规则集”

并行性：

- 可单独一个 session

### Step 7：同步 SSOT 与实施计划文档

输入：

1. SSOT
2. 实际代码计划
3. 腐败代码清单

输出：

1. 文档与实现计划一致

伪结构：

```md
## 背景+目的
## 修改文件范围
## 腐败代码清单
## 实施步骤
### Step N
- Input
- Output
- Pseudocode
- Acceptance
- Parallel
```

验收标准：

1. 文档与 SSOT 一致
2. 文档包含可执行伪代码

并行性：

- 可单独一个 session

## 5. 多 Session 并行拆分建议

### Session A：主链路改造

负责文件：

1. `FirewallUserDispatchService.ets`
2. `FirewallStore.ets`
3. `FirewallService.ets`

负责步骤：

1. Step 2
2. Step 3
3. Step 4
4. Step 5

说明：

- 单独占用核心调用链，避免冲突

### Session B：模型与 repository 收口

负责文件：

1. `DataModels.ets`
2. `FirewallUserBindingsRepository.ets`

负责步骤：

1. Step 1

说明：

- 与主链路耦合低，可并行

### Session C：测试

负责文件：

1. `service.test.ets`
2. `user-dispatch.test.ets`
3. `auth-service.test.ets`

负责步骤：

1. Step 6

说明：

- 等 Session A 接口稳定后合入

### Session D：文档

负责文件：

1. `firewall-global-policy-policy-only-single-source-of-truth.md`
2. `firewall-global-policy-policy-only-implementation-plan.md`

负责步骤：

1. Step 7

说明：

- 独立推进

## 6. 最终验收标准

1. `applyUserMode` 链路已改成 `policy-only`
2. 用户模式切换时只做：
   - PIN 认证
   - 设置完整 policy
   - 保存 `userId -> mode`
3. 用户模式切换链路中不存在：
   - 读取共享规则模板
   - 规则筛选
   - 规则清理
   - 规则下发
   - 规则式回滚
4. 自定义规则保存后不再触发用户模式自动重放
5. 首页三种模式切换不受影响
6. 自定义模式规则新增 / 删除 / 更新不受影响
7. 后续首页全局重新开启时，可依据本地历史模式恢复完整 policy
