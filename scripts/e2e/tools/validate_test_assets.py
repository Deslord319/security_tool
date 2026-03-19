from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.e2e.tools.test_asset_common import validate_test_assets


def main() -> int:
    report = validate_test_assets()
    print(f"Errors: {report['error_count']}")
    print(f"Warnings: {report['warning_count']}")
    return 0 if report["error_count"] == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
