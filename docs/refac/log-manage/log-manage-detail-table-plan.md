# 日志管理模块详情结构化展示方案

## 1. 背景

当前日志详情弹窗直接展示 `LogEntry.detail`。对于系统审计事件，这里的内容通常是原始 JSON，用户可读性较差。

结合当前已整理的系统审计事件材料，`ACCOUNT / PERMISSION / FILE` 三类事件已经具备原型样例和关键字段基础，适合从“原始文本展示”切到“结构化详情展示”。

需要特别说明的是，当前日志中的 `ACCOUNT` 事件实际存在两条来源链路：

- 系统审计源触发的 `ACCOUNT` 事件
- 业务代码主动写入的 `ACCOUNT` 运行时日志

其中，业务代码主动写入这条链路后续准备废除，因此不纳入本次详情结构化展示方案。本方案只面向系统审计事件触发的数据源。

## 2. 目的

本次改造目标是：

- 为 `LogEntry` 增加结构化详情字段
- 详情弹窗不再直接消费原始 JSON
- 封装一个可复用的表格组件
- 根据不同事件类型展示不同的表格行

本次事件范围只覆盖：

- `ACCOUNT`
- `PERMISSION`
- `FILE`

## 3. 方案方向

### 3.1 `LogEntry` 增加结构化详情字段

建议在 `LogEntry` 上增加结构化详情行字段，而不是让详情组件直接解析原始 JSON。

建议结构如下：

```ts
export interface LogDetailTableRow {
  key: string
  label: string
  value: string
}

export interface LogEntry {
  ...
  detailRows?: LogDetailTableRow[]
}
```

### 3.2 详情弹窗改为“摘要 + 表格”

详情弹窗继续保留顶部摘要信息：

- 时间
- 事件类型
- 结果

弹窗正文改为结构化表格区域，由可复用组件统一渲染 `detailRows`。

### 3.3 表格组件职责

新增一个通用表格组件，输入为 `LogDetailTableRow[]`。

组件只负责：

- 渲染字段标签和值
- 处理长文本换行
- 保持统一排版

组件不负责：

- 判断事件类型
- 从原始 JSON 提取字段
- 拼装业务字段

### 3.4 各事件类型表格行

各事件类型的表格行，严格按当前材料文档中已确认的关键字段生成。

#### ACCOUNT

- 用户名
- 用户 ID
- 结果
- 事件时间
- 事件 ID

#### PERMISSION

- 应用包名
- PID
- UID
- 新权限名称
- 新权限状态
- 事件时间
- 事件 ID

#### FILE

- 操作类型
- 文件路径
- 进程名
- PID
- UID
- 结果
- 事件时间
- 事件 ID

## 4. 代码文件修改范围

本方案对应的代码修改范围严格限定为以下文件。

### 4.1 需要修改的现有文件

- `entry/src/main/ets/models/DataModels.ets`
  - 新增 `LogDetailTableRow`
  - 为 `LogEntry` 增加结构化详情字段

- `entry/src/main/ets/services/log-manage/source/LogAuditEventMapper.ets`
  - 为 `ACCOUNT / PERMISSION / FILE` 系统审计事件组装 `detailRows`

- `entry/src/main/ets/services/log-manage/mapper/LogEntryNormalizer.ets`
  - 为 `detailRows` 增加归一化处理

- `entry/src/main/ets/services/log-manage/repository/LogEntryRepository.ets`
  - 在 `extra_json` 中持久化 `detailRows`
  - 查询回读时恢复 `detailRows`

- `entry/src/main/ets/components/log-manage/detail/LogDetailDialog.ets`
  - 改为消费结构化详情字段
  - 用表格组件替换当前原始文本详情展示

- `entry/src/main/ets/constants/modules/LogManageStrings.ets`
  - 补充详情表格展示所需文案

### 4.2 需要新增的文件

- `entry/src/main/ets/components/log-manage/detail/LogDetailTable.ets`
  - 可复用详情表格组件

## 5. 说明

本文件只记录本轮已确认的改造方向和代码文件范围，不展开具体实现细节、测试方案和后续演进议题。
