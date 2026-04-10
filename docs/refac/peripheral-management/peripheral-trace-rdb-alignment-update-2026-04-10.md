# 外设连接记录 RDB 对齐更新说明（2026-04-10）

## 1. 文档目的

补充说明外设连接记录链路在切换到 RDB 后的当前实现状态、已经完成的关键改造，以及与日志管理设计仍存在的差距。

本文件作为以下文档的增量更新说明：

- [storage-architecture-standard.md](/C:/Users/mu/Desktop/code/security_tool/docs/storage-architecture-standard.md)
- `docs/03-模块设计/外设管理组件设计说明.md`
- `docs/refac/peripheral-management/peripheral-management-module-rfc.md`

## 2. 当前结论

外设连接记录主存储已经完成从 Preferences 到 RDB 的切换，运行时主链不再依赖旧的 Preferences payload 兼容路径。

当前主链结构：

1. `PeripheralTraceEntryRepository`
   - RDB owner
   - 负责表 `peripheral_trace_entries`
   - 负责查询、计数、删除、裁剪、清空、监听

2. `PeripheralTraceMaintenanceService`
   - 负责初始化
   - 负责追加记录
   - 负责按时间清理
   - 负责按数量裁剪
   - 负责清空

3. `PeripheralConnectionRecordService`
   - 负责把 trace record 映射为页面使用的 connection record

4. `PeripheralViewModel / DashboardViewModel`
   - 直接监听 `PeripheralTraceEntryRepository`
   - 不再依赖旧的 trace facade 缓存

## 3. 已完成的关键改造

### 3.1 持久化 owner 切换

已完成：

- `PeripheralTraceEntryRepository` 成为唯一 RDB owner
- `PeripheralTraceMaintenanceService` 成为唯一维护服务
- 旧的 `PeripheralTraceRepository` 不再承担运行时主存储 owner 职责

### 3.2 数据增删确认

当前增删都是真正落在数据库中：

- 新增/覆盖写入：`upsertBatch()`
- 按时间删除：`deleteExpired()`
- 按数量裁剪：`trimToMaxEntries()`
- 清空：`clearAll()`

### 3.3 页面监听链调整

已完成：

- 外设页监听改为直接监听 `PeripheralTraceEntryRepository`
- 仪表盘外设卡片监听改为直接监听 `PeripheralTraceEntryRepository`
- 运行时事件 pipeline 改为通过 `PeripheralTraceMaintenanceService.appendEntries()` 落库

### 3.4 旧兼容路径清理

已移除：

- 旧的 Preferences 持久化主路径
- 旧的内存 records 缓存主路径
- 旧的 trace facade 作为运行时 owner 的角色

## 4. 当前与日志管理设计的差距

虽然 RDB 主链已经切换完成，但与日志管理相比，外设连接记录还有以下差距。

### 4.1 统计仍未下沉到 SQL

当前 `PeripheralTraceEntryRepository.getStatistics()` 仍然是：

1. 先查出所有记录
2. 再在内存中循环统计

这与日志管理已实现的 SQL 聚合统计不一致，也是当前最大的性能风险点。

### 4.2 页面查询仍然是全量读取

当前 `PeripheralConnectionRecordService.queryRecords()` 默认直接读取完整结果集。

这会导致：

- 外设页刷新时可能全表扫描
- 监听触发时反复加载大量记录
- 数据量接近上限时页面响应变慢

### 4.3 维护服务返回值仍然过于粗糙

当前 `PeripheralTraceMaintenanceService` 仍以 `boolean` 为主。

这会导致上层无法区分：

- 未初始化
- 保存失败
- 清理失败
- 清空失败

而日志管理已使用更明确的结果模型。

### 4.4 pipeline 成功语义仍然偏宽

当前 pipeline 在 consumer 成功产出记录后，即使落库失败，也可能把该事件当作“已处理成功”。

这会导致：

- 上游误判
- 事件被消费但数据没保存
- 页面与实际处理状态不一致

## 5. 下一步对齐方向

### 5.1 统计 SQL 化

参考日志管理，把外设统计改成：

- `countByQuery`
- `countByRawWhere`
- `groupCountByAction`
- `groupCountByDecision`
- `groupCountBySource`

目标：

- 仪表盘外设卡片不再依赖全量读
- 外设页统计不再依赖全量读

### 5.2 查询分页化

目标：

- `PeripheralConnectionRecordService` 提供 `limit/offset`
- 页面默认只读最近 N 条
- 后续如需要再扩成真正分页

### 5.3 结果模型对齐

参考日志管理，补齐：

- `PeripheralTraceInitializeResult`
- `PeripheralTraceMutationResult`
- `PeripheralTraceClearResult`

目标：

- 初始化失败原因明确
- 保存失败原因明确
- 清理失败原因明确

### 5.4 pipeline 结果语义收紧

目标：

- 区分“consumer 处理成功”
- 区分“记录已成功落库”

避免继续使用单一宽泛 `boolean` 表示整条链路成功。

## 6. 当前建议

后续如继续演进外设连接记录链路，应按以下顺序推进：

1. 先做 SQL 统计下沉
2. 再做查询分页化
3. 再做维护服务结果模型对齐
4. 最后收紧 pipeline 成功语义

## 7. 更新说明

本文件用于刷新外设连接记录切换到 RDB 后的设计状态。

如果后续完成：

- SQL 统计下沉
- 分页查询
- 结果模型统一
- pipeline 成功语义收紧

则应继续更新本文件，保持其与运行时代码一致。
