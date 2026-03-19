from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.e2e.tools.test_asset_common import import_excel_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Import Excel workbook rows into test asset catalog.")
    parser.add_argument("--file", required=True, help="Path to the .xlsx workbook to import.")
    args = parser.parse_args()

    result = import_excel_path(Path(args.file))
    print(f"Imported: {len(result.report['imported'])}")
    print(f"Conflicts: {len(result.report['conflicts'])}")
    print(f"Warnings: {len(result.report['warnings'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
