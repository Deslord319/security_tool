# 防火墙管理模块：MVVM + Strategy 渐进式重构唯一真相

> 取代声明：本文已被 `docs/refac/firewall/firewall-architecture-refactor-single-source-of-truth.md` 取代。  
> 后续防火墙架构重构、旧代码清理、规则 intent/deployment 本地模型、认证删除、快照回滚删除、metadata 删除和 worktree/分支约束，均以新文档为唯一真相。  
> 本文仅作为历史背景和旧方案参考材料保留；若与新文档冲突，以新文档为准。

> 状态：Draft  
> 日期：2026-04-07  
> 适用范围：仅用于“防火墙管理”模块目录重组、MVVM 化、策略模式改造与可测试化改造  
> 唯一判定依据：本文档

## 0. 任务背景

当前“防火墙管理”模块已经具备可运行能力，但存在三个基础问题：

1. 代码职责霰弹
2. 页面层直接编排业务
3. 目录与命名不利于人和 LLM 快速定位唯一入口

当前业务逻辑分散在以下旧目录：

- `entry/src/main/ets/services/firewall/policy/`
- `entry/src/main/ets/services/firewall/mode-control/`
- `entry/src/main/ets/services/firewall/preset/`
- `entry/src/main/ets/services/firewall/rule-management/`
- `entry/src/main/ets/services/firewall/auth-state/`

当前页面和弹窗也直接依赖多个旧 service：

- [FirewallPage.ets](/D:/project/ai/security_tool/entry/src/main/ets/views/firewall/overview/FirewallPage.ets)
- [FirewallRulesPage.ets](/D:/project/ai/security_tool/entry/src/main/ets/views/firewall/rule-management/FirewallRulesPage.ets)
- [UserFirewallControlDialog.ets](/D:/project/ai/security_tool/entry/src/main/ets/components/firewall/policy/UserFirewallControlDialog.ets)

这与本轮收口目标不一致。当前要解决的问题不是直接重写全部实现，而是：

- 先建立新的模块骨架
- 先让页面退出旧 service 直连
- 先把业务统一收口到新的 `FirewallService`
- 第一阶段通过引用旧类复用现有实现，保证行为不变
- 等骨架稳定后，再逐步把旧逻辑迁移到新目录

## 1. 目标

本轮重构目标如下：

1. 防火墙管理模块符合项目统一 MVVM 设计
2. 业务层只保留一个主服务 `FirewallService`
3. `public/private/custom` 模式差异通过策略模式表达
4. 目录结构与文件命名对人和 LLM 友好，并对齐“设备连接记录”模块风格
5. 页面层和弹窗层不再直接依赖旧业务 service
6. 第一阶段优先复用旧实现，不重写现有业务真相
7. 重构过程采用小步改动，每一步都可单独回归验证

## 2. 文件范围

本轮规划涉及以下目标目录和既有文件。

### 2.1 现有真相来源文件

- `entry/src/main/ets/services/firewall/policy/FirewallService.ets`
- `entry/src/main/ets/services/firewall/mode-control/FirewallModeService.ets`
- `entry/src/main/ets/services/firewall/mode-control/UserFirewallModeService.ets`
- `entry/src/main/ets/services/firewall/preset/FirewallPresetService.ets`
- `entry/src/main/ets/services/firewall/rule-management/FirewallCustomRuleService.ets`
- `entry/src/main/ets/services/firewall/policy/UserFirewallPolicyService.ets`
- `entry/src/main/ets/services/firewall/auth-state/FirewallToggleAuthService.ets`
- `entry/src/main/ets/services/firewall/auth-state/FirewallAuthStateRepository.ets`

### 2.2 现有页面与组件文件

- `entry/src/main/ets/views/firewall/overview/FirewallPage.ets`
- `entry/src/main/ets/views/firewall/rule-management/FirewallRulesPage.ets`
- `entry/src/main/ets/components/firewall/policy/UserFirewallControlDialog.ets`
- `entry/src/main/ets/components/firewall/rule-management/AddRuleDialog.ets`

### 2.3 目标新目录

```text
entry/src/main/ets/
├─ viewmodels/firewall/
├─ services/firewall/
├─ models/firewall/
├─ views/firewall/
└─ components/firewall/
```

说明：

- 本文档阶段允许新增新骨架文件
- 本文档不要求第一阶段删除旧文件
- 旧文件是否删除，取决于后续迁移完成度

## 3. SSOT 约束

### 3.1 先搭骨架，再迁实现

正确顺序不是先拆旧实现，而是：

1. 先建立新目录、新命名、新入口
2. 新骨架第一版内部先引用旧类
3. 页面先改为依赖新入口
4. 等新骨架稳定后，再逐步将旧逻辑迁移到新目录

### 3.2 第一阶段必须优先复用旧实现

能复用现有实现的，第一阶段必须优先通过“引用旧类”的方式复用。

禁止事项：

- 第一阶段在新目录中重新写一份 `public/private/custom` 规则构造逻辑
- 第一阶段重新实现系统防火墙 API 封装
- 第一阶段重写用户下发和绑定逻辑
- 第一阶段重写认证与锁定逻辑

### 3.3 页面层不得直接依赖旧业务 service 和策略

固定调用链：

```text
View -> ViewModel -> FirewallService -> Strategy / Repository / Store / Provider / Auth
```

禁止：

- 页面直接调用旧 `ModeService`
- 页面直接调用旧 `CustomRuleService`
- 页面直接调用旧 `UserFirewallModeService`
- 页面直接调用旧 `UserFirewallPolicyService`
- 页面直接调用旧 `FirewallToggleAuthService`
- 页面直接依赖 `FirewallModeStrategy`

### 3.4 命名风格对齐“设备连接记录”

命名规则固定如下：

- 对外主对象用 `PascalCase`
- 内部流程/用例/映射/探测/分发文件用长语义 `snake_case`
- 每个子目录提供 `index.ets`

## 4. 现有业务真相

以下真相在阶段 A 不允许被重写，只允许被包装和引用。

## 4.1 模式规则构造真相

- `public/private` 规则构造：
  [FirewallPresetService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/preset/FirewallPresetService.ets)
- `custom` 规则模板来源：
  [FirewallCustomRuleService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/rule-management/FirewallCustomRuleService.ets)

## 4.2 系统规则处理真相

- 系统防火墙 API、规则清理、规则批量下发、规则冲突判断：
  [FirewallService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/policy/FirewallService.ets)

## 4.3 用户级下发真相

- 用户绑定、按用户下发、模板变更后的重下发：
  [UserFirewallModeService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/mode-control/UserFirewallModeService.ets)

## 4.4 系统用户来源真相

- 系统用户列表和当前策略读取：
  [UserFirewallPolicyService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/policy/UserFirewallPolicyService.ets)

## 4.5 认证与锁定真相

- 受保护操作认证：
  [FirewallToggleAuthService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/auth-state/FirewallToggleAuthService.ets)
- 锁定状态存储：
  [FirewallAuthStateRepository.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/auth-state/FirewallAuthStateRepository.ets)

## 5. 目标目录与职责

## 5.1 目标目录

```text
entry/src/main/ets/
├─ viewmodels/
│  └─ firewall/
│     ├─ overview/
│     ├─ rules/
│     └─ user-dispatch/
├─ views/
│  └─ firewall/
│     ├─ overview/
│     └─ rules/
├─ components/
│  └─ firewall/
│     ├─ rules/
│     └─ user-dispatch/
├─ services/
│  └─ firewall/
│     ├─ FirewallService.ets
│     ├─ mode-strategies/
│     ├─ repositories/
│     ├─ stores/
│     ├─ providers/
│     ├─ auth/
│     ├─ rules/
│     └─ user-dispatch/
└─ models/
   └─ firewall/
```

## 5.2 目标职责

### FirewallService

业务层唯一主服务，只负责业务编排。

### FirewallModeStrategy

模式差异统一通过策略模式表达，包括：

- `PublicModeStrategy`
- `PrivateModeStrategy`
- `CustomModeStrategy`
- `FirewallModeStrategyFactory`

### FirewallRepository

只负责系统防火墙 API 调用，不负责业务编排。

### FirewallStore

只负责本地持久化：

- 当前模式
- 自定义规则模板
- 用户模式绑定

### SystemUserProvider

只负责系统用户来源和筛选。

### ViewModel

只负责页面状态和调用 `FirewallService`。

建议包括：

- `FirewallOverviewViewModel`
- `FirewallRulesViewModel`
- `FirewallUserDispatchViewModel`

## 6. 旧职责替代关系

## 6.1 旧 FirewallModeService / FirewallCustomRuleService / UserFirewallModeService

第一阶段替代为：

- 新 `FirewallService` 作为统一门面

说明：

- 新 `FirewallService` 第一版内部允许继续调用这些旧类
- 但页面和 ViewModel 不再直接依赖这些旧类

## 6.2 旧 FirewallPresetService

第一阶段替代为：

- `PublicModeStrategy`
- `PrivateModeStrategy`

说明：

- 第一版策略类只做语义包装层
- 规则构造逻辑仍然引用旧 `FirewallPresetService`

## 6.3 旧 FirewallCustomRuleService

第一阶段替代为：

- `CustomModeStrategy`
- `FirewallStore`
- 新 `FirewallService`

说明：

- 规则模板读取由 `CustomModeStrategy` 包装
- 模板持久化相关能力由 `FirewallStore` 包装
- 规则 CRUD 由新 `FirewallService` 对外统一暴露

## 6.4 旧 FirewallService

第一阶段替代为：

- `FirewallRepository`
- `services/firewall/rules/*`
- 新 `FirewallService`

说明：

- 第一版 `FirewallRepository` 仍可直接转调旧 `FirewallService`
- 后续再把系统 API 调用、冲突判断、规则集下发能力逐步迁移到新目录

## 6.5 旧 UserFirewallPolicyService

第一阶段替代为：

- `SystemUserProvider`

## 6.6 旧 FirewallToggleAuthService / FirewallAuthStateRepository

第一阶段替代为：

- `FirewallAuthService`
- `FirewallAuthStateStore`

## 7. 小步计划

## Step 1：建立 LLM 友好骨架目录

### 目标

先建立新目录和聚合出口，不迁移业务实现。

### 修改范围

- `entry/src/main/ets/viewmodels/firewall/**`
- `entry/src/main/ets/services/firewall/**`
- `entry/src/main/ets/models/firewall/**`

### 改动要点

- 先建立新目录
- 每个子目录增加 `index.ets`
- 命名对齐“设备连接记录”风格

### 完成标志

- 新目录存在
- 命名规则落地
- 旧页面和旧 service 仍可继续工作

## Step 2：建立新 FirewallService 门面，内部先引用旧类

### 目标

先把业务入口统一到新 `FirewallService`，但不重写旧逻辑。

### 修改范围

- `entry/src/main/ets/services/firewall/FirewallService.ets`

### 改动要点

- 新 `FirewallService` 第一版只做统一门面
- 内部转调旧：
  - `FirewallModeService`
  - `FirewallCustomRuleService`
  - `UserFirewallModeService`
  - `UserFirewallPolicyService`
  - `FirewallToggleAuthService`
  - 旧 `FirewallService`

### 完成标志

- 新 `FirewallService` 已存在
- 页面外部调用未来可以只认新 `FirewallService`
- 旧业务行为不变

### SSOT 证据

- 本轮要求“先复用旧实现，再迁移实现”

## Step 3：建立 Repository / Store / Provider / Auth 包装层

### 目标

先把基础设施角色名称固定下来，但第一版只做代理。

### 修改范围

- `entry/src/main/ets/services/firewall/repositories/**`
- `entry/src/main/ets/services/firewall/stores/**`
- `entry/src/main/ets/services/firewall/providers/**`
- `entry/src/main/ets/services/firewall/auth/**`

### 改动要点

- `FirewallRepository` 先转调旧 `policy/FirewallService`
- `FirewallStore` 先转调旧 `FirewallModeService`、`FirewallCustomRuleService`、`UserFirewallModeService`
- `SystemUserProvider` 先转调旧 `UserFirewallPolicyService`
- `FirewallAuthService` 先转调旧 `FirewallToggleAuthService`
- `FirewallAuthStateStore` 先转调旧 `FirewallAuthStateRepository`

### 完成标志

- 新基础设施类已存在
- 旧实现未迁移，但新角色边界已确定

### SSOT 证据

- 第一阶段只允许包装和引用，不允许大规模重写

## Step 4：建立 Strategy 层，先包装旧规则真相

### 目标

先把模式差异集中到策略目录，但第一版不重写规则构造。

### 修改范围

- `entry/src/main/ets/services/firewall/mode-strategies/**`

### 改动要点

- 建立 `FirewallModeStrategy`
- 建立 `FirewallModeStrategyFactory`
- 建立：
  - `PublicModeStrategy`
  - `PrivateModeStrategy`
  - `CustomModeStrategy`
- 第一版分别包装旧：
  - `FirewallPresetService`
  - `FirewallPresetService`
  - `FirewallCustomRuleService`

### 完成标志

- 模式差异已在新目录中被语义表达
- 实际规则真相仍然来自旧类

### SSOT 证据

- `public/private` 规则真相来自旧 `FirewallPresetService`
- `custom` 规则真相来自旧 `FirewallCustomRuleService`

## Step 5：建立三个 ViewModel，只调用新 FirewallService

### 目标

先让 ViewModel 成为页面唯一业务入口。

### 修改范围

- `entry/src/main/ets/viewmodels/firewall/overview/**`
- `entry/src/main/ets/viewmodels/firewall/rules/**`
- `entry/src/main/ets/viewmodels/firewall/user-dispatch/**`

### 改动要点

- 新增：
  - `FirewallOverviewViewModel`
  - `FirewallRulesViewModel`
  - `FirewallUserDispatchViewModel`
- 三个 VM 只允许依赖新 `FirewallService`

### 完成标志

- 页面可以开始逐步切换到 VM
- VM 不直接感知旧 service 或策略细节

## Step 6：页面按固定顺序切换到 VM

### 目标

让页面退出旧 service 直连。

### 修改范围

- `entry/src/main/ets/views/firewall/overview/FirewallPage.ets`
- `entry/src/main/ets/views/firewall/rule-management/FirewallRulesPage.ets`
- `entry/src/main/ets/components/firewall/policy/UserFirewallControlDialog.ets`

### 改动顺序

1. 先切概览页
2. 再切规则页
3. 最后切用户下发弹窗

### 完成标志

- 页面和弹窗只依赖 ViewModel
- 页面层不再直接引用旧业务 service

## Step 7：骨架稳定后，再逐块迁移旧逻辑

### 目标

在对外入口稳定后，再逐步把旧逻辑迁到新目录。

### 迁移顺序

1. 先迁 Strategy 逻辑
2. 再迁 Repository + rules 辅助能力
3. 再迁 Store 持久化逻辑
4. 再迁 user-dispatch 逻辑
5. 最后迁 auth 逻辑

### 完成标志

- 每迁完一块，即可断开对应旧引用
- 对应旧类不再承担生产职责
- 已被新目录替代且无调用方的旧实现，不得继续作为腐败代码长期保留；应删除，或降级为明确的兼容包装层

### 迁移约束

- Step 7 不是把旧逻辑复制到新目录后长期并存，而是“迁移职责 + 断开旧引用 + 收口旧实现”
- 每迁完一块，都必须判断对应旧代码属于：
  - 仍被新链路暂时复用的兼容包装层
  - 已无引用、应删除的腐败代码 / 死代码
- 对于已无引用的旧实现，必须在当前迁移步或紧随其后的收口步骤中删除，不得无限期挂起

## 8. 旧类复用清单

阶段 A 明确要求优先复用以下旧实现。

### 8.1 新 FirewallService 复用

- [FirewallModeService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/mode-control/FirewallModeService.ets)
- [FirewallCustomRuleService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/rule-management/FirewallCustomRuleService.ets)
- [UserFirewallModeService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/mode-control/UserFirewallModeService.ets)
- [UserFirewallPolicyService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/policy/UserFirewallPolicyService.ets)
- [FirewallToggleAuthService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/auth-state/FirewallToggleAuthService.ets)
- [FirewallService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/policy/FirewallService.ets)

### 8.2 Strategy 层复用

- [FirewallPresetService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/preset/FirewallPresetService.ets)
- [FirewallCustomRuleService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/rule-management/FirewallCustomRuleService.ets)

### 8.3 基础设施层复用

- [FirewallService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/policy/FirewallService.ets)
- [FirewallModeService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/mode-control/FirewallModeService.ets)
- [UserFirewallModeService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/mode-control/UserFirewallModeService.ets)
- [UserFirewallPolicyService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/policy/UserFirewallPolicyService.ets)
- [FirewallToggleAuthService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/auth-state/FirewallToggleAuthService.ets)
- [FirewallAuthStateRepository.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/firewall/auth-state/FirewallAuthStateRepository.ets)

## 9. 并行执行结论

最大并行 session 数：`1`

原因：

- 新 `FirewallService` 是统一门面，必须先定
- 页面切换依赖 ViewModel 先稳定
- 旧逻辑迁移依赖骨架先完成收口
- Strategy / Repository / Store / user-dispatch / auth 之间存在顺序依赖

执行批次：

1. Batch 1：Step 1 + Step 2
2. Batch 2：Step 3 + Step 4
3. Batch 3：Step 5 + Step 6
4. Batch 4：Step 7

## 10. 每步固定验收要求

每一步都应提供以下证据：

1. SSOT 证据
   - 引用本文档对应步骤和约束
2. 变更证据
   - `git diff -- <白名单文件>`
   - `git diff --name-only HEAD~1 HEAD`
3. 依赖收口证据
   - `rg --line-number "FirewallModeService|FirewallCustomRuleService|UserFirewallModeService|UserFirewallPolicyService|FirewallToggleAuthService" entry/src/main/ets/views entry/src/main/ets/components entry/src/main/ets/viewmodels`
4. 构建证据
   - `hvigorw assembleHap --mode module -p product=default -p module=entry`
5. Git 证据
   - `git show --name-only --stat --oneline HEAD`
   - `git status --short`
   - 当前步骤必须对应可追溯 git 提交；不接受仅存在工作区、未形成提交的“半完成状态”

Step 7 额外要求：

6. 迁移汇报
   - 哪块旧逻辑已迁入新目录
   - 哪个旧引用已断开
   - 哪些旧类仍保留为兼容包装层
   - 哪些旧类 / 旧函数已作为腐败代码删除

## 11. 完成判定

满足以下条件才算本轮重构完成：

1. 页面只依赖 ViewModel
2. ViewModel 只依赖新 `FirewallService`
3. 新 `FirewallService` 成为唯一业务入口
4. `public/private/custom` 模式差异通过 Strategy 目录表达
5. 新目录与命名对 LLM 友好，不再需要跨多个旧目录拼图
6. 阶段 A 内部通过引用旧类保持行为不变
7. 阶段 B 逐块迁移后，旧引用被逐步删除
8. 规则构造、系统下发、用户下发、认证保护的业务真相保持不变
9. 每一步修改均能通过 git 提交追溯到对应重构动作与验证证据

## 12. 后续更新规则

1. 若只涉及实施细节微调，不改变本文档原则，可补充更新
2. 若改变目录结构、命名规则、阶段顺序、旧类复用策略，必须先更新本文档
3. 若未来出现新的防火墙重构主文档，必须明确替代关系，避免并存冲突
