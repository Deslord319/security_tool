# refac 文档索引

`docs/refac` 用于沉淀 SecurityTool 各模块的重构、迁移、分步实施、测试补齐和收口类文档。这里的文档偏向“改造过程文档”，重点回答为什么改、按什么顺序改、改完如何验收，而不是作为最终功能说明书使用。

## 目录概览

- `code-structure-module-migration-plan.md`
  - 代码目录结构迁移方案设计，定义整体迁移目标、目标目录职责、迁移清单和分批实施建议。
- `code-structure-module-migration-fix-plan.md`
  - 代码目录结构迁移修复计划，面向已有迁移方案的落地修正，补充阶段划分、Git 小步提交策略和验收标准。
- `../04-测试文档/手工测试用例/测试用例V2_已处理_具体化.xlsx`
  - 当前已固化的手工测试用例基线，包含经审视后的删改结果、遗漏补充和参数具体化版本。
- `dashboard/`
  - 安全总览模块 RFC 目录，聚焦摘要聚合、导航元数据、刷新边界和首页扩展位。
- `firewall/`
  - 防火墙模块重构文档目录，聚焦防火墙模块的 SSOT、Story 拆分和分轮实施。
- `identity/`
  - 身份鉴别模块 RFC 目录，聚焦编辑态、系统态、管理员感知和保存链路收口。
- `log-manage/`
  - 日志管理模块 RFC 目录，聚焦状态收敛、详情快照、导出链路和稳定性补强。
- `peripheral-management/`
  - 外设管理模块重构文档目录，现已包含模块总 RFC，并继续覆盖“设备连接记录”链路重构、测试补齐、死代码清理、黑白名单单设备策略真实下发方案，以及 USB 接口异步回退对齐方案。
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

目录用途：记录防火墙管理模块的重构真相源和按 PR/Story/Round 切分的实施计划。

- `firewall/firewall-refactor-single-source-of-truth.md`
  - 防火墙管理模块的唯一真相文档。
  - 主要内容包括现有真相来源、目标目录职责、旧职责替代关系、分步迁移计划和完成判定。
- `firewall/firewall-refactor-rfc-story-rounds.md`
  - 防火墙模块重构的 RFC 与执行拆分文档。
  - 主要内容包括 In Scope / Out of Scope、文件范围、Story 切分、Round 切分、并行开发约束和与 SSOT 的一致性声明。
- `firewall/firewall-refactor-follow-up-open-items.md`
  - 防火墙重构完成后的后续未完成工作清单。
  - 主要内容包括 rules/provider/auth/user-dispatch 四类后续抽象与合并议题，以及建议后续顺序。

建议阅读顺序：

1. 先看 `firewall-refactor-single-source-of-truth.md`
2. 再看 `firewall-refactor-rfc-story-rounds.md`
3. 若要继续做后续抽象或跨模块公共化，再看 `firewall-refactor-follow-up-open-items.md`

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

目录用途：记录外设管理模块总 RFC，以及“设备连接记录”链路的重构方案、迁移计划、Mock 测试设计、测试执行追踪、死代码清理计划、黑白名单单设备策略真实下发方案，以及 USB 接口异步回退对齐方案。

- `peripheral-management/peripheral-management-module-rfc.md`
  - 外设管理模块执行层总 RFC。
  - 主要内容包括三条子域边界、主从 ViewModel 职责、Story / Round 拆分和与专项文档的挂靠关系。
- `peripheral-management/device-connection-record.md`
  - “设备连接记录”链路的主重构计划，也是该主题的 SSOT。
  - 适合先建立整体背景、边界、目标架构和最小改动策略。
- `peripheral-management/device-connection-record-rfc-story-rounds.md`
  - 将设备连接记录重构拆成 Story / PR / Round 的执行文档。
  - 适合并行开发或分阶段推进时使用。
- `peripheral-management/device-connection-record-runtime-service-migration-plan.md`
  - 删除 `PeripheralRuntimeEventService` 参与设备连接记录落地链路的专项迁移计划。
  - 聚焦从旧 RuntimeService 退出时的步骤、范围和约束。
- `peripheral-management/device-connection-record-runtime-service-migration-report.md`
  - RuntimeService 删除相关改造的收口报告。
  - 适合回顾阶段结果、核对计划与实际落地差异。
- `peripheral-management/device-connection-record-mock-test-design.md`
  - 设备连接记录 Mock 测试设计与用例总表。
  - 汇总测试目标、分组、场景和覆盖面。
- `peripheral-management/device-connection-record-mock-test-implementation-plan.md`
  - Mock 测试实施计划。
  - 重点是按 Session 拆分执行步骤、输入输出、改动文件和验收方式。
- `peripheral-management/device-connection-record-mock-test-tracker.md`
  - Mock 测试追踪表。
  - 用于记录执行状态、覆盖进度和回填结果。
- `peripheral-management/device-connection-record-dead-code-cleanup-plan.md`
  - 设备连接记录链路死代码清理计划。
  - 聚焦死代码判定、清理步骤、证据要求和退出条件。
- `peripheral-management/device-policy-dispatch-plan.md`
  - 黑白名单单设备策略真实下发改造方案。
  - 聚焦 USB / 蓝牙设备策略从“仅本地保存”改为“先真实下发、成功后保存”，并定义冲突处理原则。
- `peripheral-management/usb-interface-async-select-alignment-plan.md`
  - USB 接口接入 `AsyncSelectRow` 的最小改动方案。
  - 聚焦在不改变 MVVM 分层的前提下，实现 USB 接口失败回退、页面 loading 和提示逻辑保持不变。

建议阅读顺序：

1. 先看 `docs/03-模块设计/外设管理组件设计说明.md`
2. 再看 `peripheral-management-module-rfc.md`
3. 若要推进设备连接记录专项，再看 `device-connection-record.md`
4. 若要落地连接记录重构，再看 `device-connection-record-rfc-story-rounds.md`
5. 若要处理 RuntimeService 退出，再看 `device-connection-record-runtime-service-migration-plan.md` 和对应 report
6. 若要补测试，再看 `device-connection-record-mock-test-design.md`、`device-connection-record-mock-test-implementation-plan.md`、`device-connection-record-mock-test-tracker.md`
7. 若要收尾清理，再看 `device-connection-record-dead-code-cleanup-plan.md`
8. 若要推进黑白名单真实策略生效，再看 `device-policy-dispatch-plan.md`
9. 若要推进 USB 接口失败回退改造，再看 `usb-interface-async-select-alignment-plan.md`

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
- 想查看当前手工测试基线：直接打开 `docs/04-测试文档/手工测试用例/测试用例V2_已处理_具体化.xlsx`。
- 想做专项收口：优先找 `migration-plan`、`report`、`cleanup-plan`、`tracker` 这类文件。
- 新增 refac 文档时，建议同步更新本索引，保持目录和用途说明可导航。
