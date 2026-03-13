from __future__ import annotations

from copy import deepcopy
from typing import Any


DEFAULT_RESULT_POLICY = {
    "allow_unknown": True,
    "stop_on_failure": True,
}

DEFAULT_ARTIFACT_POLICY = {
    "on_failure_screenshot": True,
    "on_success_screenshot": False,
}


def normalize_case_definition(case: dict[str, Any]) -> dict[str, Any]:
    normalized = deepcopy(case)
    normalized.setdefault("preconditions", [])
    normalized.setdefault("flow", [])
    normalized.setdefault("assertions", [])
    normalized.setdefault("notes", [])

    result_policy = dict(DEFAULT_RESULT_POLICY)
    result_policy.update(normalized.get("result_policy", {}))
    normalized["result_policy"] = result_policy

    artifacts = dict(DEFAULT_ARTIFACT_POLICY)
    artifacts.update(normalized.get("artifacts", {}))
    normalized["artifacts"] = artifacts

    if normalized.get("steps"):
        normalized["execution_steps"] = normalized["steps"]
        normalized["compatibility_mode"] = "legacy_steps"
        return normalized

    execution_steps: list[dict[str, Any]] = []
    for flow_item in normalized.get("flow", []):
        execution_steps.append(
            {
                "name": flow_item.get("name") or flow_item.get("ref") or flow_item.get("action", "flow_action"),
                "type": "flow_action",
                "ref": flow_item.get("ref", flow_item.get("action", "")),
                "params": flow_item.get("params", {}),
            }
        )
    for assertion in normalized.get("assertions", []):
        execution_steps.append(
            {
                "name": assertion.get("name") or assertion.get("type", "assertion"),
                "type": "assertion_action",
                "assertion_type": assertion.get("type", ""),
                "value": assertion.get("value"),
                "level": assertion.get("level", "secondary"),
                "params": assertion.get("params", {}),
            }
        )
    normalized["execution_steps"] = execution_steps
    normalized["compatibility_mode"] = "declarative"
    return normalized
