# 防火墙自定义规则用户列表规格唯一真相

> 状态：Draft  
> 日期：2026-04-13  
> 适用范围：仅用于“防火墙管理 > 自定义模式 > 新增/编辑规则”的【用户列表】规格改造  
> 唯一判定依据：本文档

## 0. 背景+目的

当前防火墙“自定义模式”的规则模板是共享规则模型：规则本身不携带用户作用域，只能表达“存在这条规则”，不能表达“这条规则对哪些用户生效”。

这会带来两个直接问题：

1. 多用户设备场景下，规则粒度过粗，无法只对部分用户生效
2. 规则新增、编辑、展示、保存和读取链路中都缺少明确的用户范围语义

本次只聚焦一个规格变更：在“自定义模式-新增规则”中新增字段【用户列表】。

本次规格目标如下：

1. 新增规则时默认展示 `ALL`
2. `ALL` 只作为录入和展示快捷项，不作为长期持久化语义
3. 保存规则时，`ALL` 直接使用 `SystemUserProvider.loadAvailableUserIds()` 展开为当前明确的用户列表
4. 用户可改单选/多选具体用户
5. 【用户列表】不是临时 UI 字段，而是规则正式属性，进入创建、编辑、展示、保存、读取链路
6. 本次不考虑旧数据兼容，直接切换到新模型

## 1. 规格结论

### 1.1 用户列表字段语义

【用户列表】本质上是规则面向对象的固定用户集合，不是长期动态作用域语义。

每条自定义规则都必须携带正式的用户列表信息。

建议统一建模为：

- `userIds: number[]`

约束如下：

- `userIds` 必须非空
- `userIds` 在保存前必须去重并按升序归一化

### 1.2 ALL 的语义

`ALL` 只作为录入和展示快捷项，不作为持久化语义保存。

保存规则时，如果当前选择为 `ALL`，则直接调用：

- `SystemUserProvider.loadAvailableUserIds()`

并将其展开为当前明确的 `userIds` 后再保存。

因此：

- `ALL` 表示“保存当下的全部用户”
- 持久化层只保存固定的 `userIds`
- 不新增第二套用户来源
- 后续删除、更新规则时，只针对固定用户集合生效

### 1.3 新增/编辑规则弹窗行为

弹窗中的【用户列表】字段行为如下：

1. 默认值为 `ALL`
2. 用户可切换为“指定用户”
3. “指定用户”模式支持单选/多选
4. 若未选择任何用户，则不允许保存
5. 编辑已有规则时，若规则 `userIds` 恰好等于当前全部用户，可在 UI 上回显为 `ALL`

### 1.4 规则列表展示

规则列表必须展示规则用户范围，避免新增字段后用户无法判断规则面向对象。

展示建议如下：

- `ALL`
- `用户 100`
- `用户 100、101`
- 多个用户时可压缩为 `3 个用户`

说明：

- 规则列表中的 `ALL` 是展示语义
- 若某条规则的 `userIds` 恰好覆盖当前全部用户，可展示为 `ALL`

### 1.5 冲突判断边界

本次规格落地后，规则冲突判断不能再只看规则本身，还必须考虑固定 `userIds` 是否有交集。

判断原则：

1. 规则键命中
2. 且 `userIds` 有交集

只有同时满足以上两条时，才判定为重复/冲突。

## 2. 修改代码文件范围

本次只修改以下文件：

1. `entry/src/main/ets/models/DataModels.ets`
2. `entry/src/main/ets/services/firewall/repositories/FirewallCustomRulesRepository.ets`
3. `entry/src/main/ets/services/firewall/mode-strategies/CustomModeStrategy.ets`
4. `entry/src/main/ets/components/firewall/rules/AddRuleDialog.ets`
5. `entry/src/main/ets/views/firewall/rules/FirewallRulesPage.ets`
6. `entry/src/main/ets/viewmodels/firewall/rules/FirewallRulesViewModel.ets`
7. `entry/src/main/ets/services/firewall/rules/FirewallRulesService.ets`
8. `entry/src/main/ets/constants/modules/FirewallStrings.ets`

说明：

- `SystemUserProvider.ets` 不在本次修改范围内
- 原因是当前已经存在 `loadAvailableUserIds()`，可直接作为 `ALL` 的用户来源

## 3. 实施边界

本次范围内：

- 固定用户集合模型
- 新增/编辑规则弹窗用户列表字段
- 规则列表用户范围展示
- 自定义规则保存/读取
- 冲突判断纳入 `userIds` 交集

本次范围外：

- 首页总开关语义调整
- 用户级全局策略语义调整
- 规则下发到所有用户的整体编排重构
- 旧数据兼容和迁移处理

## 4. 腐败代码处理要求

本次改造过程中，以下类型代码视为腐败代码，必须删除，不得保留：

1. 旧的“无作用域规则”处理分支
2. 为兼容旧结构而增加的兜底逻辑
3. 把用户范围塞进 `description` 或页面临时变量、但不进入正式规则模型的实现
4. 把 `ALL` 作为长期动态语义持久化保存的实现
5. 页面或 ViewModel 中重复定义 `ALL`、用户列表结构、判断规则的散落逻辑
6. 冲突判断里只看规则内容、不看 `userIds` 交集的旧判断分支

## 5. 验收信号

完成后应满足：

1. 新增规则默认显示 `ALL`
2. 用户可改单选/多选具体用户
3. 保存后的规则正式携带固定 `userIds`
4. 规则列表可展示用户范围，必要时可显示为 `ALL`
5. 编辑规则时用户列表可正确回显，必要时可回显为 `ALL`
6. 冲突判断已纳入 `userIds` 交集
7. 代码中不存在旧结构兼容逻辑、动态 `ALL` 持久化逻辑和用户列表临时拼装逻辑
