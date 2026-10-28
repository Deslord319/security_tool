#!/usr/bin/env python3
"""校验文案资源键与 string.json 的一致性（国际化资源门面配套检查）。

检查项：
1. base 与 en_US 的 string.json 均可按 UTF-8 解析且结构合法；
2. 两个文件内资源名不重复；
3. base 与 en_US 的资源键集合完全一致（防止漏翻译或多翻译）；
4. entry/src/main/ets 下所有 AppStrings.get/format 引用的资源名都存在于 base 与 en_US；
5. 带占位符的资源在两个 locale 中占位符规格一致（索引与类型）；
6. 生产源码不得包含行内中文字符串字面量（对齐 logbox check-source-strings
   口径）；匹配系统应用中文名的过滤数据等白名单文件除外。

未出现在引用中的 base 资源（如脚手架字符串）仅提示 warning，不计入失败。

用法：python scripts/check_string_resources.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
BASE_STRING_PATH = PROJECT_ROOT / "entry" / "src" / "main" / "resources" / "base" / "element" / "string.json"
EN_US_STRING_PATH = PROJECT_ROOT / "entry" / "src" / "main" / "resources" / "en_US" / "element" / "string.json"
SOURCE_ROOT = PROJECT_ROOT / "entry" / "src" / "main" / "ets"

# 行内中文检查白名单：文件相对路径 -> 存在行内中文的理由
# 这些文件的中文字符串是匹配系统应用中文名等数据的过滤关键字，不是展示文案。
INLINE_CHINESE_ALLOWLIST = {
    "entry/src/main/ets/services/permission-manage/ApplicationInventoryRepository.ets":
        "匹配系统应用中文名的过滤数据（NON_MANAGEABLE_LABEL_KEYWORDS），见权限管理设计说明",
}

APP_STRINGS_REF_RE = re.compile(r"AppStrings\.(?:get|format)\(\s*['\"]([A-Za-z0-9_]+)['\"]")
R_REF_RE = re.compile(r"\$r\(\s*'app\.string\.([a-z0-9_]+)'")
STRING_LITERAL_RE = re.compile(r"['\"]([A-Za-z0-9_]+)['\"]")
PLACEHOLDER_RE = re.compile(r"%(?:\d+\$)?[dsf]")


def add_error(errors: list[str], message: str) -> None:
    errors.append(message)


def add_warning(warnings: list[str], message: str) -> None:
    warnings.append(message)


def load_string_entries(path: Path, errors: list[str]) -> dict[str, str]:
    entries: dict[str, str] = {}
    try:
        raw = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        add_error(errors, f"资源文件不存在: {path.relative_to(PROJECT_ROOT)}")
        return entries
    except UnicodeDecodeError:
        add_error(errors, f"资源文件不是合法 UTF-8: {path.relative_to(PROJECT_ROOT)}")
        return entries
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as err:
        add_error(errors, f"资源文件 JSON 解析失败: {path.relative_to(PROJECT_ROOT)}: {err}")
        return entries
    for item in data.get("string", []):
        name = item.get("name")
        value = item.get("value")
        if not isinstance(name, str) or not isinstance(value, str):
            add_error(errors, f"资源条目缺少 name/value: {path.relative_to(PROJECT_ROOT)}")
            continue
        if name in entries:
            add_error(errors, f"资源名重复: {name} ({path.relative_to(PROJECT_ROOT)})")
            continue
        entries[name] = value
    return entries


def collect_references(errors: list[str]) -> tuple[set[str], set[str]]:
    """返回两个集合：AppStrings 调用的精确资源引用（用于缺失校验）和任意
    字符串字面量集合（含注册表 define/field 的资源名参数，用于未引用校验，
    与 logbox check-source-strings 的口径一致）。"""
    app_strings_refs: set[str] = set()
    any_literals: set[str] = set()
    if not SOURCE_ROOT.exists():
        add_error(errors, f"源码目录不存在: {SOURCE_ROOT.relative_to(PROJECT_ROOT)}")
        return app_strings_refs, any_literals
    for path in sorted(SOURCE_ROOT.rglob("*.ets")):
        text = path.read_text(encoding="utf-8", errors="replace")
        for name in APP_STRINGS_REF_RE.findall(text):
            app_strings_refs.add(name)
        for name in R_REF_RE.findall(text):
            any_literals.add(name)
            app_strings_refs.add(name)
        for name in STRING_LITERAL_RE.findall(text):
            any_literals.add(name)
    return app_strings_refs, any_literals


def placeholders_of(value: str) -> list[str]:
    return sorted(PLACEHOLDER_RE.findall(value))


def check_placeholder_consistency(
    base_entries: dict[str, str],
    en_us_entries: dict[str, str],
    errors: list[str],
) -> None:
    for name in sorted(set(base_entries) & set(en_us_entries)):
        base_tokens = placeholders_of(base_entries[name])
        en_tokens = placeholders_of(en_us_entries[name])
        if base_tokens != en_tokens:
            add_error(
                errors,
                f"占位符不一致: {name} | base={base_tokens} en_US={en_tokens}",
            )


def check_inline_chinese(errors: list[str]) -> None:
    for path in sorted(SOURCE_ROOT.rglob("*.ets")):
        relative = path.relative_to(PROJECT_ROOT).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace")
        in_block = False
        for line_no, line in enumerate(text.split("\n"), start=1):
            code = line
            if in_block:
                if "*/" in code:
                    code = code.split("*/", 1)[1]
                    in_block = False
                else:
                    continue
            if "/*" in code:
                pre = code.split("/*", 1)[0]
                in_block = "*/" not in code
                code = pre + (code.split("*/", 1)[1] if "*/" in code else "")
            code = code.split("//", 1)[0]
            if re.search("[\u4e00-\u9fff]", code) and re.search(r"[\"']", code):
                if relative in INLINE_CHINESE_ALLOWLIST:
                    continue
                add_error(errors, f"生产源码包含行内中文字符串: {relative}:{line_no}")


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    base_entries = load_string_entries(BASE_STRING_PATH, errors)
    en_us_entries = load_string_entries(EN_US_STRING_PATH, errors)
    app_strings_refs, any_literals = collect_references(errors)

    if errors:
        for message in errors:
            print(f"[ERROR] {message}")
        return 1

    base_only = set(base_entries) - set(en_us_entries)
    en_only = set(en_us_entries) - set(base_entries)
    for name in sorted(base_only):
        add_error(errors, f"en_US 缺少资源: {name}")
    for name in sorted(en_only):
        add_error(errors, f"en_US 多出资源（base 未定义）: {name}")

    missing_in_base = app_strings_refs - set(base_entries)
    missing_in_en = app_strings_refs - set(en_us_entries)
    for name in sorted(missing_in_base):
        add_error(errors, f"代码引用的资源在 base 中不存在: {name}")
    for name in sorted(missing_in_en):
        add_error(errors, f"代码引用的资源在 en_US 中不存在: {name}")

    check_placeholder_consistency(base_entries, en_us_entries, errors)
    check_inline_chinese(errors)

    unreferenced = set(base_entries) - any_literals
    for name in sorted(unreferenced):
        add_warning(warnings, f"base 资源未被代码引用（确认是否为脚手架字符串）: {name}")

    for message in errors:
        print(f"[ERROR] {message}")
    for message in warnings:
        print(f"[WARN] {message}")

    print(
        f"check_string_resources: base={len(base_entries)} entries, "
        f"en_US={len(en_us_entries)} entries, appStringsRefs={len(app_strings_refs)}, "
        f"errors={len(errors)}, warnings={len(warnings)}"
    )
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
