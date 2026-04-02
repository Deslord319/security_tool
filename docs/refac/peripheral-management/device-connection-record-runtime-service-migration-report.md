# 外设管理-设备连接记录：RuntimeService 删除收口报告

> 日期：2026-04-02  
> 依据：`docs/refac/peripheral-management/device-connection-record.md`  
> 对应计划：`docs/refac/peripheral-management/device-connection-record-runtime-service-migration-plan.md`

## 1. 结论

本轮收口完成后，连接记录主链路已满足 SSOT 目标形态：

- `producer -> consumers -> pipeline -> PeripheralTraceRepository`

`PeripheralRuntimeEventService.ets` 已从生产代码中删除。  
连接记录运行时不再经由 RuntimeService 代理装配、启停或状态查询。

## 2. 删除前 RuntimeService 的职责替代关系

### 2.1 初始化装配

删除前职责：

- `init(context)`
- `pipeline.bindContext(context)`
- `pipeline.attachProducer(producer)`
- `PeripheralDevicePolicyRepository.init(context)`

替代后落点：

- `MainPage.initRuntimeServices()`
- `PeripheralConnectionRecordPipelineImpl.bindContext(...)`
- `PeripheralConnectionRecordPipelineImpl.attachProducer(...)`
- `PeripheralDevicePolicyRepository.init(context)` 由 `MainPage` 唯一启动链路触发

### 2.2 生命周期代理

删除前职责：

- `start()`
- `stop()`

替代后落点：

- `MainPage.ensureRuntimeServices()`
- `PeripheralConnectionRecordPipelineImpl.start()`
- `PeripheralConnectionRecordPipelineImpl.stop()`

### 2.3 运行状态查询

删除前职责：

- `getStatus()`
- `probeCapabilities()`

替代后落点：

- `PeripheralConnectionRecordRuntimeProducerAdapter.getStatus()`
- `MainPage` 直接读取 producer 状态

### 2.4 单例装配

删除前职责：

- `getRuntimeProducer()`
- `getRuntimePipeline()`

替代后落点：

- `MainPage` 私有字段直接持有：
  - `PeripheralConnectionRecordRuntimeProducerAdapter`
  - `PeripheralConnectionRecordPipelineImpl`

## 3. 页面级职责归属结果

### 3.1 MainPage

当前职责：

- 应用入口页加载后，作为唯一连接记录监听启动点
- 初始化：
  - `LogStorageService`
  - `LogRuntimeCollectorService`
  - `PeripheralTraceRepository.configure(...)`
  - `PeripheralDevicePolicyRepository.init(...)`
  - connection-record pipeline bind/attach/start

### 3.2 PeripheralPage

当前职责：

- 仅负责：
  - 视图展示
  - ViewModel 初始化
  - 详情、导出、清空等业务交互

已删除职责：

- 不再 `init/start` 连接记录 runtime
- 不再读取 `PeripheralRuntimeEventService.getStatus()`

## 4. SSOT 链路新增/沉淀的函数

### 4.1 Producer 侧

文件：

- [peripheral_connection_record_runtime_producer_adapter.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_runtime_producer_adapter.ets)

核心函数：

- `bindContext(...)`
- `start()`
- `stop()`
- `subscribe(...)`
- `unsubscribe(...)`
- `getStatus()`
- `registerUsbRuntimeEvents()`
- `registerBluetoothRuntimeEvents()`
- `buildProducerEvent(...)`
- `emitRuntimeEvent(...)`

对应环节：

- producer

### 4.2 USB Consumer 侧

文件：

- [peripheral_connection_record_usb_consumer.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_usb_consumer.ets)

核心函数：

- `canHandle(...)`
- `consume(...)`
- `resolveUsbEventInfo(...)`
- `evaluateUsbEventPolicy(...)`
- `mapUsbCommonEventToTraceRecord(...)`

对应环节：

- consumer

### 4.3 Bluetooth ACL Consumer 侧

文件：

- [peripheral_connection_record_bluetooth_acl_consumer.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_bluetooth_acl_consumer.ets)

核心函数：

- `canHandle(...)`
- `consume(...)`
- `resolveBluetoothAclEventInfo(...)`
- `mapBluetoothAclCommonEventToTraceRecord(...)`

对应环节：

- consumer

### 4.4 Pipeline 侧

文件：

- [peripheral_connection_record_pipeline.ets](/D:/project/ai/security_tool/entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_pipeline.ets)

核心函数：

- `bindContext(...)`
- `attachProducer(...)`
- `detachProducer()`
- `start()`
- `stop()`
- `push(...)`
- `ensureTraceRepositoryReady()`
- `shouldSkipByDedupe(...)`

对应环节：

- pipeline

## 5. 当前架构判断

### 5.1 SSOT

符合。

原因：

- 运行时订阅与标准事件生产在 producer
- 记录映射在 consumers
- 统一持久化在 pipeline -> `PeripheralTraceRepository`
- `PeripheralRuntimeEventService` 已退出链路

### 5.2 MVVM（按本项目最小改动口径）

可接受。

原因：

- `PeripheralPage` 已退出运行时初始化/启动职责
- 清空连接记录仍通过 ViewModel/usecase
- `MainPage` 作为应用入口页承担唯一启动点，属于应用级装配，不再由业务子页承担

## 6. 验收结果

1. `EntryAbility` 仍加载 `pages/MainPage`
2. `MainPage` 是唯一监听启动点
3. `PeripheralPage` 不再启动监听
4. `entry/src/main` 无 `PeripheralRuntimeEventService` 生产引用
5. `PeripheralRuntimeEventService.ets` 已删除
6. 构建通过：
   - `hvigorw assembleHap --mode module -p product=default -p module=entry`
