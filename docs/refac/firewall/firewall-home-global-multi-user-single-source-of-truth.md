# 防火墙首页全局多用户控制唯一真相

> 状态：Confirmed
> 日期：2026-04-15
> 适用范围：仅用于“防火墙管理首页顶部开关 + 首页 public/private/custom 模式切换”规格收口
> 唯一判定依据：本文档

## 1. 文档目的

本文档用于固化当前已确认的防火墙首页新业务语义。

本轮讨论的目标不是继续沿用“默认用户 100 首页控制”的旧口径，而是将首页顶部开关和首页模式切换统一升级为：

- 面向 `SystemUserProvider.loadAvailableUserIds()` 返回的全部用户生效
- 在 `custom` 模式下，按每个用户命中的规则集下发规则
- 首页顶部开关只修改所有用户的 `isOpen`，不重建 policy 与规则
- 首页模式切换负责为所有用户同步目标模式 policy 与规则

后续涉及以下行为的分析、实现、测试和文档说明，均以本文为唯一真相：

1. 首页顶部防火墙开关
2. 首页 `public / private / custom` 模式切换
3. 首页模式切换时的多用户 policy 与规则下发
4. `custom` 模式下各用户的 `NetFirewallPolicy` 恢复与规则下发

## 2. 结论

### 2.1 首页控制作用域

防火墙首页顶部开关和首页 `public / private / custom` 模式切换，均不再只作用于默认用户 `100`。

新语义固定为：

- 作用用户集合固定取自 `SystemUserProvider.loadAvailableUserIds()`
- 首页开关和首页模式切换都要对该用户集合全量生效

不再允许以下旧口径继续作为实现或评审依据：

1. “首页只控制默认用户 `100`”
2. “其他用户只受用户弹窗单独控制，不受首页影响”

### 2.2 首页模式语义

首页三种模式语义固定如下：

1. `public`
2. `private`
3. `custom`

这三种模式均属于首页全局模式。

新语义固定为：

- 首页切换到任意一种模式时，都应对 `SystemUserProvider.loadAvailableUserIds()` 返回的全部用户统一下发

### 2.3 `public / private` 模式下发规则

首页切换到 `public` 或 `private` 时：

- 对所有用户统一下发该模式对应的 policy：`isOpen=true`，`inAction=RULE_ALLOW`，`outAction=RULE_ALLOW`
- 对所有用户统一下发该模式对应的规则

此链路不使用“历史 mode -> `inAction/outAction`”推导逻辑。

固定要求：

- `public / private` 的 policy 固定为双向允许
- `public / private` 直接使用各自模式定义好的规则

### 2.4 `custom` 模式下发规则

首页切换到 `custom` 时：

- 对所有用户统一重建 policy
- 但每个用户实际收到的规则，必须是该用户命中的自定义规则

可理解为：

- “首页切到 custom”是全局动作
- “每个用户最终得到什么 policy”由本地 `userId -> mode` 历史记录决定
- “每个用户最终拿到哪些规则”仍然由规则自己的用户作用域决定

固定要求：

1. `custom` 模式要对所有用户执行 policy 恢复
2. `custom` 模式只为每个用户下发其命中的自定义规则
3. 每个用户不能简单共享一套完全相同的规则结果

## 3. 历史模式记录与 policy 推导

### 3.1 历史记录来源

当前项目已存在的“全局策略历史记录”继续沿用现有真相，不新增第二套记录来源。

当前有效历史记录为：

- `userId -> mode`

当前记录语义位于：

- `UserFirewallModeBinding`

本文确认：

- 继续使用这份历史 mode 记录作为 `custom` 模式下 `inAction / outAction` 的推导输入
- 当前项目中不存在单独持久化的 `inAction / outAction` 历史值，后续解释不得假设已有该类存储

### 3.2 mode 与 `inAction / outAction` 的固定映射

历史 mode 与 `NetFirewallPolicy.inAction / outAction` 的对应关系固定如下：

1. 白名单 `allowlist`
   - `inAction = FirewallRuleAction.RULE_DENY`
   - `outAction = FirewallRuleAction.RULE_DENY`
2. 黑名单 `denylist`
   - `inAction = FirewallRuleAction.RULE_ALLOW`
   - `outAction = FirewallRuleAction.RULE_ALLOW`

### 3.3 `custom` 模式下的 policy 生成规则

首页切换到 `custom` 时，每个用户的 `NetFirewallPolicy` 生成规则固定如下：

1. 先读取该用户历史 mode 记录
2. 如果历史 mode = `allowlist`
   - `inAction = RULE_DENY`
   - `outAction = RULE_DENY`
3. 如果历史 mode = `denylist`
   - `inAction = RULE_ALLOW`
   - `outAction = RULE_ALLOW`
4. 如果没有历史记录
   - `inAction = RULE_ALLOW`
   - `outAction = RULE_ALLOW`

补充约束：

- `custom` 模式下没有历史记录时，默认行为固定为“全部允许”
- 不允许在 `custom` 模式下使用 `public / private` 的 policy 作为兜底

## 4. 首页顶部开关语义

### 4.1 关闭语义

首页顶部防火墙开关关闭时：

- 应对 `SystemUserProvider.loadAvailableUserIds()` 返回的所有用户统一执行关闭
- 只修改每个用户 policy 的 `isOpen=false`
- 不修改 `inAction / outAction`
- 不清理规则，不重建规则，不保存模式

本文只固化“首页关闭是全量用户动作”和“只改 `isOpen`”的作用域真相。

### 4.2 重新开启语义

首页顶部防火墙开关在关闭后重新开启时，只恢复 `isOpen=true`。

固定要求：

- 对所有用户统一修改 `isOpen=true`
- 保留关闭前已有的 `inAction / outAction`
- 不按当前首页模式重建 policy
- 不重新下发 `public / private / custom` 规则

前提约束：

- 防火墙关闭后，产品侧没有其它入口允许用户修改 policy。
- 因此关闭期间不会产生需要“重新开启时重建模式 policy”的用户操作。

## 5. 作用域边界

本文只约束首页全局控制链路，不直接重写以下链路的独立业务定义：

1. 自定义规则新增 / 编辑 / 删除
2. 规则冲突判断
3. 用户列表发现机制
4. 用户历史 mode 的存储结构
5. PIN 认证链路

但如果这些链路与本文发生冲突，以本文定义的首页全局控制语义为准。

## 6. 与旧口径的关系

本文确认以下旧口径在首页链路中失效：

1. 首页只控制默认用户 `100`
2. 首页 `custom` 只影响默认用户 `100`
3. 首页模式切换只替换规则、不写 policy
4. 首页 `custom` 模式下忽略历史 mode 记录

本文不直接覆盖“用户弹窗 policy-only 链路”的全部讨论，但在“首页全局开关 / 首页全局模式切换”范围内，本文优先级更高。

## 7. 验收信号

完成后应满足：

1. 首页顶部开关不再只修改默认用户 `100`
2. 首页三种模式切换对 `SystemUserProvider.loadAvailableUserIds()` 返回的所有用户生效
3. 首页切到 `custom` 时，所有用户都参与下发
4. 首页切到 `custom` 时，每个用户只收到其命中的自定义规则
5. `custom` 模式下，历史 `allowlist` 用户得到 `DENY / DENY`
6. `custom` 模式下，历史 `denylist` 用户得到 `ALLOW / ALLOW`
7. `custom` 模式下，没有历史记录的用户得到 `ALLOW / ALLOW`
8. `public / private` 模式下，所有用户得到 `ALLOW / ALLOW`
9. 首页关闭后再次开启时，只恢复所有用户的 `isOpen=true`，不重建 policy 和规则
