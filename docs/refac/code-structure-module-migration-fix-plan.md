# 代码目录结构迁移修复计划

## 1. 背景与目标

当前 `entry/src/main/ets` 下的 `services`、`viewmodels`、`views`、`components` 同时存在“按模块归档”和“根目录平铺”两种组织方式。部分目录已经形成较清晰的模块边界，例如 `services/peripheral/connection-record`；但大量文件仍平铺在根目录，导致文件归属不直观、跨模块引用路径分散、迁移实施边界不清晰，也增加了后续问题回溯和回滚成本。

本轮修复的目标不是业务重构，而是基于既有迁移方案，逐步将目录结构收敛为“领域目录 + 子能力目录”的统一风格，并把 Git 管理要求纳入实施基线，确保每一批修改都具备以下特征：

- 改动边界明确，可单独说明“本次改了什么”
- 验证结果独立，可判断“本次是否引入问题”
- 提交记录清晰，可支持快速回溯、回滚和复盘

本轮实施坚持以下原则：

- 不修改业务逻辑
- 不顺手混入无关修复
- 不做一次性大包提交
- 不把签名文件、日志、测试产物、临时目录混入迁移提交

## 2. 修复范围

### 2.1 本次范围

- 按既定迁移方案推进目录迁移实施
- 修复因目录迁移导致的 import/export 路径变化
- 分批执行构建验证和最小回归检查
- 建立一套可执行的本地 Git 小步提交规范

### 2.2 非本次范围

- 不重写业务逻辑
- 不拆分现有代码文件
- 不修改类名、方法名、模型定义
- 不重构公共组件体系
- 不处理与本轮目录迁移无关的历史问题

## 3. 实施原则

### 3.1 结构原则

- 目录迁移以 `services/peripheral/connection-record` 为样板
- 先按领域分组，再按子能力分组
- 模块专属文件归档到模块目录，公共复用文件保持原位
- 保持文件内容主体稳定，优先通过目录表达职责边界

### 3.2 实施原则

- 每一批次只处理一层或一类结构，不跨层混做
- 每一批次都必须完成“迁移 -> 修引用 -> 验证 -> 提交”
- 发现边界不清的文件时，优先按主要职责归档，不在本轮展开职责拆分
- 对已有稳定结构的模块，如 `log-manage`，后置处理，避免同时扩散风险

### 3.3 Git 原则

- 禁止使用 `git add .`
- 只允许按路径或按文件精确暂存
- 每个提交只表达一个明确意图，不混入多类修改
- 提交前必须检查 staged 内容，确认没有无关文件进入暂存区

## 4. 分阶段修复计划

### 4.1 阶段一：基线冻结与迁移边界确认

目标：
- 固定本轮迁移边界，避免无关修改混入
- 为分阶段提交建立可追溯起点

具体执行项：
- 新建独立迁移分支，例如 `refactor/module-structure-migration`
- 记录当前工作区状态：`git status --short`
- 记录当前改动规模：`git diff --stat`
- 明确本轮只允许纳入以下目录：
  - `entry/src/main/ets/services`
  - `entry/src/main/ets/viewmodels`
  - `entry/src/main/ets/views`
  - `entry/src/main/ets/components`
  - `docs/refac/code-structure-module-migration-fix-plan.md`
- 明确本轮禁止混入以下目录：
  - `hapsigner/`
  - `hm_logs/`
  - `screenshots/`
  - `.tmp-test/`
  - `test-artifacts/`
  - 其他与目录迁移无关的临时文件
- 固定迁移顺序：`services -> viewmodels -> views -> components`

本阶段建议提交：
- `docs(refactor): add executable module migration fix plan`

本阶段验收：
- 当前迁移边界已固定
- 本轮允许修改目录和禁止混入目录已明确
- 执行顺序已固定

### 4.2 阶段二：迁移 `services`

目标：
- 建立稳定的领域目录骨架
- 优先收口最核心、最容易级联影响上层的服务层

本阶段具体迁移文件：

`firewall`
- `entry/src/main/ets/services/FirewallAuthStateRepository.ets`
  -> `entry/src/main/ets/services/firewall/auth-state/FirewallAuthStateRepository.ets`
- `entry/src/main/ets/services/FirewallToggleAuthService.ets`
  -> `entry/src/main/ets/services/firewall/auth-state/FirewallToggleAuthService.ets`
- `entry/src/main/ets/services/FirewallModeService.ets`
  -> `entry/src/main/ets/services/firewall/mode-control/FirewallModeService.ets`
- `entry/src/main/ets/services/UserFirewallModeService.ets`
  -> `entry/src/main/ets/services/firewall/mode-control/UserFirewallModeService.ets`
- `entry/src/main/ets/services/FirewallPresetService.ets`
  -> `entry/src/main/ets/services/firewall/preset/FirewallPresetService.ets`
- `entry/src/main/ets/services/FirewallPresetConfigService.ets`
  -> `entry/src/main/ets/services/firewall/preset/FirewallPresetConfigService.ets`
- `entry/src/main/ets/services/FirewallService.ets`
  -> `entry/src/main/ets/services/firewall/policy/FirewallService.ets`
- `entry/src/main/ets/services/UserFirewallPolicyService.ets`
  -> `entry/src/main/ets/services/firewall/policy/UserFirewallPolicyService.ets`
- `entry/src/main/ets/services/FirewallCustomRuleService.ets`
  -> `entry/src/main/ets/services/firewall/rule-management/FirewallCustomRuleService.ets`

`peripheral`
- `entry/src/main/ets/services/PeripheralService.ets`
  -> `entry/src/main/ets/services/peripheral/interface-control/PeripheralService.ets`
- `entry/src/main/ets/services/PeripheralPolicyService.ets`
  -> `entry/src/main/ets/services/peripheral/device-policy/PeripheralPolicyService.ets`
- `entry/src/main/ets/services/PeripheralDevicePolicyRepository.ets`
  -> `entry/src/main/ets/services/peripheral/device-policy/PeripheralDevicePolicyRepository.ets`
- `entry/src/main/ets/services/PeripheralTraceRepository.ets`
  -> `entry/src/main/ets/services/peripheral/connection-record/PeripheralTraceRepository.ets`
- `entry/src/main/ets/services/PeripheralConnectionRecordService.ets`
  -> `entry/src/main/ets/services/peripheral/connection-record/PeripheralConnectionRecordService.ets`

`identity`
- `entry/src/main/ets/services/IdentityService.ets`
  -> `entry/src/main/ets/services/identity/settings/IdentityService.ets`
- `entry/src/main/ets/services/AuthService.ets`
  -> `entry/src/main/ets/services/identity/auth/AuthService.ets`

`tool-settings`
- `entry/src/main/ets/services/SystemSettingsService.ets`
  -> `entry/src/main/ets/services/tool-settings/system-settings/SystemSettingsService.ets`
- `entry/src/main/ets/services/ToolSettingsRepository.ets`
  -> `entry/src/main/ets/services/tool-settings/system-settings/ToolSettingsRepository.ets`

`admin`
- `entry/src/main/ets/services/EnterpriseAdminService.ets`
  -> `entry/src/main/ets/services/admin/activation/EnterpriseAdminService.ets`

建议拆分为以下提交：
- `chore(refactor): create services domain folders`
- `chore(refactor): move firewall services into module folders`
- `fix(imports): update references after firewall services move`
- `chore(refactor): move peripheral services into module folders`
- `fix(imports): update references after peripheral services move`
- `chore(refactor): move identity tool-settings and admin services`
- `fix(imports): update references after remaining services move`

本阶段重点检查引用：
- `viewmodels/**/*.ets` 对上述服务路径的引用
- `views/**/*.ets` 直接引用服务的场景
- `components/**/*.ets` 中直接依赖服务的场景
- `services/**/index.ets` 或其他导出层

本阶段验收：
- 上述 19 个 `services` 迁移目标文件全部落位
- `rg "services/(Firewall|Peripheral|Identity|SystemSettings|ToolSettings|EnterpriseAdmin|Auth)" entry/src/main/ets` 不再命中旧导入路径
- 构建通过

### 4.3 阶段三：迁移 `viewmodels`

目标：
- 让状态层与服务层的领域边界保持一致

本阶段具体迁移文件：
- `entry/src/main/ets/viewmodels/DashboardViewModel.ets`
  -> `entry/src/main/ets/viewmodels/dashboard/overview/DashboardViewModel.ets`
- `entry/src/main/ets/viewmodels/IdentitySettingsViewModel.ets`
  -> `entry/src/main/ets/viewmodels/identity/settings/IdentitySettingsViewModel.ets`
- `entry/src/main/ets/viewmodels/ToolSettingsViewModel.ets`
  -> `entry/src/main/ets/viewmodels/tool-settings/system-settings/ToolSettingsViewModel.ets`
- `entry/src/main/ets/viewmodels/PeripheralViewModel.ets`
  -> `entry/src/main/ets/viewmodels/peripheral/overview/PeripheralViewModel.ets`
- `entry/src/main/ets/viewmodels/InterfaceControlViewModel.ets`
  -> `entry/src/main/ets/viewmodels/peripheral/interface-control/InterfaceControlViewModel.ets`
- `entry/src/main/ets/viewmodels/PeripheralPolicyViewModel.ets`
  -> `entry/src/main/ets/viewmodels/peripheral/device-policy/PeripheralPolicyViewModel.ets`
- `entry/src/main/ets/viewmodels/PeripheralRecordViewModel.ets`
  -> `entry/src/main/ets/viewmodels/peripheral/connection-record/PeripheralRecordViewModel.ets`
- `entry/src/main/ets/viewmodels/PeripheralRecordPresentationMapper.ets`
  -> `entry/src/main/ets/viewmodels/peripheral/connection-record/PeripheralRecordPresentationMapper.ets`
- `entry/src/main/ets/viewmodels/log-manage/LogManageViewModel.ets`
  -> `entry/src/main/ets/viewmodels/log-manage/overview/LogManageViewModel.ets`
- `entry/src/main/ets/viewmodels/log-manage/LogStorageSettingsViewModel.ets`
  -> `entry/src/main/ets/viewmodels/log-manage/storage-settings/LogStorageSettingsViewModel.ets`

建议拆分为以下提交：
- `chore(refactor): move dashboard and identity viewmodels`
- `fix(imports): update references after dashboard and identity viewmodel move`
- `chore(refactor): move peripheral viewmodels into module folders`
- `fix(imports): update references after peripheral viewmodel move`
- `chore(refactor): move tool-settings and log-manage viewmodels`
- `fix(imports): update references after remaining viewmodel move`

本阶段重点检查引用：
- `views/**/*.ets` 对 `viewmodels` 的引用
- `components/**/*.ets` 对 `viewmodels` 的引用
- `viewmodels/**/index.ets` 或聚合导出层

本阶段验收：
- 上述 10 个 `viewmodels` 迁移目标文件全部落位
- `rg "viewmodels/(DashboardViewModel|IdentitySettingsViewModel|ToolSettingsViewModel|PeripheralViewModel|InterfaceControlViewModel|PeripheralPolicyViewModel|PeripheralRecordViewModel|PeripheralRecordPresentationMapper|LogManageViewModel|LogStorageSettingsViewModel)" entry/src/main/ets` 不再命中旧导入路径
- 构建通过

### 4.4 阶段四：迁移 `views`

目标：
- 统一页面入口文件归属，提升页面层可读性

本阶段具体迁移文件：
- `entry/src/main/ets/views/DashboardPage.ets`
  -> `entry/src/main/ets/views/dashboard/overview/DashboardPage.ets`
- `entry/src/main/ets/views/FirewallPage.ets`
  -> `entry/src/main/ets/views/firewall/overview/FirewallPage.ets`
- `entry/src/main/ets/views/FirewallRulesPage.ets`
  -> `entry/src/main/ets/views/firewall/rule-management/FirewallRulesPage.ets`
- `entry/src/main/ets/views/HelpFeedbackPage.ets`
  -> `entry/src/main/ets/views/help-feedback/overview/HelpFeedbackPage.ets`
- `entry/src/main/ets/views/IdentityPage.ets`
  -> `entry/src/main/ets/views/identity/settings/IdentityPage.ets`
- `entry/src/main/ets/views/LogManagePage.ets`
  -> `entry/src/main/ets/views/log-manage/overview/LogManagePage.ets`
- `entry/src/main/ets/views/PeripheralPage.ets`
  -> `entry/src/main/ets/views/peripheral/overview/PeripheralPage.ets`
- `entry/src/main/ets/views/ToolSettingsPage.ets`
  -> `entry/src/main/ets/views/tool-settings/system-settings/ToolSettingsPage.ets`

建议拆分为以下提交：
- `chore(refactor): move dashboard firewall and identity views`
- `fix(imports): update references after dashboard firewall and identity view move`
- `chore(refactor): move peripheral tool-settings help-feedback and log-manage views`
- `fix(imports): update references after remaining view move`

本阶段重点检查引用：
- `pages/MainPage` 中页面导入路径
- 页面路由注册和跳转入口
- 页面内对 `components`、`viewmodels` 的相对路径引用

本阶段验收：
- 上述 8 个 `views` 迁移目标文件全部落位
- `rg "views/(DashboardPage|FirewallPage|FirewallRulesPage|HelpFeedbackPage|IdentityPage|LogManagePage|PeripheralPage|ToolSettingsPage)" entry/src/main/ets` 不再命中旧导入路径
- 页面入口链路不因相对路径变化而失效
- 构建通过

### 4.5 阶段五：迁移模块专属 `components`

目标：
- 收口模块私有组件，避免组件层继续平铺

本阶段具体迁移文件：

`peripheral`
- `entry/src/main/ets/components/peripheral/ConnectionDetailDialog.ets`
  -> `entry/src/main/ets/components/peripheral/connection-record/ConnectionDetailDialog.ets`
- `entry/src/main/ets/components/peripheral/DeviceRecordList.ets`
  -> `entry/src/main/ets/components/peripheral/connection-record/DeviceRecordList.ets`
- `entry/src/main/ets/components/peripheral/InterfaceControlTab.ets`
  -> `entry/src/main/ets/components/peripheral/interface-control/InterfaceControlTab.ets`
- `entry/src/main/ets/components/peripheral/PolicyList.ets`
  -> `entry/src/main/ets/components/peripheral/device-policy/PolicyList.ets`

`log-manage`
- `entry/src/main/ets/components/LogDetailDialog.ets`
  -> `entry/src/main/ets/components/log-manage/detail/LogDetailDialog.ets`
- `entry/src/main/ets/components/LogEntriesPanel.ets`
  -> `entry/src/main/ets/components/log-manage/entries/LogEntriesPanel.ets`
- `entry/src/main/ets/components/LogPaginationBar.ets`
  -> `entry/src/main/ets/components/log-manage/entries/LogPaginationBar.ets`
- `entry/src/main/ets/components/LogStorageSettingsPanel.ets`
  -> `entry/src/main/ets/components/log-manage/storage-settings/LogStorageSettingsPanel.ets`

`firewall`
- `entry/src/main/ets/components/AddRuleDialog.ets`
  -> `entry/src/main/ets/components/firewall/rule-management/AddRuleDialog.ets`
- `entry/src/main/ets/components/UserFirewallControlDialog.ets`
  -> `entry/src/main/ets/components/firewall/policy/UserFirewallControlDialog.ets`

建议拆分为以下提交：
- `chore(refactor): move peripheral module components`
- `fix(imports): update references after peripheral component move`
- `chore(refactor): move firewall and log-manage module components`
- `fix(imports): update references after firewall and log-manage component move`

本阶段重点检查引用：
- `views/**/*.ets` 对模块组件的引用
- `components/**/*.ets` 组件间互相引用
- `components/peripheral/connection-record/index.ets` 等 barrel 文件

本阶段验收：
- 上述 10 个模块专属组件迁移目标文件全部落位
- 公共组件未被迁移
- `rg "components/(LogDetailDialog|LogEntriesPanel|LogPaginationBar|LogStorageSettingsPanel|AddRuleDialog|UserFirewallControlDialog|peripheral/(ConnectionDetailDialog|DeviceRecordList|InterfaceControlTab|PolicyList))" entry/src/main/ets` 不再命中旧导入路径
- 构建通过

### 4.6 阶段六：统一收尾

目标：
- 清理迁移残留，形成可交付状态

本阶段具体执行项：
- 清理 `services`、`viewmodels`、`views`、`components` 下的旧路径引用残留
- 检查并修复以下 barrel/export 文件：
  - `entry/src/main/ets/services/peripheral/connection-record/index.ets`
  - `entry/src/main/ets/viewmodels/peripheral/connection-record/index.ets`
  - `entry/src/main/ets/views/peripheral/connection-record/index.ets`
  - `entry/src/main/ets/components/peripheral/connection-record/index.ets`
- 使用全文搜索确认不再引用旧文件位置
- 执行一次全量构建
- 执行一次最小冒烟检查，至少覆盖：
  - 主页面可加载
  - `dashboard`
  - `firewall`
  - `peripheral`
  - `identity`
  - `tool-settings`

建议提交：
- `fix(refactor): clean stale exports and old path references`
- `chore(verify): validate module structure migration build and smoke checks`

本阶段验收：
- 全文搜索无旧路径残留
- barrel/export 路径可用
- 构建通过
- 无明显循环依赖和迁移残留问题

## 5. Git 小步提交策略

### 5.1 基本要求

- 禁止执行 `git add .`
- 只按本批次涉及的目录或文件暂存
- 提交前必须检查 staged 内容
- 暂存区出现无关文件时，必须先移除再提交

### 5.2 暂存方式

推荐使用以下方式控制提交边界：

```powershell
git add entry/src/main/ets/services/firewall
git add entry/src/main/ets/services/peripheral
git add entry/src/main/ets/viewmodels/peripheral
```

当目录级粒度仍然过大时，继续细化到单文件：

```powershell
git add entry/src/main/ets/services/FirewallService.ets
git add entry/src/main/ets/services/firewall/policy/FirewallService.ets
```

### 5.3 提交前检查

每次提交前至少执行以下检查：

```powershell
git diff --cached --stat
git diff --cached
```

检查重点：

- staged 文件是否只属于当前批次
- 是否误混入 `hapsigner/`、日志、截图、临时目录、测试产物
- 是否把设计文档、代码迁移和无关修复混进同一提交

### 5.4 推荐提交粒度

单次提交只表达一类意图，建议按以下实际粒度执行：

- 阶段一文档固化：1 个提交
- `services`：6 到 7 个提交
- `viewmodels`：4 到 6 个提交
- `views`：3 到 4 个提交
- `components`：4 个提交
- 统一收尾：1 到 2 个提交

若一次改动超过约 15 到 25 个文件，继续拆小，不要把多个模块的“迁文件 + 修引用”压成一个提交。

### 5.5 推荐提交样式

建议直接使用以下提交序列：

- `docs(refactor): add executable module migration fix plan`
- `chore(refactor): create services domain folders`
- `chore(refactor): move firewall services into module folders`
- `fix(imports): update references after firewall services move`
- `chore(refactor): move peripheral services into module folders`
- `fix(imports): update references after peripheral services move`
- `chore(refactor): move identity tool-settings and admin services`
- `fix(imports): update references after remaining services move`
- `chore(refactor): move dashboard and identity viewmodels`
- `fix(imports): update references after dashboard and identity viewmodel move`
- `chore(refactor): move peripheral viewmodels into module folders`
- `fix(imports): update references after peripheral viewmodel move`
- `chore(refactor): move tool-settings and log-manage viewmodels`
- `fix(imports): update references after remaining viewmodel move`
- `chore(refactor): move dashboard firewall and identity views`
- `fix(imports): update references after dashboard firewall and identity view move`
- `chore(refactor): move peripheral tool-settings help-feedback and log-manage views`
- `fix(imports): update references after remaining view move`
- `chore(refactor): move peripheral module components`
- `fix(imports): update references after peripheral component move`
- `chore(refactor): move firewall and log-manage module components`
- `fix(imports): update references after firewall and log-manage component move`
- `fix(refactor): clean stale exports and old path references`
- `chore(verify): validate module structure migration build and smoke checks`

## 6. 每批验收标准

每一批迁移完成后，都应满足以下条件：

- 当前批次列出的具体文件已经全部迁移到目标路径
- 当前批次涉及的旧导入路径已清理
- 项目构建通过
- 未引入新的业务逻辑变化
- 无明显循环依赖
- 提交记录能够说明“迁了什么、修了什么、验证了什么”

按阶段最少应达到以下文件数量：

- `services`：19 个目标文件全部落位
- `viewmodels`：10 个目标文件全部落位
- `views`：8 个目标文件全部落位
- `components`：10 个目标文件全部落位

## 7. 主要风险与控制措施

### 7.1 `services` 级联风险高

风险：
- 服务层变动会直接影响 `viewmodels`、`views` 和部分组件

控制措施：
- 先迁目录，再修引用，再验证
- 按模块拆小提交，避免一次迁完整个服务层

### 7.2 `log-manage` 结构存在既有层次

风险：
- 与主迁移链混做时，容易扩大修改面

控制措施：
- 后置处理
- 仅按既定方案补齐目录层次，不顺手重构内部结构

### 7.3 组件公共层与模块层混淆

风险：
- 误把公共组件迁入模块目录，导致复用退化

控制措施：
- 只迁移明确属于模块私有职责的组件
- 公共组件维持原位

### 7.4 当前工作区已存在无关变更

风险：
- 无关文件混入迁移提交，破坏提交可追溯性

控制措施：
- 只按路径暂存
- 每次提交前检查 staged 清单
- 不把签名文件、日志、测试产物、临时目录纳入迁移链

## 8. 预期结果

完成本轮修复后，代码目录结构将统一到“领域目录 + 子能力目录”的组织方式。后续模块维护、影响面评估、问题定位和分阶段重构都会更清晰。更关键的是，整个迁移过程会沉淀为一串边界明确、验证独立的小步提交，而不是不可回溯的大提交，从而确保修改过程具备稳定的可追溯性和可回滚性。
