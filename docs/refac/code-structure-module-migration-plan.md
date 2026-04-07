# 代码目录结构迁移方案设计

## 1. 背景与目标

- 背景：当前 `entry/src/main/ets` 下的 `services`、`viewmodels`、`views`、`components` 同时存在“按模块归档”和“根目录平铺”两种组织方式。以 `services/peripheral/connection-record` 为代表的新结构已经体现出较清晰的领域边界与职责分层，但其他模块尚未统一到同一风格。
- 目标：在不拆分既有代码文件的前提下，逐步将各功能模块迁移为“领域目录 + 子能力目录”的目录结构，降低后续维护成本，提升文件归属可读性，并为后续进一步重构预留稳定骨架。

## 2. 范围

### 2.1 本次范围

- 输出目录结构迁移方案文档。
- 明确各模块建议子目录及职责边界。
- 形成具体到文件的迁移清单。
- 形成迁移前后目录清单对比。
- 给出分批落地建议与风险提示。

### 2.2 非本次范围

- 不执行任何代码迁移。
- 不拆分现有代码文件。
- 不修改类名、方法名、模型定义和业务逻辑。
- 不在本方案中展开 import 修复、兼容导出层、构建验证脚本等实施细节。
- 不为外设连接记录新增 `connection-record-query` 等新命名，保持现状语义，相关查询与仓储能力继续视为连接记录能力的一部分。

## 3. 代码文件说明

| 文件路径 | 角色 | 说明 | 变更类型 |
| --- | --- | --- | --- |
| `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_producer_contract.ets` | 参考样板 | 定义 Producer / Consumer / Pipeline 契约，是本轮目录风格对齐的主要参考 | 仅参考 |
| `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_runtime_producer_adapter.ets` | 参考样板 | 体现“运行时采集适配器”职责 | 仅参考 |
| `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_pipeline.ets` | 参考样板 | 体现“编排层”职责 | 仅参考 |
| `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_usb_consumer.ets` | 参考样板 | 体现“按外设类型拆 consumer”职责 | 仅参考 |
| `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_bluetooth_acl_consumer.ets` | 参考样板 | 体现“按外设类型拆 consumer”职责 | 仅参考 |
| `entry/src/main/ets/services/*.ets` | 迁移对象 | 当前仍有大量服务平铺在根目录，需要按模块与子能力归档 | 目录迁移 |
| `entry/src/main/ets/viewmodels/*.ets` | 迁移对象 | 当前仅少量模块已按子目录归档，需与领域结构对齐 | 目录迁移 |
| `entry/src/main/ets/views/*.ets` | 迁移对象 | 页面入口文件当前以根目录平铺为主 | 目录迁移 |
| `entry/src/main/ets/components/*.ets` | 迁移对象 | 部分模块专属组件仍位于根目录，需与所属模块对齐 | 目录迁移 |
| `entry/src/main/ets/components/peripheral/*.ets` | 迁移对象 | 外设组件已初步归档，但尚未按子能力进一步收口 | 目录迁移 |

## 4. 模块设计

### 4.1 模块职责

- 本方案不是业务功能重构方案，而是目录归属与命名收敛方案。
- 目录设计遵循“先按领域分组，再按子能力分组”的原则。
- 保持现有文件内容不拆分，优先通过目录归位来表达模块边界。
- 公共基础层与模块专属层分开处理：公共组件保持稳定，模块专属文件优先归档到对应领域目录。
- `services/peripheral/connection-record` 作为样板保留现状，不再额外引入新的同义目录名。

### 4.2 核心流程

1. 以现有 `services/peripheral/connection-record` 为参考样板，抽取统一的目录组织原则。
2. 盘点 `services`、`viewmodels`、`views`、`components` 中当前平铺的业务文件。
3. 按模块领域归档，如 `firewall`、`peripheral`、`identity`、`tool-settings`、`dashboard`、`help-feedback`。
4. 在领域下继续按子能力归档，如 `mode-control`、`policy`、`rule-management`、`interface-control`、`device-policy`。
5. 形成迁移映射表，先做目录重排，后续再在实施阶段统一处理 import 修复与回归验证。

### 4.3 状态与数据影响

- 本轮方案阶段仅涉及目录规划，不改变运行态数据结构。
- 由于不调整实现逻辑，现有 preferences、系统 API 调用、模型定义和页面状态流不受影响。
- 真正执行迁移时，主要影响点将是文件引用路径和 barrel export 路径。

### 4.4 异常与边界处理

- 对于职责明确但文件数量少的模块，可先只做一级或二级目录归档，不强制过度拆分。
- 对于当前已经形成较稳定内部结构的模块，如 `log-manage`，原则上以保留现状为主，仅在明显缺失模块边界时补齐外围目录。
- 对于公共组件，不因“归档整齐”而强行迁移，避免把共享层错误模块化。
- 对于外设连接记录相关能力，保持现有 `connection-record` 目录命名，不额外引入 `connection-record-query` 等新命名。

## 5. 系统模块接口

| 系统模块/API | 用途 | 调用位置 | 权限/约束 | 备注 |
| --- | --- | --- | --- | --- |
| `@kit.NetworkKit/netFirewall` | 防火墙策略与规则读写 | `FirewallService.ets`、`UserFirewallPolicyService.ets`、`FirewallPresetService.ets` | 依赖企业管理相关权限与能力 | 本方案不改变调用方式，仅调整目录归属 |
| `@kit.MDMKit` | 外设控制、密码策略等企业管理能力 | `PeripheralService.ets`、`IdentityService.ets` | 依赖企业管理员激活 | 目录迁移不影响 API 边界 |
| `@ohos.enterprise.restrictions` | 外设禁用策略探测与设置 | `PeripheralService.ets`、`EnterpriseAdminService.ets` | 依赖管理员激活 | 保持现状 |
| `@kit.ArkData/preferences` | 本地配置、规则、仓储持久化 | 多个 Repository / Service | 依赖应用上下文 | 迁移仅影响文件位置 |
| `@kit.UserAuthenticationKit/userAuth` | PIN / 指纹认证 | `AuthService.ets` | 依赖设备认证能力与授权 | 保持现状 |
| `@kit.BasicServicesKit/commonEventManager` | USB / 蓝牙运行时事件订阅 | 外设连接记录运行时采集链路 | 依赖系统事件订阅能力 | 作为目录设计样板保留 |

## 6. 风险与待确认

### 6.1 风险

- 目录迁移虽然不改业务逻辑，但会造成大面积 import 路径变化，实施阶段存在编译失败风险。
- 若同时迁移 `services`、`viewmodels`、`views`、`components`，单次改动面过大，回归定位成本高。
- 某些文件职责横跨多个子能力时，目录归属可能存在边界争议，需要先以“主要职责”归档。
- 若对公共组件误做模块归档，可能增加跨模块复用成本。

### 6.2 待确认

- 本方案默认先迁移 `services`，再迁移 `viewmodels`，最后迁移 `views/components`，实施顺序是否接受。
- `log-manage` 当前已具备较完整子目录结构，后续是否仅补外围归档而不大幅调整内部层次。
- `tool-settings/system-settings` 当前同时承载“工具配置持久化”和“打开系统设置页面”两类职责，后续是否继续保持合并归档。

## 7. 关联文档

- 现有参考文档：`docs/03-模块设计/外设管理组件设计说明.md`
- 现有参考文档：`docs/03-模块设计/防火墙管理组件设计说明.md`
- 现有参考文档：`docs/03-模块设计/身份鉴别组件设计说明.md`
- 现有参考文档：`docs/03-模块设计/工具设置组件设计说明.md`

## 附录 A：建议迁移后的子目录职责说明

### A.1 firewall

`firewall/mode-control`
- 负责防火墙整体模式切换与状态管理。
- 对应文件：`FirewallModeService.ets`、`UserFirewallModeService.ets`

`firewall/policy`
- 负责防火墙策略与规则的底层读写能力。
- 对应文件：`FirewallService.ets`、`UserFirewallPolicyService.ets`

`firewall/rule-management`
- 负责自定义规则的增删改查与持久化。
- 对应文件：`FirewallCustomRuleService.ets`

`firewall/preset`
- 负责预设模式配置读取与规则模板生成。
- 对应文件：`FirewallPresetConfigService.ets`、`FirewallPresetService.ets`

`firewall/auth-state`
- 负责认证锁定状态、受保护操作认证流程。
- 对应文件：`FirewallAuthStateRepository.ets`、`FirewallToggleAuthService.ets`

### A.2 peripheral

`peripheral/interface-control`
- 负责 USB、蓝牙、Wi-Fi、HDC、网络、打印机、摄像头、麦克风等接口级总控。
- 对应文件：`PeripheralService.ets`

`peripheral/device-policy`
- 负责单设备接入策略及其展示数据构建。
- 对应文件：`PeripheralDevicePolicyRepository.ets`、`PeripheralPolicyService.ets`

`peripheral/connection-record`
- 负责连接记录相关能力，保持现有语义，不再额外拆出新的同义目录名。
- 运行时采集链路对应文件：`peripheral_connection_record_producer_contract.ets`、`peripheral_connection_record_runtime_producer_adapter.ets`、`peripheral_connection_record_pipeline.ets`、`peripheral_connection_record_usb_consumer.ets`、`peripheral_connection_record_bluetooth_acl_consumer.ets`
- 记录查询与仓储相关文件：`PeripheralTraceRepository.ets`、`PeripheralConnectionRecordService.ets`

### A.3 identity

`identity/settings`
- 负责身份鉴别策略设置，如密码复杂度、有效期等。
- 对应文件：`IdentityService.ets`

`identity/auth`
- 负责 PIN、指纹等认证能力调用。
- 对应文件：`AuthService.ets`

### A.4 tool-settings

`tool-settings/system-settings`
- 负责工具设置持久化以及拉起系统设置相关能力。
- 对应文件：`ToolSettingsRepository.ets`、`SystemSettingsService.ets`

### A.5 admin

`admin/activation`
- 负责企业管理员激活状态探测、启用命令构造和缺失态识别。
- 对应文件：`EnterpriseAdminService.ets`

### A.6 log-manage

`log-manage/collector`
- 负责日志采集主流程编排。

`log-manage/source`
- 负责日志来源接入。

`log-manage/repository`
- 负责日志与配置持久化。

`log-manage/export`
- 负责日志导出。

`log-manage/mapper`
- 负责日志规范化映射。

`log-manage/common`
- 负责模块内部 ports、错误码和通用协议定义。

## 附录 B：具体到文件的迁移清单

### B.1 services

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

### B.2 viewmodels

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

### B.3 views

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

### B.4 components

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

## 附录 C：迁移前后目录清单对比

### C.1 迁移前

```text
services/
├─ AuthService.ets
├─ EnterpriseAdminService.ets
├─ FirewallAuthStateRepository.ets
├─ FirewallCustomRuleService.ets
├─ FirewallModeService.ets
├─ FirewallPresetConfigService.ets
├─ FirewallPresetService.ets
├─ FirewallService.ets
├─ FirewallToggleAuthService.ets
├─ IdentityService.ets
├─ PeripheralConnectionRecordService.ets
├─ PeripheralDevicePolicyRepository.ets
├─ PeripheralPolicyService.ets
├─ PeripheralService.ets
├─ PeripheralTraceRepository.ets
├─ SystemSettingsService.ets
├─ ToolSettingsRepository.ets
├─ UserFirewallModeService.ets
├─ UserFirewallPolicyService.ets
├─ log-manage/
└─ peripheral/connection-record/

viewmodels/
├─ DashboardViewModel.ets
├─ IdentitySettingsViewModel.ets
├─ InterfaceControlViewModel.ets
├─ PeripheralPolicyViewModel.ets
├─ PeripheralRecordPresentationMapper.ets
├─ PeripheralRecordViewModel.ets
├─ PeripheralViewModel.ets
├─ ToolSettingsViewModel.ets
├─ log-manage/
└─ peripheral/connection-record/

views/
├─ DashboardPage.ets
├─ FirewallPage.ets
├─ FirewallRulesPage.ets
├─ HelpFeedbackPage.ets
├─ IdentityPage.ets
├─ LogManagePage.ets
├─ PeripheralPage.ets
├─ ToolSettingsPage.ets
└─ peripheral/connection-record/

components/
├─ 通用组件若干
├─ LogDetailDialog.ets
├─ LogEntriesPanel.ets
├─ LogPaginationBar.ets
├─ LogStorageSettingsPanel.ets
├─ AddRuleDialog.ets
├─ UserFirewallControlDialog.ets
└─ peripheral/
   ├─ ConnectionDetailDialog.ets
   ├─ DeviceRecordList.ets
   ├─ InterfaceControlTab.ets
   ├─ PolicyList.ets
   └─ connection-record/index.ets
```

### C.2 迁移后

```text
services/
├─ admin/
│  └─ activation/
│     └─ EnterpriseAdminService.ets
├─ firewall/
│  ├─ auth-state/
│  │  ├─ FirewallAuthStateRepository.ets
│  │  └─ FirewallToggleAuthService.ets
│  ├─ mode-control/
│  │  ├─ FirewallModeService.ets
│  │  └─ UserFirewallModeService.ets
│  ├─ policy/
│  │  ├─ FirewallService.ets
│  │  └─ UserFirewallPolicyService.ets
│  ├─ preset/
│  │  ├─ FirewallPresetService.ets
│  │  └─ FirewallPresetConfigService.ets
│  └─ rule-management/
│     └─ FirewallCustomRuleService.ets
├─ identity/
│  ├─ auth/
│  │  └─ AuthService.ets
│  └─ settings/
│     └─ IdentityService.ets
├─ log-manage/
│  ├─ collector/
│  ├─ common/
│  ├─ export/
│  ├─ mapper/
│  ├─ repository/
│  └─ source/
├─ peripheral/
│  ├─ connection-record/
│  │  ├─ index.ets
│  │  ├─ peripheral_connection_record_bluetooth_acl_consumer.ets
│  │  ├─ peripheral_connection_record_pipeline.ets
│  │  ├─ peripheral_connection_record_producer_contract.ets
│  │  ├─ peripheral_connection_record_runtime_producer_adapter.ets
│  │  ├─ peripheral_connection_record_usb_consumer.ets
│  │  ├─ PeripheralTraceRepository.ets
│  │  └─ PeripheralConnectionRecordService.ets
│  ├─ device-policy/
│  │  ├─ PeripheralDevicePolicyRepository.ets
│  │  └─ PeripheralPolicyService.ets
│  └─ interface-control/
│     └─ PeripheralService.ets
└─ tool-settings/
   └─ system-settings/
      ├─ SystemSettingsService.ets
      └─ ToolSettingsRepository.ets

viewmodels/
├─ dashboard/overview/DashboardViewModel.ets
├─ identity/settings/IdentitySettingsViewModel.ets
├─ log-manage/
│  ├─ overview/LogManageViewModel.ets
│  └─ storage-settings/LogStorageSettingsViewModel.ets
├─ peripheral/
│  ├─ overview/PeripheralViewModel.ets
│  ├─ interface-control/InterfaceControlViewModel.ets
│  ├─ device-policy/PeripheralPolicyViewModel.ets
│  └─ connection-record/
│     ├─ index.ets
│     ├─ peripheral_connection_record_clear_usecase.ets
│     ├─ PeripheralRecordViewModel.ets
│     └─ PeripheralRecordPresentationMapper.ets
└─ tool-settings/system-settings/ToolSettingsViewModel.ets

views/
├─ dashboard/overview/DashboardPage.ets
├─ firewall/
│  ├─ overview/FirewallPage.ets
│  └─ rule-management/FirewallRulesPage.ets
├─ help-feedback/overview/HelpFeedbackPage.ets
├─ identity/settings/IdentityPage.ets
├─ log-manage/overview/LogManagePage.ets
├─ peripheral/
│  ├─ overview/PeripheralPage.ets
│  └─ connection-record/index.ets
└─ tool-settings/system-settings/ToolSettingsPage.ets

components/
├─ 通用组件若干
├─ firewall/
│  ├─ policy/UserFirewallControlDialog.ets
│  └─ rule-management/AddRuleDialog.ets
├─ log-manage/
│  ├─ detail/LogDetailDialog.ets
│  ├─ entries/
│  │  ├─ LogEntriesPanel.ets
│  │  └─ LogPaginationBar.ets
│  └─ storage-settings/LogStorageSettingsPanel.ets
└─ peripheral/
   ├─ connection-record/
   │  ├─ ConnectionDetailDialog.ets
   │  ├─ DeviceRecordList.ets
   │  └─ index.ets
   ├─ device-policy/
   │  └─ PolicyList.ets
   └─ interface-control/
      └─ InterfaceControlTab.ets
```

## 附录 D：分批实施建议

1. 第一批只迁移 `services`，建立稳定的领域目录骨架。
2. 第二批迁移 `viewmodels`，让页面状态层跟随领域归属收口。
3. 第三批迁移 `views` 与模块专属 `components`。
4. 公共组件保持不动，避免过度模块化。
5. 每一批迁移后单独进行 import 修复、构建验证和最小回归。
