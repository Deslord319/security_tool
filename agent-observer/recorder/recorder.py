from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any


SCHEMA_VERSION = "1.0"
SUMMARY_FILE_NAME = "summary.json"
EVENTS_FILE_NAME = "events.jsonl"
STEPS_FILE_NAME = "steps.jsonl"
REVIEWS_FILE_NAME = "reviews.jsonl"
RUNS_INDEX_FILE_NAME = "runs-index.json"
ARTIFACTS_DIR_NAME = "artifacts"


def now_iso() -> str:
    return datetime.now().astimezone().replace(microsecond=0).isoformat()


def print_json(data: Any) -> None:
    sys.stdout.write(json.dumps(data, ensure_ascii=False, indent=2))
    sys.stdout.write("\n")


def resolve_data_root(data_root: str | None) -> Path:
    if data_root:
        return Path(data_root).resolve()
    return (Path(__file__).resolve().parent.parent / "data" / "runs").resolve()


def observer_root_from_data_root(data_root: Path) -> Path:
    return data_root.parent.parent.resolve()


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def read_json(path: Path, default: Any = None) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: Any) -> None:
    ensure_dir(path.parent)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    rows: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        rows.append(json.loads(line))
    return rows


def write_jsonl(path: Path, rows: list[dict[str, Any]]) -> None:
    ensure_dir(path.parent)
    text = "\n".join(json.dumps(row, ensure_ascii=False) for row in rows)
    path.write_text((text + "\n") if text else "", encoding="utf-8")


def append_jsonl(path: Path, row: dict[str, Any]) -> None:
    ensure_dir(path.parent)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(row, ensure_ascii=False))
        handle.write("\n")


def load_json_file(path_value: str | None, default: Any) -> Any:
    if not path_value:
        return default
    return read_json(Path(path_value), default)


def list_run_dirs(data_root: Path) -> list[Path]:
    if not data_root.exists():
        return []
    return sorted(
        [path.parent for path in data_root.rglob(SUMMARY_FILE_NAME)],
        key=lambda item: str(item),
    )


def summary_path(run_dir: Path) -> Path:
    return run_dir / SUMMARY_FILE_NAME


def events_path(run_dir: Path) -> Path:
    return run_dir / EVENTS_FILE_NAME


def steps_path(run_dir: Path) -> Path:
    return run_dir / STEPS_FILE_NAME


def reviews_path(run_dir: Path) -> Path:
    return run_dir / REVIEWS_FILE_NAME


def artifacts_dir(run_dir: Path) -> Path:
    return run_dir / ARTIFACTS_DIR_NAME


def load_summary(run_dir: Path) -> dict[str, Any]:
    summary = read_json(summary_path(run_dir), {})
    summary.setdefault("schemaVersion", SCHEMA_VERSION)
    summary.setdefault("resultStatus", None)
    summary.setdefault("eventCount", 0)
    summary.setdefault("stepCount", 0)
    summary.setdefault("artifactCount", 0)
    summary.setdefault("agents", [])
    summary.setdefault("latestEventId", None)
    summary.setdefault("latestEventType", None)
    summary.setdefault("latestEventTitle", None)
    summary.setdefault("latestAgent", None)
    summary.setdefault("latestSummary", "")
    summary.setdefault("sequences", {"event": 0, "artifact": 0, "step": 0, "review": 0})
    summary.setdefault("taskKey", build_task_key(summary.get("title", ""), summary.get("goal", ""), summary.get("mode", ""), {}))
    return summary


def save_summary(run_dir: Path, summary: dict[str, Any]) -> None:
    write_json(summary_path(run_dir), summary)


def build_task_key(title: str, goal: str, mode: str, metadata: dict[str, Any]) -> str:
    payload = json.dumps({"title": title, "goal": goal, "mode": mode, "metadata": metadata}, ensure_ascii=False, sort_keys=True)
    digest = hashlib.sha1(payload.encode("utf-8")).hexdigest()[:12]
    return f"task-{digest}"


def build_group_key(summary: dict[str, Any]) -> str:
    return summary.get("taskKey") or build_task_key(summary.get("title", ""), summary.get("goal", ""), summary.get("mode", ""), {})


def next_sequence(summary: dict[str, Any], key: str) -> int:
    sequences = summary.setdefault("sequences", {"event": 0, "artifact": 0, "step": 0, "review": 0})
    value = int(sequences.get(key, 0)) + 1
    sequences[key] = value
    return value


def format_sequence(prefix: str, value: int) -> str:
    return f"{prefix}-{value:06d}"


def next_run_id(data_root: Path) -> str:
    now = datetime.now().astimezone()
    prefix = now.strftime("run-%Y%m%d-%H%M%S")
    date_dir = data_root / now.strftime("%Y-%m-%d")
    ensure_dir(date_dir)
    existing = {path.name for path in date_dir.iterdir() if path.is_dir()}
    counter = 1
    while True:
        candidate = f"{prefix}-{counter:03d}"
        if candidate not in existing:
            return candidate
        counter += 1


def relative_to_observer_root(path: Path, data_root: Path) -> str:
    return path.resolve().relative_to(observer_root_from_data_root(data_root)).as_posix()


def is_orphan_run(summary: dict[str, Any]) -> bool:
    return (
        summary.get("status") == "in_progress"
        and int(summary.get("stepCount", 0)) == 0
        and int(summary.get("artifactCount", 0)) == 0
        and int(summary.get("eventCount", 0)) <= 1
    )


def collect_review_stats(run_dir: Path) -> dict[str, int]:
    stats = {"valid": 0, "partial": 0, "invalid": 0}
    for review in read_jsonl(reviews_path(run_dir)):
        status = review.get("reviewStatus")
        if status in stats:
            stats[status] += 1
    return stats


def normalize_finish_status(status: str, result_status: str | None) -> tuple[str, str | None]:
    if status == "blocked":
        return "completed", "blocked"
    if status == "partial":
        return "completed", "partial"
    if status == "verified":
        return "completed", "verified"
    if status == "failed":
        return "failed", result_status or "failed"
    if status == "completed":
        return "completed", result_status or "verified"
    if status == "in_progress":
        return "in_progress", result_status
    raise ValueError(f"Unsupported finish status: {status}")


def build_run_entry(run_dir: Path, summary: dict[str, Any], data_root: Path) -> dict[str, Any]:
    return {
        "schemaVersion": SCHEMA_VERSION,
        "runId": summary["runId"],
        "taskKey": summary.get("taskKey"),
        "title": summary.get("title", ""),
        "goal": summary.get("goal", ""),
        "mode": summary.get("mode", ""),
        "status": summary.get("status", "in_progress"),
        "resultStatus": summary.get("resultStatus"),
        "createdAt": summary.get("createdAt"),
        "updatedAt": summary.get("updatedAt"),
        "completedAt": summary.get("completedAt"),
        "eventCount": int(summary.get("eventCount", 0)),
        "stepCount": int(summary.get("stepCount", 0)),
        "artifactCount": int(summary.get("artifactCount", 0)),
        "agents": summary.get("agents", []),
        "latestEventId": summary.get("latestEventId"),
        "latestEventType": summary.get("latestEventType"),
        "latestEventTitle": summary.get("latestEventTitle"),
        "latestAgent": summary.get("latestAgent"),
        "latestSummary": summary.get("latestSummary", ""),
        "reviewStats": collect_review_stats(run_dir),
        "runDir": relative_to_observer_root(run_dir, data_root),
        "summaryPath": relative_to_observer_root(summary_path(run_dir), data_root),
        "eventsPath": relative_to_observer_root(events_path(run_dir), data_root),
        "stepsPath": relative_to_observer_root(steps_path(run_dir), data_root),
        "reviewsPath": relative_to_observer_root(reviews_path(run_dir), data_root),
        "artifactsPath": relative_to_observer_root(artifacts_dir(run_dir), data_root),
    }


def rebuild_index(data_root: Path) -> dict[str, Any]:
    entries: list[dict[str, Any]] = []
    grouped: defaultdict[str, list[dict[str, Any]]] = defaultdict(list)
    for run_dir in list_run_dirs(data_root):
        summary = load_summary(run_dir)
        entries.append(build_run_entry(run_dir, summary, data_root))
    for entry in entries:
        grouped[entry.get("taskKey") or entry["runId"]].append(entry)

    visible_entries: list[dict[str, Any]] = []
    for group_entries in grouped.values():
        sorted_group = sorted(group_entries, key=lambda item: item.get("updatedAt") or "", reverse=True)
        for index, entry in enumerate(sorted_group):
            orphan = (
                entry["status"] == "in_progress"
                and entry["stepCount"] == 0
                and entry["artifactCount"] == 0
                and entry["eventCount"] <= 1
            )
            if orphan and len(sorted_group) > 1 and index > 0:
                continue
            visible_entries.append(entry)

    visible_entries.sort(key=lambda item: item.get("updatedAt") or "", reverse=True)
    index_data = {"schemaVersion": SCHEMA_VERSION, "generatedAt": now_iso(), "runs": visible_entries}
    write_json(observer_root_from_data_root(data_root) / "data" / RUNS_INDEX_FILE_NAME, index_data)
    return index_data


def find_run_dir(data_root: Path, run_id: str) -> Path:
    for run_dir in list_run_dirs(data_root):
        summary = read_json(summary_path(run_dir), {})
        if summary.get("runId") == run_id:
            return run_dir
    raise FileNotFoundError(f"Run not found: {run_id}")


def find_active_run(data_root: Path, task_key: str) -> tuple[Path, dict[str, Any]] | None:
    candidates: list[tuple[Path, dict[str, Any]]] = []
    for run_dir in list_run_dirs(data_root):
        summary = load_summary(run_dir)
        if summary.get("taskKey") == task_key and summary.get("status") == "in_progress":
            candidates.append((run_dir, summary))
    if not candidates:
        return None
    candidates.sort(key=lambda item: item[1].get("updatedAt") or "", reverse=True)
    return candidates[0]


def append_event(run_dir: Path, summary: dict[str, Any], *, agent: str, event_type: str, title: str, status: str, payload: dict[str, Any] | None = None, artifacts: list[dict[str, Any]] | None = None, parent_event_id: str | None = None, agent_task_id: str | None = None, timestamp: str | None = None) -> dict[str, Any]:
    event = {
        "schemaVersion": SCHEMA_VERSION,
        "runId": summary["runId"],
        "eventId": format_sequence("evt", next_sequence(summary, "event")),
        "parentEventId": parent_event_id,
        "timestamp": timestamp or now_iso(),
        "agent": agent,
        "agentTaskId": agent_task_id,
        "eventType": event_type,
        "title": title,
        "status": status,
        "payload": payload or {},
        "artifacts": artifacts or [],
    }
    append_jsonl(events_path(run_dir), event)
    summary["eventCount"] = int(summary.get("eventCount", 0)) + 1
    summary["updatedAt"] = event["timestamp"]
    summary["latestEventId"] = event["eventId"]
    summary["latestEventType"] = event_type
    summary["latestEventTitle"] = title
    summary["latestAgent"] = agent
    summary["latestSummary"] = (payload or {}).get("summaryText") or (payload or {}).get("outputSummary") or summary.get("latestSummary", "")
    if agent and agent not in summary.setdefault("agents", []):
        summary["agents"].append(agent)
    save_summary(run_dir, summary)
    return event


def validate_step_payload(step: dict[str, Any]) -> None:
    for field in ("runId", "agent", "title", "status", "input", "output", "artifacts"):
        if field not in step:
            raise ValueError(f"Step missing required field: {field}")
    if not isinstance(step["input"], dict) or not str(step["input"].get("summary", "")).strip():
        raise ValueError("Step input.summary is required")
    if not isinstance(step["output"], dict) or not str(step["output"].get("summary", "")).strip():
        raise ValueError("Step output.summary is required")
    if "keyPoints" not in step["output"] or not isinstance(step["output"].get("keyPoints"), list):
        raise ValueError("Step output.keyPoints must be a list")
    if "details" not in step["input"] or not isinstance(step["input"].get("details"), dict):
        raise ValueError("Step input.details must be an object")
    if "details" not in step["output"] or not isinstance(step["output"].get("details"), dict):
        raise ValueError("Step output.details must be an object")
    if not isinstance(step["artifacts"], list):
        raise ValueError("Step artifacts must be a list")


def append_step(run_dir: Path, summary: dict[str, Any], step: dict[str, Any]) -> dict[str, Any]:
    validate_step_payload(step)
    if not step.get("stepId"):
        step["stepId"] = format_sequence("step", next_sequence(summary, "step"))
    if not step.get("startedAt"):
        step["startedAt"] = now_iso()
    if not step.get("finishedAt"):
        step["finishedAt"] = step["startedAt"]
    append_jsonl(steps_path(run_dir), step)
    summary["stepCount"] = int(summary.get("stepCount", 0)) + 1
    summary["updatedAt"] = step["finishedAt"]
    summary["latestAgent"] = step["agent"]
    summary["latestSummary"] = step["output"]["summary"]
    summary["latestStepId"] = step["stepId"]
    summary["latestStepTitle"] = step["title"]
    if step["agent"] not in summary.setdefault("agents", []):
        summary["agents"].append(step["agent"])
    save_summary(run_dir, summary)
    return step


def extract_step_artifacts(target_event_id: str | None, all_events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    if not target_event_id:
        return []
    artifacts: list[dict[str, Any]] = []
    for event in all_events:
        if event.get("eventType") != "artifact.created":
            continue
        payload = event.get("payload") or {}
        if payload.get("targetEventId") == target_event_id:
            artifacts.append(
                {
                    "artifactId": payload.get("artifactId"),
                    "type": payload.get("kind") or "artifact",
                    "title": payload.get("title") or event.get("title"),
                    "path": payload.get("path"),
                }
            )
    return artifacts


def payload_without_display_fields(payload: dict[str, Any]) -> dict[str, Any]:
    return {
        key: value
        for key, value in payload.items()
        if key not in {"inputSummary", "outputSummary", "keyPoints", "reviewStatus", "details"}
    }


def derive_input_summary_from_stage(event: dict[str, Any], payload: dict[str, Any]) -> str:
    role = payload.get("role") or event.get("agent") or "Main"
    stage = payload.get("stage") or event.get("eventType")
    target = payload.get("targetPage") or payload.get("verificationTarget")
    parts = [f"角色 {role}", f"阶段 {stage}"]
    if target:
        parts.append(f"目标 {target}")
    return "；".join(parts)


def string_value(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return "；".join(string_value(item) for item in value)
    if isinstance(value, dict):
        return json.dumps(value, ensure_ascii=False)
    return str(value)


def derive_output_summary_from_stage(event: dict[str, Any], payload: dict[str, Any]) -> str:
    raw = (
        payload.get("outputSummary")
        or payload.get("summaryText")
        or payload.get("conclusion")
        or payload.get("summary")
        or event.get("title")
        or "阶段已完成"
    )
    return string_value(raw)


def derive_key_points(payload: dict[str, Any]) -> list[str]:
    key_points = payload.get("keyPoints")
    if isinstance(key_points, list) and key_points:
        return [str(item) for item in key_points if str(item).strip()]
    derived: list[str] = []
    if isinstance(payload.get("mustChange"), list):
        derived.extend(str(item) for item in payload["mustChange"][:3])
    if isinstance(payload.get("changes"), list):
        derived.extend(str(item) for item in payload["changes"][:3])
    if isinstance(payload.get("currentOrder"), list):
        derived.append("当前顺序：" + " -> ".join(str(item) for item in payload["currentOrder"]))
    if isinstance(payload.get("targetOrder"), list):
        derived.append("目标顺序：" + " -> ".join(str(item) for item in payload["targetOrder"]))
    if payload.get("result"):
        derived.append(f"结果：{payload['result']}")
    return derived[:5]


def extract_detail_map(payload: dict[str, Any]) -> dict[str, Any]:
    details = payload.get("details") if isinstance(payload.get("details"), dict) else {}
    extras = payload_without_display_fields(payload)
    merged = dict(details)
    merged.update(extras)
    return merged


def migrate_steps_for_run(run_dir: Path) -> int:
    summary = load_summary(run_dir)
    events = read_jsonl(events_path(run_dir))
    if not events:
        write_jsonl(steps_path(run_dir), [])
        summary["stepCount"] = 0
        save_summary(run_dir, summary)
        return 0

    steps: list[dict[str, Any]] = []
    agent_output_events = [event for event in events if event.get("eventType") == "agent.output"]

    if agent_output_events:
        latest_input_by_agent: dict[str, dict[str, Any]] = {}
        dedupe_keys: dict[tuple[str, str, str], int] = {}
        for event in events:
            event_type = event.get("eventType")
            agent = event.get("agent") or "Main"
            payload = event.get("payload") or {}
            if event_type == "agent.input":
                latest_input_by_agent[agent] = event
                continue
            if event_type != "agent.output":
                continue
            input_event = latest_input_by_agent.get(agent)
            output_summary = payload.get("outputSummary") or event.get("title") or "阶段输出"
            dedupe_key = (agent, event.get("title") or "", output_summary)
            step = {
                "stepId": None,
                "runId": summary["runId"],
                "agent": agent,
                "title": event.get("title") or f"{agent} 输出",
                "status": event.get("status") or "completed",
                "startedAt": (input_event or event).get("timestamp"),
                "finishedAt": event.get("timestamp"),
                "input": {
                    "summary": ((input_event or {}).get("payload") or {}).get("inputSummary") or (input_event or {}).get("title") or f"{agent} 阶段输入",
                    "details": extract_detail_map(((input_event or {}).get("payload") or {})),
                },
                "output": {
                    "summary": string_value(output_summary),
                    "keyPoints": derive_key_points(payload),
                    "details": extract_detail_map(payload) | {"sourceEventId": event["eventId"]},
                },
                "artifacts": extract_step_artifacts(event["eventId"], events),
            }
            if dedupe_key in dedupe_keys:
                steps[dedupe_keys[dedupe_key]] = step
            else:
                dedupe_keys[dedupe_key] = len(steps)
                steps.append(step)
    else:
        stage_candidates: dict[tuple[str, str], dict[str, Any]] = {}
        stage_priority = {
            "verification.stage.completed": 40,
            "workflow.stage.completed": 30,
            "workflow.stage.approved": 20,
        }
        for event in events:
            event_type = event.get("eventType")
            if event_type not in stage_priority:
                continue
            payload = event.get("payload") or {}
            role = payload.get("role") or event.get("agent") or "Main"
            raw_stage = payload.get("stage") or event_type
            stage = {"fix": "implementation", "implementation": "implementation"}.get(raw_stage, raw_stage)
            key = (role, stage)
            previous = stage_candidates.get(key)
            previous_score = -1
            if previous:
                previous_score = stage_priority.get(previous.get("eventType"), 0) * 100 + len(json.dumps(previous.get("payload") or {}, ensure_ascii=False))
            current_score = stage_priority.get(event_type, 0) * 100 + len(json.dumps(payload, ensure_ascii=False))
            if current_score >= previous_score:
                stage_candidates[key] = event

        for _, event in sorted(stage_candidates.items(), key=lambda item: item[1].get("timestamp") or ""):
            payload = event.get("payload") or {}
            role = payload.get("role") or event.get("agent") or "Main"
            steps.append(
                {
                    "stepId": None,
                    "runId": summary["runId"],
                    "agent": role,
                    "title": event.get("title") or f"{role} 阶段输出",
                    "status": event.get("status") or "completed",
                    "startedAt": event.get("timestamp"),
                    "finishedAt": event.get("timestamp"),
                    "input": {
                        "summary": derive_input_summary_from_stage(event, payload),
                        "details": {
                            key: value
                            for key, value in payload.items()
                            if key in {"stage", "role", "targetPage", "verificationTarget", "targetFile", "targetOrder", "actualOrder"}
                        },
                    },
                    "output": {
                        "summary": derive_output_summary_from_stage(event, payload),
                        "keyPoints": derive_key_points(payload),
                        "details": extract_detail_map(payload) | {"sourceEventId": event["eventId"]},
                    },
                    "artifacts": extract_step_artifacts(event["eventId"], events),
                }
            )

    for index, step in enumerate(steps, start=1):
        step["stepId"] = f"step-{index:06d}"

    write_jsonl(steps_path(run_dir), steps)
    summary["stepCount"] = len(steps)
    summary.setdefault("sequences", {}).update({"step": len(steps)})
    if steps:
        latest_step = steps[-1]
        summary["latestAgent"] = latest_step["agent"]
        summary["latestSummary"] = latest_step["output"]["summary"]
        summary["latestStepId"] = latest_step["stepId"]
        summary["latestStepTitle"] = latest_step["title"]
        summary["updatedAt"] = latest_step["finishedAt"]
    save_summary(run_dir, summary)
    return len(steps)


def command_start_run(args: argparse.Namespace) -> int:
    data_root = resolve_data_root(args.data_root)
    ensure_dir(data_root)
    metadata = load_json_file(args.metadata_file, {})
    task_key = args.task_key or build_task_key(args.title, args.goal, args.mode, metadata)
    if not args.force_new:
        existing = find_active_run(data_root, task_key)
        if existing:
            run_dir, summary = existing
            print_json(
                {
                    "runId": summary["runId"],
                    "taskKey": summary["taskKey"],
                    "runDir": str(run_dir),
                    "summaryPath": str(summary_path(run_dir)),
                    "eventsPath": str(events_path(run_dir)),
                    "stepsPath": str(steps_path(run_dir)),
                    "status": summary["status"],
                    "reused": True,
                }
            )
            return 0

    run_id = next_run_id(data_root)
    now = datetime.now().astimezone()
    run_dir = data_root / now.strftime("%Y-%m-%d") / run_id
    ensure_dir(run_dir)
    ensure_dir(artifacts_dir(run_dir))
    events_path(run_dir).write_text("", encoding="utf-8")
    steps_path(run_dir).write_text("", encoding="utf-8")
    reviews_path(run_dir).write_text("", encoding="utf-8")

    summary = {
        "schemaVersion": SCHEMA_VERSION,
        "runId": run_id,
        "taskKey": task_key,
        "title": args.title,
        "goal": args.goal,
        "mode": args.mode,
        "status": "in_progress",
        "resultStatus": None,
        "createdAt": now_iso(),
        "updatedAt": now_iso(),
        "completedAt": None,
        "eventCount": 0,
        "stepCount": 0,
        "artifactCount": 0,
        "agents": [],
        "latestEventId": None,
        "latestEventType": None,
        "latestEventTitle": None,
        "latestAgent": None,
        "latestSummary": "",
        "sequences": {"event": 0, "artifact": 0, "step": 0, "review": 0},
    }
    save_summary(run_dir, summary)
    started_event = append_event(
        run_dir,
        summary,
        agent="Main",
        event_type="run.started",
        title=args.title,
        status="completed",
        payload={"goal": args.goal, "mode": args.mode, "metadata": metadata},
    )
    rebuild_index(data_root)
    print_json(
        {
            "runId": run_id,
            "taskKey": task_key,
            "runDir": str(run_dir),
            "summaryPath": str(summary_path(run_dir)),
            "eventsPath": str(events_path(run_dir)),
            "stepsPath": str(steps_path(run_dir)),
            "reviewsPath": str(reviews_path(run_dir)),
            "startedEventId": started_event["eventId"],
            "status": "in_progress",
            "reused": False,
        }
    )
    return 0


def command_write_step(args: argparse.Namespace) -> int:
    data_root = resolve_data_root(args.data_root)
    run_dir = find_run_dir(data_root, args.run_id)
    summary = load_summary(run_dir)
    step = {
        "stepId": args.step_id,
        "runId": args.run_id,
        "agent": args.agent,
        "title": args.title,
        "status": args.status,
        "startedAt": args.started_at,
        "finishedAt": args.finished_at,
        "input": load_json_file(args.input_file, {}),
        "output": load_json_file(args.output_file, {}),
        "artifacts": load_json_file(args.artifacts_file, []),
    }
    saved_step = append_step(run_dir, summary, step)
    rebuild_index(data_root)
    print_json(saved_step)
    return 0


def command_write_event(args: argparse.Namespace) -> int:
    data_root = resolve_data_root(args.data_root)
    run_dir = find_run_dir(data_root, args.run_id)
    summary = load_summary(run_dir)
    payload = load_json_file(args.payload_file, {})
    artifacts = load_json_file(args.artifacts_file, [])
    event = append_event(
        run_dir,
        summary,
        agent=args.agent or "Main",
        event_type=args.event_type,
        title=args.title,
        status=args.status,
        payload=payload,
        artifacts=artifacts,
        parent_event_id=args.parent_event_id,
        agent_task_id=args.agent_task_id,
    )
    rebuild_index(data_root)
    print_json(event)
    return 0


def command_add_artifact(args: argparse.Namespace) -> int:
    data_root = resolve_data_root(args.data_root)
    run_dir = find_run_dir(data_root, args.run_id)
    summary = load_summary(run_dir)
    source = Path(args.source).resolve()
    if not source.exists():
        raise FileNotFoundError(f"Artifact source not found: {source}")

    artifact_id = format_sequence("art", next_sequence(summary, "artifact"))
    ext = source.suffix
    subdir = artifacts_dir(run_dir) / args.agent.lower()
    ensure_dir(subdir)
    target_name = f"{artifact_id}__{source.stem}{ext}"
    target = subdir / target_name
    shutil.copy2(source, target)

    artifact_payload = {
        "artifactId": artifact_id,
        "kind": args.kind,
        "title": args.title,
        "path": target.relative_to(run_dir).as_posix(),
        "sourcePath": str(source),
        "sourceAgent": args.agent,
        "targetEventId": args.target_event_id,
        "targetStepId": args.target_step_id,
        "createdAt": now_iso(),
    }
    summary["artifactCount"] = int(summary.get("artifactCount", 0)) + 1
    event = append_event(
        run_dir,
        summary,
        agent=args.agent,
        event_type="artifact.created",
        title=args.title,
        status="completed",
        payload=artifact_payload,
        artifacts=[artifact_payload],
        parent_event_id=args.target_event_id,
    )
    rebuild_index(data_root)
    print_json({"artifact": artifact_payload, "eventId": event["eventId"]})
    return 0


def command_write_review(args: argparse.Namespace) -> int:
    data_root = resolve_data_root(args.data_root)
    run_dir = find_run_dir(data_root, args.run_id)
    summary = load_summary(run_dir)
    review = {
        "schemaVersion": SCHEMA_VERSION,
        "runId": args.run_id,
        "reviewId": format_sequence("rev", next_sequence(summary, "review")),
        "targetEventId": args.target_event_id,
        "targetStepId": args.target_step_id,
        "reviewStatus": args.review_status,
        "comment": args.comment or "",
        "reviewedBy": args.reviewed_by or "user",
        "reviewedAt": now_iso(),
    }
    append_jsonl(reviews_path(run_dir), review)
    summary["updatedAt"] = review["reviewedAt"]
    save_summary(run_dir, summary)
    rebuild_index(data_root)
    print_json(review)
    return 0


def command_finish_run(args: argparse.Namespace) -> int:
    data_root = resolve_data_root(args.data_root)
    run_dir = find_run_dir(data_root, args.run_id)
    summary = load_summary(run_dir)
    lifecycle_status, result_status = normalize_finish_status(args.status, args.result_status)
    finished_at = now_iso()
    summary["status"] = lifecycle_status
    summary["resultStatus"] = result_status
    summary["updatedAt"] = finished_at
    summary["completedAt"] = finished_at if lifecycle_status in {"completed", "failed"} else None
    payload = {"summaryText": args.summary_text or "", "resultStatus": result_status}
    event_type = "run.failed" if lifecycle_status == "failed" else "run.completed"
    event = append_event(
        run_dir,
        summary,
        agent="Main",
        event_type=event_type,
        title="Run completed" if lifecycle_status != "failed" else "Run failed",
        status="completed" if lifecycle_status != "failed" else "failed",
        payload=payload,
        timestamp=finished_at,
    )
    if int(summary.get("stepCount", 0)) == 0:
        migrate_steps_for_run(run_dir)
    rebuild_index(data_root)
    print_json({"runId": args.run_id, "status": lifecycle_status, "resultStatus": result_status, "eventId": event["eventId"]})
    return 0


def command_rebuild_index(args: argparse.Namespace) -> int:
    data_root = resolve_data_root(args.data_root)
    index_data = rebuild_index(data_root)
    print_json(index_data)
    return 0


def command_migrate_legacy_runs(args: argparse.Namespace) -> int:
    data_root = resolve_data_root(args.data_root)
    migrated: list[dict[str, Any]] = []
    for run_dir in list_run_dirs(data_root):
        summary = load_summary(run_dir)
        current_status = summary.get("status", "in_progress")
        current_result = summary.get("resultStatus")
        if current_status in {"blocked", "partial", "verified"}:
            normalized_status, normalized_result = normalize_finish_status(current_status, current_result)
            summary["status"] = normalized_status
            summary["resultStatus"] = normalized_result
        elif current_status == "completed" and not current_result:
            events = read_jsonl(events_path(run_dir))
            terminal = next((event for event in reversed(events) if event.get("eventType") in {"run.completed", "run.failed"}), None)
            summary["resultStatus"] = ((terminal or {}).get("payload") or {}).get("resultStatus") or "verified"
        if not steps_path(run_dir).exists() or args.force:
            step_count = migrate_steps_for_run(run_dir)
        else:
            step_count = len(read_jsonl(steps_path(run_dir)))
            summary["stepCount"] = step_count
            save_summary(run_dir, summary)
        migrated.append(
            {
                "runId": summary["runId"],
                "status": summary.get("status"),
                "resultStatus": summary.get("resultStatus"),
                "stepCount": step_count,
            }
        )
    index_data = rebuild_index(data_root)
    print_json({"migrated": migrated, "indexCount": len(index_data["runs"])})
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Agent Observer recorder CLI")
    parser.add_argument("--data-root", dest="data_root")
    subparsers = parser.add_subparsers(dest="command", required=True)

    start_run = subparsers.add_parser("start-run")
    start_run.add_argument("--title", required=True)
    start_run.add_argument("--goal", required=True)
    start_run.add_argument("--mode", required=True)
    start_run.add_argument("--task-key")
    start_run.add_argument("--metadata-file")
    start_run.add_argument("--force-new", action="store_true")
    start_run.set_defaults(func=command_start_run)

    write_step = subparsers.add_parser("write-step")
    write_step.add_argument("--run-id", required=True)
    write_step.add_argument("--agent", required=True)
    write_step.add_argument("--title", required=True)
    write_step.add_argument("--status", required=True)
    write_step.add_argument("--input-file", required=True)
    write_step.add_argument("--output-file", required=True)
    write_step.add_argument("--artifacts-file")
    write_step.add_argument("--step-id")
    write_step.add_argument("--started-at")
    write_step.add_argument("--finished-at")
    write_step.set_defaults(func=command_write_step)

    write_event = subparsers.add_parser("write-event")
    write_event.add_argument("--run-id", required=True)
    write_event.add_argument("--event-type", required=True)
    write_event.add_argument("--agent")
    write_event.add_argument("--title", required=True)
    write_event.add_argument("--status", default="completed")
    write_event.add_argument("--payload-file")
    write_event.add_argument("--artifacts-file")
    write_event.add_argument("--parent-event-id")
    write_event.add_argument("--agent-task-id")
    write_event.set_defaults(func=command_write_event)

    add_artifact = subparsers.add_parser("add-artifact")
    add_artifact.add_argument("--run-id", required=True)
    add_artifact.add_argument("--target-event-id")
    add_artifact.add_argument("--target-step-id")
    add_artifact.add_argument("--kind", required=True)
    add_artifact.add_argument("--title", required=True)
    add_artifact.add_argument("--agent", required=True)
    add_artifact.add_argument("--source", required=True)
    add_artifact.set_defaults(func=command_add_artifact)

    write_review = subparsers.add_parser("write-review")
    write_review.add_argument("--run-id", required=True)
    write_review.add_argument("--review-status", required=True)
    write_review.add_argument("--target-event-id")
    write_review.add_argument("--target-step-id")
    write_review.add_argument("--comment")
    write_review.add_argument("--reviewed-by")
    write_review.set_defaults(func=command_write_review)

    finish_run = subparsers.add_parser("finish-run")
    finish_run.add_argument("--run-id", required=True)
    finish_run.add_argument("--status", required=True)
    finish_run.add_argument("--result-status")
    finish_run.add_argument("--summary-text")
    finish_run.set_defaults(func=command_finish_run)

    rebuild = subparsers.add_parser("rebuild-index")
    rebuild.set_defaults(func=command_rebuild_index)

    migrate = subparsers.add_parser("migrate-legacy-runs")
    migrate.add_argument("--force", action="store_true")
    migrate.set_defaults(func=command_migrate_legacy_runs)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.func(args))
    except Exception as exc:  # noqa: BLE001
        sys.stderr.write(f"[recorder] {exc}\n")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
