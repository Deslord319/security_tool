# 外设管理-设备连接记录：RuntimeService 迁移收口报告

> 日期：2026-04-02  
> 依据：`docs/refac/peripheral-management/device-connection-record.md`  
> 对应计划：`docs/refac/peripheral-management/device-connection-record-runtime-service-migration-plan.md`

## 1. 结论

本轮迁移完成后，连接记录主链路已经回到 SSOT 目标形态：

- `producer -> consumers -> pipeline -> PeripheralTraceRepository`

`PeripheralRuntimeEventService.ets` 已退出连接记录订阅、事件生产、事件消费、mapping helper 和 pipeline push 直接入口职责。

## 2. PeripheralRuntimeEventService 当前保留职责

当前 [PeripheralRuntimeEventService.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/PeripheralRuntimeEventService.ets) 仅保留以下职责：

1. 连接记录链路初始化编排
- `init(context)`
- 负责：
  - `pipeline.bindContext(context)`
  - `pipeline.attachProducer(runtimeProducer)`
  - `PeripheralDevicePolicyRepository.init(context)`

2. 运行时生命周期外壳
- `start()`
- `stop()`
- 负责通过 `pipeline.start()/stop()` 驱动 producer 生命周期

3. 状态查询
- `getStatus()`
- `probeCapabilities()`

4. 单例装配
- `getRuntimeProducer()`
- `getRuntimePipeline()`

5. 初始化失败原因归一
- `buildInitDegradedReason(...)`

## 3. 从 RuntimeEventService 删除的连接记录职责

以下职责已从 `PeripheralRuntimeEventService.ets` 删除：

1. 连接记录订阅
- `registerUsbRuntimeEvents(...)`
- `registerBluetoothRuntimeEvents(...)`

2. 连接记录事件入口
- `consumeUsbCommonEvent(...)`
- `consumeBluetoothAclCommonEvent(...)`

3. 标准事件组装
- `buildProducerEvent(...)`

4. USB mapping helper
- `mapUsbCommonEventToTraceRecord(...)`
- `resolveUsbEventInfo(...)`
- `evaluateUsbEventPolicy(...)`

5. Bluetooth ACL mapping helper
- `mapBluetoothAclCommonEventToTraceRecord(...)`
- `resolveBluetoothAclEventInfo(...)`

6. connection-record pipeline glue
- RuntimeEventService 直接 `pipeline.push(...)` 路径

## 4. SSOT 目标链路新增/沉淀的函数

### 4.1 Producer 侧

文件：
- [peripheral_connection_record_runtime_producer_adapter.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_runtime_producer_adapter.ets)

本轮沉淀的核心函数：

1. 订阅与启停
- `start()`
- `stop()`
- `registerUsbRuntimeEvents()`
- `registerBluetoothRuntimeEvents()`
- `cleanupBluetoothRuntimeEvents()`
- `cleanupBluetoothAclSubscriber(...)`

2. 蓝牙 ACL 订阅恢复与权限处理
- `handleBluetoothStateChange(...)`
- `resumeBluetoothAclSubscriptionIfNeeded(...)`
- `subscribeBluetoothAclStateChange(...)`
- `ensureBluetoothRuntimePermission(...)`
- `hasBluetoothRuntimePermission()`
- `enterBluetoothPermissionBlocked(...)`
- `isBluetoothPermissionDeniedError(...)`

3. 标准事件生产
- `buildProducerEvent(...)`
- `emitRuntimeEvent(...)`

4. producer 生命周期与能力
- `bindContext(...)`
- `subscribe(...)`
- `unsubscribe(...)`
- `getStatus()`
- `buildDegradedReason(...)`

### 4.2 USB Consumer 侧

文件：
- [peripheral_connection_record_usb_consumer.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_usb_consumer.ets)

已沉淀的核心函数：

1. 入口
- `canHandle(...)`
- `consume(...)`

2. USB mapping / policy
- `resolveAction(...)`
- `resolveUsbEventInfo(...)`
- `evaluateUsbEventPolicy(...)`
- `readCurrentUsbPolicySnapshot(...)`
- `readCurrentUsbStoragePolicy(...)`
- `resolveEffectivePolicyLabel(...)`

3. USB payload 解析 helper
- `collectPayloadSources(...)`
- `resolveVendorId(...)`
- `resolveProductId(...)`
- `resolveBaseClass(...)`
- `resolveSubClass(...)`
- `resolveProtocol(...)`

### 4.3 Bluetooth ACL Consumer 侧

文件：
- [peripheral_connection_record_bluetooth_acl_consumer.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_bluetooth_acl_consumer.ets)

已沉淀的核心函数：

1. 入口
- `canHandle(...)`
- `consume(...)`

2. Bluetooth ACL mapping
- `resolveBluetoothAclEventInfo(...)`
- `resolveBluetoothAclAction(...)`
- `resolveBluetoothAclStateLabel(...)`
- `resolveBluetoothAclReasonLabel(...)`
- `resolveBluetoothOccurAt(...)`
- `resolveBluetoothDeviceName(...)`

3. Bluetooth payload 解析 helper
- `collectPayloadSources(...)`
- `resolveBluetoothDeviceId(...)`
- `maskBluetoothIdentifier(...)`

### 4.4 Pipeline 侧

文件：
- [peripheral_connection_record_pipeline.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_pipeline.ets)

已沉淀的核心函数：

1. producer 装配
- `attachProducer(...)`
- `detachProducer(...)`
- `bindContext(...)`

2. 生命周期
- `start()`
- `stop()`

3. 主处理链
- `push(...)`
- `shouldSkipByDedupe(...)`
- `ensureTraceRepositoryReady()`

## 5. 当前验收状态

1. `entry/src/main/ets/services/peripheral/connection-record/` 下主代码已不再调用 `PeripheralRuntimeEventService.*`
2. `PeripheralRuntimeEventService.ets` 中已无连接记录订阅、直接 push、mapping helper
3. 构建验证通过：
- `hvigorw assembleHap --mode module -p product=default -p module=entry`

## 6. 后续注意项

1. Step 5 删除了 RuntimeService 旧 helper 后，旧测试若仍 monkeypatch 这些 helper，需要同步改到 consumer 侧或 mock 其真实依赖。
2. 当前项目测试入口仍未统一，`hvigorw :entry:test` 不可用；如需补测试回归，应先确定可执行测试任务。
