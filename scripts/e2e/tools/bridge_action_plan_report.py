from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.e2e.bridges.action_plans import ACTION_PLANS


def write_markdown(project_root: Path) -> Path:
    target = project_root / "scripts/e2e/docs/BRIDGE_ACTION_PLANS.md"
    lines = [
        "# Bridge Action Plans",
        "",
        "This document lists the normalized UI actions expected by the HarmonyOS MCP bridge.",
        "",
    ]

    for action, plan in sorted(ACTION_PLANS.items()):
        lines.append(f"## `{action}`")
        lines.append("")
        lines.append(f"- Goal: {plan.get('goal', '')}")
        lines.append(f"- Required Params: {', '.join(plan.get('required_params', [])) or '(none)'}")
        lines.append(f"- Suggested MCP Tools: {', '.join(plan.get('mcp_tools', [])) or '(none)'}")
        lines.append("- Steps:")
        for step in plan.get("steps", []):
            lines.append(f"  - {step}")
        lines.append("")

    target.write_text("\n".join(lines), encoding="utf-8")
    return target


def main() -> int:
    project_root = Path(__file__).resolve().parents[3]
    target = write_markdown(project_root)
    print(target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
