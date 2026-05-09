from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any

from .adapter import AdapterConfig
from .contracts import ContractError, validate_case_contract, validate_result_contract
from .context import ExecutionContext
from .execution_backend import classify_execution_backend
from .failures import (
    ASSERTION_FAILED,
    ASSERTION_NOT_IMPLEMENTED,
    COMMAND_FAILED,
    FLOW_NOT_IMPLEMENTED,
    MCP_ACTION_PENDING,
    UNKNOWN_NOT_ALLOWED,
    UNSUPPORTED_STEP_TYPE,
)
from .models import CaseResult, FAIL, PASS, UNKNOWN, StepResult, SuiteSummary
from .normalizer import normalize_case_definition
from .registry import load_adapter, load_adapter_flow_executor, load_adapter_suite, list_adapter_suites
from .reporters import write_case_result, write_suite_summary
from .utils import format_command, resolve_placeholders, utc_now
from scripts.e2e.assertions.executor import AssertionExecutor
from scripts.e2e.drivers.hdc_driver import HdcDriver
from scripts.e2e.drivers.mcp_driver import McpDriver, MpcActionRequest


class RunnerError(RuntimeError):
    pass


DEFAULT_OUTPUT_DIR = "scripts/e2e/results"


def step_success(
    name: str,
    step_type: str,
    started_at: str,
    command: list[str] | None = None,
    result: Any | None = None,
    message: str | None = None,
    evidence: dict[str, Any] | None = None,
) -> StepResult:
    return StepResult(
        name=name,
        step_type=step_type,
        status=PASS,
        started_at=started_at,
        finished_at=utc_now(),
        failure_code="",
        command=format_command(command) if command else None,
        returncode=result.returncode if result is not None and hasattr(result, "returncode") else None,
        stdout=result.stdout.strip() if result is not None and hasattr(result, "stdout") else None,
        stderr=result.stderr.strip() if result is not None and hasattr(result, "stderr") else None,
        message=message,
        evidence=evidence or {},
    )


def step_failure(
    name: str,
    step_type: str,
    started_at: str,
    failure_code: str,
    command: list[str] | None = None,
    result: Any | None = None,
    message: str | None = None,
    evidence: dict[str, Any] | None = None,
) -> StepResult:
    return StepResult(
        name=name,
        step_type=step_type,
        status=FAIL,
        started_at=started_at,
        finished_at=utc_now(),
        failure_code=failure_code,
        command=format_command(command) if command else None,
        returncode=result.returncode if result is not None and hasattr(result, "returncode") else None,
        stdout=result.stdout.strip() if result is not None and hasattr(result, "stdout") else None,
        stderr=result.stderr.strip() if result is not None and hasattr(result, "stderr") else None,
        message=message,
        evidence=evidence or {},
    )


def step_unknown(
    name: str,
    step_type: str,
    started_at: str,
    failure_code: str,
    message: str,
    evidence: dict[str, Any] | None = None,
) -> StepResult:
    return StepResult(
        name=name,
        step_type=step_type,
        status=UNKNOWN,
        started_at=started_at,
        finished_at=utc_now(),
        failure_code=failure_code,
        message=message,
        evidence=evidence or {},
    )


class E2ERunner:
    def __init__(self, project_root: Path, output_dir: Path, adapter: AdapterConfig, device_id: str | None, dry_run: bool):
        self.adapter = adapter
        detected_device = device_id
        self.hdc = HdcDriver(project_root, device_id, dry_run)
        if not detected_device and not dry_run:
            detected_device = self.hdc.detect_single_device()
            self.hdc.device_id = detected_device
        self.mcp = McpDriver(project_root, dry_run)
        flow_executor_cls = load_adapter_flow_executor(adapter.adapter_name)
        self.assertion_executor = AssertionExecutor(self.hdc, self.mcp, dry_run)
        self.flow_executor = flow_executor_cls(
            self.hdc,
            self.mcp,
            dry_run,
            bundle_name=adapter.bundle_name,
            main_ability=adapter.main_ability,
        )
        self.context = ExecutionContext(
            project_root=project_root,
            output_dir=output_dir,
            adapter=adapter,
            device_id=detected_device,
            dry_run=dry_run,
        )
        self.context.output_dir.mkdir(parents=True, exist_ok=True)

    def run_case(self, case_path: Path) -> CaseResult:
        raw_case = json.loads(case_path.read_text(encoding="utf-8"))
        validate_case_contract(raw_case)
        case = normalize_case_definition(raw_case)
        started_at = utc_now()
        steps: list[StepResult] = []
        notes: list[str] = []
        status = PASS
        failure_code = ""
        failure_stage = ""
        primary_evidence: dict[str, Any] = {}
        secondary_evidence: list[dict[str, Any]] = []
        context = self.context.placeholder_map()

        for raw_step in case.get("execution_steps", []):
            step = resolve_placeholders(raw_step, context)
            result = self.run_step(step)
            steps.append(result)

            if result.status == FAIL:
                status = FAIL
                failure_code = result.failure_code
                failure_stage = step.get("name", "")
                primary_evidence = {
                    "type": "step_failure",
                    "step_name": step.get("name", ""),
                    "failure_code": result.failure_code,
                    "message": result.message or "",
                }
                if case["result_policy"].get("stop_on_failure", True):
                    break

            if result.status == UNKNOWN and status != FAIL:
                status = UNKNOWN
                failure_code = result.failure_code
                if not failure_stage:
                    failure_stage = step.get("name", "")
                if not primary_evidence:
                    primary_evidence = {
                        "type": "step_unknown",
                        "step_name": step.get("name", ""),
                        "failure_code": result.failure_code,
                        "message": result.message or "",
                    }

            if result.evidence:
                secondary_evidence.append({"step_name": step.get("name", ""), **result.evidence})

        if status == UNKNOWN and not case["result_policy"].get("allow_unknown", True):
            status = FAIL
            failure_code = UNKNOWN_NOT_ALLOWED
            if not primary_evidence:
                primary_evidence = {
                    "type": "result_policy",
                    "failure_code": UNKNOWN_NOT_ALLOWED,
                    "message": "Case produced UNKNOWN but result_policy does not allow UNKNOWN",
                }

        if status == PASS and not primary_evidence:
            primary_evidence = {
                "type": "step_success",
                "step_name": steps[-1].name if steps else "",
                "message": steps[-1].message if steps else "Case completed",
            }

        notes.extend(self.adapter.notes)
        notes.extend(case.get("notes", []))
        environment_snapshot = self.context.environment_snapshot(
            connected=bool(self.context.device_id) or self.context.dry_run,
        )

        case_result = CaseResult(
            case_id=case["case_id"],
            case_name=case["case_name"],
            module=case["module"],
            started_at=started_at,
            finished_at=utc_now(),
            status=status,
            failure_code=failure_code,
            failure_stage=failure_stage,
            primary_evidence=primary_evidence,
            secondary_evidence=secondary_evidence,
            steps=steps,
            notes=notes,
            result_policy=case["result_policy"],
            environment_snapshot=environment_snapshot,
        )
        validate_result_contract(case_result)
        return case_result

    def run_step(self, step: dict[str, Any]) -> StepResult:
        step_type = step["type"]
        name = step["name"]
        started_at = utc_now()

        if step_type == "hdc":
            command = self.hdc.command(step["args"])
            if self.context.dry_run:
                return step_success(name, step_type, started_at, command, message="Dry run: skipped execution")
            result = self.hdc.run(step["args"], step.get("timeout_sec", 20))
            if result.returncode != 0:
                return step_failure(name, step_type, started_at, COMMAND_FAILED, command, result, message="HDC command failed")
            return step_success(name, step_type, started_at, command, result)

        if step_type == "hdc_shell":
            command = self.hdc.command(["shell", step["command"]])
            if self.context.dry_run:
                return step_success(name, step_type, started_at, command, message="Dry run: skipped execution")
            result = self.hdc.shell(step["command"], step.get("timeout_sec", 20))
            if result.returncode != 0:
                return step_failure(name, step_type, started_at, COMMAND_FAILED, command, result, message="HDC shell command failed")
            return step_success(name, step_type, started_at, command, result)

        if step_type == "assert_hdc_shell_contains":
            command = self.hdc.command(["shell", step["command"]])
            if self.context.dry_run:
                return step_success(name, step_type, started_at, command, message=f"Dry run: assumed output contains {step['contains']}")
            result = self.hdc.shell(step["command"], step.get("timeout_sec", 20))
            if result.returncode != 0:
                return step_failure(name, step_type, started_at, COMMAND_FAILED, command, result, message="Assertion command failed")
            haystack = f"{result.stdout}\n{result.stderr}"
            if step["contains"] not in haystack:
                return step_failure(
                    name,
                    step_type,
                    started_at,
                    ASSERTION_FAILED,
                    command,
                    result,
                    message=f"Expected output to contain: {step['contains']}",
                )
            return step_success(name, step_type, started_at, command, result, message="Assertion passed")

        if step_type == "assert_hdc_shell_not_contains":
            command = self.hdc.command(["shell", step["command"]])
            if self.context.dry_run:
                return step_success(
                    name,
                    step_type,
                    started_at,
                    command,
                    message=f"Dry run: assumed output excludes {step['not_contains']}",
                )
            result = self.hdc.shell(step["command"], step.get("timeout_sec", 20))
            if result.returncode != 0:
                return step_failure(name, step_type, started_at, COMMAND_FAILED, command, result, message="Assertion command failed")
            haystack = f"{result.stdout}\n{result.stderr}"
            if step["not_contains"] in haystack:
                return step_failure(
                    name,
                    step_type,
                    started_at,
                    ASSERTION_FAILED,
                    command,
                    result,
                    message=f"Unexpected output matched: {step['not_contains']}",
                )
            return step_success(name, step_type, started_at, command, result, message="Assertion passed")

        if step_type == "sleep":
            if not self.context.dry_run:
                time.sleep(step.get("seconds", 1))
            return step_success(name, step_type, started_at, message=f"Slept {step.get('seconds', 1)} second(s)")

        if step_type == "mcp_action":
            request = MpcActionRequest(
                action=step.get("action", ""),
                params=step.get("params", {}),
                expected=step.get("expected", ""),
            )
            return step_unknown(
                name,
                step_type,
                started_at,
                MCP_ACTION_PENDING,
                message="Requires MCP/UI automation execution",
                evidence=self.mcp.describe(request),
            )

        if step_type == "flow_action":
            flow_ref = step.get("ref", "")
            execution = self.flow_executor.execute(flow_ref, step.get("params", {}))
            if execution.status == PASS:
                return step_success(
                    name,
                    step_type,
                    started_at,
                    execution.command,
                    execution.command_result,
                    execution.message,
                    execution.evidence,
                )
            if execution.status == FAIL:
                return step_failure(
                    name,
                    step_type,
                    started_at,
                    execution.failure_code or FLOW_NOT_IMPLEMENTED,
                    execution.command,
                    execution.command_result,
                    execution.message,
                    execution.evidence,
                )
            return step_unknown(
                name,
                step_type,
                started_at,
                execution.failure_code or FLOW_NOT_IMPLEMENTED,
                execution.message,
                execution.evidence,
            )

        if step_type == "assertion_action":
            execution = self.assertion_executor.execute(
                step.get("assertion_type", ""),
                step.get("value"),
                step.get("params", {}),
            )
            if execution.status == PASS:
                return step_success(
                    name,
                    step_type,
                    started_at,
                    execution.command,
                    execution.command_result,
                    execution.message,
                    execution.evidence,
                )
            if execution.status == FAIL:
                return step_failure(
                    name,
                    step_type,
                    started_at,
                    execution.failure_code or ASSERTION_NOT_IMPLEMENTED,
                    execution.command,
                    execution.command_result,
                    execution.message,
                    execution.evidence,
                )
            return step_unknown(
                name,
                step_type,
                started_at,
                execution.failure_code or ASSERTION_NOT_IMPLEMENTED,
                execution.message,
                execution.evidence,
            )

        if step_type == "note":
            return step_success(name, step_type, started_at, message=step.get("message", ""))

        raise RunnerError(f"{UNSUPPORTED_STEP_TYPE}: {step_type}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Cross-platform E2E runner for HarmonyOS device flows")
    parser.add_argument("--case", action="append", dest="cases", help="Path to a case JSON file. Can be repeated.")
    parser.add_argument("--suite", default=None, help="Logical suite name exposed by the adapter.")
    parser.add_argument("--cases-dir", default=None, help="Directory containing case JSON files.")
    parser.add_argument("--output-dir", default="scripts/e2e/results", help="Directory for result JSON files.")
    parser.add_argument("--device-id", default=None, help="Target HarmonyOS device id.")
    parser.add_argument("--bundle-name", default=None, help="Override adapter bundle name.")
    parser.add_argument("--adapter", default="security_tool", help="Project adapter to load.")
    parser.add_argument("--list-suites", action="store_true", help="List suites exposed by the selected adapter and exit.")
    parser.add_argument("--dry-run", action="store_true", help="Print logical flow without executing device commands.")
    return parser.parse_args()


def find_cases(project_root: Path, explicit_cases: list[str] | None, cases_dir: str) -> list[Path]:
    if explicit_cases:
        case_paths: list[Path] = []
        for case_path in explicit_cases:
            candidate = Path(case_path)
            case_paths.append(candidate if candidate.is_absolute() else project_root / candidate)
        return case_paths
    case_dir = project_root / cases_dir
    return sorted(
        path
        for path in case_dir.rglob("*.json")
        if "__pycache__" not in path.parts
    )


def find_suite_cases(project_root: Path, adapter_name: str, suite_name: str, cases_dir: str) -> list[Path]:
    case_dir = project_root / cases_dir
    return [case_dir / file_name for file_name in load_adapter_suite(adapter_name, suite_name)]


def validate_execution_backend(execution_backend: str, dry_run: bool) -> None:
    if dry_run:
        return
    if execution_backend != "real_bridge":
        raise RunnerError(
            "Real-device E2E requires HARMONYOS_E2E_MCP_BRIDGE=python scripts\\e2e\\bridges\\harmonyos_mcp_bridge.py "
            "and HARMONYOS_E2E_MCP_BACKEND_MODULE=scripts\\e2e\\bridges\\real_harmonyos_mcp_backend.py."
        )


def main() -> int:
    args = parse_args()
    project_root = Path(__file__).resolve().parents[3]
    if args.list_suites:
        for suite_name in list_adapter_suites(args.adapter):
            print(suite_name)
        return 0
    adapter = load_adapter(args.adapter)
    if args.bundle_name:
        adapter = AdapterConfig(
            project_id=adapter.project_id,
            adapter_name=adapter.adapter_name,
            adapter_version=adapter.adapter_version,
            bundle_name=args.bundle_name,
            mode=adapter.mode,
            main_ability=adapter.main_ability,
            admin_ability=adapter.admin_ability,
            cases_dir=adapter.cases_dir,
            page_registry_version=adapter.page_registry_version,
            notes=adapter.notes,
        )

    cases_dir = args.cases_dir or adapter.cases_dir
    if args.cases and args.suite:
        raise RunnerError("Use either --case or --suite, not both")
    case_paths = (
        find_suite_cases(project_root, args.adapter, args.suite, cases_dir)
        if args.suite
        else find_cases(project_root, args.cases, cases_dir)
    )
    if not case_paths:
        print("No case files found.", file=sys.stderr)
        return 1

    bridge_command = os.environ.get("HARMONYOS_E2E_MCP_BRIDGE", "").strip()
    bridge_backend_module = os.environ.get("HARMONYOS_E2E_MCP_BACKEND_MODULE", "").strip()
    execution_backend = classify_execution_backend(args.dry_run, bridge_command, bridge_backend_module)
    try:
        validate_execution_backend(execution_backend, args.dry_run)
    except RunnerError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    output_dir = project_root / args.output_dir

    runner = E2ERunner(
        project_root=project_root,
        output_dir=output_dir,
        adapter=adapter,
        device_id=args.device_id,
        dry_run=args.dry_run,
    )

    suite_started_at = utc_now()
    final_status = PASS
    pass_count = 0
    fail_count = 0
    unknown_count = 0
    result_files: list[str] = []

    for case_path in case_paths:
        try:
            case_result = runner.run_case(case_path)
        except ContractError as exc:
            print(f"[FAIL] {case_path.name} -> contract error: {exc}", file=sys.stderr)
            return 2
        result_path = write_case_result(output_dir, case_result)
        result_files.append(str(result_path.relative_to(project_root)))
        print(f"[{case_result.status}] {case_result.case_id} -> {result_path}")
        if case_result.status == FAIL:
            final_status = FAIL
            fail_count += 1
        elif case_result.status == UNKNOWN:
            if final_status != FAIL:
                final_status = UNKNOWN
            unknown_count += 1
        else:
            pass_count += 1

    summary = SuiteSummary(
        suite_name=args.suite or "all_cases",
        adapter_name=adapter.adapter_name,
        adapter_version=adapter.adapter_version,
        project_id=adapter.project_id,
        mode=adapter.mode,
        started_at=suite_started_at,
        finished_at=utc_now(),
        overall_status=final_status,
        total_cases=len(case_paths),
        pass_count=pass_count,
        fail_count=fail_count,
        unknown_count=unknown_count,
        execution_backend=execution_backend,
        bridge_command=bridge_command,
        bridge_backend_module=bridge_backend_module,
        result_files=result_files,
    )
    suite_json_path, suite_md_path = write_suite_summary(output_dir, summary)

    print(f"Suite JSON: {suite_json_path}")
    print(f"Suite Markdown: {suite_md_path}")
    print(f"Overall: {final_status}")
    return 0 if final_status != FAIL else 2
