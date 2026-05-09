from __future__ import annotations

import json
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.e2e.bridges.action_plans import ACTION_PLANS
from scripts.e2e.tools.test_asset_common import BRIDGE_MAP_PATH


def load_flow_registry(project_root: Path) -> dict:
    namespace: dict = {}
    registry_file = project_root / "scripts/e2e/adapters/security_tool/flows/registry.py"
    exec(registry_file.read_text(encoding="utf-8"), namespace)  # noqa: S102
    return namespace["FLOW_REGISTRY"]


def load_bridge_map(project_root: Path) -> dict[str, str]:
    return json.loads((project_root / BRIDGE_MAP_PATH.relative_to(PROJECT_ROOT)).read_text(encoding="utf-8"))


def build_rows(flow_registry: dict, bridge_map: dict[str, str]) -> list[dict]:
    rows: list[dict] = []
    for flow_ref, meta in sorted(flow_registry.items()):
        action = bridge_map.get(flow_ref, "")
        rows.append(
            {
                "flow_ref": flow_ref,
                "kind": meta.get("kind", ""),
                "bridge_action": action,
                "has_action_plan": "yes" if action in ACTION_PLANS else "no",
            }
        )
    return rows


def write_markdown(project_root: Path, rows: list[dict]) -> Path:
    target = project_root / "scripts/e2e/docs/BRIDGE_ACTION_COVERAGE.md"
    lines = [
        "# Bridge Action Coverage",
        "",
        "| Flow Ref | Kind | Bridge Action | Action Plan |",
        "| --- | --- | --- | --- |",
    ]
    for row in rows:
        lines.append(
            f"| `{row['flow_ref']}` | `{row['kind']}` | `{row['bridge_action'] or '-'}` | "
            f"`{row['has_action_plan']}` |"
        )
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return target


def main() -> int:
    project_root = Path(__file__).resolve().parents[3]
    flow_registry = load_flow_registry(project_root)
    bridge_map = load_bridge_map(project_root)
    rows = build_rows(flow_registry, bridge_map)
    target = write_markdown(project_root, rows)
    print(target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
