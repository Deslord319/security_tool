# Recorder CLI

`recorder.py` 是一个只负责固定格式落盘的本地工具。

它不负责：

- 决定下一步调哪个 agent
- 调度 subagent
- 总结业务结论

这些都由主 agent 负责。主 agent 只是在每个关键阶段前后调用 `recorder.py`，把 `run`、`event`、`artifact`、`review` 写入本地。

## 当前主模型

observer 当前主路径统一为：

- `run`
- `event`
- `artifact`
- `review`

`step` 相关命令和文件目前仍在代码里保留，主要用于兼容历史数据，不再是推荐写入路径。

## 端到端流程

```text
用户任务
  -> 主 agent
    -> recorder.py start-run
    -> 调 SE / CTest / BugFix / Reviewer
    -> 子 agent 返回完整 handoff JSON
    -> recorder.py write-event(agent.output, payload=完整 handoff)
    -> recorder.py add-artifact
    -> 可选：recorder.py write-review
    -> ...
    -> recorder.py finish-run
  -> agent-observer 读取 summary.json / events.jsonl / reviews.jsonl / artifacts/
```

## 目录结构

默认数据目录：

```text
agent-observer/
  data/
    runs/
      2026-03-22/
        run-20260322-163337-001/
          summary.json
          events.jsonl
          reviews.jsonl
          artifacts/
            ctest/
              art-000001__ctest-darkmode-topright-crop.png
```

## 命令

### 1. start-run

创建 run 目录，并写入第一条 `run.started` 事件。

```bash
python agent-observer/recorder/recorder.py start-run ^
  --title "深色模式顶部按钮可见性审查" ^
  --goal "复现并分析深色模式下右上角按钮不可见问题" ^
  --mode "review"
```

### 2. write-event

写入一条标准事件。推荐正式阶段结果统一使用 `agent.output`。

```bash
python agent-observer/recorder/recorder.py write-event ^
  --run-id run-20260322-163337-001 ^
  --event-type agent.output ^
  --agent CTest ^
  --agent-task-id task-731edb659c9d ^
  --title "深色模式顶部按钮复现" ^
  --payload-file D:\temp\ctest_handoff.json
```

说明：

- `payload-file` 推荐直接传完整 handoff JSON。
- 不要把正式阶段结果压缩成 `summary/evidence/details` 一类临时字段。
- 如需显式挂回 artifact 引用，可通过 `--artifacts-file` 传入 `artifactId` 列表。

### 3. add-artifact

复制一份证据文件到 run 目录，并自动写入一条 `artifact.created` 事件。

```bash
python agent-observer/recorder/recorder.py add-artifact ^
  --run-id run-20260322-163337-001 ^
  --target-event-id evt-000002 ^
  --kind screenshot ^
  --title "深色模式顶部按钮裁剪图" ^
  --agent CTest ^
  --source D:\project\ai\security_tool\screenshots\ctest-darkmode-topright-crop.png
```

### 4. write-review

给某个事件补充人工复核结果。

```bash
python agent-observer/recorder/recorder.py write-review ^
  --run-id run-20260322-163337-001 ^
  --target-event-id evt-000002 ^
  --review-status valid ^
  --reviewed-by Main ^
  --comment "复现结论与截图一致。"
```

### 5. finish-run

写入最后一条 run 生命周期事件，并更新 `summary.json`。

```bash
python agent-observer/recorder/recorder.py finish-run ^
  --run-id run-20260322-163337-001 ^
  --status completed ^
  --result-status reviewed ^
  --summary-text "已完成 CTest 复现与 SE 分析，本轮未进入修复。"
```

## 主 agent 推荐调用顺序

```text
1. start-run
2. 调用子 agent
3. 校验子 agent 返回的 handoff JSON
4. write-event(agent.output, payload=完整 handoff)
5. 对 handoff.artifacts 逐个 add-artifact
6. 如有需要，补写 write-review
7. 重复 2~6
8. finish-run
```

## 最小 schema 示例

### summary.json

```json
{
  "schemaVersion": "1.0",
  "runId": "run-20260322-163337-001",
  "title": "深色模式顶部按钮可见性审查",
  "goal": "复现并分析深色模式下右上角按钮不可见问题",
  "mode": "review",
  "status": "completed",
  "resultStatus": "reviewed",
  "createdAt": "2026-03-22T16:33:37+08:00",
  "updatedAt": "2026-03-22T16:33:39+08:00",
  "completedAt": "2026-03-22T16:33:39+08:00",
  "eventCount": 12,
  "artifactCount": 8,
  "agents": [
    "Main",
    "CTest",
    "SE"
  ],
  "latestEventId": "evt-000012",
  "latestEventType": "run.completed",
  "latestEventTitle": "Run completed"
}
```

### agent.output 事件

```json
{
  "schemaVersion": "1.0",
  "runId": "run-20260322-163337-001",
  "eventId": "evt-000002",
  "parentEventId": null,
  "timestamp": "2026-03-22T16:33:37+08:00",
  "agent": "CTest",
  "agentTaskId": "task-731edb659c9d",
  "eventType": "agent.output",
  "title": "深色模式顶部按钮复现",
  "status": "completed",
  "payload": {
    "handoffVersion": "1.0",
    "sourceAgent": "CTest",
    "sourceAgentTaskId": "task-731edb659c9d",
    "stepTitle": "深色模式顶部按钮复现",
    "status": "completed",
    "input": {
      "summary": "复现并确认问题位置与按钮归属",
      "details": {}
    },
    "output": {
      "summary": "问题已复现，位置在主窗口标题栏/窗口控制区。",
      "keyPoints": [
        "复现成立",
        "四个按钮分别是 menu、maximize/restore、minimize、close"
      ],
      "details": {
        "verificationMode": "reuse-installed-build",
        "finalVerdict": "verified"
      }
    },
    "artifacts": []
  },
  "artifacts": [
    {
      "artifactId": "art-000001"
    }
  ]
}
```

### artifact.created 事件载荷

```json
{
  "artifactId": "art-000001",
  "kind": "screenshot",
  "title": "深色模式顶部按钮裁剪图",
  "path": "artifacts/ctest/art-000001__ctest-darkmode-topright-crop.png",
  "sourcePath": "D:\\project\\ai\\security_tool\\screenshots\\ctest-darkmode-topright-crop.png",
  "sourceAgent": "CTest",
  "targetEventId": "evt-000002",
  "createdAt": "2026-03-22T16:33:37+08:00"
}
```

### reviews.jsonl

```json
{
  "schemaVersion": "1.0",
  "runId": "run-20260322-163337-001",
  "reviewId": "rev-000001",
  "targetEventId": "evt-000002",
  "reviewStatus": "valid",
  "reviewedBy": "Main",
  "reviewedAt": "2026-03-22T16:40:00+08:00",
  "comment": "复现结论与截图一致。"
}
```

## 说明

- `artifact.created` 事件负责本地文件和事件关联。
- handoff `artifacts[]` 负责补充描述、原始路径和更完整的元信息。
- 前端当前主视图读取 `summary.json`、`events.jsonl`、`reviews.jsonl` 和 `artifacts/`，不再依赖 `steps.jsonl`。
- 历史 run 若只保留弱结构事件，前端会尝试降级展示，但无法恢复未落盘的信息。
