from __future__ import annotations

from dataclasses import asdict
from typing import Any

from .models import CaseResult, FAIL, PASS, UNKNOWN


class ContractError(ValueError):
    pass


def validate_case_contract(case: dict[str, Any]) -> None:
    required = ["case_id", "case_name", "module"]
    missing = [field for field in required if not case.get(field)]
    if missing:
        raise ContractError(f"Case is missing required fields: {', '.join(missing)}")

    if "steps" in case:
        raise ContractError("Case field 'steps' is no longer supported; use 'flow' and 'assertions'")
    if "flow" in case and not isinstance(case["flow"], list):
        raise ContractError("Case field 'flow' must be a list when present")
    if "assertions" in case and not isinstance(case["assertions"], list):
        raise ContractError("Case field 'assertions' must be a list when present")
    if "result_policy" in case and not isinstance(case["result_policy"], dict):
        raise ContractError("Case field 'result_policy' must be an object when present")


def validate_result_contract(case_result: CaseResult) -> None:
    payload = asdict(case_result)
    required = ["case_id", "case_name", "module", "started_at", "finished_at", "status", "steps", "environment_snapshot"]
    missing = [field for field in required if payload.get(field) in (None, "")]
    if missing:
        raise ContractError(f"Result is missing required fields: {', '.join(missing)}")

    if payload["status"] not in {PASS, FAIL, UNKNOWN}:
        raise ContractError(f"Invalid result status: {payload['status']}")
    if "result_policy" not in payload or not isinstance(payload["result_policy"], dict):
        raise ContractError("Result is missing a valid result_policy object")

    snapshot = payload["environment_snapshot"]
    for field in ["project_id", "adapter_name", "adapter_version", "bundle_name", "mode", "connected"]:
        if field not in snapshot:
            raise ContractError(f"Environment snapshot is missing field: {field}")
