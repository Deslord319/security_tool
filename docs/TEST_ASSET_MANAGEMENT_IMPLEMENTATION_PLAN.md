# 测试资产管理与用例生成实施文档

## 1. 目标

在现有 `scripts/e2e` 框架上增加一层“测试资产管理层”，先完成可视化、可编辑、可导入、可生成、可治理，再决定是否执行代码改造。

本阶段只定义落地方案，不改变现有 runner 协议和用例执行入口。

## 2. 当前现状

仓库内已经具备以下基础能力：

- `scripts/e2e/cases/` 已有正式 case JSON
- `scripts/e2e/adapters/security_tool/flows/registry.py` 已定义 flow registry
- `scripts/e2e/adapters/security_tool/suites.py` 已定义 suite
- `scripts/e2e/tools/bridge_coverage_report.py` 已能生成 bridge action coverage 文档
- `scripts/e2e/docs/E2E_EXCEL_MAPPING.md` 已给出 Excel 到 case JSON 的映射思路
- `scripts/e2e/schemas/case_schema.json` 已定义 case contract

当前缺口不在执行层，而在“管理层”：

- 没有统一的用例台账
- 没有区分“已实现 / 计划中 / 导入待确认”
- 没有面向用户的可视化编辑界面
- 没有 Excel 导入后的标准化结果
- 没有从台账生成 case 草稿的流程
- 没有把写用例规范固化成统一机制

## 3. 总体设计

### 3.1 设计原则

- `case JSON` 继续作为 runner 的直接输入
- 新增一份“测试资产台账”作为管理层事实源
- 管理页只编辑业务层字段，不直接编辑底层 MCP/HDC 细节
- Excel 只是导入来源之一，不作为唯一事实源
- 自动生成只生成 `case JSON + 检查点草稿`
- bridge 未覆盖的能力要显式暴露，不做隐式兜底

### 3.2 最终形成的结构

建议新增以下目录与文件：

```text
scripts/e2e/
  metadata/
    case_catalog.json
    coverage_snapshot.json
    import_report.json
    generation_report.json
  tools/
    build_case_catalog.py
    build_coverage_snapshot.py
    import_excel_cases.py
    generate_case_drafts.py
    validate_test_assets.py
  drafts/
    *.json

docs/
  test-assets-dashboard.html
  TEST_ASSET_MANAGEMENT_IMPLEMENTATION_PLAN.md
```

说明：

- `metadata/` 存放管理层数据产物
- `drafts/` 存放自动生成但未转正的 case 草稿
- `docs/test-assets-dashboard.html` 为本地静态管理页

### 3.3 Excel 导入设计基线

Excel 导入遵循以下映射链路：

```text
Excel 行 -> case 台账记录 -> case JSON 草稿
        -> flow ref
        -> backend action
        -> MCP tool / HDC
```

约束：

- Excel 只描述业务步骤和关键参数
- case JSON 只描述测试意图、flow 和检查点
- adapter/flow 负责项目语义
- backend action 负责页面执行语义
- MCP tool / HDC 只负责原子动作

这条链路必须保持，避免把 Excel 直接耦合到具体 UI 操作。

### 3.4 Excel 推荐字段

第一版导入模板建议沿用以下字段：

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `case_id` | 是 | 用例唯一标识 |
| `case_name` | 是 | 用例名称 |
| `module` | 是 | 模块名，如 `tool-settings` |
| `enabled` | 是 | 是否启用，建议 `Y/N` |
| `flow_1_ref` | 是 | 第一步 flow 引用 |
| `flow_1_params` | 否 | 第一步参数，JSON 字符串 |
| `flow_2_ref` | 否 | 第二步 flow 引用 |
| `flow_2_params` | 否 | 第二步参数，JSON 字符串 |
| `flow_3_ref` | 否 | 第三步 flow 引用 |
| `flow_3_params` | 否 | 第三步参数，JSON 字符串 |
| `flow_4_ref` | 否 | 第四步 flow 引用 |
| `flow_4_params` | 否 | 第四步参数，JSON 字符串 |
| `allow_unknown` | 否 | 是否允许 `UNKNOWN` |
| `stop_on_failure` | 否 | 是否失败即停 |
| `notes` | 否 | 备注 |

为适配测试资产管理层，导入器还应补充以下内部字段，但不要求 Excel 显式提供：

- `status`
- `source`
- `suite_membership`
- `checkpoint_summary`
- `bridge_coverage_status`
- `last_result_status`

默认规则：

- `enabled = N` 的记录导入为 `planned` 或 `deprecated`
- `enabled = Y` 的新记录默认导入为 `draft`
- `source` 自动标记为 `excel_import`

### 3.5 Excel 到 case 的示例

示例 Excel 行：

| case_id | case_name | module | enabled | flow_1_ref | flow_1_params | flow_2_ref | flow_2_params | flow_3_ref | flow_3_params | flow_4_ref | flow_4_params |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `SET-STARTUP-001` | `Startup Auth Toggle` | `tool-settings` | `Y` | `app.launch` | `{"timeout_sec":20}` | `navigation.open_page` | `{"page_id":"tool-settings"}` | `tool_settings.toggle_startup_auth` | `{"target_state":"invert"}` | `tool_settings.save` | `{}` |

生成的标准 case 草稿结构：

```json
{
  "case_id": "SET-STARTUP-001",
  "case_name": "Startup Auth Toggle",
  "module": "tool-settings",
  "flow": [
    { "ref": "app.launch", "params": { "timeout_sec": 20 } },
    { "ref": "navigation.open_page", "params": { "page_id": "tool-settings" } },
    { "ref": "tool_settings.toggle_startup_auth", "params": { "target_state": "invert" } },
    { "ref": "tool_settings.save", "params": {} }
  ],
  "assertions": [],
  "result_policy": {
    "allow_unknown": true,
    "stop_on_failure": true
  },
  "notes": [
    "Imported from Excel and pending checkpoint review."
  ]
}
```

### 3.6 Excel 边界约束

不允许把 Excel 设计成直接描述底层 MCP 参数，例如：

| flow_1_ref | flow_1_params |
| --- | --- |
| `mcp.click_element` | `{"text":"工具设置"}` |

原因：

1. 页面改版后 Excel 会大面积失效
2. 业务维护成本高
3. case 与 UI 实现耦合过重

推荐写法必须保持在业务语义层，例如：

| flow_1_ref | flow_1_params |
| --- | --- |
| `navigation.open_page` | `{"page_id":"tool-settings"}` |

例外情况只允许两类：

1. 断言层使用受控的等待或可见性检查
2. flow 尚未抽象完成时，作为临时兜底能力使用，但不能成为主流写法

### 3.7 Excel 导入实施顺序

Excel 导入能力建议按以下顺序建设：

1. 先冻结 Excel 列定义
2. 再实现 `Excel -> case_catalog.json` 导入脚本
3. 先用 `tool-settings` 模块验证
4. 再扩展到 `firewall / peripheral / identity / logs`

### 3.8 Excel 模板写法调整为“自然语言整段描述”

为了让业务、测试、产品都能直接理解，Excel 不应要求用户按固定的技术结构录入，也不应强制每一步都单独拆成“步骤列 + 预期列”。

更符合实际的方式是：

- 一个单元格里可以写完整步骤
- 有些步骤后面带检查点，有些不带
- 检查点可以只在关键步骤后出现
- 导入器负责把整段自然语言拆成步骤和检查点草稿

建议第一版 Excel 模板使用下面这些字段：

| 用例编号 | 用例名称 | 所属模块 | 是否启用 | 前置条件 | 操作步骤 | 检查点 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- |

这种写法的目的：

- 用户只需要写“怎么操作”
- 用户只需要写“哪些地方要重点看”
- 不要求用户理解系统内部工具
- 不要求每一步都配一个检查点
- 后续再由导入器把自然语言映射成系统里的 `flow` 和检查点草稿

建议的填写样例如下：

| 用例编号 | 用例名称 | 所属模块 | 是否启用 | 前置条件 | 操作步骤 | 检查点 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `SET-STARTUP-001` | 启动认证开关保存 | 工具设置 | 是 | 应用已安装并可正常打开 | `1. 打开应用进入工具设置页面；2. 打开启动时身份校验开关；3. 点击保存设置；4. 重新进入工具设置页面查看状态。` | `重点检查保存后状态是否生效；重新进入后状态是否保持一致。` | `不是每一步都要单独验，只看关键结果。` |
| `SET-AUTH-001` | 修改认证方式 | 工具设置 | 是 | 已进入工具设置页面 | `1. 进入认证方式设置区域；2. 将认证方式改为 PIN；3. 点击保存设置；4. 重新进入页面查看。` | `重点检查当前认证方式是否变成 PIN；重新进入页面后是否仍然保持。` | `若设备不支持对应认证方式，需要记录原因。` |
| `FW-STATUS-001` | 防火墙状态切换 | 防火墙管理 | 是 | 应用已打开 | `1. 进入防火墙管理页面；2. 切换防火墙开关；3. 返回或刷新后再次查看。` | `重点检查开关状态是否变化；刷新后状态是否持久生效。` | `中间步骤可以没有单独检查点。` |

填写规则：

- `操作步骤` 允许在一个单元格里写完整流程
- 推荐用 `1. 2. 3.` 这样的自然语言编号
- `检查点` 只写关键观察结果，不要求覆盖每一步
- `检查点` 可以为空，后续由导入器先生成草稿，再人工补充
- `所属模块` 用业务名称即可，导入时再映射到系统模块 ID
- `是否启用` 建议填“是/否”
- `备注` 用来写风险点、特殊限制、人工重点关注项

### 3.9 自然语言到系统结构的转换规则

导入器不直接要求用户写技术字段，而是分两步处理：

1. 用户在 Excel 中写自然语言步骤和预期
2. 系统将自然语言记录转换成内部结构：
   - 生成 `case_catalog.json` 里的业务记录
   - 生成推荐的 `flow` 草稿
   - 从“检查点”列和“操作步骤”中的关键词提取 `checkpoint_summary`
   - 生成待人工确认的 `assertions` 草稿

转换后的内部技术字段仍然存在，但它们是系统产物，不是用户输入项。

转换规则建议如下：

- 如果 `检查点` 列有内容，优先使用该列生成 `checkpoint_summary`
- 如果 `检查点` 列为空，则从 `操作步骤` 中提取带有“检查/确认/验证/查看”语义的句子，生成草稿检查点
- 如果两者都没有明显检查信息，则生成空检查点草稿，并标记为“待人工补充”
- 系统不要求“步骤数”和“检查点数”一一对应

### 3.10 技术字段只作为系统内部层

像下面这些字段：

- `flow_ref`
- `params`
- `allow_unknown`
- `stop_on_failure`

不适合作为第一层 Excel 录入字段。

更合理的做法是：

- Excel 给人填，自然语言表达
- 导入器给系统用，转换成结构化 case
- 管理页给测试负责人用，审核转换结果是否合理

### 3.11 后续双层模板建议

建议最终保留两层模板：

1. 用户模板
- 面向业务、测试、产品
- 只写自然语言步骤、预期、备注

2. 系统模板
- 面向导入器和自动生成脚本
- 由系统自动生成 `flow`、检查点草稿、结果策略

这样可以把“用户易懂”和“系统可执行”拆开，避免一开始就让用户理解工具细节。

## 4. 数据模型

### 4.1 `case_catalog.json`

这是核心台账文件。每条记录建议包含：

```json
{
  "case_id": "SET-STARTUP-001",
  "case_name": "Startup Auth Toggle",
  "module": "tool-settings",
  "status": "implemented",
  "source": "manual",
  "suite_membership": ["tool_settings", "completeness"],
  "case_path": "scripts/e2e/cases/tool_settings/startup_auth.json",
  "flow_refs": [
    "app.launch",
    "navigation.open_page",
    "tool_settings.toggle_startup_auth",
    "tool_settings.save"
  ],
  "checkpoint_summary": [
    "启动认证开关状态变化",
    "保存动作成功触发"
  ],
  "bridge_coverage_status": "covered",
  "last_result_status": "UNKNOWN",
  "owner": "",
  "notes": []
}
```

字段约束：

- `status`：`implemented` / `planned` / `draft` / `deprecated`
- `source`：`manual` / `excel_import` / `generated`
- `bridge_coverage_status`：`covered` / `partial` / `missing`
- `last_result_status`：`PASS` / `FAIL` / `UNKNOWN` / `NOT_RUN`

### 4.2 `coverage_snapshot.json`

该文件用于管理页展示，不作为执行输入。建议包含：

- 模块维度统计
- suite 维度统计
- flow ref 覆盖统计
- bridge action 覆盖统计
- 已实现 / 计划中 / 草稿 / 废弃数量
- 最近执行结果分布

### 4.3 `import_report.json`

用于记录 Excel 导入结果：

- 成功导入记录
- 发现的重复 `case_id`
- 非法 `flow_ref`
- 非法 JSON 参数
- 待人工确认的冲突项

### 4.4 `generation_report.json`

用于记录从台账生成 case 草稿的结果：

- 已生成的草稿文件
- 跳过原因
- bridge 缺口提示
- 需要人工确认的检查点列表

## 5. 管理页设计

### 5.1 页面目标

本地打开 `docs/test-assets-dashboard.html` 后，应能完成以下操作：

- 查看当前所有用例
- 查看各模块覆盖情况
- 区分当前已生成、即将开发、草稿待确认、已废弃
- 查看 flow / bridge 覆盖缺口
- 编辑业务层字段
- 从 Excel 导入新用例
- 生成 case 草稿
- 导出更新后的 metadata 文件

### 5.2 页面模块

建议分 5 个区域：

1. 概览区
- 总用例数
- 已实现数
- 计划中数
- 草稿数
- bridge 缺口数

2. 覆盖区
- 模块覆盖表
- suite 覆盖表
- flow ref 覆盖表
- bridge action 覆盖表

3. 用例台账区
- 支持筛选模块、状态、来源、最近执行结果
- 支持搜索 `case_id`、`case_name`

4. 用例编辑区
- 编辑 `case_name`
- 编辑 `module`
- 编辑 `status`
- 编辑 `suite_membership`
- 编辑 `flow_refs` 与 `params`
- 编辑 `checkpoint_summary`
- 编辑 `notes`

5. 导入与生成区
- 导入 Excel
- 展示导入报告
- 生成 case 草稿
- 展示生成报告

### 5.3 编辑边界

页面只允许编辑业务层字段：

- case 基本信息
- 业务 flow ref
- params
- 检查点摘要
- suite 归属
- 状态与备注

页面不允许直接编辑：

- MCP tool 调用细节
- HDC shell 细节
- backend action 实现代码

## 6. 脚本设计

### 6.1 `build_case_catalog.py`

职责：

- 扫描 `scripts/e2e/cases/**/*.json`
- 读取正式 case JSON
- 回填 `suite_membership`
- 汇总 `flow_refs`
- 读取 `scripts/e2e/results` 中最新结果
- 输出 `metadata/case_catalog.json`

输入：

- `cases/`
- `suites.py`
- `results/`

输出：

- `metadata/case_catalog.json`

### 6.2 `build_coverage_snapshot.py`

职责：

- 读取 `case_catalog.json`
- 读取 `FLOW_REGISTRY`
- 读取 bridge coverage 映射
- 产出覆盖统计快照

输入：

- `metadata/case_catalog.json`
- `flows/registry.py`
- bridge action coverage 数据

输出：

- `metadata/coverage_snapshot.json`

### 6.3 `import_excel_cases.py`

职责：

- 解析 Excel
- 按现有 Excel mapping 规则抽取记录
- 校验 `case_id`、`module`、`flow_ref`、`params`
- 将合格记录写入 `case_catalog.json` 的 `draft/planned` 项
- 生成导入报告

输入：

- Excel 文件
- `FLOW_REGISTRY`
- `case_catalog.json`

输出：

- 更新后的 `case_catalog.json`
- `metadata/import_report.json`

导入策略：

- 新增记录默认进入 `draft`
- 若 `case_id` 已存在，则记录为冲突项，不覆盖正式 case
- `flow_n_ref` 必须存在于 `FLOW_REGISTRY`
- `flow_n_params` 必须能解析为 JSON 对象
- 导入器先产出台账记录，再由生成器决定是否生成 case 草稿

### 6.4 `generate_case_drafts.py`

职责：

- 从 `case_catalog.json` 中筛选 `draft/planned` 且信息完整的记录
- 生成标准 case JSON 草稿
- 写入 `scripts/e2e/drafts/`
- 生成检查点草稿与说明
- 记录 bridge 未覆盖项

输入：

- `metadata/case_catalog.json`
- `case_schema.json`
- `FLOW_REGISTRY`

输出：

- `scripts/e2e/drafts/*.json`
- `metadata/generation_report.json`

生成规则：

- flow ref 必须来自 `FLOW_REGISTRY`
- `allow_unknown` 默认为 `true`
- 如果涉及 bridge 缺口，则在 `notes` 中自动写明
- `assertions` 先生成草稿，不强行自动补全复杂断言

### 6.5 `validate_test_assets.py`

职责：

- 校验 metadata 一致性
- 校验草稿 case 是否符合 schema
- 校验 suite 归属是否合法
- 校验 flow ref 是否存在
- 校验 metadata 与 case JSON 的主键一致性

输出：

- 控制台报告
- 可选 JSON 报告

## 7. 自动生成策略

### 7.1 生成范围

自动生成内容：

- 标准 case 基础结构
- flow 数组
- result policy 默认值
- notes 草稿
- assertions 草稿

人工确认内容：

- 检查点是否真的能验证业务行为
- 是否收紧 `allow_unknown`
- 是否转正到 `scripts/e2e/cases/`
- 是否需要新增 flow executor 或 bridge action

### 7.2 bridge 缺口处理

如果 case 使用到的 flow 对应 action 尚未覆盖：

- `bridge_coverage_status` 标记为 `missing` 或 `partial`
- 生成 case 时保留 `allow_unknown = true`
- 自动在 `notes` 中写明依赖缺口
- 不自动实现 action

## 8. 写用例规范固化

后续新增用例统一遵循以下规则：

- 优先写业务语义 flow，不直接写底层 UI 操作
- 检查点要描述业务结果，不描述脆弱坐标或临时 UI 文案
- `legacy/` 不再作为新增用例入口
- 所有新增 case 必须先进入台账，再生成草稿，再确认转正
- 每个 case 至少要有：
  - 唯一 `case_id`
  - 明确模块
  - flow ref 列表
  - 检查点摘要
  - suite 归属

## 9. 实施顺序

建议按 5 个阶段执行：

### 阶段 1：打底数据层

- 新建 `metadata/`
- 编写 `build_case_catalog.py`
- 编写 `build_coverage_snapshot.py`
- 先把现有 case、suite、bridge 覆盖汇总成 JSON

完成标准：

- 能生成 `case_catalog.json`
- 能生成 `coverage_snapshot.json`

### 阶段 2：Excel 导入层

- 编写 `import_excel_cases.py`
- 实现基础校验
- 生成 `import_report.json`

完成标准：

- Excel 可导入为 `draft/planned`
- 冲突项不会覆盖正式 case

### 阶段 3：草稿生成层

- 编写 `generate_case_drafts.py`
- 将完整记录生成到 `drafts/`
- 生成 `generation_report.json`

完成标准：

- 至少能对 `tool-settings` 模块成功生成草稿

### 阶段 4：静态管理页

- 编写 `docs/test-assets-dashboard.html`
- 从 metadata 读取数据
- 支持筛选、查看、编辑业务层字段
- 支持导入与生成操作说明

完成标准：

- 本地打开页面即可浏览和编辑测试资产

### 阶段 5：校验与规范

- 编写 `validate_test_assets.py`
- 增加统一检查入口
- 补充文档：如何新增用例、如何导入、如何转正

完成标准：

- 新增资产可以被统一校验
- 文档足够让后续按同一规范维护

## 10. 命令约定

建议最终统一为以下命令：

```powershell
python scripts/e2e/tools/build_case_catalog.py
python scripts/e2e/tools/build_coverage_snapshot.py
python scripts/e2e/tools/import_excel_cases.py --file "security-app\\信创工具需求清单_修正版.xlsx"
python scripts/e2e/tools/generate_case_drafts.py
python scripts/e2e/tools/validate_test_assets.py
```

## 11. 验收标准

满足以下条件才算该方案落地完成：

- 能一键生成当前测试资产台账
- 能区分已实现、计划中、草稿待确认、废弃
- 能看到模块、suite、flow、bridge 覆盖
- 能从 Excel 增量导入新用例
- 导入后能生成 case 草稿
- 人工只需重点确认检查点和缺失能力
- 新增用例流程有固定入口和校验规则

## 12. 风险与注意事项

- 不要让管理页变成原始 JSON 编辑器，否则会绕过约束
- 不要让 Excel 成为唯一事实源，否则会和仓库 case 发生反向覆盖冲突
- 不要在生成器里自动实现 backend action，这会把“管理”和“执行”耦合
- `UNKNOWN` 不是失败，但必须在台账中可见，否则会误判覆盖质量

## 13. 本文档用途

这份文档的用途是：

- 先评审方案
- 确认数据结构与边界
- 后续按阶段实施

如果确认方案无误，再开始真正落代码。
