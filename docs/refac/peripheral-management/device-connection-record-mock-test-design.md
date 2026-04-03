# 外设管理-设备连接记录 Mock 测试设计与用例总表

> 状态：Draft  
> 最后更新：2026-04-03  
> 适用范围：`外设管理 > 设备连接记录`

## 1. 文档目标

本文档用于沉淀“设备连接记录”业务逻辑的 Mock 测试设计原则、分层测试范围和完整测试用例矩阵，目标是在**不入侵生产代码**前提下，完成对当前业务链路的高覆盖验证。

覆盖对象包括：

- USB 连接记录消费逻辑
- 蓝牙 ACL 连接记录消费逻辑
- 连接记录 pipeline 编排逻辑
- 连接记录 repository / service / viewmodel 状态逻辑
- 连接记录展示映射逻辑
- 页面最小契约验证

## 2. 设计原则

### 2.1 零入侵生产代码

- 不修改生产代码结构以配合测试。
- 不增加 `if (isTest)`、`MockMode`、隐藏调试入口等测试分支。
- 不修改生产代码构造链路、页面逻辑或业务语义以便注入 fake。
- Mock 仅存在于测试代码中，通过替换外部依赖返回值、伪造输入数据、拦截静态方法调用完成。

### 2.2 严格沿用现有 MVVM 边界

测试按现有分层开展，不人为重组生产层次：

- View：`PeripheralPage.ets`、`DeviceRecordList.ets`、`ConnectionDetailDialog.ets`
- ViewModel：`PeripheralViewModel.ets`、`PeripheralRecordViewModel.ets`
- Service：`PeripheralConnectionRecordService.ets`
- Repository：`PeripheralTraceRepository.ets`
- Connection Record Runtime Chain：
  - `peripheral_connection_record_runtime_producer_adapter.ets`
  - `peripheral_connection_record_usb_consumer.ets`
  - `peripheral_connection_record_bluetooth_acl_consumer.ets`
  - `peripheral_connection_record_pipeline.ets`

### 2.3 只测本项目业务，不测系统框架

- 不验证 HarmonyOS 公共事件系统本身是否正常。
- 不验证 Preferences 框架本身是否可靠。
- 不验证 Dialog/UI 框架本身是否可用。
- 只验证“收到某种输入时，本项目代码是否产出正确业务结果”。

### 2.4 优先测试公开边界与可观察结果

- 优先测试公开类、公开方法、公开状态。
- 优先测试 ViewModel 状态变化、Repository 查询结果、Service 映射结果。
- 页面层只验证最小契约，不做重型 UI 行为测试。
- 某私有实现不易直接测试时，改为测试其上层或下层的可观察结果，不反向推动生产代码改造。

### 2.5 Mock 使用边界

- 测 consumer / pipeline / viewmodel / service 时，允许 Mock 外部依赖。
- 测 repository 自身时，不 Mock repository 主体行为，直接测真实公开行为。
- 测页面最小契约时，只 Mock 页面依赖的状态来源，不扩展页面专用测试逻辑。

### 2.6 当前代码基线说明

本设计文档基于 `2026-04-03` 当前仓库代码状态，以下实现约束已成立：

- `entry/src/main/ets/services/PeripheralRuntimeEventService.ets` 已退出生产链路，不再作为当前测试设计依赖。
- `entry/src/main/ets/views/PeripheralPage.ets` 已移除以下旧测试包装入口：
  - `executePeripheralPageClearHistory(...)`
  - `PeripheralPageClearHistoryAction`
  - `createClearConnectionHistoryActionForTest(...)`
- `entry/src/main/ets/viewmodels/PeripheralViewModel.ets` 已移除 `setConnectionRecordClearUsecaseForTest(...)`。

因此：

- 页面最小契约组不能再依赖旧页面测试包装器。
- `PeripheralViewModel.clearConnectionHistory()` 的验证不能再通过 test-only setter 注入 `ClearUsecase`。
- 所有相关测试必须通过当前仍存在的公开边界和可观察结果完成。

## 3. 分层测试策略

### 3.1 业务规则组

目标：打满“设备连接记录”核心业务分支。

覆盖文件：

- `peripheral_connection_record_usb_consumer.ets`
- `peripheral_connection_record_bluetooth_acl_consumer.ets`
- `peripheral_connection_record_pipeline.ets`
- `PeripheralConnectionRecordService.ets`

### 3.2 状态管理组

目标：验证 ViewModel 与 Usecase 的状态流转、导出、清理、刷新行为。

覆盖文件：

- `PeripheralRecordViewModel.ets`
- `PeripheralViewModel.ets`
- `peripheral_connection_record_clear_usecase.ets`

补充约束：

- `ClearUsecase` 的单元测试与 `PeripheralViewModel` 的行为测试必须分开。
- `PeripheralViewModel.clearConnectionHistory()` 只能通过其真实依赖链的公开静态方法控制成功/失败分支，例如：
  - `PeripheralTraceRepository.init`
  - `PeripheralTraceRepository.clearAll`

### 3.3 展示语义组

目标：验证记录展示文案、时间格式、历史记录聚合规则。

覆盖文件：

- `PeripheralRecordPresentationMapper.ets`
- `PeripheralStrings.ets`
- `DataModels.ets`

### 3.4 Repository 真实行为组

目标：验证记录持久化仓库的追加、查询、清理、统计、监听行为。

覆盖文件：

- `PeripheralTraceRepository.ets`

### 3.5 页面最小契约组

目标：验证 View 与 ViewModel/组件的接线正确，不做重型 UI 自动化。

覆盖文件：

- `PeripheralPage.ets`
- `DeviceRecordList.ets`
- `ConnectionDetailDialog.ets`

补充约束：

- 页面最小契约以 `ohosTest` 设备侧 UI 验证为主。
- `entry/src/test/views/PeripheralPage.test.ets` 如需保留，只能围绕当前仍存在的公开边界重写，不能继续引用已删除的测试包装器。
- 首轮自动化最小集合优先覆盖：
  - 能进入“外设管理”页
  - 能切到“设备连接记录”页签
  - 能看到“导出记录”“清理记录”

## 4. Mock 约束

### 4.1 允许的测试手段

- 伪造 `PeripheralConnectionRecordProducerEvent`
- 临时替换静态方法返回值
- 构造 fake context / fake producer / fake consumer
- 拦截 repository append/query/clearAll/init 行为
- 拦截导出服务返回值

### 4.2 禁止的测试手段

- 修改生产代码 public/private 结构以适配测试
- 在生产代码内加入测试专用分支
- 改动页面业务逻辑只为方便断言
- 通过真实系统事件、真实插拔设备、真实蓝牙连接完成单元测试
- 依赖当前代码中已删除的 test-only 入口或包装器

## 5. 完整测试用例表

字段说明：

- `Mock 项`：测试中需要替换的外部依赖；无则写“无”
- `输入/前置`：触发条件、构造数据或前置状态
- `核心断言`：测试必须明确验证的结果
- `优先级`：`P0` 核心业务、`P1` 重要补全、`P2` 最小契约

### 5.1 USB Consumer

| 用例 ID | 层级 | 目标文件 | 用例名称 | Mock 项 | 输入/前置 | 核心断言 | 优先级 |
|---|---|---|---|---|---|---|---|
| U-USB-001 | 业务规则 | `peripheral_connection_record_usb_consumer.ets` | USB attach 命中 USB 总开关禁用 | `PeripheralService.getInterfaceDisabledWithResult` | USB attached 事件；USB disabled=true | `policyHit=deny`；`result=BLOCKED`；`matchedPolicyKind=usb_disabled` | P0 |
| U-USB-002 | 业务规则 | `peripheral_connection_record_usb_consumer.ets` | USB 存储 attach 命中存储禁用 | `PeripheralService.getUsbStoragePolicyWithResult` | USB storage attach；storage policy=DISABLED | `matchedPolicyKind=usb_storage_disabled`；结果为阻止 | P0 |
| U-USB-003 | 业务规则 | `peripheral_connection_record_usb_consumer.ets` | USB 存储 attach 命中只读 | `PeripheralService.getUsbStoragePolicyWithResult` | USB storage attach；storage policy=READ_ONLY | `matchedPolicyKind=usb_storage_read_only`；`effectivePolicyLabel=只读` | P0 |
| U-USB-004 | 业务规则 | `peripheral_connection_record_usb_consumer.ets` | USB attach 命中单设备 deny | `PeripheralDevicePolicyRepository.getAll` | attach 设备命中 deny 策略 | `matchedPolicyKind=device_deny`；结果为阻止 | P0 |
| U-USB-005 | 业务规则 | `peripheral_connection_record_usb_consumer.ets` | USB attach 默认允许 | `PeripheralService.*`、`PeripheralDevicePolicyRepository.getAll` | 总开关开启；无 deny；正常策略 | `matchedPolicyKind=default_allow`；结果成功 | P0 |
| U-USB-006 | 业务规则 | `peripheral_connection_record_usb_consumer.ets` | USB detach 事件映射 | 视情况替换策略读取 | USB detached 事件 | `action=disconnect`；`matchedPolicyKind=disconnect_event`；不走阻断文案 | P0 |
| U-USB-007 | 业务规则 | `peripheral_connection_record_usb_consumer.ets` | 非支持 USB 事件忽略 | 无 | 非 attach/detach 事件名 | `consume()` 返回 `null` | P0 |
| U-USB-008 | 业务规则 | `peripheral_connection_record_usb_consumer.ets` | 原始事件缺少 payload 时稳定返回 | 无 | `rawData` 缺失或为空结构 | 不抛异常；返回 `null` 或稳定默认结果 | P1 |
| U-USB-009 | 业务规则 | `peripheral_connection_record_usb_consumer.ets` | USB 设备类型按 baseClass 推断 | 无 | baseClass 分别为 storage/camera/printer/other | `deviceType` 正确 | P1 |
| U-USB-010 | 业务规则 | `peripheral_connection_record_usb_consumer.ets` | 原始 payload 可序列化进 `rawPayload` | 无 | 正常 USB 事件 | `rawPayload` 非空 | P1 |

### 5.2 Bluetooth ACL Consumer

| 用例 ID | 层级 | 目标文件 | 用例名称 | Mock 项 | 输入/前置 | 核心断言 | 优先级 |
|---|---|---|---|---|---|---|---|
| U-BT-001 | 业务规则 | `peripheral_connection_record_bluetooth_acl_consumer.ets` | 蓝牙 ACL connect 事件映射 | 无 | `STATE_CONNECTED` 事件 | `action=connect`；`matchedPolicyKind=bluetooth_connection_event` | P0 |
| U-BT-002 | 业务规则 | `peripheral_connection_record_bluetooth_acl_consumer.ets` | 蓝牙 ACL disconnect 事件映射 | 无 | `STATE_DISCONNECTED` 事件 | `action=disconnect`；结果成功 | P0 |
| U-BT-003 | 业务规则 | `peripheral_connection_record_bluetooth_acl_consumer.ets` | 蓝牙 ACL unknown state 忽略 | 无 | 未知状态值/标签 | `consume()` 返回 `null` | P0 |
| U-BT-004 | 业务规则 | `peripheral_connection_record_bluetooth_acl_consumer.ets` | 蓝牙 ACL 缺少 deviceId 忽略 | 无 | 缺失 `deviceId/deviceAddr/address` | 返回 `null` | P0 |
| U-BT-005 | 业务规则 | `peripheral_connection_record_bluetooth_acl_consumer.ets` | 蓝牙设备名优先使用 payload 名称 | 无 | payload 同时包含 deviceId 和 deviceName | `deviceName` 使用 payload 值 | P1 |
| U-BT-006 | 业务规则 | `peripheral_connection_record_bluetooth_acl_consumer.ets` | 蓝牙设备名 fallback 稳定 | `connection.getRemoteDeviceName` 所在链路可控时替换 | payload 无名称 | 使用 fallback 名称；不抛异常 | P1 |
| U-BT-007 | 业务规则 | `peripheral_connection_record_bluetooth_acl_consumer.ets` | 蓝牙地址格式化 | 无 | 原始地址无统一格式 | `deviceId` 被标准化 | P1 |
| U-BT-008 | 业务规则 | `peripheral_connection_record_bluetooth_acl_consumer.ets` | 原始 payload 可序列化进 `rawPayload` | 无 | 正常 ACL 事件 | `rawPayload` 非空 | P1 |

### 5.3 Pipeline

| 用例 ID | 层级 | 目标文件 | 用例名称 | Mock 项 | 输入/前置 | 核心断言 | 优先级 |
|---|---|---|---|---|---|---|---|
| U-PIPE-001 | 业务规则 | `peripheral_connection_record_pipeline.ets` | USB 1500ms 去重 | `PeripheralTraceRepository.init/append` | 连续两次同 key USB 事件；时间差 <1500ms | 仅 append 一次 | P0 |
| U-PIPE-002 | 业务规则 | `peripheral_connection_record_pipeline.ets` | 蓝牙 ACL 不参与去重 | `PeripheralTraceRepository.init/append` | 连续两次 ACL 事件 | append 两次 | P0 |
| U-PIPE-003 | 业务规则 | `peripheral_connection_record_pipeline.ets` | `canHandle=false` 的 consumer 不处理事件 | `PeripheralTraceRepository.init/append` | pipeline 挂多个 consumer | 不匹配 consumer 不被调用 | P0 |
| U-PIPE-004 | 业务规则 | `peripheral_connection_record_pipeline.ets` | consumer 返回 `null` 时不写库 | `PeripheralTraceRepository.init/append` | `consume()` 返回 `null` | 不 append | P0 |
| U-PIPE-005 | 业务规则 | `peripheral_connection_record_pipeline.ets` | 多 consumer 时只由匹配 consumer 产出记录 | `PeripheralTraceRepository.init/append` | 同时挂 USB/BT consumer | 仅匹配链路 append | P1 |
| U-PIPE-006 | 业务规则 | `peripheral_connection_record_pipeline.ets` | repository init 失败时跳过写库 | `PeripheralTraceRepository.init` | `init=false` | `push()` 返回 `false`；不 append | P1 |
| U-PIPE-007 | 业务规则 | `peripheral_connection_record_pipeline.ets` | repository append 失败时保持稳定 | `PeripheralTraceRepository.append` | `append=false` | 不抛异常；`push()` 仍完成 | P1 |
| U-PIPE-008 | 业务规则 | `peripheral_connection_record_pipeline.ets` | `attachProducer` 后重新启动 producer | fake producer | 已 start 再切换 producer | 新 producer 被绑定并启动 | P1 |
| U-PIPE-009 | 业务规则 | `peripheral_connection_record_pipeline.ets` | `detachProducer` 释放订阅 | fake producer | 已订阅后 detach | 调用 `unsubscribe/stop` | P1 |

### 5.4 Connection Record Service

| 用例 ID | 层级 | 目标文件 | 用例名称 | Mock 项 | 输入/前置 | 核心断言 | 优先级 |
|---|---|---|---|---|---|---|---|
| U-SVC-001 | 业务规则 | `PeripheralConnectionRecordService.ets` | 仅查询 `runtime_event` | `PeripheralTraceRepository.query` | query 返回 runtime/audit/snapshot 混合 | 最终仅保留 runtime | P0 |
| U-SVC-002 | 业务规则 | `PeripheralConnectionRecordService.ets` | 查询结果按时间倒序 | `PeripheralTraceRepository.query` | occurAt 乱序 | 返回按时间降序 | P0 |
| U-SVC-003 | 业务规则 | `PeripheralConnectionRecordService.ets` | 记录字段完整映射 | `PeripheralTraceRepository.query` | trace record 包含扩展字段 | `matchedPolicyKind/effectivePolicyLabel/rawEventName` 等字段不丢失 | P0 |
| U-SVC-004 | 业务规则 | `PeripheralConnectionRecordService.ets` | 过滤条件透传到 query | `PeripheralTraceRepository.query` | 传入 `deviceTypes/results/keyword/startTime/endTime` | query 参数包含这些值且固定 `sources=['runtime_event']` | P1 |
| U-SVC-005 | 业务规则 | `PeripheralConnectionRecordService.ets` | repository 抛错时返回空列表 | `PeripheralTraceRepository.query` | `query()` 抛异常 | 返回 `[]` | P1 |

### 5.5 Record ViewModel

| 用例 ID | 层级 | 目标文件 | 用例名称 | Mock 项 | 输入/前置 | 核心断言 | 优先级 |
|---|---|---|---|---|---|---|---|
| U-RVM-001 | 状态管理 | `PeripheralRecordViewModel.ets` | reloadRecords 成功刷新列表 | `PeripheralConnectionRecordService.queryRecords` | 返回多条记录 | `records` 更新 | P0 |
| U-RVM-002 | 状态管理 | `PeripheralRecordViewModel.ets` | reloadRecords 异常兜底 | `PeripheralConnectionRecordService.queryRecords` | 抛异常 | `records=[]` | P0 |
| U-RVM-003 | 状态管理 | `PeripheralRecordViewModel.ets` | 打开详情弹窗加载当前记录和历史记录 | 无或替换 records 数据 | 预置同设备/异设备记录 | `visible=true`；history 仅含同设备记录 | P0 |
| U-RVM-004 | 状态管理 | `PeripheralRecordViewModel.ets` | 关闭详情弹窗清空状态 | 无 | 先打开再关闭 | `visible=false`；record/history 清空 | P0 |
| U-RVM-005 | 状态管理 | `PeripheralRecordViewModel.ets` | 导出成功返回文件名 | `LogStorageService.init/exportToCsvFile` | 有 records 且 context 就绪 | 返回 success=true 且 fileName 存在 | P0 |
| U-RVM-006 | 状态管理 | `PeripheralRecordViewModel.ets` | 导出空记录失败 | 无 | `records=[]` | 返回 `emptyConnectionHistory` | P0 |
| U-RVM-007 | 状态管理 | `PeripheralRecordViewModel.ets` | 导出时 context 缺失失败 | 无 | `context=null` | 返回 `exportEnvNotReady` | P0 |
| U-RVM-008 | 状态管理 | `PeripheralRecordViewModel.ets` | 导出底层失败兜底 | `LogStorageService.*` | `exportToCsvFile` 失败或抛错 | 返回导出失败 reason | P0 |
| U-RVM-009 | 状态管理 | `PeripheralRecordViewModel.ets` | CSV 表头与字段顺序正确 | `LogStorageService.exportToCsvFile` 拦截参数 | 预置一条记录 | CSV 含 BOM、表头、时间/名称/类型/设备标识/动作/策略/结果/来源 | P1 |
| U-RVM-010 | 状态管理 | `PeripheralRecordViewModel.ets` | CSV 对逗号/引号/换行做转义 | 同上 | 设备名含特殊字符 | CSV 转义正确 | P1 |

### 5.6 Clear Usecase

| 用例 ID | 层级 | 目标文件 | 用例名称 | Mock 项 | 输入/前置 | 核心断言 | 优先级 |
|---|---|---|---|---|---|---|---|
| U-CLEAR-001 | 状态管理 | `peripheral_connection_record_clear_usecase.ets` | context 为空直接失败 | 无 | `context=null` | 返回 `false` | P1 |
| U-CLEAR-002 | 状态管理 | `peripheral_connection_record_clear_usecase.ets` | repository init 失败时返回 false | `PeripheralTraceRepository.init` | `init=false` | 返回 `false` | P1 |
| U-CLEAR-003 | 状态管理 | `peripheral_connection_record_clear_usecase.ets` | clearAll 成功 | `PeripheralTraceRepository.init/clearAll` | `init=true`；`clearAll=true` | 返回 `true` | P1 |
| U-CLEAR-004 | 状态管理 | `peripheral_connection_record_clear_usecase.ets` | clearAll 抛异常兜底 | `PeripheralTraceRepository.clearAll` | `clearAll()` 抛错 | 返回 `false` | P1 |

### 5.7 Page ViewModel

| 用例 ID | 层级 | 目标文件 | 用例名称 | Mock 项 | 输入/前置 | 核心断言 | 优先级 |
|---|---|---|---|---|---|---|---|
| U-PVM-001 | 状态管理 | `PeripheralViewModel.ets` | initialize 成功加载记录和策略并注册监听 | `PeripheralTraceRepository.addChangeListener`、`PeripheralDevicePolicyRepository.addChangeListener`、子 VM 方法 | context 就绪 | 完成初始化；listener id 被记录；`reasonCode=null` | P0 |
| U-PVM-002 | 状态管理 | `PeripheralViewModel.ets` | initialize 异常设置失败原因 | 相关依赖抛错 | 初始化过程中抛异常 | `reasonCode=initFailed` | P0 |
| U-PVM-003 | 状态管理 | `PeripheralViewModel.ets` | reloadDeviceRecords 同步刷新记录和策略 | `records.reloadRecords`、`policy.reloadRecords` | 调用 `reloadDeviceRecords()` | 两者均被调用；触发刷新 | P0 |
| U-PVM-004 | 状态管理 | `PeripheralViewModel.ets` | openConnectionDetailDialog 驱动刷新 | `records.openConnectionDetailDialog` | 打开一条记录 | 详情状态刷新；触发 `onRefresh` | P1 |
| U-PVM-005 | 状态管理 | `PeripheralViewModel.ets` | closeConnectionDetailDialog 驱动刷新 | `records.closeConnectionDetailDialog` | 关闭详情 | 状态关闭；触发 `onRefresh` | P1 |
| U-PVM-006 | 状态管理 | `PeripheralViewModel.ets` | clearConnectionHistory 成功后关闭详情并重载记录 | `PeripheralTraceRepository.init/clearAll` | `init=true`；`clearAll=true` | 关闭详情；调用 `reloadDeviceRecords` | P0 |
| U-PVM-007 | 状态管理 | `PeripheralViewModel.ets` | clearConnectionHistory 失败不误清状态 | `PeripheralTraceRepository.init/clearAll` | `init=false` 或 `clearAll=false` | 返回 `false`；不错误清空 | P0 |
| U-PVM-008 | 状态管理 | `PeripheralViewModel.ets` | switchToTab 非法值不切换 | 无 | `index<0` 或 `index>2` | `currentTab` 不变 | P1 |
| U-PVM-009 | 状态管理 | `PeripheralViewModel.ets` | switchToTab 相同值不切换 | 无 | `index===currentTab` | `currentTab` 不变 | P1 |
| U-PVM-010 | 状态管理 | `PeripheralViewModel.ets` | trace listener 触发后刷新记录和策略 | 保存注册回调并手工触发 | 初始化完成后触发回调 | `records.reloadRecords`、`policy.reloadRecords` 被调用 | P1 |
| U-PVM-011 | 状态管理 | `PeripheralViewModel.ets` | device policy listener 触发后只刷新策略 | 保存注册回调并手工触发 | 初始化完成后触发策略回调 | 仅 `policy.reloadRecords` 被调用 | P1 |

### 5.8 Presentation Mapper

| 用例 ID | 层级 | 目标文件 | 用例名称 | Mock 项 | 输入/前置 | 核心断言 | 优先级 |
|---|---|---|---|---|---|---|---|
| U-MAP-001 | 展示语义 | `PeripheralRecordPresentationMapper.ets` | 所有 `matchedPolicyKind` 枚举映射正确 | 无 | 逐个传入枚举值 | 返回对应中文文案 | P1 |
| U-MAP-002 | 展示语义 | `PeripheralRecordPresentationMapper.ets` | `policy_snapshot` 记录返回待定策略文案 | 无 | `source=policy_snapshot` | 返回 `policyPending` | P1 |
| U-MAP-003 | 展示语义 | `PeripheralRecordPresentationMapper.ets` | 优先使用 `matchedPolicyKind` 文案 | 无 | 同时具备 `policyHit` 和 `matchedPolicyKind` | 使用 `matchedPolicyKind` 对应文案 | P1 |
| U-MAP-004 | 展示语义 | `PeripheralRecordPresentationMapper.ets` | 未知策略回退到 `policyHit` | 无 | `matchedPolicyKind` 缺失 | 按 allow/deny/unknown 显示 | P1 |
| U-MAP-005 | 展示语义 | `PeripheralRecordPresentationMapper.ets` | 结果状态 SUCCESS/BLOCKED/FAILED/UNKNOWN 映射正确 | 无 | 分别传入不同 result | 文案正确 | P1 |
| U-MAP-006 | 展示语义 | `PeripheralRecordPresentationMapper.ets` | `formatPeripheralTimestamp` 对非法时间返回 `--` | 无 | `timestamp<=0` | 返回 `--` | P1 |
| U-MAP-007 | 展示语义 | `PeripheralRecordPresentationMapper.ets` | `buildConnectionHistoryItems` 只聚合同设备记录 | 无 | records 含多设备 | 仅输出同设备记录 | P1 |
| U-MAP-008 | 展示语义 | `PeripheralRecordPresentationMapper.ets` | `buildConnectionHistoryItems` 忽略非法时间记录 | 无 | 含 `timestamp<=0` 记录 | 结果中不包含非法记录 | P1 |
| U-MAP-009 | 展示语义 | `PeripheralRecordPresentationMapper.ets` | `buildConnectionHistoryItems` 对 deviceId 大小写和空白归一化匹配 | 无 | 同设备不同格式 id | 能被识别为同一设备 | P1 |

### 5.9 Repository

| 用例 ID | 层级 | 目标文件 | 用例名称 | Mock 项 | 输入/前置 | 核心断言 | 优先级 |
|---|---|---|---|---|---|---|---|
| U-REPO-001 | Repository | `PeripheralTraceRepository.ets` | append 单条写入成功 | 最少化 context 或使用现有测试钩子 | 一条 trace record | query 能读到该记录 | P0 |
| U-REPO-002 | Repository | `PeripheralTraceRepository.ets` | appendBatch 空数组安全返回 | 无 | `[]` | 返回成功；无新增 | P1 |
| U-REPO-003 | Repository | `PeripheralTraceRepository.ets` | appendBatch 多条写入后 newest first | 无 | 多条记录按时间写入 | 内存顺序正确 | P0 |
| U-REPO-004 | Repository | `PeripheralTraceRepository.ets` | query 不带条件返回全部 | 无 | 预置多条记录 | 返回全部 | P1 |
| U-REPO-005 | Repository | `PeripheralTraceRepository.ets` | query 按 `deviceId` 过滤 | 无 | 多设备记录 | 仅返回目标设备 | P1 |
| U-REPO-006 | Repository | `PeripheralTraceRepository.ets` | query 按 `deviceTypes` 过滤 | 无 | 多类型记录 | 仅返回目标类型 | P1 |
| U-REPO-007 | Repository | `PeripheralTraceRepository.ets` | query 按 `actions` 过滤 | 无 | connect/disconnect/intercept 混合 | 结果正确 | P1 |
| U-REPO-008 | Repository | `PeripheralTraceRepository.ets` | query 按 `results` 过滤 | 无 | success/blocked/failed 混合 | 结果正确 | P1 |
| U-REPO-009 | Repository | `PeripheralTraceRepository.ets` | query 按 `sources` 过滤 | 无 | runtime/audit/snapshot 混合 | 结果正确 | P1 |
| U-REPO-010 | Repository | `PeripheralTraceRepository.ets` | query 按 `keyword` 模糊匹配 | 无 | 关键字命中名称/设备 ID/summary/detail/processName | 结果正确 | P1 |
| U-REPO-011 | Repository | `PeripheralTraceRepository.ets` | query 分页 `pageOffset/pageSize` 正确 | 无 | 多条记录 | 返回分页结果 | P1 |
| U-REPO-012 | Repository | `PeripheralTraceRepository.ets` | getStats 统计正确 | 无 | 混合动作/结果/source | total/connects/disconnects/allows/denies 等正确 | P1 |
| U-REPO-013 | Repository | `PeripheralTraceRepository.ets` | clearAll 清空成功 | 无 | 预置记录后 clear | query 为空 | P0 |
| U-REPO-014 | Repository | `PeripheralTraceRepository.ets` | add/remove listener 生效 | 无 | 注册 listener 后 append / remove | 注册时收到通知；移除后不再通知 | P1 |
| U-REPO-015 | Repository | `PeripheralTraceRepository.ets` | configure/forceCleanup 按 retentionDays 生效 | 控制当前时间 | 过期记录 + 有效记录 | 过期记录被清理 | P1 |
| U-REPO-016 | Repository | `PeripheralTraceRepository.ets` | configure/forceCleanup 按 maxEntries 生效 | 无 | 超出上限记录 | 仅保留上限数量 | P1 |

### 5.10 页面最小契约

| 用例 ID | 层级 | 目标文件 | 用例名称 | Mock 项 | 输入/前置 | 核心断言 | 优先级 |
|---|---|---|---|---|---|---|---|
| U-VIEW-001 | 页面契约 | `PeripheralPage.ets` | 当前为设备连接记录页签时显示导出/清理按钮 | 页面状态或 VM 状态 | `currentTabIndex=1` | 出现“导出记录”“清理记录” | P2 |
| U-VIEW-002 | 页面契约 | `DeviceRecordList.ets` | 空记录时显示空态 | 无 | `deviceRecords=[]` | 渲染空状态文案 | P2 |
| U-VIEW-003 | 页面契约 | `DeviceRecordList.ets` | 非空记录时渲染详情入口 | 无 | `deviceRecords` 含一条记录 | 出现“详情”入口 | P2 |
| U-VIEW-004 | 页面契约 | `PeripheralPage.ets` | 点击记录详情后页面进入详情流转 | 用 fake callback 或页面状态观察 | 点击一条记录详情 | `detailRecord/historyItems` 被同步 | P2 |
| U-VIEW-005 | 页面契约 | `ConnectionDetailDialog.ets` | 详情弹窗展示关键字段和历史记录数量 | 无 | 传入 `selectedRecord/historyItems` | 关键信息和数量显示正确 | P2 |

页面最小契约组实施说明：

- `U-VIEW-001`、`U-VIEW-003` 优先进入首轮自动化。
- `U-VIEW-002`、`U-VIEW-004`、`U-VIEW-005` 如依赖前置数据或环境稳定性，可在追踪表中标记为 `blocked`，待真机前置条件满足后执行。
- 页面最小契约测试不得依赖已删除的 `PeripheralPage` 本地测试包装器。

## 6. 优先级与实施顺序

### 6.1 P0

先补核心业务链路：

- USB consumer
- Bluetooth ACL consumer
- pipeline
- connection record service
- record viewmodel
- page viewmodel 中与清理/刷新/详情相关逻辑
- repository 的 append / clearAll / 基础 query

### 6.2 P1

补齐重要语义和异常分支：

- mapper
- clear usecase
- repository 高级过滤、统计、监听、cleanup
- pipeline/consumer 的鲁棒性边界

### 6.3 P2

最后补最小页面契约：

- tab 动作按钮
- 空态
- 详情入口
- 详情弹窗入参展示

## 7. 不纳入本轮单元 Mock 覆盖的内容

- 真 USB 设备插拔
- 真蓝牙设备连接/断开
- HarmonyOS 公共事件系统可靠性
- Preferences 框架本身可靠性
- 重型页面像素级 UI 回归

上述内容如需验证，应进入：

- 手工测试
- CTest 冒烟
- 端到端测试
- 真机联调

## 8. 交付建议

建议最终交付由以下几部分构成：

1. `entry/src/test/peripheral/` 下补齐 consumer / pipeline / service / repository 相关测试
2. `entry/src/test/viewmodels/` 下补齐 record/page viewmodel 相关测试
3. 视现有 UI 测试能力决定是否补充最小页面契约测试

完成标准建议为：

- P0 用例全部落地
- P1 用例覆盖率达到主要异常分支
- 页面最小契约至少覆盖空态、详情入口、记录页签动作按钮
- 所有测试均不要求改动生产代码
