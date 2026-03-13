from __future__ import annotations

import json
from dataclasses import asdict
from pathlib import Path

from scripts.e2e.core.models import CaseResult, SuiteSummary


def write_case_json(output_dir: Path, case_result: CaseResult) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{case_result.case_id}.json"
    output_path.write_text(json.dumps(asdict(case_result), ensure_ascii=False, indent=2), encoding="utf-8")
    return output_path


def write_suite_json(output_dir: Path, summary: SuiteSummary) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{summary.suite_name}_suite_summary.json"
    output_path.write_text(json.dumps(asdict(summary), ensure_ascii=False, indent=2), encoding="utf-8")
    return output_path
