# 自定义模式规则页状态回填问题分析

> 状态：Open
> 日期：2026-04-10
> 关联模块：
> - `entry/src/main/ets/viewmodels/firewall/rules/FirewallRulesViewModel.ets`
> - `entry/src/main/ets/services/firewall/stores/FirewallStore.ets`
> - `entry/src/main/ets/components/firewall/rules/AddRuleDialog.ets`

## 1. 文档目的

本文用于记录“防火墙管理 > 自定义模式”规则页在新增规则后执行删除 / 更新时误伤同批规则的问题分析结论、当前判断边界和修复方向。

这是一条运行期缺陷分析文档，不属于防火墙重构后的长期 follow-up open items。

## 2. 问题现象

- 新增两条同类型规则后，删除其中一条，会连带删除多条规则
- 新增两条同类型规则后，更新其中一条，会连带更新多条规则
- 表面现象容易看成“按类型批量删除 / 更新”
- 实际上不是按规则类型命中，而是多个规则在页面内存态里缺少稳定 `id`，被当成同一个目标一起命中

## 3. 已确认事实

### 3.1 自定义模式规则的稳定身份来源

当前自定义模式规则的稳定身份应继续来自持久化层，而不是系统 `ruleId`：

- 存储主键：`customRuleId`
- 展示态主键：`id = hash(customRuleId)`

该机制已在 `FirewallStore` 中存在，不需要新建另一套身份体系。

### 3.2 当前根因不在 `customRuleId` 生成

当前问题的根因不是“新增时没有生成 `customRuleId`”，而是：

- `saveRules(...)` 保存成功后
- `FirewallRulesViewModel` 直接把 `nextRules` 回填给 `this.rules`
- `nextRules` 属于页面输入态 / 临时态对象
- 新增规则在该时点尚未经过持久化回读，因此没有稳定 `id`

### 3.3 为什么会表现为“同一类型规则一起被删 / 改”

删除、更新、冲突替换等逻辑都依赖 `getLocalRuleId(...)` 定位目标规则。

当多条新增规则在页面里都没有稳定 `id` 时：

- 删除逻辑会把多个 `undefined id` 规则一起过滤掉
- 更新逻辑会把多个 `undefined id` 规则一起替换掉

之所以经常表现为“同一类型规则一起被删 / 改”，只是因为同批新增的规则恰好往往属于同一类型；真正命中条件是“同样缺少稳定 `id`”，不是“同类型”。

## 4. 当前判断边界

### 4.1 不作为本问题主修复点的内容

- 不以系统 `ruleId` 作为自定义模式规则页的稳定身份
- 不新增新的规则主键模型
- 不把该问题归类为长期重构 follow-up open item
- 不依赖 `FirewallRepository` 侧兜底保留已有 `id/ruleId` 作为本问题的主修复手段

### 4.2 当前主修复点

主修复点应放在：

- `entry/src/main/ets/viewmodels/firewall/rules/FirewallRulesViewModel.ets`

原因：

- 问题发生在“保存成功后的状态回填”
- 不是发生在“持久化主键生成”
- 也不是发生在“系统规则返回”

## 5. 建议修复方向

在 `saveRules(...)` 成功分支中：

- 删除直接回填 `nextRules` 给 `this.rules` 的逻辑
- 改为统一调用 `reloadRules(context)` 或等价的持久化回读链路

目标是让页面规则列表始终以持久化结果为唯一真相：

- 由存储层负责提供稳定 `customRuleId`
- 由回读链路负责恢复展示态 `id`
- ViewModel 不再把临时输入态对象当成最终状态

## 6. 验收信号

修复完成后应满足：

- 新增两条同类型规则后，删除其中一条，只删除目标规则
- 新增两条同类型规则后，更新其中一条，只更新目标规则
- 保存成功后，页面不再持有未带稳定 `id` 的新增规则对象
- 规则页状态真相统一来自持久化回读结果

## 7. 备注

本问题文档用于承载此次缺陷讨论和修复判断，后续如问题关闭，可在文档内补充：

- 最终修改文件
- 最终验证结论
- 关联提交号
