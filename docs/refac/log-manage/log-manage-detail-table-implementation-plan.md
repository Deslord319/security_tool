# 日志管理模块详情结构化展示实施计划

## 1. 背景

当前日志详情弹窗直接展示 `LogEntry.detail`。对于系统审计事件，这里的内容通常是原始 JSON，用户可读性较差。

本轮改造聚焦把详情展示从“原始文本”切到“结构化表格”。

需要特别说明的是，当前日志中的 `ACCOUNT` 事件实际存在两条来源链路：

- 系统审计源触发的 `ACCOUNT` 事件
- 业务代码主动写入的 `ACCOUNT` 运行时日志

其中，业务代码主动写入这条链路后续准备废除，因此不纳入本次实施计划。本计划只面向系统审计事件触发的数据源。

## 2. 目的

本次改造目标是：

- 为 `LogEntry` 增加结构化详情字段
- 新增可复用表格组件
- `ACCOUNT / PERMISSION / FILE` 按已确认关键字段展示不同表格行
- 详情弹窗只消费结构化字段，不再把原始 JSON 作为主内容

## 3. 代码文件修改范围

本次改造的代码文件范围严格限定如下。

### 3.1 需要修改的现有文件

- `entry/src/main/ets/models/DataModels.ets`
- `entry/src/main/ets/services/log-manage/source/LogAuditEventMapper.ets`
- `entry/src/main/ets/services/log-manage/mapper/LogEntryNormalizer.ets`
- `entry/src/main/ets/services/log-manage/repository/LogEntryRepository.ets`
- `entry/src/main/ets/components/log-manage/detail/LogDetailDialog.ets`
- `entry/src/main/ets/constants/modules/LogManageStrings.ets`
- `entry/src/test/log-manage/audit-source.test.ets`
- `entry/src/test/log-manage/entry-normalizer.test.ets`
- `entry/src/test/log-manage/entry-repository.test.ets`

### 3.2 需要新增的文件

- `entry/src/main/ets/components/log-manage/detail/LogDetailTable.ets`

## 4. 实施步骤

### Step 1. 冻结数据结构契约

**输入**

- `docs/refac/log-manage/log-manage-audit-event-materials.md`
- `docs/refac/log-manage/log-manage-detail-table-plan.md`
- `entry/src/main/ets/models/DataModels.ets`

**输出**

- `LogDetailTableRow`
- `LogEntry.detailRows?: LogDetailTableRow[]`
- 字段约束：`key / label / value` 都为字符串

**验收标准**

- `LogEntry` 已可承载结构化详情
- 不新增事件特定的零散顶层字段
- 不破坏现有 `LogEntry` 使用方编译

**并行性**

- 本步骤是后续步骤的契约基础，不能跳过

### Step 2. 实现系统审计事件到 `detailRows` 的组装

**输入**

- Step 1 的数据结构
- `entry/src/main/ets/services/log-manage/source/LogAuditEventMapper.ets`
- 已确认的事件字段口径

**输出**

- `ACCOUNT / PERMISSION / FILE` 的 `detailRows`

**验收标准**

- `ACCOUNT` 行至少包含：用户名、用户 ID、结果、事件时间、事件 ID
- `PERMISSION` 行至少包含：应用包名、进程名候选、PID、UID、新权限名称、新权限状态、已有权限列表、事件时间、事件 ID
- `FILE` 行至少包含：操作类型、文件路径、进程名、PID、UID、结果、事件时间、事件 ID
- `detailRows` 为空时不生成垃圾占位项

**并行性**

- 依赖 Step 1
- 可与 Step 3 并行开发

### Step 3. 实现 `detailRows` 的归一化与持久化

**输入**

- Step 1 的数据结构
- `entry/src/main/ets/services/log-manage/mapper/LogEntryNormalizer.ets`
- `entry/src/main/ets/services/log-manage/repository/LogEntryRepository.ets`

**输出**

- `detailRows` 经过 normalizer 清洗
- `detailRows` 写入 `extra_json`
- 查询回读时恢复为 `LogEntry.detailRows`

**验收标准**

- 入库前后 `detailRows` 不丢失
- 空数组和非法项被安全处理
- 不改数据库表结构
- 不影响原有查询、统计、分页能力

**并行性**

- 依赖 Step 1
- 可与 Step 2、Step 4 并行开发

### Step 4. 新增通用表格组件并改造详情弹窗

**输入**

- Step 1 的数据结构
- `entry/src/main/ets/components/log-manage/detail/LogDetailDialog.ets`
- `entry/src/main/ets/constants/modules/LogManageStrings.ets`

**输出**

- 新增 `entry/src/main/ets/components/log-manage/detail/LogDetailTable.ets`
- 详情弹窗切换为“顶部摘要 + 结构化表格”
- 弹窗默认消费 `entry.detailRows`

**验收标准**

- 弹窗不再把原始 JSON 作为主视图正文
- 表格组件不判断事件类型，只渲染传入行
- 长文本可以换行
- 空行不展示

**并行性**

- 依赖 Step 1
- 可与 Step 2、Step 3 并行开发
- 最终联调依赖 Step 2 和 Step 3 已提供真实 `detailRows`

### Step 5. 删除因改造产生的腐败代码

**输入**

- Step 2 到 Step 4 的完成代码

**输出**

- 删除 `LogDetailDialog.ets` 中已经失效的固定字段拼装逻辑
- 删除只为旧详情模式存在的重复方法和无效文案

**必删项**

- `entry/src/main/ets/components/log-manage/detail/LogDetailDialog.ets` 中旧的 `LogDetailField`
- `entry/src/main/ets/components/log-manage/detail/LogDetailDialog.ets` 中 `pushTextField`
- `entry/src/main/ets/components/log-manage/detail/LogDetailDialog.ets` 中 `pushNumberField`
- `entry/src/main/ets/components/log-manage/detail/LogDetailDialog.ets` 中旧的 `getFields()`
- 本轮改造后不再使用的旧详情文案常量

**验收标准**

- 不保留“新表格 + 旧固定字段”的双轨逻辑
- 不保留死类型、死方法、死文案
- 组件职责边界清晰

**并行性**

- 依赖 Step 4，不能提前结束

### Step 6. 补测试并做回归

**输入**

- Step 2 到 Step 5 的最终代码
- 现有测试文件

**输出**

- `audit-source.test.ets`：补 `detailRows` 断言
- `entry-normalizer.test.ets`：补 `detailRows` 归一化断言
- `entry-repository.test.ets`：补 `detailRows` 存取断言

**验收标准**

- 单测通过
- 三类系统审计事件至少各有一类样例覆盖 `detailRows`
- 不出现序列化和反序列化回归

**并行性**

- 可在 Step 2、Step 3 启动后并行编写测试
- 最终通过依赖实现完成

## 5. 多 Session 并行建议

建议拆成 3 条并行线，减少文件冲突。

### Session A：数据模型与持久化

负责文件：

- `entry/src/main/ets/models/DataModels.ets`
- `entry/src/main/ets/services/log-manage/mapper/LogEntryNormalizer.ets`
- `entry/src/main/ets/services/log-manage/repository/LogEntryRepository.ets`
- `entry/src/test/log-manage/entry-normalizer.test.ets`
- `entry/src/test/log-manage/entry-repository.test.ets`

### Session B：审计事件映射

负责文件：

- `entry/src/main/ets/services/log-manage/source/LogAuditEventMapper.ets`
- `entry/src/test/log-manage/audit-source.test.ets`

### Session C：详情 UI

负责文件：

- `entry/src/main/ets/components/log-manage/detail/LogDetailDialog.ets`
- `entry/src/main/ets/components/log-manage/detail/LogDetailTable.ets`
- `entry/src/main/ets/constants/modules/LogManageStrings.ets`

## 6. 并行协作约束

- `detailRows` 的字段名、类型、空值规则必须先冻结
- `LogAuditEventMapper.ets` 只负责组装数据，不负责 UI 排版逻辑
- `LogDetailTable.ets` 不允许出现事件类型分支
- `LogEntryRepository.ets` 只持久化 `detailRows`，不重新推导业务字段
- 合入前必须执行一次死代码清理，禁止旧详情逻辑残留

## 7. 完成判定

本轮任务完成标准如下：

- 点击日志详情时，`ACCOUNT / PERMISSION / FILE` 不再以原始 JSON 作为主内容
- 详情页展示为统一摘要 + 结构化表格
- 表格组件可复用，且不包含事件类型判断
- `detailRows` 已贯通 mapper、normalizer、repository、dialog
- 旧的固定字段拼装逻辑已删除，不留双轨实现
