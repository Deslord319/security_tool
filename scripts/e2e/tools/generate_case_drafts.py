from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.e2e.tools.test_asset_common import generate_case_drafts


def main() -> int:
    report = generate_case_drafts()
    print(f"Generated drafts: {len(report['generated'])}")
    print(f"Skipped: {len(report['skipped'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
