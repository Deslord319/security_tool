# 日志大包导入按文件拆分 Task 实施方案

> 日期：2026-07-29
> 状态：已实施；当前 254 MB 复现包验收通过，数 GB 现网包待补充容量验收
> 所属模块：日志管理（`log-manage`）
> 类型：日志导入稳定性修复
> 总体风险：中等；按准备、单文件解析、批量持久化三个边界分步实施时可控

## 0. 实施与验证结果

截至 2026-07-29，本方案中的最小修复已经完成：

- 后台链路已拆为准备 LongTask 和逐文件解析 Task，不再跨 TaskPool 返回全包日志数组。
- 单文件解析结果按 1000 条过滤、查重和写入；累计写入达到 10000 条时执行无通知维护，结束时统一维护并通知。
- 保持现有页面入口、加载弹框、动画、结果提示和临时工作区清理行为；未新增进度、取消、断点或任务表。
- 单元测试、文档一致性检查、主 HAP 构建、签名和真机安装均已通过。
- 266,370,339 字节复现包真机导入成功：扫描 7464 个文件，识别 82 个候选文件，解析 48667 条，写入 48130 条，跳过重复 17 条，过滤过期 520 条，失败文件 0 个。
- 导入耗时约 103 秒，未出现 TaskPool 16 MB 序列化异常；最终数据库按既有容量策略保留 20000 条。

尚未使用数 GB 现网包完成容量验收。该项只补充验证，不改变本次架构和代码范围。

## 1. 背景与问题

当前离线日志导入由一个 `TaskPool` 任务完成整个压缩包的解压、文件扫描、规则解析和批内去重。后台任务将所有文件产生的 `LogEntry` 合并为一个数组，再把完整数组返回主线程。

实机导入日志已经确认失败原因：

```text
The serialization data size has exceed limit Size,
current size is: 22678943
max size is: 16777216

taskpool: failed to serialize result.
```

已验证的日志包特征：

- 外层日志包约 254 MB。
- 包内包含多个轮转的 `hilog_kmsg*.gz`。
- 单个内核日志解压后约 4.25 MB。
- 单个文件通常产生约 900～1300 条有效日志。
- 单个文件的解析结果未超过 TaskPool 16 MB 限制。
- 全部文件解析结果合并后约 22.68 MB，超过 TaskPool 单次序列化上限。
- 现网日志包总大小可能达到数 GB，但仍以多个轮转日志文件组成，不是一个无边界增长的单文件。

因此，本次问题的直接原因不是 ZIP 无效、GZIP 解压失败或 RDB 容量不足，而是后台任务把整个日志包的解析结果作为一次 TaskPool 返回值传输。

## 2. 目标与非目标

### 2.1 目标

1. 删除“整个压缩包解析结果一次返回”的路径，避免触发 TaskPool 16 MB 序列化限制。
2. 继续在后台线程执行 ZIP、嵌套 ZIP、GZIP、日志读取和规则解析，保证加载动画不被解析工作阻塞。
3. 以单个候选日志文件为 TaskPool 解析边界，解析完成后立即持久化并释放该文件结果。
4. 每 1000 条执行一次过期过滤、批内去重、库内重复查询和事务写入，避免逐条数据库查询及超大事务。
5. 导入期间不触发逐批页面刷新；全部完成后统一执行存储维护和一次页面通知。
6. 在数 GB、多轮转文件日志包场景下，使内存占用与单文件解析结果相关，而不是与整个压缩包结果总量相关。
7. 保持现有日志解析规则、用户入口、加载动效、结果反馈和临时工作区清理行为。

### 2.2 非目标

本次明确不实现：

1. 导入阶段进度、文件进度或字节进度展示。
2. 取消导入。
3. 断点续传或应用重启后恢复。
4. 导入任务表、任务历史或后台任务中心。
5. 使用 `Task.sendData()` 传输日志记录。
6. 使用 NDJSON 或其它临时结果文件承载解析结果。
7. 修改内核日志、崩溃日志、系统日志的识别和字段解析规则。
8. 修改 ZIP、嵌套 ZIP、GZIP 的格式支持范围。
9. 修改当前窗口级加载弹框、遮罩范围和首帧准备延时。
10. 支持“单个日志文件自身解析结果超过 16 MB”的未知输入；该场景需后续另行采用规则流式 Sink 或临时结果文件。

## 3. 当前架构

### 3.1 当前调用链

```text
LogManagePage
  -> LogManageViewModel.importSelectedLogs()
    -> LogImportService.importSelected()
      -> taskpool.execute(runLogImportParseTask)
        -> LogArchiveExtractor.extract()
        -> 遍历全部文件
        -> KernelLogImportRule / CrashLogImportRule / SystemLogImportRule
        -> parsedEntries.concat(ruleResult.entries)
        -> 全包 Set 去重
        -> 返回 entries: LogEntry[]
      -> LogImportService.importParsedEntries()
        -> 逐条 LogEntryRepository.hasEntry()
        -> 累计 newEntries: LogEntry[]
        -> LogStorageMaintenanceService.appendEntries(newEntries)
        -> 单次大事务写入、维护、通知
```

### 3.2 当前资源边界

| 环节 | 当前边界 | 问题 |
|---|---|---|
| 文件读取 | 每次 64 KB | 已是流式读取，无需修改 |
| 调度让步 | 每 200 行让步一次 | 已存在，无需修改 |
| 单规则结果 | 当前文件的 `LogEntry[]` | 可接受，保留 |
| 后台总结果 | 整个压缩包的 `LogEntry[]` | 超过 TaskPool 16 MB |
| 主线程待写结果 | 整个压缩包的 `newEntries[]` | 内存随全包结果增长 |
| 库内重复查询 | 每条一次 `hasEntry()` | 大量 SQL 往返 |
| RDB 写入 | 全量单事务 | 事务过大、失败范围过大 |
| 页面通知 | `appendEntries()` 完成后通知 | 后续分批写入时不能逐批通知 |

## 4. 目标架构

### 4.1 目标调用链

```text
LogManagePage
  -> LogManageViewModel.importSelectedLogs()
    -> LogImportService.importSelected()
      -> LongTask: runLogImportPrepareTask()
        -> LogArchiveExtractor.extract()
        -> 扫描全部文件
        -> 使用现有规则 canHandle() 过滤候选文件
        -> 返回候选文件元数据和解压统计
      -> 顺序遍历候选文件
        -> TaskPool: runLogImportFileParseTask(file)
          -> 选择现有解析规则
          -> 只解析当前文件
          -> 返回当前文件 LogImportRuleResult
        -> LogImportService.persistFileEntries()
          -> 每 1000 条过滤过期
          -> 每 1000 条批内去重
          -> 每 1000 条批量查询库内重复
          -> 每 1000 条事务写入
          -> 释放当前文件结果
      -> 定期执行无通知容量维护
      -> 最终执行一次完整维护和页面通知
      -> finally 清理导入工作目录
```

### 4.2 分层职责

| 层级 | 目标职责 |
|---|---|
| Page | 保持当前加载弹框、防重复触发和结果反馈，不参与解析或持久化 |
| ViewModel | 保持导入命令转发和成功后的页面刷新，不持有文件任务细节 |
| LogImportService | 编排准备任务、逐文件解析任务、1000 条批处理、统计和失败收敛 |
| LogImportBackgroundTask | 提供准备任务和单文件解析任务，不再累计全包结果 |
| Import Rules | 继续完成单文件识别和解析，接口保持不变 |
| LogEntryRepository | 批量查询已有 ID，提供导入专用不覆盖写入 |
| LogStorageMaintenanceService | 提供无通知批量追加、导入中容量维护和最终统一维护 |
| RdbStoreProvider / RdbRepository | 继续作为底层 RDB 能力封装，不向 Page 或 ViewModel 泄漏 SQL |

### 4.3 依赖方向

```text
Page
  -> ViewModel
    -> LogImportService
      -> Background Task
        -> ArchiveExtractor / Import Rules
      -> LogStorageMaintenanceService
        -> LogEntryRepository
          -> RdbRepository / RdbStoreProvider
```

禁止以下反向依赖：

- 后台任务不得依赖 Page、ViewModel 或 Dialog。
- Import Rules 不得直接写 RDB。
- Page、ViewModel、Service 不得直接拼接 SQL。
- Repository 不得调用加载弹框或页面刷新。

## 5. 核心设计决策

### 5.1 为什么按文件拆 Task

按文件拆 Task 与当前现网日志结构一致：

- 当前失败由多个小文件结果累计引起。
- 单文件结果与 16 MB 上限之间仍有足够余量。
- 现有解析规则本身就是单文件输入、单文件结果。
- 不需要修改规则接口，也不需要新增临时结果格式。
- 文件解析完成后可以立即入库和释放，内存不再随整个日志包增长。

### 5.2 为什么不使用临时结果文件

临时结果文件可以完全绕开 TaskPool 返回值限制，但会增加：

- 额外磁盘写入和读取。
- 临时文件格式及兼容约束。
- 临时文件损坏和清理分支。
- 结果 Writer、Reader 和测试端口。
- 原始解压文件之外的额外磁盘占用。

当前实机已经证明单文件结果小于 16 MB，因此本次不引入临时结果文件。

### 5.3 为什么不使用 Task.sendData

`Task.sendData()` 仍受单次序列化约束，并且需要处理：

- 主线程接收回调和异步入库之间的排队。
- 生产速度大于消费速度时的内存积压。
- 任务完成与最后一批消息消费完成之间的时序。
- 错误、清理和统计收敛。

该方案复杂度高于按文件顺序调度，不符合本次最小改动目标。

### 5.4 为什么固定 1000 条一批

当前单个内核日志通常产生约 900～1300 条记录，固定 1000 条具有以下特点：

- 常见文件只产生 1～2 个数据库批次。
- 比 500 条减少约一半查询和事务往返。
- 单批内存通常仍在数 MB 范围内。
- 不会形成 5000 或 10000 条级别的长事务。
- 便于单测直接验证 `1000 + 1000 + 余数` 的边界。

统一常量：

```ts
const IMPORT_PERSIST_BATCH_SIZE = 1000
```

### 5.5 为什么准备任务使用 LongTask

准备阶段包含整个外层 ZIP 和嵌套 ZIP 解压，数 GB 日志包可能长时间运行。准备任务使用 `taskpool.LongTask`：

- 不设置连续任务执行时间上限。
- 仍在后台线程执行。
- 只返回候选文件元数据和统计，不返回日志记录。
- 在 `finally` 中调用 `taskpool.terminateTask()` 回收任务。

单个轮转日志文件较小，单文件解析继续使用普通 `taskpool.execute()`，避免为每个文件保留连续任务线程。

### 5.6 统计口径

保持现有结果字段及语义：

| 字段 | 目标口径 |
|---|---|
| `extractedFileCount` | 解压工作区内枚举到的全部文件数 |
| `scannedFileCount` | 完成路径扫描的文件数 |
| `parsedEntryCount` | 各单文件规则产生的记录数量之和 |
| `insertedEntryCount` | 通过过期及重复过滤并成功提交写入的记录数 |
| `skippedDuplicateCount` | 当前批次重复、前序批次重复和库内已有记录之和 |
| `skippedExpiredCount` | 时间早于当前自然日留存截止点的记录数 |
| `droppedEntryCount` | 各规则无法形成有效记录的行或块数量之和 |
| `failedEntryCount` | 各规则失败计数及单文件解析任务异常计数之和 |

定期容量裁剪可能删除刚导入但时间较旧的记录。`insertedEntryCount` 继续沿用当前语义，表示成功提交入库的数量，不表示最终数据库净增长量。

### 5.7 失败与部分写入语义

| 失败位置 | 行为 |
|---|---|
| 用户取消 Picker | 返回 `user_canceled`，不创建准备任务 |
| 非 ZIP 外层文件 | 返回 `invalid_archive`，不解析、不入库 |
| ZIP 或嵌套 ZIP 解压失败 | 返回 `extract_failed`，不进入文件解析 |
| 单文件规则解析失败 | 计入失败数量，继续下一个文件，保持当前行为 |
| 单文件 TaskPool 调度或返回失败 | 计入失败数量，继续下一个文件 |
| 任意导入批次写入失败 | 停止后续文件处理，返回 `save_failed` |
| 导入中容量维护失败 | 停止导入，返回 `save_failed` |
| 最终维护失败 | 返回 `save_failed`，不伪装成功 |
| 工作目录清理失败 | 记录错误，不覆盖主要导入结果 |

分批写入后，入库失败之前已经成功的批次会保留。再次导入时通过确定性 ID、批量库内查重和 `INSERT OR IGNORE` 跳过已存在记录，不覆盖旧数据。

## 6. 目标接口

### 6.1 准备任务结果

```ts
export interface LogImportPrepareTaskResult {
  success: boolean
  code: 'ok' | 'invalid_archive' | 'extract_failed'
  extractedFileCount: number
  scannedFileCount: number
  files: ImportedLogFile[]
}
```

`files` 只包含至少一个现有导入规则可以处理的候选文件。

### 6.2 准备任务

```ts
@Concurrent
export async function runLogImportPrepareTask(
  archivePath: string,
  targetDirectory: string
): Promise<LogImportPrepareTaskResult>
```

### 6.3 单文件解析任务

```ts
@Concurrent
export async function runLogImportFileParseTask(
  file: ImportedLogFile
): Promise<LogImportRuleResult>
```

任务内部按既有顺序选择规则：

```text
KernelLogImportRule
CrashLogImportRule
SystemLogImportRule
```

候选文件应只命中一个规则。若没有规则命中，返回空结果，不抛出异常。

### 6.4 批量库内查重

```ts
async findExistingEntryIds(
  entryIds: string[]
): Promise<Set<string>>
```

SQL 语义：

```sql
SELECT record_id
FROM log_entries
WHERE record_id IN (?, ?, ...)
```

调用方每次最多传入 1000 个 ID。

### 6.5 导入专用写入

```ts
async insertImportEntries(entries: LogEntry[]): Promise<boolean>
```

写入语义：

```sql
INSERT OR IGNORE INTO log_entries (...)
VALUES (...)
```

不得使用 `INSERT OR REPLACE`，避免竞态下覆盖已经存在的确定性 ID 记录。

### 6.6 导入维护接口

```ts
static async appendImportBatch(
  entries: LogEntry[]
): Promise<MutationResult>

static async reconcileImportStorage(
  notifyChanged: boolean
): Promise<MutationResult>
```

规则：

- `appendImportBatch()` 只规范化和写入，不执行维护、不通知页面。
- 每累计成功提交约 10000 条时调用 `reconcileImportStorage(false)`。
- 全部文件完成后调用 `reconcileImportStorage(true)`。
- 最终只有一次 `notifyChanged()`。

## 7. 文件级修改清单

| 文件 | 修改内容 | 是否改变用户交互 |
|---|---|---|
| `docs/03-模块设计/日志管理组件设计说明.md` | 先更新线程模型、导入数据流、持久化职责、失败策略和验收口径 | 文档先行 |
| `entry/src/main/ets/services/log-manage/import/LogImportBackgroundTask.ets` | 拆分准备任务和单文件解析任务，删除全包数组累计 | 否 |
| `entry/src/main/ets/services/log-manage/import/LogImportService.ets` | LongTask 准备、逐文件调度、1000 条批处理、统计收敛 | 否 |
| `entry/src/main/ets/services/log-manage/repository/LogEntryRepository.ets` | 批量查重、导入专用 `INSERT OR IGNORE` | 否 |
| `entry/src/main/ets/services/log-manage/maintenance/LogStorageMaintenanceService.ets` | 无通知批量追加、定期裁剪、最终统一通知 | 否 |
| `entry/src/test/log-manage/import-service.test.ets` | 更新任务结果契约和批处理测试 | 否 |
| `entry/src/test/log-manage/entry-repository.test.ets` | 增加批量查重及不覆盖写入测试 | 否 |
| `entry/src/test/log-manage/maintenance-service.test.ets` | 增加导入批次、无通知维护和最终通知测试 | 否 |

明确不修改：

- `entry/src/main/ets/views/log-manage/overview/LogManagePage.ets`
- `entry/src/main/ets/components/CommonLoadingDialog.ets`
- `entry/src/main/ets/utils/TimedLoadingDialogRunner.ets`
- `KernelLogImportRule.ets`
- `CrashLogImportRule.ets`
- `SystemLogImportRule.ets`
- 权限声明和签名模板

## 8. 实施任务拆分

### Task 1：模块设计文档先行

修改：

```text
docs/03-模块设计/日志管理组件设计说明.md
```

内容：

1. 将离线导入线程模型改为“LongTask 准备 + 单文件 TaskPool 解析”。
2. 将导入数据流改为单文件结果立即分批持久化。
3. 明确 1000 条批次和 10000 条无通知维护阈值。
4. 明确 Repository、Maintenance Service 的新增职责。
5. 明确部分写入、重试去重和最终一次通知语义。
6. 补充自动化及实机验收口径。
7. 在现有动效设计版本基础上增加新版本和变更日志，不覆盖现有未提交内容。

完成条件：

- 文档模板结构保持完整。
- 中文 UTF-8 回读正常。
- 文档描述与本方案一致。

### Task 2：后台任务按准备和单文件解析拆分

修改：

```text
LogImportBackgroundTask.ets
```

步骤：

1. 定义 `LogImportPrepareTaskResult`。
2. 将 `LogArchiveExtractor.extract()` 移入 `runLogImportPrepareTask()`。
3. 在准备任务中使用现有规则 `canHandle()` 过滤候选文件。
4. 新增 `runLogImportFileParseTask(file)`。
5. 删除 `parsedEntries`、全包 `Set` 和全包 `entries` 返回。
6. 保留单文件规则异常计数和日志。

完成条件：

- 后台代码不再出现全包 `parsedEntries.concat(...)`。
- 准备结果不包含 `LogEntry[]`。
- 单文件任务只解析传入文件。
- 三个规则接口和实现不修改。

回滚边界：

- 本任务只调整后台任务职责，不同时修改页面和解析规则。

### Task 3：Repository 批量查重与导入写入

修改：

```text
LogEntryRepository.ets
entry-repository.test.ets
```

步骤：

1. 新增 `findExistingEntryIds()`。
2. 限定单次最多 1000 个 ID。
3. 新增 `insertImportEntries()`。
4. 使用 `INSERT OR IGNORE`，保持已有记录不更新。
5. 保留现有 `hasEntry()` 和 `upsertEntries()`，避免影响实时采集及页面详情。

完成条件：

- 1000 个 ID 只执行一次查询。
- 返回集合只包含数据库已存在的 ID。
- 重复 `record_id` 不覆盖旧记录。
- 普通实时采集写入路径行为不变。

回滚边界：

- 新接口仅由导入链路使用，不替换其它存储调用。

### Task 4：Maintenance Service 增加导入批次模式

修改：

```text
LogStorageMaintenanceService.ets
maintenance-service.test.ets
```

步骤：

1. 新增 `appendImportBatch()`。
2. 复用 `LogEntryNormalizer.normalizeEntriesForAppend()`。
3. 调用 `LogEntryRepository.insertImportEntries()`。
4. 新增 `reconcileImportStorage(notifyChanged)`。
5. `notifyChanged=false` 时只删除过期和裁剪条数。
6. `notifyChanged=true` 时维护完成后通知一次。
7. 保持现有 `appendEntries()` 行为不变。

完成条件：

- 导入批次不会触发页面通知。
- 定期维护不会刷新页面。
- 最终维护只通知一次。
- 留存天数和最大条数规则与现有配置一致。

### Task 5：LogImportService 按文件编排

修改：

```text
LogImportService.ets
import-service.test.ets
```

步骤：

1. 使用 `taskpool.LongTask` 执行准备任务。
2. 在 `finally` 中终止 LongTask。
3. 顺序遍历候选文件，不并行堆积多个文件结果。
4. 每个文件调用 `runLogImportFileParseTask()`。
5. 将单文件结果按 1000 条切分。
6. 每批先过滤过期，再用当前批次 `Set` 去重。
7. 调用 `findExistingEntryIds()` 批量过滤库内重复。
8. 调用 `appendImportBatch()` 写入。
9. 每累计约 10000 条成功提交记录执行无通知维护。
10. 全部完成后执行最终维护和一次通知。
11. 汇总并返回现有导入统计字段。
12. 保持 `finally` 工作目录清理。

完成条件：

- 主流程不再接收或构造全包 `LogEntry[]`。
- 任意时刻只处理一个文件结果。
- 单批最多 1000 条。
- 入库失败停止后续处理并返回 `save_failed`。
- 成功完成后只触发一次存储通知。

### Task 6：自动化回归

步骤：

1. 更新现有导入 Service UT。
2. 增加 2300 条的 `1000 + 1000 + 300` 批次边界测试。
3. 增加批内重复测试。
4. 增加跨批次和跨文件重复测试。
5. 增加过期记录过滤测试。
6. 增加第二批写入失败测试。
7. 增加每 10000 条无通知维护测试。
8. 增加最终只通知一次测试。
9. 回归三个导入规则、行读取器、Repository 和 Maintenance Service 测试。

完成条件：

- 不删除或降低现有测试断言。
- 新增行为均有直接 UT 覆盖。
- 原有解析规则快照保持一致。

### Task 7：构建和设备验收

步骤：

1. 运行文档一致性和编码检查。
2. 运行 `entry@default` UT。
3. 编译主 HAP。
4. 签名并安装设备。
5. 使用当前 254 MB 日志包验收。
6. 使用多个轮转文件组成的数 GB 日志包验收。
7. 检查 TaskPool、RDB、加载动效和临时目录日志。

完成条件：

- 自动化、构建和实机验收全部满足第 9、10 节。

## 9. 自动化验收点

### 9.1 静态架构验收

1. `LogImportBackgroundTask` 不再返回全包 `entries: LogEntry[]`。
2. 不存在 `parsedEntries.concat(ruleResult.entries)`。
3. `LogImportService` 不直接调用 `LogArchiveExtractor` 或具体导入规则。
4. Import Rules 不依赖 Repository、Maintenance Service 或页面。
5. Page 和 ViewModel 不新增 TaskPool、文件系统或 SQL 依赖。
6. Repository 是 `log_entries` 表的唯一 SQL owner。
7. 不新增 NDJSON、临时解析结果文件或 `Task.sendData()`。
8. 不修改权限、签名模板、包名和数据库 schema。
9. 不修改当前加载弹框和页面交互文件。

### 9.2 准备任务 UT

至少覆盖：

1. 非 ZIP 返回 `invalid_archive`。
2. 解压失败返回 `extract_failed`。
3. 扫描文件总数正确。
4. 只返回能被现有规则处理的候选文件。
5. 普通 `remoteLog/hilog/hilog.*` 仍不进入系统日志候选。
6. 内核、崩溃和系统候选文件均能保留。
7. 准备结果不包含日志记录。

### 9.3 单文件任务 UT

至少覆盖：

1. 内核候选文件调用内核规则。
2. faultlogger 候选文件调用崩溃规则。
3. 系统白名单文件调用系统规则。
4. 非候选文件返回空结果。
5. 单文件规则失败计入失败，不构造全包状态。
6. 单文件结果的 dropped、failed 和 entries 原样返回。

### 9.4 批次处理 UT

至少覆盖：

1. 0 条不调用 Repository。
2. 1 条生成一个批次。
3. 1000 条生成一个批次。
4. 1001 条生成 `1000 + 1` 两个批次。
5. 2300 条生成 `1000 + 1000 + 300` 三个批次。
6. 每次 `findExistingEntryIds()` 入参不超过 1000。
7. 每次 `appendImportBatch()` 入参不超过 1000。
8. 当前批次重复在数据库查询前被过滤。
9. 前序批次已经写入的记录在后续批次被识别为重复。
10. 前一个文件已写入的记录在后续文件被识别为重复。
11. 过期记录不进入批量查询和写入。
12. 插入数量、重复数量和过期数量累计正确。

### 9.5 Repository UT

至少覆盖：

1. 空 ID 数组返回空集合，不执行 SQL。
2. 单 ID 查询正确。
3. 1000 个 ID 查询正确。
4. 只返回已存在的 `record_id`。
5. `INSERT OR IGNORE` 首次写入成功。
6. 再次写入同一 `record_id` 不覆盖原详情。
7. 同批出现重复 ID 时数据库保持一条记录。
8. 普通 `upsertEntries()` 行为不变。

### 9.6 Maintenance Service UT

至少覆盖：

1. `appendImportBatch()` 未初始化时返回 `not_initialized`。
2. 空批次直接成功。
3. 规范化后空批次直接成功。
4. 写入失败返回 `save_failed`。
5. 写入成功不调用 `notifyChanged()`。
6. `reconcileImportStorage(false)` 执行过期清理和条数裁剪但不通知。
7. `reconcileImportStorage(true)` 维护完成后通知一次。
8. 删除过期失败或裁剪失败返回 `save_failed`。
9. 现有 `appendEntries()` 仍维持实时采集后的维护和通知。

### 9.7 Service 失败 UT

至少覆盖：

1. Picker 取消不启动准备任务。
2. 准备任务失败不启动单文件任务。
3. 单文件任务失败后继续后续文件。
4. 第二个入库批次失败时停止后续批次和文件。
5. 中途维护失败时返回 `save_failed`。
6. 最终维护失败时返回 `save_failed`。
7. 已成功写入的前序批次不做应用层回滚。
8. 成功、失败和异常分支均调用工作目录清理。
9. 清理失败不覆盖原导入结果。
10. LongTask 在成功和异常分支均执行终止。

## 10. 构建与实机验收点

### 10.1 必须运行的命令

按项目工具链查找规则解析 `hvigorw.bat`，执行：

```text
python scripts/check_docs_consistency.py
git diff --check
hvigorw test --mode module -p product=default -p module=entry@default
hvigorw assembleHap --mode module -p product=default -p module=entry
```

若设备侧回归需要 ohosTest，再执行：

```text
hvigorw test --mode module -p product=default -p module=entry@ohosTest
hvigorw assembleHap --mode module -p product=default -p module=entry@ohosTest
```

### 10.2 当前 254 MB 日志包验收

使用已经复现问题的日志包，必须满足：

1. 日志包可以完成解压、解析和入库。
2. 不再出现：

```text
failed to serialize result
current size is ... max size is 16777216
```

3. 后台日志显示候选文件逐个开始和完成解析。
4. 不再出现“全包 parsed/unique entries 返回”的日志。
5. 加载弹框覆盖整个应用窗口。
6. 加载动画在准备、解析和入库阶段持续正常。
7. 导入期间底层页面不可操作。
8. 导入完成后加载弹框关闭，成功结果正常展示。
9. 页面最终列表、总数和分类统计正确刷新。
10. `context.filesDir/log_import_tmp` 在导入结束后被清理。

### 10.3 数 GB 多文件日志包验收

使用由多个轮转文件组成的数 GB 日志包，必须满足：

1. 日志包总解析结果即使远大于 16 MB，也不形成单次大返回值。
2. 不发生 TaskPool 序列化大小异常。
3. 不发生应用 OOM、闪退或长时间无响应。
4. 内存中不保留整个日志包的 `LogEntry[]`。
5. 每个候选文件完成后才开始下一个文件持久化或解析。
6. 单个数据库批次不超过 1000 条。
7. 导入过程中数据库记录数量按阈值定期收敛。
8. 导入完成后数据库记录数量不超过 `maxLocalEntries`。
9. 导入完成后不存在超过当前留存天数的记录。
10. 页面只在最终维护后刷新一次，不因每批写入反复刷新。

### 10.4 重复和留存验收

1. 同一日志包重复导入时，已有记录不更新。
2. 重复记录计入 `skippedDuplicateCount`。
3. 已超过当前自然日留存截止点的记录不入库。
4. 过期记录计入 `skippedExpiredCount`。
5. 前一个文件和后一个文件中的相同确定性 ID 只保留一条。
6. 导入失败后重新选择相同包，已成功批次被跳过，剩余记录可继续导入。

### 10.5 失败验收

1. 非 ZIP 文件仍提示选择 ZIP 格式日志包。
2. ZIP 解压失败仍返回解压失败。
3. 单个文件规则失败不阻断其它文件。
4. RDB 写入失败时停止导入并展示入库失败。
5. 已写入批次不会因后续批次失败而显示为数据库未写入。
6. 工作目录清理失败只记录错误，不覆盖主要结果。
7. 页面退出、导入成功、导入失败或异常时加载弹框均可关闭。

## 11. 观测日志要求

保留必要的关键流程结论，不增加重复 start/success 噪音。

建议日志：

```text
prepare start / done
candidate file count
file parse start / done
file persist done
periodic reconcile done
final reconcile done
import done
import failed
```

每个文件完成日志至少包含：

```text
importId
file relativePath
parsed
dropped
failed
inserted
duplicate
expired
elapsedMs
```

禁止：

- 每条日志输出一条业务日志。
- 每 1000 条重复输出无诊断价值的成功日志。
- 在业务文件直接调用 `hilog`。

## 12. 风险与控制措施

| 风险 | 等级 | 控制措施 |
|---|---|---|
| 单个文件结果超过 16 MB | 中 | 当前实机单文件有足够余量；明确列为本次非目标；实机记录最大单文件解析数量 |
| 候选文件清单自身超过 16 MB | 低 | 现网轮转文件数量远低于该边界；准备任务只返回候选文件元数据 |
| 分批写入后部分成功 | 中 | 明确部分写入语义；确定性 ID + 批量查重 + INSERT OR IGNORE 支持安全重试 |
| 导入期间数据库临时增长 | 中 | 每累计约 10000 条执行无通知维护 |
| 逐批通知导致动效或查询抖动 | 中 | 导入批次禁止通知，最终只通知一次 |
| 批量 IN 查询参数过多 | 低 | 固定上限 1000，并通过 Repository UT 和实机验证 |
| LongTask 未终止 | 中 | `finally` 强制 `terminateTask()`，增加成功和异常 UT |
| 现有动效修改被覆盖 | 中 | 本方案不修改 Page、CommonLoadingDialog 和 TimedLoadingDialogRunner |
| 中文文档或代码乱码 | 低 | 使用 UTF-8、apply_patch，修改后回读并运行文档一致性检查 |

## 13. 回滚触发条件

出现以下任一情况，当前工作包不得继续合入：

1. 当前 254 MB 日志包仍出现 TaskPool 16 MB 序列化异常。
2. 单个文件解析结果被错误合并回全包数组。
3. 导入期间每个批次都触发页面刷新。
4. 重复导入覆盖已有记录。
5. 最终数据库超过最大条数或保留过期记录。
6. 三个现有解析规则的输出语义发生变化。
7. 当前加载弹框无法打开、提前关闭或动画卡住。
8. 导入失败后工作目录无法在下一次导入前清理。
9. Repository 之外出现新的日志表 SQL。
10. 为解决本问题新增进度、取消、断点或任务表等超范围能力。

## 14. 完成定义

全部满足以下条件才视为完成：

1. 日志模块设计文档先于代码更新，并与实现一致。
2. 后台任务已拆为准备任务和单文件解析任务。
3. 不再存在全包 `LogEntry[]` 返回和全包 `newEntries[]`。
4. 单文件结果按 1000 条完成过期过滤、批内去重、库内查重和事务写入。
5. 导入链路不再逐条调用 `hasEntry()`。
6. 导入专用写入不覆盖已有确定性 ID 记录。
7. 导入期间定期无通知维护，最终只通知页面一次。
8. 当前 254 MB 复现包导入成功且无序列化异常。
9. 数 GB、多轮转文件日志包完成导入且无 OOM、闪退或全包结果累计。
10. 重复、过期、单文件失败、批次写入失败和目录清理均通过验收。
11. 相关 UT、文档一致性检查和主 HAP 构建通过。
12. 当前加载动效、页面交互、解析规则、权限和签名配置无回归。

## 15. 已知边界与后续触发条件

本方案依赖“现网大包由多个轮转日志文件组成，单文件解析结果小于 16 MB”这一已验证事实。

如果后续出现以下任一情况，应单独立项，不在本次方案中继续叠加：

1. 单个候选日志文件的 TaskPool 返回值超过 16 MB。
2. 单个候选日志文件解析持续时间超过普通 Task 可接受范围。
3. 候选文件数量大到文件清单本身接近 16 MB。
4. 产品要求导入进度、取消或断点恢复。

届时优先评估：

```text
规则流式 Sink
  -> 固定大小结果分片
  -> 临时文件或受控消息通道
  -> 消费完成后立即释放
```

该后续架构不属于本次最小修复范围。
