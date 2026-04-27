# refac 文档索引

`docs/refac` 用于沉淀 SecurityTool 各模块的重构、迁移、分步实施、测试补齐和收口类文档。这里的文档偏向“改造过程文档”，重点回答为什么改、按什么顺序改、改完如何验收，而不是作为最终功能说明书使用。

## 目录概览

- `code-structure-module-migration-plan.md`
  - 代码目录结构迁移方案设计，定义整体迁移目标、目标目录职责、迁移清单和分批实施建议。
- `code-structure-module-migration-fix-plan.md`
  - 代码目录结构迁移修复计划，面向已有迁移方案的落地修正，补充阶段划分、Git 小步提交策略和验收标准。
- `../04-测试文档/手工测试用例/测试用例基线.xlsx`
  - 当前已固化的手工测试用例基线，包含经审视后的删改结果、遗漏补充和参数具体化版本。
- `dashboard/`
  - 安全总览模块 RFC 目录，聚焦摘要聚合、导航元数据、刷新边界和首页扩展位。
- `firewall/`
  - 防火墙模块重构文档已收敛到 `docs/03-模块设计/防火墙管理组件设计说明.md`，目录不再保留长期真相源。
- `identity/`
  - 身份鉴别模块 RFC 目录，聚焦编辑态、系统态、管理员感知和保存链路收口。
- `log-manage/`
  - 日志管理模块 RFC 目录，聚焦状态收敛、详情快照、导出链路和稳定性补强。
- `peripheral-management/`
  - 外设管理模块历史重构文档目录，已完成收口，不再作为长期维护入口。
- `tool-settings/`
  - 工具设置模块 RFC 目录，聚焦启动认证、认证方式可用性和工具级设置边界。

## dashboard

目录用途：记录安全总览模块的收口与演进设计，重点回答首页如何保持“只做摘要聚合，不做业务真相源”。

- `dashboard/dashboard-module-rfc.md`
  - 安全总览模块执行层 RFC。
  - 主要内容包括首页职责边界、摘要模型、Story / Round 拆分、刷新边界和扩展位规范。

建议阅读顺序：

1. 先看 `docs/03-模块设计/安全总览组件设计说明.md`
2. 再看 `dashboard/dashboard-module-rfc.md`

## firewall

目录状态：防火墙模块重构文档已完成收口，历史 SSOT、专项结论和一次性实施计划不再作为长期维护入口。

建议阅读顺序：

1. 只看 `docs/03-模块设计/防火墙管理组件设计说明.md`

## identity

目录用途：记录身份鉴别模块的状态收口与后续演进设计，重点固定编辑态、系统态、管理员状态与保存链路的边界。

- `identity/identity-module-rfc.md`
  - 身份鉴别模块执行层 RFC。
  - 主要内容包括状态分层、Story / Round 拆分、风险和验收信号。

建议阅读顺序：

1. 先看 `docs/03-模块设计/身份鉴别组件设计说明.md`
2. 再看 `identity/identity-module-rfc.md`

## log-manage

目录用途：记录日志管理模块的状态收敛和持续演进设计，重点解决页面镜像态、详情稳定性、导出链路与高频刷新稳定性问题。

- `log-manage/log-manage-module-rfc.md`
  - 日志管理模块执行层 RFC。
  - 主要内容包括单一真相源约束、Story / Round 拆分、文件白名单建议和验收信号。
- `log-manage/log-manage-audit-event-materials.md`
  - 日志管理模块系统审计事件材料归档。
  - 主要内容包括当前讨论范围、`ACCOUNT / PERMISSION / FILE` 原型样例，以及当前已确认可抽取字段。
- `log-manage/log-manage-detail-table-plan.md`
  - 日志管理模块详情结构化展示方案。
  - 主要内容包括结构化详情字段方向、可复用表格组件目标，以及本轮严格限定的代码文件范围。
- `log-manage/log-manage-detail-table-implementation-plan.md`
  - 日志管理模块详情结构化展示实施计划。
  - 主要内容包括背景和目的、严格文件范围、分步实施、输入输出、验收标准、并行拆分和死代码清理要求。
- `log-manage/log-manage-audit-result-mapping-analysis-2026-04-14.md`
  - 日志管理模块审计结果映射问题分析。
  - 主要内容包括列表与详情弹窗结果展示逻辑、`entry.result` 来源、`Fail -> SUCCESS` 根因和修复方向。

建议阅读顺序：

1. 先看 `docs/03-模块设计/日志管理模块V2状态收敛与实施设计.md`
2. 再看 `docs/03-模块设计/日志管理模块重构方案.md`
3. 再看 `log-manage/log-manage-module-rfc.md`
4. 若要查看系统审计事件的当前材料归档，再看 `log-manage/log-manage-audit-event-materials.md`
5. 若要推进详情弹窗结构化展示，再看 `log-manage/log-manage-detail-table-plan.md`
6. 若要按多 Session 方式落地实施，再看 `log-manage/log-manage-detail-table-implementation-plan.md`
7. 若要回看一次真实审计失败事件为何被展示成“成功”，再看 `log-manage/log-manage-audit-result-mapping-analysis-2026-04-14.md`

## peripheral-management

目录状态：外设管理模块重构文档已完成收口，历史专项方案和阶段性计划不再作为长期维护入口。

建议阅读顺序：

1. 只看 `docs/03-模块设计/外设管理组件设计说明.md`

## tool-settings

目录用途：记录工具设置模块的职责边界、保存链路和后续扩展规则，避免模块演变成杂项设置页。

- `tool-settings/tool-settings-module-rfc.md`
  - 工具设置模块执行层 RFC。
  - 主要内容包括模块边界、Story / Round 拆分、风险和验收信号。

建议阅读顺序：

1. 先看 `docs/03-模块设计/工具设置组件设计说明.md`
2. 再看 `tool-settings/tool-settings-module-rfc.md`

## 使用建议

- 想了解整个重构方向：优先看根目录下两份代码结构迁移文档。
- 想推进具体模块：进入对应子目录，先读模块设计，再读 SSOT 或执行层 RFC。
- 想查看当前手工测试基线：直接打开 `docs/04-测试文档/手工测试用例/测试用例基线.xlsx`。
- 想做专项收口：优先找 `migration-plan`、`report`、`cleanup-plan`、`tracker` 这类文件。
- 新增 refac 文档时，建议同步更新本索引，保持目录和用途说明可导航。
