# Recorder CLI

`recorder.py` 是一个只负责固定格式落盘的工具脚本。

它不负责：

- 决定下一步调哪个 agent
- 调 subagent
- 总结业务结论

这些都由主 agent 负责。主 agent 只是在每个关键步骤前后调用 `recorder.py`，把 run、event 和 artifact 写入本地。

## 端到端流程

```text
用户任务
  -> 主 agent
    -> recorder.py start-run
    -> recorder.py write-event(agent.input)
    -> 调 SE / BugFix / CTest / Reviewer
    -> recorder.py write-event(agent.output)
    -> recorder.py add-artifact
    -> 主 agent 决定下一步
    -> ...
    -> recorder.py finish-run
  -> agent-observer 读取 summary.json / events.jsonl / artifacts/
```

## 目录结构

默认数据目录：

```text
agent-observer/
  data/
    runs/
      2026-03-20/
        run-20260320-143501-001/
          events.jsonl
          summary.json
          artifacts/
            ctest/
              art-000001__screenshot.png
```

## 命令

### 1. start-run

创建 run 目录，并写入第一条 `run.started` 事件。

```bash
python agent-observer/recorder/recorder.py start-run ^
  --title "防火墙规则保存失败" ^
  --goal "定位保存无响应并验证修复" ^
  --mode "一般缺陷"
```

输出示例：

```json
{
  "runId": "run-20260320-143501-001",
  "runDir": "D:\\project\\ai\\security_tool\\agent-observer\\data\\runs\\2026-03-20\\run-20260320-143501-001",
  "summaryPath": "...\\summary.json",
  "eventsPath": "...\\events.jsonl",
  "startedEventId": "evt-000001",
  "status": "in_progress"
}
```

### 2. write-event

写入一条标准事件，例如 `agent.input` 或 `agent.output`。

```bash
python agent-observer/recorder/recorder.py write-event ^
  --run-id run-20260320-143501-001 ^
  --event-type agent.input ^
  --agent SE ^
  --title "SE 输入" ^
  --payload-file D:\\temp\\se_input.json
```

```bash
python agent-observer/recorder/recorder.py write-event ^
  --run-id run-20260320-143501-001 ^
  --event-type agent.output ^
  --agent SE ^
  --title "SE 输出" ^
  --payload-file D:\\temp\\se_output.json
```

### 3. add-artifact

复制一份证据文件到 run 目录，并自动写入 `artifact.created` 事件。

```bash
python agent-observer/recorder/recorder.py add-artifact ^
  --run-id run-20260320-143501-001 ^
  --target-event-id evt-000003 ^
  --kind screenshot ^
  --title "失败截图" ^
  --agent CTest ^
  --source D:\\temp\\failure.png
```

### 4. finish-run

写入最终 run 事件，并更新 `summary.json`。

```bash
python agent-observer/recorder/recorder.py finish-run ^
  --run-id run-20260320-143501-001 ^
  --status completed ^
  --summary-text "主路径验证通过"
```

## 主 agent 的推荐调用顺序

```text
1. start-run
2. write-event(agent.input)
3. 调 subagent
4. write-event(agent.output)
5. 如有证据，add-artifact
6. 重复 2~5
7. finish-run
```

## 最小 schema 示例

### summary.json

```json
{
  "schemaVersion": "1.0",
  "runId": "run-20260320-143501-001",
  "title": "防火墙规则保存失败",
  "goal": "定位保存无响应并验证修复",
  "mode": "一般缺陷",
  "status": "in_progress",
  "createdAt": "2026-03-20T14:35:01+08:00",
  "updatedAt": "2026-03-20T14:35:01+08:00",
  "completedAt": null,
  "eventCount": 1,
  "artifactCount": 0,
  "agents": [
    "Main"
  ],
  "latestEventId": "evt-000001"
}
```

### events.jsonl

每行一个 JSON 对象，例如：

```json
{
  "schemaVersion": "1.0",
  "runId": "run-20260320-143501-001",
  "eventId": "evt-000002",
  "parentEventId": null,
  "timestamp": "2026-03-20T14:36:10+08:00",
  "agent": "SE",
  "agentTaskId": null,
  "eventType": "agent.input",
  "title": "SE 输入",
  "status": "completed",
  "payload": {
    "requestSummary": "定位保存失败原因并输出修改方案"
  },
  "artifacts": []
}
```

### artifact.created 的 payload

```json
{
  "artifactId": "art-000001",
  "kind": "screenshot",
  "title": "失败截图",
  "path": "artifacts/ctest/art-000001__failure.png",
  "sourcePath": "D:\\temp\\failure.png",
  "sourceAgent": "CTest",
  "targetEventId": "evt-000003",
  "createdAt": "2026-03-20T14:40:01+08:00"
}
```

## 说明

- `add-artifact` 会单独写一条 `artifact.created` 事件。
- 如果主 agent 想把 artifact 信息同时附在某条 `agent.output` 上，可以先调用 `add-artifact`，再把返回的 artifact 元数据写回后续 `write-event` 的 `artifacts` 字段。
- 当前实现是 V1 最小版本，默认按单进程、顺序调用设计，不处理并发写入。
