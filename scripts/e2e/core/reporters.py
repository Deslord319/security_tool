from __future__ import annotations

from pathlib import Path

from scripts.e2e.core.models import CaseResult, SuiteSummary
from scripts.e2e.reporters.json_reporter import write_case_json, write_suite_json
from scripts.e2e.reporters.markdown_reporter import write_suite_markdown


def write_case_result(output_dir: Path, case_result: CaseResult) -> Path:
    return write_case_json(output_dir, case_result)


def write_suite_summary(output_dir: Path, summary: SuiteSummary) -> tuple[Path, Path]:
    return write_suite_json(output_dir, summary), write_suite_markdown(output_dir, summary)
