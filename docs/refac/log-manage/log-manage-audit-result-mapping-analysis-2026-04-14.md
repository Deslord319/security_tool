# 日志管理模块审计结果映射问题分析（2026-04-14）

## 1. 背景

本次排查聚焦日志管理列表和详情弹窗中的“成功 / 失败 / 阻止”展示是否正确，问题来源于一次失败的用户认证事件在日志列表中显示为“成功”。

为缩小范围，本轮只分析系统审计日志链路，不扩展到崩溃日志、导出链路或页面渲染样式问题。

## 2. 排查目标

1. 确认日志列表右侧“结果”是否为渲染层误判。
2. 确认详情弹窗中的“结果”字段是否与列表共用同一逻辑。
3. 确认 `entry.result` 的真实来源。
4. 定位 `outcome=Fail` 被错误展示为“成功”的根因。

## 3. 关键结论

### 3.1 列表和详情弹窗不是两套逻辑

日志列表和详情弹窗都直接展示 `entry.result`，并共用同一组结果文案与颜色映射函数：

- `getLogEventResultLabel(result)`
- `getLogEventResultColor(result)`

因此：

- 列表显示“成功”
- 详情弹窗显示“成功”

如果出现错误，通常不是两个展示组件各自判断出错，而是 `entry.result` 在进入展示层之前已经被错误归一化。

### 3.2 `entry.result` 不是页面生成的

`entry.result` 的值在日志来源映射阶段就已经确定：

- 审计日志：`entry/src/main/ets/services/log-manage/source/LogAuditEventMapper.ets`
- 崩溃日志：`entry/src/main/ets/services/log-manage/source/LogCrashEventMapper.ets`

列表和弹窗只负责读取，不负责重新推导结果。

### 3.3 本次问题根因不在渲染层，而在审计结果映射逻辑

排查日志表明：

- 原始审计事件 `content` 中带有 `outcome: "Fail"`
- 审计结果映射日志显示 `AUDIT_RESULT_MAPPING rawOutcome=Fail, mappedResult=0`
- `mappedResult=0` 对应 `SUCCESS`

因此问题根因是：

- 审计结果归一化逻辑只识别 `failed / error / reject`
- 没有识别 `fail`
- 导致 `Fail` 落入默认分支并被归为 `SUCCESS`

## 4. 代码链路

### 4.1 原始审计日志进入业务链路

文件：

- `entry/src/main/ets/services/log-manage/source/LogAuditSource.ets`

系统审计事件进入 `createAuditEventCallback()` 后，先拿到原始 `securityAudit.AuditEvent`，再交给 mapper 处理。

本轮新增的诊断日志：

- `AUDIT_RAW_INPUT`
- `AUDIT_RAW_INPUT_ACCEPTED`

用途：

- 观察原始 `eventId / timestamp / userId / content / metadata`
- 观察 mapper 输出后的 `result / rawOutcome`

### 4.2 审计结果映射

文件：

- `entry/src/main/ets/services/log-manage/source/LogAuditEventMapper.ets`

关键步骤：

1. 从 `content / metadata` 解析 JSON
2. 从以下字段中提取原始结果：
   - `outcome`
   - `result`
   - `status`
   - `decision`
   - `actionResult`
   - `action_result`
3. 将提取到的 `rawOutcome` 交给 `mapResult(rawOutcome)`
4. 产出统一的 `LogEventResult`

本轮新增的诊断日志：

- `AUDIT_RESULT_MAPPING`
- `AUDIT_MAPPED_RESULT`

用途：

- 观察 `rawOutcome -> mappedResult`
- 观察 mapper 最终输出的关键字段摘要

## 5. 真实样例

本次问题样例中的关键日志如下：

```text
AUDIT_RAW_INPUT eventId=268435712 ... content={"...","outcome":"Fail",...}
AUDIT_RESULT_MAPPING rawOutcome=Fail, mappedResult=0
AUDIT_MAPPED_RESULT ... rawOutcome=Fail, mappedResult=0
AUDIT_RAW_INPUT_ACCEPTED ... result=0, rawOutcome=Fail
```

解释：

- 原始输入明确给了 `outcome=Fail`
- mapper 把 `Fail` 归一化成了 `mappedResult=0`
- `0` 对应 `SUCCESS`
- 所以页面展示“成功”只是忠实展示了错误的业务结果

## 6. 修复方案

修复文件：

- `entry/src/main/ets/services/log-manage/source/LogAuditEventMapper.ets`

修复思路：

1. 对 `rawOutcome` 先做 `trim().toLowerCase()`
2. 失败类关键词从只识别：
   - `failed`
   - `error`
   - `reject`
3. 扩展为也识别：
   - `fail`

修复后的判断方向：

- `blocked / deny / intercept` -> `BLOCKED`
- `fail / failed / error / reject` -> `FAILED`
- 其他 -> `SUCCESS`

## 7. 影响面判断

本次修复不修改列表组件和详情弹窗组件，因为它们本身没有独立结果判断逻辑。

理论影响面只在审计日志的结果归一化：

- 用户认证失败
- 权限拒绝
- 文件访问失败
- 其他以 `Fail` 或类似失败表达上报的审计事件

只要原始 `rawOutcome` 中包含 `fail`，都会被正确归类到 `FAILED`。

## 8. 诊断日志关键词

后续排查时可以直接检索以下关键词：

- `AUDIT_RAW_INPUT`
- `AUDIT_RAW_INPUT_ACCEPTED`
- `AUDIT_RESULT_MAPPING`
- `AUDIT_MAPPED_RESULT`

建议阅读顺序：

1. 先看 `AUDIT_RAW_INPUT`
2. 再看 `AUDIT_RESULT_MAPPING`
3. 再看 `AUDIT_MAPPED_RESULT`
4. 最后看 `AUDIT_RAW_INPUT_ACCEPTED`

## 9. 本轮结论

本轮已确认：

1. 日志列表与详情弹窗结果展示共用同一套逻辑。
2. 问题不在渲染层。
3. `entry.result` 在 mapper 阶段就已确定。
4. `Fail -> SUCCESS` 的根因是审计结果映射规则漏识别 `fail`。
5. 修复应落在 `LogAuditEventMapper.ets`，而不是页面组件。
