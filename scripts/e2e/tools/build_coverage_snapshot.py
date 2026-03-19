from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.e2e.tools.test_asset_common import build_coverage_snapshot, load_catalog


def main() -> int:
    snapshot = build_coverage_snapshot(load_catalog())
    print(f"Coverage snapshot updated: total_cases={snapshot['total_cases']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
