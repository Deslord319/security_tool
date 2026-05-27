from __future__ import annotations

import re
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]

ROUTE_DOCS = {
    "dashboard": "docs/03-模块设计/安全总览组件设计说明.md",
    "firewall": "docs/03-模块设计/防火墙管理组件设计说明.md",
    "firewall-rules": "docs/03-模块设计/防火墙管理组件设计说明.md",
    "log-manage": "docs/03-模块设计/日志管理组件设计说明.md",
    "peripheral-manage": "docs/03-模块设计/外设管理组件设计说明.md",
    "identity": "docs/03-模块设计/身份鉴别组件设计说明.md",
    "tool-settings": "docs/03-模块设计/工具设置组件设计说明.md",
    "help-feedback": "docs/03-模块设计/帮助与反馈组件设计说明.md",
}

MODULE_DOCS = sorted(set(ROUTE_DOCS.values()))

TEST_PATHS = {
    "dashboard": {
        "unit": ["entry/src/test/dashboard"],
        "ohosTest": ["entry/src/ohosTest/ets/test/simple/RouteAction.test.ets"],
        "e2e": ["scripts/e2e/cases/dashboard"],
    },
    "firewall": {
        "unit": ["entry/src/test/firewall"],
        "ohosTest": [
            "entry/src/ohosTest/ets/test/firewall/subroute-state.test.ets",
            "entry/src/ohosTest/ets/test/simple/RouteAction.test.ets",
        ],
        "e2e": ["scripts/e2e/cases/firewall"],
    },
    "log-manage": {
        "unit": ["entry/src/test/log-manage"],
        "ohosTest": ["entry/src/ohosTest/ets/test/simple/RouteAction.test.ets"],
        "e2e": ["scripts/e2e/cases/logs"],
    },
    "peripheral-manage": {
        "unit": ["entry/src/test/peripheral"],
        "ohosTest": [
            "entry/src/ohosTest/ets/test/peripheral/connection-record-contract.test.ets",
            "entry/src/ohosTest/ets/test/simple/RouteAction.test.ets",
        ],
        "e2e": ["scripts/e2e/cases/peripheral"],
    },
    "identity": {
        "unit": ["entry/src/test/identity"],
        "ohosTest": ["entry/src/ohosTest/ets/test/simple/RouteAction.test.ets"],
        "e2e": ["scripts/e2e/cases/identity"],
    },
    "tool-settings": {
        "unit": ["entry/src/test/tool-settings"],
        "ohosTest": ["entry/src/ohosTest/ets/test/simple/RouteAction.test.ets"],
        "e2e": ["scripts/e2e/cases/tool_settings"],
    },
    "help-feedback": {
        "unit": ["entry/src/test/help"],
        "ohosTest": [
            "entry/src/ohosTest/ets/test/simple/RouteAction.test.ets",
            "entry/src/ohosTest/ets/test/theme/theme-menu-popup.test.ets",
        ],
        "e2e": ["scripts/e2e/cases/navigation"],
    },
}

REFERENCE_DOCS = [
    "AGENTS.md",
    "README.md",
    "docs/02-总体设计/PRD.md",
    "docs/02-总体设计/总体设计RFC.md",
]

REQUIRED_MODULE_HEADING_PATTERNS = [
    r"^## 0\. 文档契约",
    r"^## 1\. 业务概述",
    r"^## 2\. 状态与数据流",
    r"^## 3\. 核心功能场景",
    r"^## 4\. 模块结构",
    r"^## 5\. 异常处理",
    r"^### 5\.1 实施步骤与测试验收",
    r"^## 6\. 变更日志",
]

CHECK_SCRIPT_PATH = "scripts/check_docs_consistency.py"
AI_PLAYBOOK_PATH = "docs/05-AI开发/AI常见任务手册.md"


def read_text(path: str) -> str:
    return (PROJECT_ROOT / path).read_text(encoding="utf-8")


def add_error(errors: list[str], message: str) -> None:
    errors.append(f"[ERROR] {message}")


def add_warning(warnings: list[str], message: str) -> None:
    warnings.append(f"[WARN] {message}")


def extract_route_ids() -> set[str]:
    text = read_text("entry/src/main/ets/constants/RouteIds.ets")
    return set(re.findall(r"static\s+readonly\s+\w+\s*=\s*'([^']+)'", text))


def extract_module_permissions() -> set[str]:
    text = read_text("entry/src/main/module.json5")
    permissions = set()
    for permission in re.findall(r'["\']?name["\']?\s*:\s*"([^"]+)"', text):
        if permission.startswith("ohos.permission."):
            permissions.add(permission)
    return permissions


def extract_hapsigner_permissions() -> set[str]:
    text = read_text("hapsigner/UnsgnedDebugProfileTemplate.json")
    return set(re.findall(r'"(ohos\.permission\.[^"]+)"', text))


def extract_agents_permissions() -> set[str]:
    text = read_text("AGENTS.md")
    match = re.search(r"## 当前权限列表\s*```(?:\w+)?\s*(.*?)```", text, flags=re.S)
    if not match:
        return set()
    return set(line.strip() for line in match.group(1).splitlines() if line.strip())


def extract_bundle_name(path: str, field: str) -> str | None:
    text = read_text(path)
    match = re.search(rf"{re.escape(field)}\s*:\s*\"([^\"]+)\"", text)
    return match.group(1) if match else None


def check_routes(errors: list[str]) -> None:
    route_ids = extract_route_ids()
    expected = set(ROUTE_DOCS.keys())
    missing = expected - route_ids
    extra = route_ids - expected
    if missing:
        add_error(errors, f"RouteIds.ets 缺少路由: {', '.join(sorted(missing))}")
    if extra:
        add_error(errors, f"RouteIds.ets 存在未纳入文档映射的路由: {', '.join(sorted(extra))}")

    references = {path: read_text(path) for path in REFERENCE_DOCS}
    for route, doc_path in ROUTE_DOCS.items():
        if not (PROJECT_ROOT / doc_path).exists():
            add_error(errors, f"路由 {route} 对应模块设计文档不存在: {doc_path}")
        for ref_path, ref_text in references.items():
            if route not in ref_text:
                add_error(errors, f"{ref_path} 未提及路由 {route}")
        if doc_path not in references["AGENTS.md"]:
            add_error(errors, f"AGENTS.md 未索引模块设计文档: {doc_path}")
        if doc_path not in references["README.md"]:
            add_error(errors, f"README.md 未索引模块设计文档: {doc_path}")


def check_module_docs(errors: list[str]) -> None:
    for doc_path in MODULE_DOCS:
        path = PROJECT_ROOT / doc_path
        if not path.exists():
            add_error(errors, f"模块设计文档不存在: {doc_path}")
            continue
        text = path.read_text(encoding="utf-8")
        for pattern in REQUIRED_MODULE_HEADING_PATTERNS:
            if not re.search(pattern, text, flags=re.M):
                add_error(errors, f"{doc_path} 缺少模板标题模式: {pattern}")


def check_permissions(errors: list[str]) -> None:
    module_permissions = extract_module_permissions()
    hapsigner_permissions = extract_hapsigner_permissions()
    agents_permissions = extract_agents_permissions()
    if not module_permissions:
        add_error(errors, "entry/src/main/module.json5 未解析到权限")
    if module_permissions != hapsigner_permissions:
        add_error(
            errors,
            "module.json5 与 hapsigner/UnsgnedDebugProfileTemplate.json 权限不一致: "
            f"module-only={sorted(module_permissions - hapsigner_permissions)}, "
            f"hapsigner-only={sorted(hapsigner_permissions - module_permissions)}",
        )
    if module_permissions != agents_permissions:
        add_error(
            errors,
            "module.json5 与 AGENTS.md 当前权限列表不一致: "
            f"module-only={sorted(module_permissions - agents_permissions)}, "
            f"agents-only={sorted(agents_permissions - module_permissions)}",
        )

    app_bundle = extract_bundle_name("AppScope/app.json5", "bundleName")
    signer_bundle = extract_bundle_name("hapsigner/UnsgnedDebugProfileTemplate.json", "bundle-name")
    if app_bundle != signer_bundle:
        add_error(errors, f"bundleName 不一致: AppScope={app_bundle}, hapsigner={signer_bundle}")


def path_has_files(path: Path, pattern: str) -> bool:
    if path.is_file():
        return True
    if not path.is_dir():
        return False
    return any(path.rglob(pattern))


def check_test_paths(errors: list[str]) -> None:
    for module, groups in TEST_PATHS.items():
        for test_type, paths in groups.items():
            pattern = "*.json" if test_type == "e2e" else "*.test.ets"
            if not any(path_has_files(PROJECT_ROOT / path, pattern) for path in paths):
                add_error(
                    errors,
                    f"{module} 缺少 {test_type} 测试路径或用例: {', '.join(paths)}",
                )


def check_ai_docs(errors: list[str]) -> None:
    if not (PROJECT_ROOT / AI_PLAYBOOK_PATH).exists():
        add_error(errors, f"AI 常见任务手册不存在: {AI_PLAYBOOK_PATH}")
    readme = read_text("README.md")
    agents = read_text("AGENTS.md")
    if AI_PLAYBOOK_PATH not in readme:
        add_error(errors, f"README.md 未索引 {AI_PLAYBOOK_PATH}")
    if AI_PLAYBOOK_PATH not in agents:
        add_error(errors, f"AGENTS.md 未索引 {AI_PLAYBOOK_PATH}")
    if CHECK_SCRIPT_PATH not in readme:
        add_error(errors, f"README.md 未说明 {CHECK_SCRIPT_PATH}")
    if CHECK_SCRIPT_PATH not in agents:
        add_error(errors, f"AGENTS.md 未说明 {CHECK_SCRIPT_PATH}")


def check_garbled_text(errors: list[str], warnings: list[str]) -> None:
    paths = [
        PROJECT_ROOT / "AGENTS.md",
        PROJECT_ROOT / "README.md",
        *sorted((PROJECT_ROOT / "docs").rglob("*.md")),
    ]
    for path in paths:
        text = path.read_text(encoding="utf-8")
        bad_replacement_lines = [
            line_no
            for line_no, line in enumerate(text.splitlines(), start=1)
            if "\ufffd" in line and "乱码" not in line and "替换字符" not in line
        ]
        if bad_replacement_lines:
            add_error(
                errors,
                f"{path.relative_to(PROJECT_ROOT)} 包含疑似异常替换字符: {bad_replacement_lines[:8]}",
            )
        suspicious = [
            line_no
            for line_no, line in enumerate(text.splitlines(), start=1)
            if "??" in line and re.search(r"[\u4e00-\u9fff].*\?{2,}|\?{2,}.*[\u4e00-\u9fff]", line)
        ]
        if suspicious:
            add_warning(
                warnings,
                f"{path.relative_to(PROJECT_ROOT)} 存在含中文和问号的行，请确认不是转码异常: {suspicious[:8]}",
            )


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    for check in (check_routes, check_module_docs, check_permissions, check_test_paths, check_ai_docs):
        check(errors)
    check_garbled_text(errors, warnings)

    for warning in warnings:
        print(warning)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        print(f"Docs consistency check failed: {len(errors)} error(s), {len(warnings)} warning(s).", file=sys.stderr)
        return 1

    print(f"Docs consistency check passed: 0 error(s), {len(warnings)} warning(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
