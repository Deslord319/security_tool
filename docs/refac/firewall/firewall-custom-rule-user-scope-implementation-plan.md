# 防火墙自定义规则用户列表实施计划

> 状态：Draft  
> 日期：2026-04-14  
> 适用范围：仅用于“防火墙管理 > 自定义模式 > 新增/编辑规则”的【用户列表】改造实施  
> 规格来源：`docs/refac/firewall/firewall-custom-rule-user-scope-single-source-of-truth.md`

## 0. 执行工作区

本计划只允许在以下独立 worktree 中实施：

- 工作区：`D:\project\ai\security_tool-firewall-module-analysis`
- 分支：`task/firewall-module-analysis`

如需多 session 并行，必须继续从该任务分支派生独立 worktree，不允许直接在主工作区 `D:\project\ai\security_tool` 上执行。

## 1. 背景+目的

当前防火墙“自定义模式”规则是共享模板模型，规则本身不区分用户范围，因此只能表达“有这条规则”，不能表达“这条规则对哪些用户生效”。在多用户设备场景下，这种模型粒度过粗，无法支持按用户定向控制。

本次改造只聚焦“自定义模式-新增/编辑规则”的【用户列表】能力，并且要把这个能力真正接入规则生效链路。核心目标如下：

1. 新增【用户列表】字段
2. 默认显示 `ALL`
3. 用户可改单选/多选具体用户
4. `ALL` 只作为录入和展示快捷项，不作为长期持久化语义
5. 保存规则时，使用 `SystemUserProvider.loadAvailableUserIds()` 将 `ALL` 展开成固定 `userIds`
6. 持久化层只保存固定 `userIds`
7. 真正应用自定义模式时，先按 `userIds` 拆成“每个用户自己的规则集”，再逐用户调用系统接口下发

一句话概括：

- 以前的自定义规则是“一套模板直接整体生效”
- 现在改成“同一套模板先按用户拆分，再分别生效”

## 2. 修改代码文件范围

### 2.1 `entry/src/main/ets/models/DataModels.ets`

文件介绍：

- 防火墙领域核心数据模型定义位置。

修改内容：

- 为自定义规则正式补充 `userIds: number[]`
- 明确 `userIds` 约束：非空、去重、升序
- 如有必要，补充“按用户拆分后的规则集”相关内部结构定义

### 2.2 `entry/src/main/ets/services/firewall/repositories/FirewallCustomRulesRepository.ets`

文件介绍：

- 自定义规则模板本地持久化仓储。

修改内容：

- 让持久化记录准确保存/读取 `userIds`
- 保存时不落库 `ALL` 标记，只保存展开后的固定用户数组
- 删除旧结构兼容兜底逻辑
- 不在此处增加 `ALL` 展开或按用户分桶的业务逻辑

### 2.3 `entry/src/main/ets/services/firewall/mode-strategies/CustomModeStrategy.ets`

文件介绍：

- 自定义模式策略实现，负责规则回读、展示态转换和应用前准备。

修改内容：

- 适配带 `userIds` 的规则结构
- 新增“将共享模板规则按 `userIds` 拆分为每用户规则集”的能力
- 不再把整套模板规则直接当成一个统一规则集输出
- 删除依赖旧共享单规则集模型的转换逻辑

### 2.4 `entry/src/main/ets/services/firewall/FirewallService.ets`

文件介绍：

- 防火墙统一门面服务。

修改内容：

- 适配自定义规则保存后的应用链路
- 调用新的“按用户拆分并逐用户应用”能力
- 不再假设自定义模式只会生成一套统一规则集

### 2.5 `entry/src/main/ets/services/firewall/stores/FirewallStore.ets`

文件介绍：

- 防火墙运行态编排层，负责用户模式应用和按用户规则落地。

修改内容：

- 新增按 `userIds` 拆分后逐用户应用规则的编排逻辑
- 对每个目标用户分别执行：
  - 设置该用户 policy
  - 清理该用户受管规则
  - 添加该用户命中的规则
- 删除“将全部自定义规则不区分用户，直接作为单一规则集应用”的旧实现

### 2.6 `entry/src/main/ets/components/firewall/rules/AddRuleDialog.ets`

文件介绍：

- 新增/编辑防火墙规则弹窗。

修改内容：

- 新增【用户列表】字段
- 默认显示 `ALL`
- 支持单选/多选具体用户
- 保存时若当前为 `ALL`，调用 `SystemUserProvider.loadAvailableUserIds()` 展开为固定 `userIds`
- 编辑已有规则时，若规则 `userIds` 覆盖当前全部用户，可回显为 `ALL`
- 增加“未选择任何用户不可保存”的校验
- 删除只在页面临时态保存用户范围、但不写入规则对象的实现

### 2.7 `entry/src/main/ets/views/firewall/rules/FirewallRulesPage.ets`

文件介绍：

- 自定义规则页，负责规则列表展示和交互编排。

修改内容：

- 在规则列表中增加“用户范围”展示
- 支持把覆盖当前全部用户的 `userIds` 显示为 `ALL`
- 适配新增/编辑后的规则对象展示
- 删除无法表达用户范围的旧展示拼接

### 2.8 `entry/src/main/ets/viewmodels/firewall/rules/FirewallRulesViewModel.ets`

文件介绍：

- 规则页状态模型。

修改内容：

- 适配带 `userIds` 的新规则结构
- 保证新增、编辑、删除、回滚链路中 `userIds` 不丢失
- 删除更新/恢复规则时遗漏新字段的旧拷贝逻辑

### 2.9 `entry/src/main/ets/services/firewall/rules/FirewallRulesService.ets`

文件介绍：

- 规则领域服务，负责冲突判断、规则比较和统计。

修改内容：

- 冲突判断从“只看规则内容”升级为“规则内容 + `userIds` 交集”
- 删除只按规则键判断、不看用户集合的旧冲突分支

### 2.10 `entry/src/main/ets/constants/modules/FirewallStrings.ets`

文件介绍：

- 防火墙模块文案集中定义位置。

修改内容：

- 新增【用户列表】、`ALL`、指定用户、请选择用户、用户范围展示相关文案
- 删除页面中的同类硬编码来源

## 3. 关键伪代码

### 3.1 规则模型

```ts
interface ScopedFirewallRule extends netFirewall.NetFirewallRule {
  userIds: number[]
}

function normalizeUserIds(userIds: number[]): number[] {
  return Array.from(new Set(userIds))
    .filter((id) => Number.isInteger(id) && id >= 0)
    .sort((a, b) => a - b)
}
```

### 3.2 保存时展开 `ALL`

```ts
async function resolveUserIdsForSave(
  mode: 'all' | 'selected',
  selectedUserIds: number[]
): Promise<number[]> {
  if (mode === 'all') {
    const result = await SystemUserProvider.loadAvailableUserIds()
    return normalizeUserIds(result.users.map((item) => item.userId))
  }
  return normalizeUserIds(selectedUserIds)
}
```

### 3.3 按用户拆分规则

```ts
function bucketRulesByUser(rules: ScopedFirewallRule[]): Map<number, netFirewall.NetFirewallRule[]> {
  const buckets = new Map<number, netFirewall.NetFirewallRule[]>()

  for (const rule of rules) {
    for (const userId of rule.userIds) {
      const cloned = FirewallRepository.cloneRuleForCreate(rule)
      cloned.userId = userId
      delete (cloned as ScopedFirewallRule).userIds

      const list = buckets.get(userId) ?? []
      list.push(cloned)
      buckets.set(userId, list)
    }
  }

  return buckets
}
```

### 3.4 逐用户应用

```ts
async function applyBuckets(
  buckets: Map<number, netFirewall.NetFirewallRule[]>
): Promise<ApplySummary> {
  const summary = createSummary()

  for (const [userId, rules] of buckets.entries()) {
    const policyOk = await FirewallStore.setPolicy(userId, buildPolicyForUser(userId))
    if (!policyOk) {
      summary.failedUsers.push(userId)
      continue
    }

    const clearOk = await FirewallStore.clearManagedRules(userId)
    if (!clearOk) {
      summary.failedUsers.push(userId)
      continue
    }

    const addOk = await FirewallStore.addRulesForUser(userId, rules)
    if (!addOk) {
      summary.failedUsers.push(userId)
      continue
    }

    summary.successUsers.push(userId)
  }

  return summary
}
```

## 4. 实施计划

### Step 1：收口正式规则模型

状态：

- 串行起点

输入：

- 当前唯一真相
- 当前规则模型与规则对象使用方式

输出：

- 统一后的正式规则模型，规则固定携带 `userIds`

执行文件：

- `entry/src/main/ets/models/DataModels.ets`

验收标准：

- 代码中存在唯一正式的用户范围模型：`userIds`
- 不存在动态 `ALL` 持久化语义
- 模型能表达“共享模板规则带固定用户集合”

腐败代码删除：

- 删除动态 `ALL` 作用域设计
- 删除旧的“无用户范围规则”模型

可并行：

- 否

### Step 2：持久化记录切换到 `userIds`

状态：

- 依赖 Step 1

输入：

- 新规则模型
- 当前规则仓储与回读实现

输出：

- 仓储层准确保存/读取 `userIds`

执行文件：

- `entry/src/main/ets/services/firewall/repositories/FirewallCustomRulesRepository.ets`
- `entry/src/main/ets/services/firewall/mode-strategies/CustomModeStrategy.ets` 的存储/回读部分

验收标准：

- 保存后的规则记录带固定 `userIds`
- 回读后 `userIds` 不丢失
- 仓储层不保存 `ALL` 标记

腐败代码删除：

- 删除旧结构兼容分支
- 删除动态 `ALL` 落库存储逻辑

可并行：

- 可与 Step 3 并行

### Step 3：页面文案与展示位准备

状态：

- 依赖 Step 1

输入：

- 新规则模型
- 当前页面布局

输出：

- 页面与文案可承载用户范围

执行文件：

- `entry/src/main/ets/constants/modules/FirewallStrings.ets`
- `entry/src/main/ets/views/firewall/rules/FirewallRulesPage.ets` 的展示位部分

验收标准：

- 页面不再硬编码 `ALL`、用户列表等文案
- 规则列表具备用户范围展示位

腐败代码删除：

- 删除页面硬编码文案
- 删除旧展示拼接中无法表达用户范围的部分

可并行：

- 可与 Step 2 并行

### Step 4：弹窗支持用户列表录入

状态：

- 依赖 Step 2、Step 3

输入：

- 新规则结构
- 文案
- `SystemUserProvider.loadAvailableUserIds()`

输出：

- 新增/编辑弹窗可输出固定 `userIds`

执行文件：

- `entry/src/main/ets/components/firewall/rules/AddRuleDialog.ets`

验收标准：

- 新增规则默认显示 `ALL`
- 可单选/多选具体用户
- 当前为 `ALL` 时，保存会展开为固定 `userIds`
- 未选择任何用户时不可保存
- 编辑规则时可正确回显，必要时显示为 `ALL`

腐败代码删除：

- 删除只在页面临时态保存用户范围的逻辑
- 删除把用户范围塞进 `description` 的实现

可并行：

- 否

### Step 5：规则页与 ViewModel 适配

状态：

- 依赖 Step 2、Step 4

输入：

- 带 `userIds` 的规则对象
- 弹窗输出结果

输出：

- 规则页完整支持新增、编辑、删除、回滚和展示

执行文件：

- `entry/src/main/ets/viewmodels/firewall/rules/FirewallRulesViewModel.ets`
- `entry/src/main/ets/views/firewall/rules/FirewallRulesPage.ets`

验收标准：

- `userIds` 在所有页面操作中不丢失
- 列表能展示用户范围
- 覆盖当前全用户时显示 `ALL`

腐败代码删除：

- 删除遗漏 `userIds` 的旧 clone/map 逻辑
- 删除只展示规则主体的旧逻辑

可并行：

- 否

### Step 6：冲突判断升级

状态：

- 依赖 Step 2、Step 5

输入：

- 带 `userIds` 的规则对象
- 当前冲突判断逻辑

输出：

- 冲突判断支持 `userIds` 交集

执行文件：

- `entry/src/main/ets/services/firewall/rules/FirewallRulesService.ets`

验收标准：

- `userIds` 不相交时不判冲突
- `userIds` 有交集时按规则内容继续判冲突

腐败代码删除：

- 删除只看规则键、不看 `userIds` 的旧冲突分支

可并行：

- 可独立 session 执行

### Step 7：真正下发链路改造为“先拆用户，再逐用户下发”

状态：

- 依赖 Step 2、Step 5

输入：

- 带 `userIds` 的共享模板规则
- 当前自定义模式应用链路
- 系统接口只能按单用户执行

输出：

- 共享模板规则真正按用户生效

执行文件：

- `entry/src/main/ets/services/firewall/mode-strategies/CustomModeStrategy.ets` 的应用前展开部分
- `entry/src/main/ets/services/firewall/FirewallService.ets`
- `entry/src/main/ets/services/firewall/stores/FirewallStore.ets`

验收标准：

- 不再把整套模板规则直接整体应用
- 会先拆成 `userId -> rules[]`
- 再逐用户调用系统接口
- 每个用户只收到自己的规则

腐败代码删除：

- 删除“整套模板规则直接整体应用”的旧实现
- 删除把多用户规则直接喂给单用户接口的隐含假设

可并行：

- 可独立 session 执行，但不要和 Step 6 抢同文件

## 5. 并行执行建议

可并行的 session 分组如下：

### Session A

- Step 2
- 文件：
  - `FirewallCustomRulesRepository.ets`
  - `CustomModeStrategy.ets` 的存储/回读部分

### Session B

- Step 3
- 文件：
  - `FirewallStrings.ets`
  - `FirewallRulesPage.ets` 展示位部分

### Session C

- Step 4 + Step 5
- 文件：
  - `AddRuleDialog.ets`
  - `FirewallRulesViewModel.ets`
  - `FirewallRulesPage.ets`

### Session D

- Step 6
- 文件：
  - `FirewallRulesService.ets`

### Session E

- Step 7
- 文件：
  - `CustomModeStrategy.ets` 的应用前展开部分
  - `FirewallService.ets`
  - `FirewallStore.ets`

必须串行的依赖：

1. Step 1 最先完成
2. Step 2、Step 3 在 Step 1 后可并行
3. Step 4 在 Step 2、Step 3 后执行
4. Step 5 在 Step 2、Step 4 后执行
5. Step 6 在 Step 2、Step 5 后执行
6. Step 7 在 Step 2、Step 5 后执行

## 6. 整体验收口径

完成后应满足：

1. 新增/编辑规则支持【用户列表】
2. 默认显示 `ALL`
3. 保存后的规则正式携带固定 `userIds`
4. 规则列表可展示用户范围，必要时显示 `ALL`
5. 编辑规则时用户列表可正确回显
6. 冲突判断已纳入 `userIds` 交集
7. 自定义模式真正应用时，会先按 `userIds` 拆分，再逐用户调用系统接口下发
8. 代码中不存在动态 `ALL` 持久化逻辑、旧结构兼容逻辑、用户范围临时拼装逻辑，以及“整套模板规则直接整体应用”的旧实现
