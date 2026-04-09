# 外设管理-设备连接记录：策略标签对齐方案

> 状态：Draft
> 日期：2026-04-09
> 适用范围：仅用于“设备连接记录列表”的【策略】标签修正
> 当前阶段：方案沉淀，不进入执行

## 1. 背景

当前“外设管理 > 设备连接记录列表”的【策略】列存在两个已确认问题：

1. USB 单设备黑白名单下发 `deny` 后，列表未稳定显示为 `已禁用`
2. 蓝牙设备记录当前显示为 `--`，没有进入与 USB 一致的 `已启用 / 已禁用` 状态语义

经过代码定位，现状问题点如下：

- 列表最终显示逻辑位于：
  - `entry/src/main/ets/components/peripheral/connection-record/DeviceRecordList.ets`
- 当前组件内的旧逻辑为：
  - `getPolicyText(record)` 先取 `record.effectivePolicyLabel`
  - 若为空，再回退到 `getPeripheralConnectionPolicyLabel(record)`
- 蓝牙记录当前写库时直接写入：
  - `effectivePolicyLabel: '--'`
  - 文件：`entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_bluetooth_acl_consumer.ets`
- USB `device_deny` 分支当前虽然命中 deny，但仍沿用旧的 `effectivePolicyLabel`
  - 文件：`entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_usb_consumer.ets`

结论：

- 当前问题不是仓库没同步，而是“用于列表展示的最终状态”写得不完整
- 同时，“列表标签显示规则”被放在组件层，偏离当前 MVVM 分层

## 2. 目的

本次方案只解决“列表【策略】列最终显示不正确”的问题，不扩大成运行时链路重构。

目标如下：

- USB 单设备 deny -> 列表显示 `已禁用`
- 蓝牙默认 -> 列表显示 `已启用`
- 蓝牙命中 deny -> 列表显示 `已禁用`
- View 组件不再自己解释业务显示逻辑
- 展示逻辑收口到 mapper，符合当前 MVVM 架构

## 3. 核心思路

本次方案的核心思路已经收敛为一条固定路径：

1. 在连接记录生成时，把“列表展示所需的最终状态”写对
2. 在展示层只做统一读取，不再补猜
3. 在 View 层只渲染 mapper 结果，不再写业务判断

换句话说：

- consumer 负责写对 `effectivePolicyLabel`
- mapper 负责输出列表最终展示文案
- `DeviceRecordList` 只负责显示

本次不接受“如果 mapper 不够，再追加改 consumer”这类分叉方案。  
方案必须在设计阶段就收敛为单一路径。

## 4. 方案边界

本次方案明确不做以下事情：

- 不重构 producer / pipeline / repository 主链路
- 不新增第二套持久化真源
- 不把列表标签展示问题扩展成详情弹窗语义重构
- 不在组件层继续叠加 if/else 解释业务状态

## 5. 确定修改范围

当前讨论确定后，后续进入执行阶段时，允许修改的文件范围固定如下：

- `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_usb_consumer.ets`
- `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_bluetooth_acl_consumer.ets`
- `entry/src/main/ets/viewmodels/peripheral/connection-record/PeripheralRecordPresentationMapper.ets`
- `entry/src/main/ets/components/peripheral/connection-record/DeviceRecordList.ets`
- `entry/src/test/peripheral/connection-record-usb-consumer.test.ets`
- `entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets`
- `entry/src/test/utils/PeripheralRecordViewDataUtils.test.ets`

本文件只沉淀方向和范围，不展开具体 patch。

## 6. 具体代码位置与责任

### 6.1 USB consumer

文件：

- `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_usb_consumer.ets`

当前关键位置：

- `device_deny` 分支：约第 177-186 行
- `resolveEffectivePolicyLabel(...)`：约第 226-234 行

本轮责任：

- USB 单设备 deny 时，写入明确的 `effectivePolicyLabel='已禁用'`
- USB 允许态统一写成列表需要的最终展示值

### 6.2 蓝牙 consumer

文件：

- `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_bluetooth_acl_consumer.ets`

当前关键位置：

- 返回记录对象：约第 52-70 行

本轮责任：

- 删除 `effectivePolicyLabel='--'`
- 根据蓝牙设备策略写入 `已启用 / 已禁用`
- 不再固定 `decision='unknown'`

### 6.3 Presentation Mapper

文件：

- `entry/src/main/ets/viewmodels/peripheral/connection-record/PeripheralRecordPresentationMapper.ets`

当前关键位置：

- `getPeripheralConnectionPolicyLabel(record)`：约第 52-60 行

本轮责任：

- 保留现有 `getPeripheralConnectionPolicyLabel(record)`，继续服务详情/历史
- 新增列表专用方法，用于输出列表【策略】列最终文案
- 列表方法不再输出“命中单设备禁止接入”“蓝牙连接事件”这类原因型文案

### 6.4 DeviceRecordList

文件：

- `entry/src/main/ets/components/peripheral/connection-record/DeviceRecordList.ets`

当前关键位置：

- `getPolicyText(record)`：约第 232-236 行

本轮责任：

- 删除组件层旧展示判断
- 改为只调用 mapper 的列表专用方法

## 7. 必须删除的腐败代码

后续进入执行阶段时，以下代码属于必须删除的腐败代码：

1. `entry/src/main/ets/components/peripheral/connection-record/DeviceRecordList.ets`
   - `getPolicyText(record)` 中当前直接判断 `effectivePolicyLabel` 的旧逻辑
   - 当前 fallback 到 `getPeripheralConnectionPolicyLabel(record)` 的旧逻辑

2. `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_bluetooth_acl_consumer.ets`
   - `effectivePolicyLabel: '--'`
   - 固定 `decision: 'unknown'` 的旧写法

3. `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_usb_consumer.ets`
   - `device_deny` 分支继续复用旧 `effectivePolicyLabel` 的写法

4. `entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets`
   - 所有把蓝牙 `--` 视为正确结果的旧断言

说明：

- 这里的“腐败代码”特指：在新方案成立后，仍保留旧显示语义、旧状态写法、旧测试预期的代码
- 后续执行时必须显式删除，不能通过“新逻辑叠加在旧逻辑之上”的方式保留

## 8. 架构约束

本方案必须满足以下 MVVM 约束：

- consumer 负责生成记录状态
- mapper 负责展示映射
- View 组件只负责渲染

因此不允许：

- 在 `DeviceRecordList.ets` 中继续新增业务状态判断
- 让 mapper 去猜测底层没有写清楚的状态
- 保留“组件层解释状态 + mapper 层再解释一次”的双轨逻辑

## 9. 当前结论

本轮讨论已经收敛出以下稳定结论：

1. 方案必须是单一路径，不能保留“如果不够再改”的分叉
2. 状态必须在写记录时写对，列表层不负责补洞
3. 展示收口应落在 `PeripheralRecordPresentationMapper.ets`
4. `DeviceRecordList.ets` 中现有 `getPolicyText(record)` 旧逻辑属于后续必须删除的目标
5. 本文件用于后续执行前对齐，不代表已经批准开始改代码

## 10. 后续动作

本文件之后的下一步应为：

- 在不进入代码执行前提下，基于本文件继续细化成小步实施计划
- 明确每一步输入 / 输出 / 验收标准 / 并行边界

在该实施计划得到确认前，不应直接改生产代码。
