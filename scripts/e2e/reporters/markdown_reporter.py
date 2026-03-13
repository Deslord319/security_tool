from __future__ import annotations

import json
from pathlib import Path

from scripts.e2e.core.models import SuiteSummary


def write_suite_markdown(output_dir: Path, summary: SuiteSummary) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{summary.suite_name}_suite_summary.md"
    result_lines: list[str] = []
    for path in summary.result_files:
        result_file = Path(path)
        if not result_file.is_absolute():
            result_file = output_dir.parents[3] / path
        if result_file.exists():
            payload = json.loads(result_file.read_text(encoding="utf-8"))
            result_lines.append(
                f"| `{payload.get('case_id', '')}` | `{payload.get('module', '')}` | "
                f"`{payload.get('status', '')}` | `{payload.get('failure_code', '')}` | "
                f"{payload.get('failure_stage', '') or '-'} |"
            )
    output_path.write_text(
        "\n".join(
            [
                "# Suite Summary",
                "",
                f"- Suite: `{summary.suite_name}`",
                f"- Adapter: `{summary.adapter_name}` `{summary.adapter_version}`",
                f"- Project: `{summary.project_id}`",
                f"- Mode: `{summary.mode}`",
                f"- Overall: `{summary.overall_status}`",
                f"- Total: `{summary.total_cases}`",
                f"- PASS: `{summary.pass_count}`",
                f"- FAIL: `{summary.fail_count}`",
                f"- UNKNOWN: `{summary.unknown_count}`",
                "",
                "## Case Status",
                "",
                "| Case | Module | Status | Failure Code | Failure Stage |",
                "| --- | --- | --- | --- | --- |",
                *result_lines,
                "",
                "## Results",
                *[f"- `{path}`" for path in summary.result_files],
            ]
        ),
        encoding="utf-8",
    )
    return output_path
