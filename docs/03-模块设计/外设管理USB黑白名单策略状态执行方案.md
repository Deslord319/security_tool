---
module: "peripheral"
title: "USB 黑白名单策略状态执行方案"
status: "wip"
last_updated: "2026-07-09"
version: "0.1.0"
---

# USB 黑白名单策略状态执行方案

## 1. 目标范围

本方案用于外设管理模块 USB 黑白名单规格变更的实施拆解。

目标只针对黑白名单中的 USB 设备生效，不扩展蓝牙、Wi-Fi、打印、HDC、网络共享、麦克风、摄像头等接口管控逻辑。USB Hub 拓扑节点继续按现有规则过滤，不进入连接记录、黑白名单和 USB 策略状态库。

新规格要求应用自己维护一套 USB 设备策略状态：

- USB 插入后识别设备唯一标识。
- 有 SN 时按 SN 强匹配。
- 无 SN 时按 `VID + PID + description` 弱指纹匹配。
- 插入后记录设备当前黑白名单策略状态。
- 黑名单设备插入后立即下发禁止策略。
- 黑名单设备拔出后内部恢复系统允许策略，但 UI 仍显示禁止。
- 插拔触发的内部策略恢复不补连接记录，也不补策略变更记录。
- 设备离线后，黑白名单页面不允许修改该设备策略。
- 删除连接记录不应破坏已有黑白名单策略状态。
- 还原策略需要同步更新本地策略状态。

## 2. 职责拆分

### 2.1 USB 唯一标识解析

新增 `UsbDeviceIdentityResolver`，只负责从 USB 公共事件或系统枚举信息生成设备 identity。

该组件不得依赖数据库，不得读写策略，不得调用 MDM 能力。

输出建议模型：

```ts
export interface UsbDeviceIdentity {
  fingerprintKey: string
  fingerprintType: 'serial' | 'weak'
  serialNumber?: string
  vendorId: number
  productId: number
  description?: string
  baseClass: number
  deviceName: string
}
```

唯一标识规则：

```text
有 serialNumber:
  fingerprintKey = USB-SN:<normalizedSerialNumber>
  fingerprintType = serial

无 serialNumber:
  fingerprintKey = USB-WEAK:<VID>:<PID>:<hash(normalizedDescription)>
  fingerprintType = weak
```

弱指纹中的 `description` 取公共事件 payload 的 `description` 字段。若 `description` 后续变化，会被识别为另一个弱指纹设备。

设备展示名继续复用现有 USB 名称规则：

```text
manufacturerName + productName -> deviceName -> 通用 USB 兜底名称
```

展示名不得参与 fingerprint 生成。

### 2.2 USB 策略状态持久化

新增 `UsbDevicePolicyStateRepository`，只负责本地 USB 策略状态增删改查。

该组件不得生成 fingerprint，不得调用 MDM 能力，不得直接读取连接记录列表。

建议新增 RDB 表：`usb_device_policy_states`。

最小字段如下：

| 字段 | 类型 | 必须 | 说明 |
|---|---:|---:|---|
| `fingerprint_key` | TEXT | 是 | 主键，强标识或弱指纹结果 |
| `fingerprint_type` | TEXT | 是 | `serial` / `weak` |
| `serial_number` | TEXT | 否 | 有 SN 时记录，弱指纹为空 |
| `vendor_id` | INTEGER | 是 | USB VID |
| `product_id` | INTEGER | 是 | USB PID |
| `description` | TEXT | 否 | 归一化后的公共事件 `description` |
| `base_class` | INTEGER | 是 | USB 类型级下发和同类型保护使用 |
| `device_name` | TEXT | 是 | 最新展示名，插入时刷新 |
| `desired_policy` | TEXT | 是 | UI 逻辑策略：`allow` / `deny` |
| `present` | INTEGER | 是 | 当前是否插入：`0` / `1` |
| `active_policy` | TEXT | 是 | 当前由本应用保持的系统下发态：`none` / `deny` |
| `last_seen_at` | INTEGER | 是 | 最近一次插入时间 |
| `updated_at` | INTEGER | 是 | 本行最后更新时间 |

不建议保存的冗余字段：

- `device_type`：可由 `base_class` 推导。
- `policy_index`：可由 `desired_policy` 推导。
- `last_attach_at` 和 `last_detach_at`：连接记录已保存事件时间，策略状态库只需要 `last_seen_at`。
- `physical_state = allow_restored`：可由 `desired_policy=deny + present=0 + active_policy=none` 表达。
- `last_dispatch_policy`：与 `active_policy` 重复。
- `last_dispatch_at`：当前业务不展示、不参与策略判断，失败和耗时应走日志。
- `last_error`：失败原因不应长期影响策略状态，走操作返回和日志。
- `source_record_id`：策略状态不能耦合连接记录，否则删除记录会破坏后续重插自动下发。
- `description_hash`：已包含在 `fingerprint_key` 中，不单独保存。

### 2.3 USB 策略状态服务

新增 `UsbDevicePolicyStateService`，负责串联 identity、repository 和 dispatch。

核心职责：

- USB 插入时更新本地状态并按需下发 deny。
- USB 拔出时按需内部恢复 allow。
- 用户修改策略时校验设备是否在线。
- 用户还原策略时同步本地状态和系统策略。
- 删除连接记录或清空连接记录时避免破坏已有策略状态。
- 处理同 `base_class` 多设备同时在线时的恢复保护。

## 3. 数据库字段减法结论

最终建议只保留业务闭环必须字段：

```text
fingerprint_key
fingerprint_type
serial_number
vendor_id
product_id
description
base_class
device_name
desired_policy
present
active_policy
last_seen_at
updated_at
```

判断依据：

- identity 字段只保存匹配和展示必要信息。
- UI 策略只保存 `desired_policy`。
- 系统下发态只保存 `active_policy`，不额外保存可推导状态。
- 在线态只保存 `present`。
- 时间只保留列表排序和刷新必要的 `last_seen_at / updated_at`。
- 不保存连接记录 ID，避免策略库和记录库耦合。

## 4. 插入流程

USB attach 事件进入后：

1. 解析事件 action，确认是 `connect`。
2. 解析 VID、PID、baseClass、SN、description、设备展示名。
3. 过滤 USB Hub。
4. 调用 `UsbDeviceIdentityResolver.resolve(...)` 生成 identity。
5. 使用 `fingerprint_key` 查询 `UsbDevicePolicyStateRepository`。
6. 若不存在状态：
   - 写入新状态。
   - `desired_policy` 按当前 USB 默认策略决定，默认允许时为 `allow`，默认禁止时为 `deny`。
   - `present=1`。
   - `active_policy=none`。
7. 若存在状态：
   - 刷新 `present=1`。
   - 刷新 `device_name`、`base_class`、`description`、`last_seen_at`、`updated_at`。
8. 如果最终 `desired_policy=deny`：
   - 调用 `PeripheralDevicePolicyDispatchService` 下发 deny。
   - 下发成功后更新 `active_policy=deny`。
   - 下发失败时不把 `active_policy` 改成 deny，连接记录追加失败原因。
9. 生成正常 USB 插入连接记录。
10. 不额外补 `policy_snapshot`，不额外补策略变更记录。

## 5. 拔出流程

USB detach 事件进入后：

1. 解析事件 action，确认是 `disconnect`。
2. 解析同一套 identity。
3. 使用 `fingerprint_key` 查询策略状态。
4. 更新当前设备 `present=0`。
5. 如果当前设备 `active_policy=deny`：
   - 查询同 `base_class` 是否仍存在其它 `present=1 && active_policy=deny` 的 USB 设备。
   - 若存在，不恢复 allow，避免同类型黑名单设备仍在线时提前放开系统策略。
   - 若不存在，内部调用 allow 恢复系统策略。
6. 恢复成功后更新当前设备 `active_policy=none`。
7. UI 仍根据 `desired_policy` 显示禁止。
8. 生成正常 USB 断开连接记录。
9. 不补策略变更记录，不补插拔导致的内部 allow 恢复记录。

## 6. 用户修改黑白名单策略

黑白名单页面策略修改入口必须先判断设备是否在线。

在线设备：

- 设置为 deny：
  - 下发 deny。
  - 成功后写入 `desired_policy=deny`、`active_policy=deny`。
- 设置为 allow：
  - 下发 allow。
  - 成功后写入 `desired_policy=allow`、`active_policy=none`。

离线设备：

- 不允许修改。
- UI 控件禁用。
- 不调用 MDM 下发。
- 不修改 `desired_policy`。

离线禁用修改的原因是当前系统策略按 USB 类型下发，不是单设备精准下发。离线修改会导致 UI 逻辑策略和系统真实状态难以一致。

## 7. 还原策略

还原策略是用户主动行为，和插拔内部恢复不同。

在线设备：

1. 如果 `active_policy=deny`，先下发 allow。
2. 成功后清理策略状态，或更新为 `desired_policy=allow`、`active_policy=none`。
3. 允许保留现有用户主动策略变更记录逻辑。

离线设备：

1. 不调用 MDM 下发。
2. 只更新本地数据库状态。
3. 可清理策略状态，或更新为 `desired_policy=allow`、`active_policy=none`。

插拔触发的内部 allow 恢复不得进入本流程，不得补连接记录或策略变更记录。

## 8. 删除连接记录和清空连接记录

连接记录库和 USB 策略状态库必须解耦。

删除连接记录时：

- 只删除连接记录展示数据。
- 当前实现只在清空连接记录时清理 `present=0` 的 USB 策略状态。
- `present=1` 的在线设备状态不动，避免清记录动作误改当前系统策略。

清空连接记录时：

- 删除 `present=0` 的 USB 策略状态。
- 保留 `present=1` 的 USB 策略状态。

## 9. UI 展示规则

黑白名单页面后续不再从连接记录反推候选，也不兼容旧 `device_policies` 单设备策略。

展示数据来源：

- 只来自 `usb_device_policy_states`。
- UI 策略显示 `desired_policy`。
- 在线状态显示 `present`。

交互规则：

- `present=1` 时允许修改策略。
- `present=0` 时禁用策略修改控件。
- `desired_policy=deny && present=0 && active_policy=none` 时，UI 仍显示禁止。

## 10. 需要修改的文件

设计文档：

- `docs/03-模块设计/外设管理组件设计说明.md`

模型：

- `entry/src/main/ets/models/PeripheralModels.ets`

新增服务：

- `entry/src/main/ets/services/peripheral/device-policy/UsbDeviceIdentityResolver.ets`
- `entry/src/main/ets/services/peripheral/device-policy/UsbDevicePolicyStateRepository.ets`
- `entry/src/main/ets/services/peripheral/device-policy/UsbDevicePolicyStateService.ets`

调整现有服务：

- `entry/src/main/ets/services/peripheral/connection-record/PeripheralConnectionRecordUsbConsumer.ets`
- `entry/src/main/ets/services/peripheral/device-policy/PeripheralDevicePolicyDispatchService.ets`
- `entry/src/main/ets/services/peripheral/device-policy/PeripheralPolicyService.ets`
- `entry/src/main/ets/viewmodels/peripheral/device-policy/PeripheralPolicyViewModel.ets`
- `entry/src/main/ets/viewmodels/peripheral/connection-record/PeripheralConnectionRecordClearUsecase.ets`

调整 UI：

- 黑白名单列表组件。
- 策略选择控件增加离线禁用态。

测试：

- `entry/src/test/peripheral/connection-record-usb-consumer.test.ets`
- `entry/src/test/peripheral/device-policy-dispatch-service.test.ets`
- 新增 USB identity resolver 测试。
- 新增 USB policy state repository/service 测试。
- `entry/src/test/viewmodels/PeripheralPolicyViewModel.test.ets`
- 必要时补 ohosTest 连接记录契约。

## 11. 验收用例

必须覆盖以下场景：

1. 有 SN 的 USB 首次插入后写入策略状态。
2. 有 SN 的 USB 重插后命中原策略。
3. 无 SN 的 USB 使用 `VID + PID + description` 生成弱指纹。
4. 弱指纹 USB 重插后命中原策略。
5. 黑名单 USB 插入后自动下发 deny。
6. 黑名单 USB 拔出后内部恢复 allow。
7. 内部恢复 allow 后 UI 仍显示禁止。
8. 插拔触发的内部策略变化不补连接记录。
9. 插拔触发的内部策略变化不补 `policy_snapshot`。
10. 离线 USB 黑白名单控件禁用，不能修改策略。
11. 多个同 `base_class` 黑名单 USB 同时在线时，拔出其中一个不得提前恢复 allow。
12. 最后一个同 `base_class` 黑名单 USB 拔出后才恢复 allow。
13. 删除连接记录不删除已有黑白名单策略状态。
14. 清空连接记录后，已有黑白名单策略设备仍能展示。
15. 在线设备还原策略时下发 allow 并更新数据库。
16. 离线设备还原策略时只更新数据库，不调用 MDM。
17. USB Hub 不进入策略状态库。
18. USB 存储总策略为 `DISABLED` 时，继续遵循现有账户级禁止冲突规则。

## 12. 风险和边界

当前系统 MDM 下发能力按 USB 类型或 baseClass 生效，不是按单个 USB fingerprint 精确生效。

因此：

- 应用可以按 SN 或弱指纹维护逻辑黑白名单。
- 实际系统下发仍可能影响同类型 USB 设备。
- 同类型多设备在线时必须做 active deny 保护。
- 一个黑名单设备和一个白名单同类型设备同时在线时，白名单设备仍可能受到类型级 deny 影响，这是当前规格接受的系统能力边界。

## 13. 实施顺序

1. 更新正式外设模块设计文档。
2. 新增 USB identity 模型和 resolver。
3. 新增 USB 策略状态 repository。
4. 新增 USB 策略状态 service。
5. 改造 USB attach/detach consumer。
6. 改造策略下发 service，支持内部恢复 allow 和同类型保护。
7. 改造黑白名单列表构建逻辑。
8. 改造 ViewModel 和 UI 离线禁用态。
9. 改造还原策略和清空连接记录逻辑。
10. 补单元测试。
11. 回读中文文档，确认无乱码。
12. 运行 `python scripts/check_docs_consistency.py`。
13. 构建 HAP 并安装验证。
