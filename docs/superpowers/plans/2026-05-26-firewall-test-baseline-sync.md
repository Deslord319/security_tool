# Firewall Test Baseline Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sync the firewall manual test baseline and UT support matrix with the current firewall module design and existing unit tests.

**Architecture:** This is a documentation and spreadsheet synchronization task. No production ArkTS, test ArkTS, ohosTest dispatcher, permissions, signing profile, or runtime behavior is changed.

**Tech Stack:** Markdown, Excel `.xlsx`, Python/OpenPyXL for deterministic workbook row updates, project consistency checker.

---

## Workspace And Branch

- Workspace: `D:\project\ai\security_tool`
- Branch: `codex/firewall-test-baseline-sync`
- Base branch observed before execution: `master`

## Background

Recent firewall unit tests in `entry/src/test/firewall/service.test.ets` now cover stricter rule mutation contracts:

- multi-user rule create rollback on partial failure
- rule edit user-delta update/add/remove behavior
- edit rollback for updated, added, and removed deployments
- delete partial failure restore behavior
- DNS-to-DNS edit via remove+add instead of `updateNetFirewallRule`
- DNS replace failure restoration
- DNS-to-IP edit via in-place update

The firewall module design document already describes these contracts in `docs/03-模块设计/防火墙管理组件设计说明.md` version `2.0.30`.

## Purpose

Update the test baseline documents so the baseline explicitly reflects the current module design and UT coverage. This prevents the test baseline from understating existing coverage.

## Strict File Scope

Modify only:

- `docs/superpowers/plans/2026-05-26-firewall-test-baseline-sync.md`
- `docs/04-测试文档/手工测试用例/测试用例基线.xlsx`
- `docs/04-测试文档/手工测试用例/测试用例基线_UT支撑调研矩阵.md`

Do not modify:

- production ArkTS
- local UT ArkTS
- ohosTest files
- `docs/04-测试文档/DEVICE_TEST_FRAMEWORK.md`
- module design documents
- signing, permission, CI, or build files

## Expected Document Changes

### `测试用例基线.xlsx`

Append firewall cases:

| ID | Summary | UT Status |
|---|---|---|
| FW-033 | multi-user create partial failure rolls back successful deployments | 已有UT覆盖 |
| FW-034 | edit rule applies user-delta update/add/remove and saves deployments | 已有UT覆盖 |
| FW-035 | edit removal failure rolls back updated/added/removed system actions | 已有UT覆盖 |
| FW-036 | delete partial failure restores removed system rules and deployments | 已有UT覆盖 |
| FW-037 | DNS-to-DNS edit uses remove+add and saves new `systemRuleId` | 已有UT覆盖 |
| FW-038 | DNS replace add failure restores old DNS deployment and does not save new intent | 已有UT覆盖 |
| FW-039 | DNS-to-IP edit uses in-place update and keeps `systemRuleId` | 已有UT覆盖 |

### `测试用例基线_UT支撑调研矩阵.md`

Append matching FW-033 through FW-039 rows under the firewall section.

Update summary:

- 基线用例总数: `126`
- `已有UT覆盖`: `101`
- `UT部分覆盖`: `4`
- `待补UT`: `0`
- `不补UT`: `21`

## Pseudocode

```text
load workbook docs/04-测试文档/手工测试用例/测试用例基线.xlsx
select sheet 测试用例_ai
assert FW-033..FW-039 are absent
append seven firewall rows with full manual steps, expected results, UT status, and UT location
save workbook

read docs/04-测试文档/手工测试用例/测试用例基线_UT支撑调研矩阵.md as UTF-8
replace summary counts 119/94 with 126/101
insert FW-033..FW-039 rows after FW-032 in firewall section
write UTF-8
```

## Corrupt Code Handling

No production or test code should be changed. Do not introduce committed helper scripts. Any temporary scratch file, exported intermediate file, or cache created during execution must be deleted before commit.

## Tasks

### Task 1: Create Branch

**Input:** Clean or reviewable working tree on `master`.

**Output:** Branch `codex/firewall-test-baseline-sync`.

**Acceptance:** `git branch --show-current` prints `codex/firewall-test-baseline-sync`.

### Task 2: Add This Plan

**Input:** User-approved plan content.

**Output:** `docs/superpowers/plans/2026-05-26-firewall-test-baseline-sync.md`.

**Acceptance:** File exists and includes workspace, branch, background, purpose, strict file scope, pseudocode, and step-by-step acceptance criteria.

### Task 3: Update Excel Baseline

**Input:** Existing workbook and firewall design/test evidence.

**Output:** Workbook with FW-033 through FW-039 appended.

**Acceptance:**

- workbook has 126 data cases plus one header row
- FW-033 through FW-039 exist exactly once
- all seven new rows have `已有UT覆盖`
- all seven new rows point to `entry/src/test/firewall/service.test.ets`

### Task 4: Update UT Matrix Markdown

**Input:** Updated Excel rows and current Markdown matrix.

**Output:** Markdown matrix with FW-033 through FW-039 and updated summary counts.

**Acceptance:**

- summary counts are `126 / 101 / 4 / 0 / 21`
- all seven rows are in the firewall section after FW-032
- UTF-8 Chinese text reads normally

### Task 5: Verify Docs

**Input:** Modified workbook and Markdown matrix.

**Output:** Consistency check result.

**Acceptance:**

```powershell
python scripts/check_docs_consistency.py
```

passes, and UTF-8 readback contains no Unicode replacement character.

### Task 6: Build, Install, And Launch

**Input:** Documentation-only changes and existing project build/signing scripts.

**Output:** Fresh build/install/launch attempt results.

**Acceptance:**

- run project consistency checker
- run HAP build using the project hvigor lookup rules
- sign the HAP
- install signed HAP if device is available
- launch app if device is available
- if device is unavailable, record the exact blocker without changing scope

### Task 7: Commit

**Input:** Verified documentation changes.

**Output:** Git commit.

**Acceptance:**

```powershell
git status --short
git log -1 --oneline
```

shows only the intended committed changes and commit message:

```text
docs: sync firewall test baseline cases
```
