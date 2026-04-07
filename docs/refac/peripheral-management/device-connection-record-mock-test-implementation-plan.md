# 外设管理-设备连接记录 Mock 测试实施计划

> 状态：Draft  
> 最后更新：2026-04-03  
> 关联文档：`device-connection-record-mock-test-design.md`

## 1. 目标

将 `device-connection-record-mock-test-design.md` 中的测试用例清单落实为可并行执行、可逐步验收、可回溯的实施计划。

本计划遵循以下约束：

- 不入侵生产代码
- 不为了测试修改现有 MVVM 架构
- 每一步只处理一个小范围测试目标
- 每一步都明确输入、输出、伪代码、修改文件、执行命令和验收口径
- 支持多个 session 并行推进，且写入范围互斥

## 2. 执行总原则

### 2.1 追溯原则

每一步都必须记录：

- 输入用例 ID
- 输出测试文件
- 输出覆盖的测试用例 ID
- 执行命令
- 执行结果
- 未完成项

### 2.2 并行原则

不同 session 只能修改各自负责的测试文件，避免冲突。

### 2.3 最小步骤原则

- 先补 P0 主链路
- 再补 P1 异常和边界
- 最后补 P2 页面最小契约
- 每个子步骤必须收敛为单一可提交单元，不允许跨步骤混合提交

### 2.4 文件归属原则

优先复用现有测试文件；只有在现有文件职责过杂或不适合承载新用例时，才新增测试文件。

### 2.5 Git 提交追踪原则

- 每个子步骤必须单独形成一个最小 Git 提交。
- 一个提交只能覆盖一个子步骤；禁止把 `A-1` 和 `A-2`、`B-1` 和 `B-2` 等混在同一提交。
- 提交前必须先更新 tracker 中对应行的 `步骤 ID`、`提交状态`、`备注`。
- 提交后必须回填 tracker 中对应行的 `提交摘要` 和 `最近一次执行结果`。
- 如某个子步骤只完成代码未完成验证，允许提交，但 tracker 必须标记为 `in_progress` 或 `blocked`，不得标记为 `done`。
- 提交信息格式固定为：`test(peripheral-record): <步骤ID> cover <用例ID范围>`。

### 2.6 当前代码基线约束

本计划基于 `2026-04-03` 当前仓库代码状态执行，以下事实视为实施前提：

- `entry/src/main/ets/services/PeripheralRuntimeEventService.ets` 已退出生产链路，不再作为实施对象。
- `entry/src/main/ets/views/PeripheralPage.ets` 不再暴露 `executePeripheralPageClearHistory(...)`、`PeripheralPageClearHistoryAction`、`createClearConnectionHistoryActionForTest(...)`。
- `entry/src/main/ets/viewmodels/PeripheralViewModel.ets` 不再暴露 `setConnectionRecordClearUsecaseForTest(...)`。

因此：

- Session E 不允许继续依赖旧页面测试包装器。
- Session C 不允许继续依赖 test-only setter 注入 clear usecase。
- 如计划、追踪表或执行记录中出现上述旧入口，必须在实施前先清理。

## 3. Session 划分

| Session | 范围 | 负责用例组 | 主要测试文件 |
|---|---|---|---|
| A | USB / 蓝牙 consumer | `U-USB-*`、`U-BT-*` | `entry/src/test/peripheral/connection-record-usb-consumer.test.ets`、`entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets` |
| B | pipeline / service | `U-PIPE-*`、`U-SVC-*` | `entry/src/test/peripheral/connection-record-pipeline.test.ets`、`entry/src/test/peripheral/connection-record-service.test.ets` |
| C | record viewmodel / clear usecase / page viewmodel | `U-RVM-*`、`U-CLEAR-*`、`U-PVM-*` | `entry/src/test/viewmodels/PeripheralRecordViewModel.test.ets`、`entry/src/test/viewmodels/PeripheralViewModel.test.ets` |
| D | mapper / repository | `U-MAP-*`、`U-REPO-*` | `entry/src/test/utils/PeripheralRecordDisplayUtils.test.ets`、`entry/src/test/utils/PeripheralRecordViewDataUtils.test.ets`、必要时新增 repository 测试文件 |
| E | 页面最小契约 | `U-VIEW-*` | `entry/src/test/views/PeripheralPage.test.ets`、`entry/src/ohosTest/ets/test/peripheral/*.test.ets` |

## 4. 步骤 0：建立追踪表

### 4.1 目标

建立唯一执行跟踪基线，避免多 session 漏测、重测、冲突。

### 4.2 输入

- `device-connection-record-mock-test-design.md`

### 4.3 输出

- 一份测试实施追踪表文档
- 每个用例 ID 已绑定到唯一 session

### 4.4 要修改的文件

- 新增：`docs/refac/peripheral-management/device-connection-record-mock-test-tracker.md`

### 4.5 建议内容结构

追踪表字段固定为：

- 用例 ID
- 负责人 session
- 步骤 ID
- 状态：`todo` / `in_progress` / `done` / `blocked`
- 提交状态：`pending` / `committed`
- 提交摘要
- 目标测试文件
- 最近一次执行命令
- 最近一次执行结果
- 备注

### 4.6 伪代码

```text
ALGORITHM BuildTrackerFromDesignDoc
INPUT:
  designDocPath
  sessionAssignmentRules
OUTPUT:
  trackerDocument
PRECONDITION:
  designDocPath exists
STEPS:
  1. caseList <- ParseAllCaseIds(designDocPath)
  2. trackerRows <- []
  3. FOR EACH caseItem IN caseList DO
       owner <- AssignSession(caseItem.id, sessionAssignmentRules)
       targetFiles <- ResolveTargetTestFiles(caseItem.id)
       trackerRows <- trackerRows + NewTrackerRow(
         id = caseItem.id,
         name = caseItem.name,
         owner = owner,
         status = "todo",
         targetFiles = targetFiles
       )
     END FOR
  4. trackerDocument <- RenderTrackerMarkdown(trackerRows)
  5. WriteFile("docs/refac/peripheral-management/device-connection-record-mock-test-tracker.md", trackerDocument)
  6. RETURN trackerDocument
```

### 4.7 验收

- 所有用例 ID 都出现在追踪表中
- 没有用例 ID 未分配
- 没有两个 session 指向同一个测试文件写入

## 5. 步骤 1：Session A 实施计划

### 5.1 目标

补齐 USB consumer 与 Bluetooth ACL consumer 的 P0 和 P1 用例。

### 5.2 输入

- 用例 ID：
  - `U-USB-001` 到 `U-USB-010`
  - `U-BT-001` 到 `U-BT-008`
- 生产文件：
  - `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_usb_consumer.ets`
  - `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_bluetooth_acl_consumer.ets`

### 5.3 输出

- 更新后的 USB consumer 测试文件
- 更新后的 Bluetooth consumer 测试文件
- 对应执行结果记录

### 5.4 要修改的文件

- 修改：`entry/src/test/peripheral/connection-record-usb-consumer.test.ets`
- 修改：`entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets`

### 5.5 执行子步骤

#### A-1：补齐 USB attach 各策略分支

输入：

- `U-USB-001`、`U-USB-002`、`U-USB-003`、`U-USB-004`、`U-USB-005`

输出：

- USB attach 各策略分支单测

伪代码：

```text
ALGORITHM ImplementUsbPolicyBranchTests
INPUT:
  testCases = [U-USB-001, U-USB-002, U-USB-003, U-USB-004, U-USB-005]
OUTPUT:
  updatedUsbConsumerTestFile
PRECONDITION:
  connection-record-usb-consumer.test.ets exists
STEPS:
  1. Open target test file
  2. Add SetupBlock:
       SaveOriginal(PeripheralService.getInterfaceDisabledWithResult)
       SaveOriginal(PeripheralService.getUsbStoragePolicyWithResult)
       SaveOriginal(PeripheralDevicePolicyRepository.getAll)
  3. FOR EACH caseId IN testCases DO
       event <- BuildUsbAttachedEvent()
       SWITCH caseId
         CASE U-USB-001:
           MockUsbDisabled(true)
           MockUsbStoragePolicy(READ_ONLY)
           MockDevicePolicies([])
           expected <- { matchedPolicyKind: "usb_disabled", result: BLOCKED }
         CASE U-USB-002:
           MockUsbDisabled(false)
           MockUsbStoragePolicy(DISABLED)
           MockDevicePolicies([])
           expected <- { matchedPolicyKind: "usb_storage_disabled", result: BLOCKED }
         CASE U-USB-003:
           MockUsbDisabled(false)
           MockUsbStoragePolicy(READ_ONLY)
           MockDevicePolicies([])
           expected <- { matchedPolicyKind: "usb_storage_read_only", effectivePolicyLabel: "只读" }
         CASE U-USB-004:
           MockUsbDisabled(false)
           MockUsbStoragePolicy(READ_ONLY)
           MockDevicePolicies([DENY_FOR_EVENT_DEVICE])
           expected <- { matchedPolicyKind: "device_deny", result: BLOCKED }
         CASE U-USB-005:
           MockUsbDisabled(false)
           MockUsbStoragePolicy(ALLOW)
           MockDevicePolicies([])
           expected <- { matchedPolicyKind: "default_allow", result: SUCCESS }
       END SWITCH
       record <- consumer.consume(event)
       ASSERT record != null
       ASSERT record.matchedPolicyKind == expected.matchedPolicyKind
       ASSERT record.result == expected.result WHEN expected.result exists
       ASSERT record.effectivePolicyLabel == expected.effectivePolicyLabel WHEN expected.effectivePolicyLabel exists
     END FOR
  4. Add TeardownBlock:
       RestoreOriginals()
  5. Save target test file
  6. RETURN updatedUsbConsumerTestFile
```

验收：

- 上述 5 个用例全部通过

#### A-2：补齐 USB detach / 非法事件 / 边界 payload

输入：

- `U-USB-006`、`U-USB-007`、`U-USB-008`

输出：

- USB disconnect 和非法输入相关单测

伪代码：

```text
ALGORITHM ImplementUsbDetachAndInvalidEventTests
INPUT:
  testCases = [U-USB-006, U-USB-007, U-USB-008]
OUTPUT:
  updatedUsbConsumerTestFile
STEPS:
  1. detachedEvent <- BuildUsbDetachedEvent()
  2. detachedRecord <- consumer.consume(detachedEvent)
  3. ASSERT detachedRecord != null
  4. ASSERT detachedRecord.action == "disconnect"
  5. ASSERT detachedRecord.matchedPolicyKind == "disconnect_event"
  6. invalidEvent <- BuildUsbEvent(eventName = "unsupported.event")
  7. invalidRecord <- consumer.consume(invalidEvent)
  8. ASSERT invalidRecord == null
  9. malformedEvents <- [BuildUsbEventWithoutPayload(), BuildUsbEventWithBrokenPayload()]
 10. FOR EACH event IN malformedEvents DO
       ASSERT NoExceptionThrown(consumer.consume(event))
     END FOR
 11. Save target test file
 12. RETURN updatedUsbConsumerTestFile
```

验收：

- 异常输入场景不崩溃

#### A-3：补齐 USB 类型与 rawPayload 行为

输入：

- `U-USB-009`、`U-USB-010`

输出：

- baseClass 推断与 rawPayload 序列化相关测试

伪代码：

```text
ALGORITHM ImplementUsbTypeInferenceAndPayloadTests
INPUT:
  testCases = [U-USB-009, U-USB-010]
OUTPUT:
  updatedUsbConsumerTestFile
STEPS:
  1. typeMatrix <- [
       { baseClass: 0x08, expectedType: USB_STORAGE },
       { baseClass: 0x0E, expectedType: USB_CAMERA },
       { baseClass: 0x07, expectedType: USB_PRINTER },
       { baseClass: 0xFF, expectedType: USB_OTHER }
     ]
  2. FOR EACH item IN typeMatrix DO
       event <- BuildUsbAttachedEvent(baseClass = item.baseClass)
       record <- consumer.consume(event)
       ASSERT record != null
       ASSERT record.deviceType == item.expectedType
     END FOR
  3. payloadEvent <- BuildUsbAttachedEvent(baseClass = 0x08)
  4. payloadRecord <- consumer.consume(payloadEvent)
  5. ASSERT payloadRecord != null
  6. ASSERT payloadRecord.rawPayload != ""
  7. Save target test file
  8. RETURN updatedUsbConsumerTestFile
```

验收：

- 所有断言通过

#### A-4：补齐 Bluetooth ACL 主流程与异常流程

输入：

- `U-BT-001` 到 `U-BT-008`

输出：

- Bluetooth ACL consumer 全量测试

伪代码：

```text
ALGORITHM ImplementBluetoothAclConsumerTests
INPUT:
  testCases = [U-BT-001 ... U-BT-008]
OUTPUT:
  updatedBluetoothConsumerTestFile
STEPS:
  1. connectedEvent <- BuildBluetoothAclEvent(state = "STATE_CONNECTED")
  2. connectedRecord <- consumer.consume(connectedEvent)
  3. ASSERT connectedRecord != null
  4. ASSERT connectedRecord.action == "connect"
  5. disconnectedEvent <- BuildBluetoothAclEvent(state = "STATE_DISCONNECTED")
  6. disconnectedRecord <- consumer.consume(disconnectedEvent)
  7. ASSERT disconnectedRecord != null
  8. ASSERT disconnectedRecord.action == "disconnect"
  9. unknownEvent <- BuildBluetoothAclEvent(state = "UNKNOWN")
 10. ASSERT consumer.consume(unknownEvent) == null
 11. missingDeviceIdEvent <- BuildBluetoothAclEventWithoutDeviceId()
 12. ASSERT consumer.consume(missingDeviceIdEvent) == null
 13. namedEvent <- BuildBluetoothAclEvent(deviceName = "Keyboard")
 14. namedRecord <- consumer.consume(namedEvent)
 15. ASSERT namedRecord.deviceName == "Keyboard"
 16. fallbackEvent <- BuildBluetoothAclEvent(deviceName = "")
 17. ASSERT NoExceptionThrown(consumer.consume(fallbackEvent))
 18. formattedRecord <- consumer.consume(BuildBluetoothAclEvent(deviceId = "11:22:33:44:55:66"))
 19. ASSERT formattedRecord.deviceId != "11:22:33:44:55:66" OR IsNormalizedBluetoothId(formattedRecord.deviceId)
 20. ASSERT formattedRecord.rawPayload != ""
 21. Save target test file
 22. RETURN updatedBluetoothConsumerTestFile
```

验收：

- 全部 Bluetooth 相关用例通过

### 5.6 执行命令

```powershell
hvigorw test --mode module -p product=default -p module=entry@default
```

### 5.7 回填追踪表

- 将 `U-USB-*`、`U-BT-*` 的状态更新为 `done` 或 `blocked`
- 填写执行命令和结果

## 6. 步骤 2：Session B 实施计划

### 6.1 目标

补齐 pipeline 与 connection record service 的 P0 / P1 测试。

### 6.2 输入

- 用例 ID：
  - `U-PIPE-001` 到 `U-PIPE-009`
  - `U-SVC-001` 到 `U-SVC-005`
- 生产文件：
  - `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_pipeline.ets`
  - `entry/src/main/ets/services/PeripheralConnectionRecordService.ets`

### 6.3 输出

- 更新后的 pipeline 测试
- 更新后的 service 测试

### 6.4 要修改的文件

- 修改：`entry/src/test/peripheral/connection-record-pipeline.test.ets`
- 修改：`entry/src/test/peripheral/connection-record-service.test.ets`

### 6.5 执行子步骤

#### B-1：补齐 pipeline P0 主流程

输入：

- `U-PIPE-001` 到 `U-PIPE-004`

输出：

- USB 去重、蓝牙不去重、`canHandle=false`、`consume=null` 测试

伪代码：

```text
ALGORITHM ImplementPipelineCoreTests
INPUT:
  testCases = [U-PIPE-001, U-PIPE-002, U-PIPE-003, U-PIPE-004]
OUTPUT:
  updatedPipelineTestFile
STEPS:
  1. Mock PeripheralTraceRepository.init => true
  2. appendCounter <- 0
  3. Mock PeripheralTraceRepository.append => appendCounter <- appendCounter + 1; return true
  4. usbConsumer <- FakeConsumer(canHandle = usbOnly, consume = returnsUsbRecord)
  5. btConsumer <- FakeConsumer(canHandle = btOnly, consume = returnsBtRecord)
  6. nullConsumer <- FakeConsumer(canHandle = usbOnly, consume = null)
  7. pipeline <- NewPipeline(consumers = [usbConsumer, btConsumer])
  8. BindContext(pipeline)
  9. PushSameUsbEventTwiceWithinWindow(pipeline)
 10. ASSERT appendCounter == 1
 11. Reset appendCounter
 12. PushSameBluetoothEventTwice(pipeline)
 13. ASSERT appendCounter == 2
 14. Reset appendCounter
 15. pipeline <- NewPipeline(consumers = [btConsumer])
 16. PushUsbEvent(pipeline)
 17. ASSERT appendCounter == 0
 18. pipeline <- NewPipeline(consumers = [nullConsumer])
 19. PushUsbEvent(pipeline)
 20. ASSERT appendCounter == 0
 21. Save target test file
 22. RETURN updatedPipelineTestFile
```

验收：

- append 调用次数和预期一致

#### B-2：补齐 pipeline P1 边界

输入：

- `U-PIPE-005` 到 `U-PIPE-009`

输出：

- 多 consumer、init 失败、append 失败、attach/detach producer 行为测试

伪代码：

```text
ALGORITHM ImplementPipelineBoundaryTests
INPUT:
  testCases = [U-PIPE-005 ... U-PIPE-009]
OUTPUT:
  updatedPipelineTestFile
STEPS:
  1. producerA <- FakeProducer()
  2. producerB <- FakeProducer()
  3. pipeline <- NewPipeline(producerA, [FakeConsumer(...)])
  4. BindContext(pipeline)
  5. Start(pipeline)
  6. AttachProducer(pipeline, producerB)
  7. ASSERT producerA.stopCalled == true
  8. ASSERT producerA.unsubscribeCalled == true
  9. ASSERT producerB.startCalled == true
 10. Mock PeripheralTraceRepository.init => false
 11. result <- PushUsbEvent(pipeline)
 12. ASSERT result == false
 13. Mock PeripheralTraceRepository.init => true
 14. Mock PeripheralTraceRepository.append => false
 15. ASSERT NoExceptionThrown(PushUsbEvent(pipeline))
 16. DetachProducer(pipeline)
 17. ASSERT producerB.stopCalled == true
 18. ASSERT producerB.unsubscribeCalled == true
 19. Save target test file
 20. RETURN updatedPipelineTestFile
```

验收：

- pipeline 状态机相关断言通过

#### B-3：补齐 service P0 / P1

输入：

- `U-SVC-001` 到 `U-SVC-005`

输出：

- runtime_event 过滤、倒序、字段映射、过滤条件透传、异常兜底测试

伪代码：

```text
ALGORITHM ImplementConnectionRecordServiceTests
INPUT:
  testCases = [U-SVC-001 ... U-SVC-005]
OUTPUT:
  updatedServiceTestFile
STEPS:
  1. capturedQuery <- null
  2. Mock PeripheralTraceRepository.query(query):
       capturedQuery <- query
       return MixedSourceTraceRecords()
  3. records <- PeripheralConnectionRecordService.queryRecords(filter = SampleFilter())
  4. ASSERT All(records.source == "runtime_event")
  5. ASSERT IsSortedByTimestampDesc(records)
  6. ASSERT HasMappedFields(records[0], ["matchedPolicyKind", "effectivePolicyLabel", "rawEventName"])
  7. ASSERT capturedQuery.sources == ["runtime_event"]
  8. ASSERT capturedQuery.deviceTypes == SampleFilter().deviceTypes
  9. Mock PeripheralTraceRepository.query => THROW Error
 10. records <- PeripheralConnectionRecordService.queryRecords()
 11. ASSERT records.length == 0
 12. Save target test file
 13. RETURN updatedServiceTestFile
```

验收：

- service 全部用例通过

### 6.6 执行命令

```powershell
hvigorw test --mode module -p product=default -p module=entry@default
```

### 6.7 回填追踪表

- 更新 `U-PIPE-*`、`U-SVC-*` 状态

## 7. 步骤 3：Session C 实施计划

### 7.1 目标

补齐 record viewmodel、clear usecase、page viewmodel 的主流程和状态流转测试。

### 7.2 输入

- 用例 ID：
  - `U-RVM-001` 到 `U-RVM-010`
  - `U-CLEAR-001` 到 `U-CLEAR-004`
  - `U-PVM-001` 到 `U-PVM-011`
- 生产文件：
  - `entry/src/main/ets/viewmodels/PeripheralRecordViewModel.ets`
  - `entry/src/main/ets/viewmodels/peripheral/connection-record/peripheral_connection_record_clear_usecase.ets`
  - `entry/src/main/ets/viewmodels/PeripheralViewModel.ets`

### 7.3 输出

- viewmodel 和 usecase 测试补齐

### 7.4 要修改的文件

- 修改：`entry/src/test/viewmodels/PeripheralRecordViewModel.test.ets`
- 修改：`entry/src/test/viewmodels/PeripheralViewModel.test.ets`

### 7.5 执行子步骤

#### C-1：补齐 RecordViewModel 刷新与详情状态

输入：

- `U-RVM-001` 到 `U-RVM-004`

输出：

- reload、open detail、close detail 相关测试

伪代码：

```text
ALGORITHM ImplementRecordViewModelStateTests
INPUT:
  testCases = [U-RVM-001 ... U-RVM-004]
OUTPUT:
  updatedRecordViewModelTestFile
STEPS:
  1. vm <- New PeripheralRecordViewModel()
  2. Mock PeripheralConnectionRecordService.queryRecords => SampleRecords()
  3. vm.reloadRecords()
  4. ASSERT vm.records == SampleRecords()
  5. Mock PeripheralConnectionRecordService.queryRecords => THROW Error
  6. vm.reloadRecords()
  7. ASSERT vm.records.length == 0
  8. vm.records <- MultiDeviceRecords()
  9. targetRecord <- PickRecordByDevice(vm.records, "target")
 10. vm.openConnectionDetailDialog(targetRecord)
 11. ASSERT vm.connectionDetailDialog.visible == true
 12. ASSERT vm.connectionDetailDialog.record.id == targetRecord.id
 13. ASSERT AllHistoryItemsMatchTargetDevice(vm.connectionDetailDialog.historyItems, targetRecord.deviceId)
 14. vm.closeConnectionDetailDialog()
 15. ASSERT vm.connectionDetailDialog.visible == false
 16. ASSERT vm.connectionDetailDialog.record == null
 17. ASSERT vm.connectionDetailDialog.historyItems.length == 0
 18. Save target test file
 19. RETURN updatedRecordViewModelTestFile
```

验收：

- 所有状态断言通过

#### C-2：补齐 RecordViewModel 导出链路

输入：

- `U-RVM-005` 到 `U-RVM-010`

输出：

- 导出成功/失败/BOM/转义测试

伪代码：

```text
ALGORITHM ImplementRecordViewModelExportTests
INPUT:
  testCases = [U-RVM-005 ... U-RVM-010]
OUTPUT:
  updatedRecordViewModelTestFile
STEPS:
  1. vm <- New PeripheralRecordViewModel()
  2. vm.records <- SampleExportRecords()
  3. capturedCsv <- ""
  4. Mock LogStorageService.init => success
  5. Mock LogStorageService.exportToCsvFile(args):
       capturedCsv <- args.csvContent
       return { success: true, fileName: "x.csv" }
  6. result <- vm.exportConnectionHistory(FakeContext())
  7. ASSERT result.success == true
  8. ASSERT result.fileName == "x.csv"
  9. ASSERT StartsWithBom(capturedCsv) == true
 10. ASSERT CsvHeadersAreCorrect(capturedCsv) == true
 11. ASSERT CsvColumnOrderIsCorrect(capturedCsv) == true
 12. vm.records <- []
 13. ASSERT vm.exportConnectionHistory(FakeContext()).reason == PeripheralStrings.emptyConnectionHistory
 14. vm.records <- SampleExportRecords()
 15. ASSERT vm.exportConnectionHistory(null).reason == PeripheralStrings.exportEnvNotReady
 16. Mock LogStorageService.exportToCsvFile => THROW Error
 17. result <- vm.exportConnectionHistory(FakeContext())
 18. ASSERT result.success == false
 19. ASSERT result.reason == PeripheralStrings.exportConnectionHistoryFailed
 20. specialCsv <- BuildCsvByRecordWithSpecialChars()
 21. ASSERT CsvEscapeIsCorrect(specialCsv) == true
 22. Save target test file
 23. RETURN updatedRecordViewModelTestFile
```

验收：

- 导出相关分支通过

#### C-3：补齐 ClearUsecase

输入：

- `U-CLEAR-001` 到 `U-CLEAR-004`

输出：

- clear usecase 全量测试

伪代码：

```text
ALGORITHM ImplementClearUsecaseTests
INPUT:
  testCases = [U-CLEAR-001 ... U-CLEAR-004]
OUTPUT:
  updatedPageViewModelTestFile
STEPS:
  1. usecase <- New PeripheralConnectionRecordClearUsecase()
  2. ASSERT usecase.execute(null) == false
  3. Mock PeripheralTraceRepository.init => false
  4. ASSERT usecase.execute(FakeContext()) == false
  5. Mock PeripheralTraceRepository.init => true
  6. Mock PeripheralTraceRepository.clearAll => true
  7. ASSERT usecase.execute(FakeContext()) == true
  8. Mock PeripheralTraceRepository.clearAll => THROW Error
  9. ASSERT usecase.execute(FakeContext()) == false
 10. Save target test file
 11. RETURN updatedPageViewModelTestFile
```

验收：

- usecase 全部用例通过

#### C-4：补齐 PageViewModel 主流程和监听器行为

输入：

- `U-PVM-001` 到 `U-PVM-011`

输出：

- initialize、reload、clear、detail dialog、tab 切换、listener 回调测试

伪代码：

```text
ALGORITHM ImplementPageViewModelTests
INPUT:
  testCases = [U-PVM-001 ... U-PVM-011]
OUTPUT:
  updatedPageViewModelTestFile
STEPS:
  1. vm <- New PeripheralViewModel()
  2. traceListener <- null
  3. policyListener <- null
  4. Mock PeripheralTraceRepository.addChangeListener(cb):
       traceListener <- cb
       return 101
  5. Mock PeripheralDevicePolicyRepository.addChangeListener(cb):
       policyListener <- cb
       return 102
  6. Stub vm.records.reloadRecords, vm.policy.reloadRecords, vm.policy.initialize
  7. vm.initialize(FakeContext())
  8. ASSERT vm.reasonCode == null
  9. ASSERT traceListener != null
 10. ASSERT policyListener != null
 11. Invoke traceListener()
 12. ASSERT vm.records.reloadRecords called
 13. ASSERT vm.policy.reloadRecords called
 14. Reset spies
 15. Invoke policyListener()
 16. ASSERT vm.policy.reloadRecords called
 17. ASSERT vm.records.reloadRecords not called
 18. vm.records.records <- SampleRuntimeRecords()
 19. vm.openConnectionDetailDialog(vm.records.records[0])
 20. Mock PeripheralTraceRepository.init => true
 21. Mock PeripheralTraceRepository.clearAll => true
 22. result <- vm.clearConnectionHistory()
 23. ASSERT result == true
 24. ASSERT vm.records.connectionDetailDialog.visible == false
 25. Mock PeripheralTraceRepository.init => true
 26. Mock PeripheralTraceRepository.clearAll => false
 27. vm.records.records <- SampleRuntimeRecords()
 28. vm.openConnectionDetailDialog(vm.records.records[0])
 29. result <- vm.clearConnectionHistory()
 30. ASSERT result == false
 31. ASSERT vm.records.connectionDetailDialog.visible == true
 32. originalTab <- vm.currentTab
 33. vm.switchToTab(-1)
 34. ASSERT vm.currentTab == originalTab
 35. vm.switchToTab(originalTab)
 36. ASSERT vm.currentTab == originalTab
 37. Save target test file
 38. RETURN updatedPageViewModelTestFile
```

实施说明：

- 不允许通过 test-only setter 替换 `connectionRecordClearUsecase`。
- `clearConnectionHistory()` 的成功/失败分支必须通过其真实依赖链来控制：
  - `PeripheralTraceRepository.init`
  - `PeripheralTraceRepository.clearAll`
- `ClearUsecase` 的单元测试与 `PeripheralViewModel` 的行为测试必须分开写，避免重新引入测试注入入口。

验收：

- page viewmodel 主链路全部通过

### 7.6 执行命令

```powershell
hvigorw test --mode module -p product=default -p module=entry@default
```

### 7.7 回填追踪表

- 更新 `U-RVM-*`、`U-CLEAR-*`、`U-PVM-*`

## 8. 步骤 4：Session D 实施计划

### 8.1 目标

补齐展示映射与 repository 真实行为测试。

### 8.2 输入

- 用例 ID：
  - `U-MAP-001` 到 `U-MAP-009`
  - `U-REPO-001` 到 `U-REPO-016`
- 生产文件：
  - `entry/src/main/ets/viewmodels/PeripheralRecordPresentationMapper.ets`
  - `entry/src/main/ets/services/PeripheralTraceRepository.ets`

### 8.3 输出

- mapper 测试
- repository 测试

### 8.4 要修改的文件

- 修改：`entry/src/test/utils/PeripheralRecordDisplayUtils.test.ets`
- 修改：`entry/src/test/utils/PeripheralRecordViewDataUtils.test.ets`
- 如现有文件不适合承载 repository 行为：
  - 新增：`entry/src/test/peripheral/trace-repository.test.ets`

### 8.5 执行子步骤

#### D-1：补齐 mapper 语义映射

输入：

- `U-MAP-001` 到 `U-MAP-009`

输出：

- 文案、结果、时间、history 聚合测试

伪代码：

```text
ALGORITHM ImplementMapperTests
INPUT:
  testCases = [U-MAP-001 ... U-MAP-009]
OUTPUT:
  updatedMapperTestFiles
STEPS:
  1. FOR EACH kind IN AllMatchedPolicyKinds() DO
       label <- getPeripheralMatchedPolicyKindLabel(kind)
       ASSERT label != ""
     END FOR
  2. snapshotLabel <- getPeripheralConnectionPolicyLabel(PolicySnapshotRecord())
  3. ASSERT snapshotLabel == PeripheralStrings.policyPending
  4. matchedLabel <- getPeripheralConnectionPolicyLabel(RecordWithMatchedPolicyKind())
  5. ASSERT matchedLabel == ExpectedMatchedPolicyLabel()
  6. fallbackLabel <- getPeripheralConnectionPolicyLabel(RecordWithoutMatchedPolicyKind())
  7. ASSERT fallbackLabel == ExpectedPolicyHitLabel()
  8. FOR EACH result IN [SUCCESS, BLOCKED, FAILED, UNKNOWN] DO
       ASSERT getPeripheralConnectionResultLabel(RecordWithResult(result)) == ExpectedResultLabel(result)
     END FOR
  9. ASSERT formatPeripheralTimestamp(0) == "--"
 10. history <- buildConnectionHistoryItems(MultiDeviceRecordsWithInvalidTimestamp(), SelectedRecord())
 11. ASSERT OnlyTargetDeviceIncluded(history) == true
 12. ASSERT InvalidTimestampExcluded(history) == true
 13. ASSERT DeviceIdNormalizedMatch(history) == true
 14. Save target test file
 15. RETURN updatedMapperTestFiles
```

验收：

- 所有 mapper 用例通过

#### D-2：补齐 repository 基础行为

输入：

- `U-REPO-001`、`U-REPO-003`、`U-REPO-013`

输出：

- append / appendBatch / clearAll 基础测试

伪代码：

```text
ALGORITHM ImplementRepositoryCoreTests
INPUT:
  testCases = [U-REPO-001, U-REPO-003, U-REPO-013]
OUTPUT:
  updatedRepositoryTestFile
PRECONDITION:
  repository test environment can be reset safely
STEPS:
  1. ResetRepositoryTestState()
  2. InitRepository(FakeContext())
  3. record1 <- BuildTraceRecord(timestamp = 100)
  4. ASSERT PeripheralTraceRepository.append(record1) == true
  5. ASSERT QueryAllContains(record1) == true
  6. record2 <- BuildTraceRecord(timestamp = 200)
  7. record3 <- BuildTraceRecord(timestamp = 300)
  8. ASSERT PeripheralTraceRepository.appendBatch([record2, record3]) == true
  9. allRecords <- PeripheralTraceRepository.query()
 10. ASSERT IsNewestFirst(allRecords) == true
 11. ASSERT PeripheralTraceRepository.clearAll() == true
 12. ASSERT PeripheralTraceRepository.query().length == 0
 13. Save target test file
 14. RETURN updatedRepositoryTestFile
```

验收：

- 基础仓库行为稳定

#### D-3：补齐 repository query / stats / listener / cleanup

输入：

- `U-REPO-002`、`U-REPO-004` 到 `U-REPO-016`

输出：

- 过滤、分页、统计、listener、retention/maxEntries 测试

伪代码：

```text
ALGORITHM ImplementRepositoryAdvancedTests
INPUT:
  testCases = [U-REPO-002, U-REPO-004 ... U-REPO-016]
OUTPUT:
  updatedRepositoryTestFile
STEPS:
  1. ResetRepositoryTestState()
  2. InitRepository(FakeContext())
  3. SeedRepository(MixedTraceRecords())
  4. ASSERT QueryByDeviceIdWorks()
  5. ASSERT QueryByDeviceTypesWorks()
  6. ASSERT QueryByActionsWorks()
  7. ASSERT QueryByResultsWorks()
  8. ASSERT QueryBySourcesWorks()
  9. ASSERT QueryByKeywordWorks()
 10. ASSERT QueryByPaginationWorks()
 11. stats <- PeripheralTraceRepository.getStats()
 12. ASSERT StatsAreCorrect(stats)
 13. notifyCount <- 0
 14. listenerId <- PeripheralTraceRepository.addChangeListener(() => notifyCount <- notifyCount + 1)
 15. PeripheralTraceRepository.append(BuildTraceRecord(timestamp = 999))
 16. ASSERT notifyCount > 0
 17. PeripheralTraceRepository.removeChangeListener(listenerId)
 18. previousNotifyCount <- notifyCount
 19. PeripheralTraceRepository.append(BuildTraceRecord(timestamp = 1000))
 20. ASSERT notifyCount == previousNotifyCount
 21. ConfigureRetentionAndMaxEntries()
 22. removed <- PeripheralTraceRepository.forceCleanup(retentionDays, maxEntries)
 23. ASSERT removed >= 0
 24. ASSERT ExpiredAndOverflowRecordsRemoved() == true
 25. Save target test file
 26. RETURN updatedRepositoryTestFile
```

验收：

- repository 全部用例通过

### 8.6 执行命令

```powershell
hvigorw test --mode module -p product=default -p module=entry@default
```

### 8.7 回填追踪表

- 更新 `U-MAP-*`、`U-REPO-*`

## 9. 步骤 5：Session E 实施计划

### 9.1 目标

完成页面最小契约测试，验证 UI 最后一跳接线。

### 9.2 输入

- 用例 ID：
  - `U-VIEW-001` 到 `U-VIEW-005`
- 生产文件：
  - `entry/src/main/ets/views/PeripheralPage.ets`
  - `entry/src/main/ets/components/peripheral/DeviceRecordList.ets`
  - `entry/src/main/ets/components/peripheral/ConnectionDetailDialog.ets`

### 9.3 输出

- 页面边界逻辑测试
- 设备侧 UI 最小契约测试

### 9.4 要修改的文件

- 修改：`entry/src/test/views/PeripheralPage.test.ets`
- 修改或新增：`entry/src/ohosTest/ets/test/peripheral/snapshot.test.ets`
- 如需要更清晰拆分，可新增：
  - `entry/src/ohosTest/ets/test/peripheral/connection-record-contract.test.ets`

### 9.5 执行子步骤

#### E-1：补齐页面边界单测

输入：

- 当前仍存在的页面公开边界或可观察边界

输出：

- 重写 `entry/src/test/views/PeripheralPage.test.ets`

伪代码：

```text
ALGORITHM RewritePeripheralPageBoundaryTests
INPUT:
  targetTestFile = "entry/src/test/views/PeripheralPage.test.ets"
OUTPUT:
  updatedPeripheralPageBoundaryTestFile
STEPS:
  1. Open targetTestFile
  2. Remove all references to:
       executePeripheralPageClearHistory
       PeripheralPageClearHistoryAction
       createClearConnectionHistoryActionForTest
  3. boundaryOptions <- DiscoverCurrentPublicOrObservableBoundaries(PeripheralPage)
  4. IF boundaryOptions contains stable local-test boundary THEN
       Implement minimal assertions against that boundary
     ELSE
       Replace file content with compatibility note tests OR retire file from active plan
     END IF
  5. Save target test file
  6. RETURN updatedPeripheralPageBoundaryTestFile
```

验收：

- `PeripheralPage.test.ets` 不再引用已删除入口
- 不因历史包装器缺失而编译失败

实施说明：

- 当前 `PeripheralPage` 已移除旧的 test wrapper，因此 E-1 的首要目标不是“增量补测试”，而是“先让旧边界测试与当前代码一致”。
- 如果当前页面不存在稳定的本地单测边界，则允许将页面最小契约重心完全转移到 `ohosTest`，同时把 `entry/src/test/views/PeripheralPage.test.ets` 降级为兼容性占位或移出本轮核心路径。

#### E-2：补齐设备侧 UI 契约

输入：

- `U-VIEW-001` 到 `U-VIEW-005`

输出：

- ohosTest UI 契约测试

伪代码：

```text
ALGORITHM ImplementPeripheralUiContractTests
INPUT:
  testCases = [U-VIEW-001 ... U-VIEW-005]
OUTPUT:
  updatedOhosTestFiles
PRECONDITION:
  app installed
  test module installed
STEPS:
  1. delegator <- GetAbilityDelegator()
  2. StartAbility(bundle = "com.huawei.securitytool", ability = "EntryAbility")
  3. Wait(2000ms)
  4. driver <- Driver.create()
  5. navPeripheral <- driver.findComponent(ON.text("外设管理"))
  6. ASSERT navPeripheral != null
  7. Click(navPeripheral)
  8. ASSERT driver.assertComponentExist(ON.text("外设管理")) succeeds
  9. tabRecord <- driver.findComponent(ON.text("设备连接记录"))
 10. ASSERT tabRecord != null
 11. Click(tabRecord)
 12. ASSERT driver.assertComponentExist(ON.text("导出记录")) succeeds
 13. ASSERT driver.assertComponentExist(ON.text("清理记录")) succeeds
 14. IF EmptyStateScenarioPrepared() THEN
       ASSERT driver.assertComponentExist(ON.text(ExpectedEmptyStateText())) succeeds
     ELSE
       MarkCaseBlocked("U-VIEW-002")
     END IF
 15. IF DetailScenarioPrepared() THEN
       detailButton <- driver.findComponent(ON.text("详情"))
       Click(detailButton)
       ASSERT driver.assertComponentExist(ON.text(ExpectedDetailTitleText())) succeeds
     ELSE
       MarkCaseBlocked("U-VIEW-004")
       MarkCaseBlocked("U-VIEW-005")
     END IF
 16. Save target test file
 17. RETURN updatedOhosTestFiles
```

验收：

- 至少稳定通过以下最小集合：
  - 进入外设管理页
  - 切到设备连接记录 tab
  - 显示导出/清理按钮

说明：

- `空态` 和 `详情` 如果自动化环境数据不稳定，可先标记为 `blocked`，保留在追踪表中，待真机前置数据补齐后再执行。
- `U-VIEW-001`、`U-VIEW-003` 应优先进入自动化最小集合。
- `U-VIEW-002`、`U-VIEW-004`、`U-VIEW-005` 允许依赖前置数据准备，若当前环境不具备则不强推为首轮必须完成项。

### 9.6 执行命令

本地单测：

```powershell
hvigorw :entry:test
```

设备侧 UI 测试：

```powershell
hdc shell aa test -b com.huawei.securitytool -m entry_test -s unittest OpenHarmonyTestRunner -w 180
```

### 9.7 回填追踪表

- 更新 `U-VIEW-*`
- 标记自动化可稳定执行的项和依赖前置数据的项

## 10. 步骤 6：统一验收与收口

### 10.1 目标

对照设计文档做最终闭环，确认各 Session 输出可追溯。

### 10.2 输入

- `device-connection-record-mock-test-design.md`
- `device-connection-record-mock-test-tracker.md`
- 各测试文件
- 执行结果

### 10.3 输出

- 一份完整的实施结果
- 所有已完成与未完成用例的最终状态

### 10.4 要修改的文件

- 修改：`docs/refac/peripheral-management/device-connection-record-mock-test-tracker.md`
- 可选新增：`docs/refac/peripheral-management/device-connection-record-mock-test-execution-report.md`

### 10.5 伪代码

```text
ALGORITHM FinalizeExecutionAndAuditCoverage
INPUT:
  trackerPath
  designDocPath
  executionArtifacts
OUTPUT:
  executionReport
STEPS:
  1. trackerRows <- ReadTracker(trackerPath)
  2. designCases <- ParseAllCaseIds(designDocPath)
  3. ASSERT EveryDesignCaseExistsInTracker(designCases, trackerRows) == true
  4. p0Rows <- FilterByPriority(trackerRows, "P0")
  5. p1Rows <- FilterByPriority(trackerRows, "P1")
  6. p2Rows <- FilterByPriority(trackerRows, "P2")
  7. ASSERT AllRowsDone(p0Rows) == true
  8. blockedRows <- FilterByStatus(trackerRows, "blocked")
  9. remainingRows <- FilterByStatus(trackerRows, ["todo", "in_progress"])
 10. executionReport <- BuildExecutionReport(
       trackerRows,
       blockedRows,
       remainingRows,
       executionArtifacts
     )
 11. WriteFile("docs/refac/peripheral-management/device-connection-record-mock-test-execution-report.md", executionReport)
 12. RETURN executionReport
```

### 10.6 验收口径

- P0 必须全部完成
- P1 原则上完成，剩余项必须有阻塞说明
- P2 至少完成最小集合
- 整个实施过程不修改生产代码
- 所有测试方案均不得依赖已删除的 test-only 生产入口

## 11. 每次提交的固定模板

每个 session 每次提交后，都应按以下模板记录：

```text
Session: A/B/C/D/E
Step: A-1 / B-2 / ...
Input IDs: U-XXX-001, U-XXX-002
Commit: test(peripheral-record): A-1 cover U-XXX-001..002
Output Files:
- path/to/test1
- path/to/test2
Command:
- hvigorw test --mode module -p product=default -p module=entry@default
Result:
- pass / fail
Completed IDs:
- U-XXX-001
- U-XXX-002
Remaining IDs:
- U-XXX-003
Notes:
- blocker or none
```

若当前子步骤尚未形成提交，则 `Commit` 固定写为 `pending`，并在 `Notes` 中注明原因。

## 12. 推荐执行顺序

### 第一轮并行

- Session A：`A-1`、`A-2`
- Session B：`B-1`
- Session C：`C-1`、`C-3`
- Session D：`D-1`
- Session E：`E-1`

目标：

- 尽快打通最核心的 P0 主链路

### 第二轮并行

- Session A：`A-3`、`A-4`
- Session B：`B-2`、`B-3`
- Session C：`C-2`、`C-4`
- Session D：`D-2`
- Session E：`E-2`

目标：

- 完成 P1 和页面最小契约

### 第三轮收口

- Session D：`D-3`
- 主协调 session：步骤 6 统一验收与报告

目标：

- 完成 repository 深水区和统一收口
