from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


PASS = "PASS"
FAIL = "FAIL"
UNKNOWN = "UNKNOWN"


@dataclass
class StepResult:
    name: str
    step_type: str
    status: str
    started_at: str
    finished_at: str
    failure_code: str = ""
    command: str | None = None
    returncode: int | None = None
    stdout: str | None = None
    stderr: str | None = None
    message: str | None = None
    evidence: dict[str, Any] = field(default_factory=dict)


@dataclass
class EnvironmentSnapshot:
    project_id: str
    adapter_name: str
    adapter_version: str
    bundle_name: str
    device_id: str | None
    mode: str
    connected: bool


@dataclass
class CaseResult:
    case_id: str
    case_name: str
    module: str
    started_at: str
    finished_at: str
    status: str
    failure_code: str = ""
    failure_stage: str = ""
    primary_evidence: dict[str, Any] = field(default_factory=dict)
    secondary_evidence: list[dict[str, Any]] = field(default_factory=list)
    steps: list[StepResult] = field(default_factory=list)
    artifacts: list[str] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)
    result_policy: dict[str, Any] = field(default_factory=dict)
    environment_snapshot: dict[str, Any] = field(default_factory=dict)


@dataclass
class SuiteSummary:
    suite_name: str
    adapter_name: str
    adapter_version: str
    project_id: str
    mode: str
    started_at: str
    finished_at: str
    overall_status: str
    total_cases: int
    pass_count: int
    fail_count: int
    unknown_count: int
    result_files: list[str] = field(default_factory=list)
