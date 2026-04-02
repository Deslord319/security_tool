# 外设管理-设备连接记录：删除 PeripheralRuntimeEventService 落地计划

> 状态：Draft  
> 日期：2026-04-02  
> 适用范围：仅用于“外设管理-设备连接记录”链路从 `PeripheralRuntimeEventService` 彻底退出  
> 唯一判定依据：`docs/refac/peripheral-management/device-connection-record.md`

## 0. 任务背景

当前“设备连接记录”链路的核心职责已经迁入 SSOT 规定的文件：

- producer：`entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_runtime_producer_adapter.ets`
- USB consumer：`entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_usb_consumer.ets`
- Bluetooth ACL consumer：`entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_bluetooth_acl_consumer.ets`
- pipeline：`entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_pipeline.ets`
- repository：`entry/src/main/ets/services/PeripheralTraceRepository.ets`

但当前生产代码中，`PeripheralRuntimeEventService.ets` 仍承担：

1. 链路装配
2. 生命周期代理
3. 运行状态查询

同时，启动监听的入口仍有两处：

- `entry/src/main/ets/pages/MainPage.ets`
- `entry/src/main/ets/views/PeripheralPage.ets`

这与本轮收口目标不一致。当前要解决的问题不是继续拆更多文件，而是：

- 让 `MainPage` 成为唯一启动点
- 让 `PeripheralPage` 退出运行时初始化/启动职责
- 让调用方直接依赖 SSOT 链路文件
- 删除 `PeripheralRuntimeEventService.ets`

## 1. SSOT 约束

依据 `device-connection-record.md`：

1. Step 2 已定义 producer contract 与 runtime producer adapter
2. Step 3 已定义 USB / Bluetooth ACL consumer
3. Step 4 明确链路必须是：
   - `producer -> consumers -> pipeline -> PeripheralTraceRepository`

因此，本轮替代原则是：

- 订阅与事件生产职责 -> producer
- 事件消费与记录映射职责 -> consumers
- 链路编排与写库职责 -> pipeline
- 页面只负责应用启动与业务展示，不再通过 `PeripheralRuntimeEventService` 间接驱动链路

## 2. 目标

1. `EntryAbility -> MainPage` 仍为应用入口
2. `MainPage` 成为连接记录监听唯一启动点
3. `PeripheralPage` 不再负责连接记录运行时初始化/启动
4. 生产代码不再引用 `PeripheralRuntimeEventService`
5. 删除 `PeripheralRuntimeEventService.ets`

## 3. 文件范围

只允许改以下现有文件，不新增文件：

- `entry/src/main/ets/pages/MainPage.ets`
- `entry/src/main/ets/views/PeripheralPage.ets`
- `entry/src/main/ets/services/peripheral/connection-record/index.ets`
- `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_runtime_producer_adapter.ets`
- `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_pipeline.ets`
- `entry/src/main/ets/services/PeripheralRuntimeEventService.ets`

最终需要删除：

- `entry/src/main/ets/services/PeripheralRuntimeEventService.ets`

## 4. 职责替代关系

## 4.1 `PeripheralRuntimeEventService.init(context)`

替代为：

- `pipeline.bindContext(context)`
- `pipeline.attachProducer(producer)`

落点：

- `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_pipeline.ets`
- `entry/src/main/ets/pages/MainPage.ets`

## 4.2 `PeripheralRuntimeEventService.start()/stop()`

替代为：

- `pipeline.start()`
- `pipeline.stop()`

落点：

- `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_pipeline.ets`
- `entry/src/main/ets/pages/MainPage.ets`

## 4.3 `PeripheralRuntimeEventService.getStatus()/probeCapabilities()`

替代为：

- `producer.getStatus()`

落点：

- `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_runtime_producer_adapter.ets`
- `entry/src/main/ets/pages/MainPage.ets`
- `entry/src/main/ets/views/PeripheralPage.ets`

## 4.4 `PeripheralRuntimeEventService.getRuntimeProducer()/getRuntimePipeline()`

替代为：

- 页面直接持有 producer / pipeline 引用

落点：

- `entry/src/main/ets/pages/MainPage.ets`

说明：

- 本轮不新增组合器文件
- 因此装配代码直接回收至唯一启动点 `MainPage`

## 5. 小步计划

## Step 1：MainPage 接管唯一启动职责

### 目标

让 `MainPage` 直接装配并启动连接记录链路。

### 修改文件

- `entry/src/main/ets/pages/MainPage.ets`
- `entry/src/main/ets/services/peripheral/connection-record/index.ets`
- `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_runtime_producer_adapter.ets`
- `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_pipeline.ets`

### 改动要点

- 删除 `PeripheralRuntimeEventService` import
- 直接构造 producer / pipeline
- 在 `MainPage` 内按固定顺序执行：
  1. `pipeline.bindContext(context)`
  2. `pipeline.attachProducer(producer)`
  3. `pipeline.start()`

### 完成标志

- `MainPage` 不再调用 `PeripheralRuntimeEventService.init/start/getStatus`
- `MainPage` 成为唯一启动点

### SSOT 证据

- 应用入口在 `EntryAbility -> pages/MainPage`
- Step 4：运行链路应由 producer / consumers / pipeline 组成，而不是由 RuntimeService 代理

## Step 2：PeripheralPage 删除重复启动逻辑

### 目标

让 `PeripheralPage` 只做展示和交互，不再负责连接记录运行时启动。

### 修改文件

- `entry/src/main/ets/views/PeripheralPage.ets`
- `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_runtime_producer_adapter.ets`

### 改动要点

- 删除 `PeripheralRuntimeEventService` import
- 删除页面中的：
  - `init(context)`
  - `start()`
- 页面如需显示运行状态，直接读 producer 状态

### 完成标志

- `PeripheralPage` 不再触发监听注册/启动

### SSOT 证据

- 监听属于 producer 职责，不应由业务页面二次启动

## Step 3：状态查询归还给 producer

### 目标

让页面侧直接依赖 producer 状态，而不是再通过 RuntimeService 查询。

### 修改文件

- `entry/src/main/ets/pages/MainPage.ets`
- `entry/src/main/ets/views/PeripheralPage.ets`
- `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_runtime_producer_adapter.ets`

### 改动要点

- 调用方统一使用 `producer.getStatus()`
- 取消 `PeripheralRuntimeEventService.getStatus()/probeCapabilities()` 的依赖

### 完成标志

- 页面层无 `PeripheralRuntimeEventService` 状态依赖

### SSOT 证据

- runtime capability 属于 producer source 状态，不属于独立 RuntimeService

## Step 4：收紧 pipeline 为唯一运行时入口

### 目标

让页面层只操作 pipeline 生命周期，不再自己拼接链路细节。

### 修改文件

- `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_pipeline.ets`
- `entry/src/main/ets/pages/MainPage.ets`

### 改动要点

- 确认并固化 pipeline 对外能力：
  - `bindContext`
  - `attachProducer`
  - `start`
  - `stop`
- `MainPage` 只通过 pipeline 管理链路生命周期

### 完成标志

- 页面层对连接记录运行时只有 pipeline 启停入口

### SSOT 证据

- Step 4：pipeline 是 producer -> consumers -> repo 的中枢

## Step 5：删除 PeripheralRuntimeEventService

### 前置条件

- `MainPage` 无引用
- `PeripheralPage` 无引用
- 其他生产代码无引用

### 修改文件

- 删除 `entry/src/main/ets/services/PeripheralRuntimeEventService.ets`

### 验收命令

```powershell
rg --line-number "PeripheralRuntimeEventService" entry/src/main
```

### 完成标志

- `entry/src/main` 无生产代码命中 `PeripheralRuntimeEventService`

## Step 6：汇报替代结果

### 目标

在 Step 1-5 完成后，形成一份结果汇报，明确：

1. `PeripheralRuntimeEventService` 删除前承载了哪些职责
2. 这些职责分别迁到了哪个 SSOT 文件
3. 新链路为接住这些职责，新增或沉淀了哪些函数

### 汇报内容

#### A. 职责替代清单

- 启动 / 停止 -> `MainPage` + `pipeline`
- 状态查询 -> `producer`
- 装配 -> `MainPage`
- 订阅与标准事件生产 -> `runtime_producer_adapter`

#### B. 新链路函数清单

按文件列出：

- `runtime_producer_adapter.ets`
- `pipeline.ets`
- 如页面侧新增了装配辅助函数，也要列出

## 6. 并行执行结论

最大并行 session 数：`1`

原因：

- `MainPage` 是唯一启动点，方案必须先统一
- `PeripheralPage` 的删除动作依赖 `MainPage` 先完成接管
- 删除 `PeripheralRuntimeEventService` 依赖前述步骤全部完成

执行批次：

1. Batch 1：Step 1
2. Batch 2：Step 2 + Step 3 + Step 4（同一 session 顺序完成）
3. Batch 3：Step 5
4. Batch 4：Step 6

## 7. 每步固定验收要求

每一步必须提交以下证据：

1. SSOT 证据
   - 引用 `device-connection-record.md` 对应要求
2. 变更证据
   - `git diff -- <白名单文件>`
   - `git diff --name-only HEAD~1 HEAD`
3. 入口点证据
   - `rg --line-number "loadContent\\('pages/MainPage'\\)|PeripheralRuntimeEventService|pipeline\\.start\\(|attachProducer\\(|bindContext\\(" entry/src/main/ets`
4. 构建证据
   - `hvigorw assembleHap --mode module -p product=default -p module=entry`
5. Git 证据
   - `git show --name-only --stat --oneline HEAD`
   - `git status --short`

Step 6 额外要求：

6. 结果汇报
   - `PeripheralRuntimeEventService` 职责替代表
   - 新链路函数清单
   - 页面级启动点归属说明

## 8. 完成判定

满足以下条件才算本轮完成：

1. `EntryAbility` 仍加载 `pages/MainPage`
2. `MainPage` 是唯一监听启动点
3. `PeripheralPage` 不再启动监听
4. 生产代码不再引用 `PeripheralRuntimeEventService`
5. `PeripheralRuntimeEventService.ets` 已删除
6. 构建通过
7. 已输出职责替代与新增函数汇报
