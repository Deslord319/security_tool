# AI 常见任务手册

本文面向后续接手本仓库的 AI 编码助手，补充“遇到常见开发任务时应该先看什么、改什么、验什么”。它不是 PRD、RFC 或模块设计文档的替代品；具体业务结论仍以 `docs/02-总体设计/PRD.md`、`docs/02-总体设计/总体设计RFC.md` 和 `docs/03-模块设计/*.md` 为准。

## 1. 进入任务后的固定读法

每次开始改动前按以下顺序缩小上下文：

1. 先读 `AGENTS.md`，确认构建、签名、权限、日志、编码和“模块设计先行”规则。
2. 再读 `README.md`，确认当前架构、目录结构、路由和测试入口。
3. 涉及需求、架构、模块边界时，阅读 `docs/02-总体设计/PRD.md` 和 `docs/02-总体设计/总体设计RFC.md`。
4. 涉及任一模块行为、状态、交互、服务职责或验收口径时，先读并更新 `docs/03-模块设计/` 下对应模块设计文档。
5. 涉及测试链路时，阅读 `docs/04-测试文档/DEVICE_TEST_FRAMEWORK.md`、`docs/04-测试文档/e2e测试/端到端测试框架设计.md` 和 `scripts/e2e/README.md`。
6. 涉及 RDB、Repository 或持久化时，阅读 `docs/storage-architecture-standard.md`。

## 2. 通用实施流程

1. 确认影响范围：模块、路由、权限、系统能力、存储、测试、文档索引。
2. 判断是否触发模块设计更新；触发时必须先更新对应模块设计文档，再改代码。
3. 按既有分层修改：Page/Component -> ViewModel -> Service -> Repository/Provider/Adapter -> 系统能力或持久化。
4. 同步测试：UT 覆盖纯逻辑和状态机，ohosTest 覆盖页面和设备能力边界，E2E 覆盖跨模块主链路。
5. 同步索引和约束文档：`README.md`、`AGENTS.md`、PRD、RFC、模块设计、测试文档。
6. 运行文档一致性检查和必要测试，最后再提交。

## 3. 常见任务卡片

### 3.1 新增或调整权限

先确认权限对应的业务模块和系统能力，更新相关模块设计文档中的“系统能力调用、权限、MDM、企业管理员依赖”和“测试覆盖”。

实施时必须同步以下位置：

- `entry/src/main/module.json5` 的 `requestPermissions`
- `hapsigner/UnsgnedDebugProfileTemplate.json` 的 `acls.allowed-acls`
- `hapsigner/UnsgnedDebugProfileTemplate.json` 的 `permissions.restricted-permissions`
- `AGENTS.md` 的“当前权限列表”
- 如果权限影响 PRD/RFC 的能力边界，同步更新 `docs/02-总体设计/PRD.md` 和 `docs/02-总体设计/总体设计RFC.md`

修改 `hapsigner/UnsgnedDebugProfileTemplate.json` 后，必须重新生成 p7b，再执行签名。提交前至少运行：

```bash
python scripts/check_docs_consistency.py
```

### 3.2 修改页面交互、状态或路由

先更新对应模块设计文档的以下部分：

- 模块目标与范围
- 页面结构与交互流程
- 状态模型和状态流转
- ViewModel / Service / Repository 职责边界
- 非目标范围
- `4.1 实施步骤与测试验收`

涉及路由时同步检查：

- `entry/src/main/ets/constants/RouteIds.ets`
- `entry/src/main/ets/pages/MainPage.ets`
- `README.md` 的页面路由表和架构说明
- `AGENTS.md` 的页面路由表和模块设计文档映射
- `docs/02-总体设计/PRD.md`
- `docs/02-总体设计/总体设计RFC.md`
- 对应 ohosTest 或 E2E 用例

页面不应直接承载系统能力细节。页面负责渲染和用户动作分发，ViewModel 负责状态聚合和命令编排，Service/Repository/Provider 负责业务规则、系统能力和持久化边界。

### 3.3 新增 E2E 用例

先判断新增用例是否改变模块级验收口径。如果改变，先更新对应模块设计文档的 `4.1 实施步骤与测试验收`。

实施顺序：

1. 选择或新增 `scripts/e2e/cases/` 下的模块用例。
2. 如果只是组合既有动作，优先复用现有操作和断言。
3. 如果需要新动作，先确认页面 `data-test-id`、测试驱动、适配器职责是否已有模式可复用。
4. 更新 `scripts/e2e/README.md` 或测试框架设计文档中的覆盖说明。
5. 运行资产校验和文档一致性检查。

常用命令：

```bash
python scripts/e2e/tools/validate_test_assets.py
python scripts/check_docs_consistency.py
```

`scripts/check_docs_consistency.py` 会同步检查模块的 UT、ohosTest 和 E2E 用例目录是否仍存在，避免新增模块或改路由后遗漏测试入口。

### 3.4 调整 RDB、缓存或持久化结构

先阅读 `docs/storage-architecture-standard.md`，再阅读受影响模块设计文档。设计文档需要写清楚：

- 数据模型字段和约束
- 表结构、索引、迁移策略
- Repository 与 Store/Provider 的职责边界
- 清理、导出、审计或保留策略
- 回滚和异常兜底
- UT、ohosTest、E2E 的覆盖边界

实施时避免让页面或 ViewModel 直接拼接 SQL。数据访问应收敛到对应 Repository 或既有存储封装内。

### 3.5 调整防火墙规则或策略

先更新 `docs/03-模块设计/防火墙管理组件设计说明.md`，确认规则列表、详情页、系统防火墙 API、Repository 和本地缓存之间的边界。

实施时重点检查：

- `FirewallPage` / `FirewallRulesPage` 只处理视图和用户动作
- `FirewallViewModel` 聚合规则状态、加载态、错误态和提交结果
- `FirewallService` 编排业务规则
- `FirewallSystemRepository` 封装系统防火墙能力
- 本地 Repository 只处理规则持久化和查询
- 新增系统权限时按“新增或调整权限”任务卡同步

测试覆盖至少包括规则加载、启停、异常兜底、权限失败、空态和设备能力不可用场景。

### 3.6 调整外设运行时或策略

先更新 `docs/03-模块设计/外设管理组件设计说明.md`。外设模块通常涉及设备连接事件、策略持久化、管理员激活状态和 UI 展示状态，设计文档需要把这些状态流转写完整。

实施时重点检查：

- 运行时事件来源和订阅生命周期
- 策略 Repository 的读写边界
- 管理员未激活时的降级展示和操作禁用
- 蓝牙、USB、Wi-Fi 等能力对应权限是否完整
- E2E 是否覆盖主要策略开关和异常提示

### 3.7 调整日志采集、查询或导出

先更新 `docs/03-模块设计/日志管理组件设计说明.md`。日志模块需要区分业务日志、审计事件、查询条件、导出文件和 UI 列表状态。

实施时重点检查：

- 采集器和数据源职责是否清晰
- Repository 是否统一处理查询、分页、保留策略和导出
- ViewModel 是否只暴露页面所需状态
- 导出失败、空结果、权限不足是否有用户可见反馈
- 测试是否覆盖筛选、分页、导出和异常路径

### 3.8 调整身份鉴别或启动认证

先更新 `docs/03-模块设计/身份鉴别组件设计说明.md` 和必要的 `docs/03-模块设计/工具设置组件设计说明.md`。身份鉴别通常会影响启动流程、锁定策略、生物识别、密码策略和用户可见错误态。

实施时重点检查：

- `EntryAbility` 或启动链路是否仍只负责入口编排
- 身份状态、锁定状态和策略状态是否有明确来源
- 生物识别和账号权限是否同步到权限文档
- 工具设置中的开关是否与身份模块状态一致
- 测试覆盖启动认证、失败重试、锁定、禁用认证和降级路径

## 4. 提交前最小验证矩阵

| 改动类型 | 最小验证 |
|---|---|
| 纯文档或索引 | `python scripts/check_docs_consistency.py`、`git diff --check` |
| 权限、签名或包名 | `python scripts/check_docs_consistency.py`，必要时重新 p7b + 签名 |
| 模块行为或状态 | 对应 UT、必要 ohosTest、`python scripts/check_docs_consistency.py` |
| 页面交互或路由 | 对应 ohosTest/E2E、`python scripts/check_docs_consistency.py` |
| E2E 资产 | `python scripts/e2e/tools/validate_test_assets.py`、`python scripts/check_docs_consistency.py` |
| RDB 或 Repository | Repository UT、迁移/兼容验证、`python scripts/check_docs_consistency.py` |

如果本机缺少 DevEco Studio、设备或签名环境，最终说明和提交说明中必须写清楚未运行的验证及原因。

## 5. 不要做的事

- 不要在脚本、测试或说明中写死本机 DevEco、Java、SDK 绝对路径。
- 不要用编码不明确的 PowerShell 整文件重写中文文档。
- 不要绕过 ViewModel/Service/Repository 分层，让页面直接调用系统能力或持久化细节。
- 不要只改代码不改模块设计文档，除非本次改动明确属于 `AGENTS.md` 中“可不更新模块设计文档”的场景。
- 不要提交构建产物、签名产物、临时日志或本机 IDE 缓存。
- 不要把过期过程文档当成设计依据；应以 PRD、RFC、模块设计和测试文档为准。

## 6. 最终回复或提交说明模板

建议最终说明至少包含：

```text
已更新：
- <文档或代码变更摘要>

模块设计文档：
- 已更新 <模块设计文档路径>
  或
- 未更新模块设计文档：本次仅为 <原因>，不改变模块行为、状态、交互、职责或验收口径。

验证：
- <已运行命令>
- <未运行命令及原因>
```
