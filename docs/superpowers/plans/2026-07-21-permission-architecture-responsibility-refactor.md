# 权限管理职责拆分与 Presentation 层归位方案

> 日期：2026-07-21
> 状态：待实施
> 类型：行为保持型架构重构
> 总体风险：中等；按提交边界分步实施时可控

## 1. 目标与非目标

### 1.1 目标

1. 将 `PermissionPage` 中可独立验证的展示职责拆入模块组件，页面只保留生命周期、区块组合、ViewModel 动作转发和 Dialog/loading 反馈。
2. 将 `PermissionViewModel` 中非响应式的刷新并发控制抽取为独立协调器，ViewModel 继续作为唯一页面状态持有者和公开动作入口。
3. 将真正面向 UI 的 `PresentationMapper` 从 `viewmodels` 目录迁入独立 `presentation` 层，消除组件为了格式化显示而依赖 ViewModel 目录的问题。
4. 保持现有权限管理业务规则、状态模型、MDM 参数、页面布局和用户交互不变。

### 1.2 非目标

1. 不拆分安装、卸载、运行、网络和 3D 等多个子 ViewModel。
2. 不修改 `PermissionPageState`、`PermissionAppSnapshot`、策略身份字段或持久化结构。
3. 不修改 MDM、Repository、Service 的系统调用语义。
4. 不调整页面文案、布局、弹窗、loading、空态和错误态。
5. 不新增权限，不修改签名模板，不修改 ukey。
6. 不为 ohosTest 增加生产 ID、测试分支、额外点击转发或其它测试专用生产逻辑。

## 2. 目标目录与依赖方向

```text
PermissionPage
├── PermissionTargetPanel              账号、禁止安装、目标应用选择
├── PermissionApplicationPolicyPanel   已存在，单应用策略设置
└── PermissionPolicyTable              当前策略展示与删除入口

PermissionViewModel
├── PermissionRefreshCoordinator       刷新并发与账号事件排队
├── PermissionAccountRefreshUseCase    账号/应用刷新结果归并
├── PermissionPolicyActionUseCase      写操作前上下文校验
├── PermissionStateReducer             单一状态表提交与派生
└── PermissionPolicyRecordMapper       3D/本地策略记录构造

presentation
├── firewall/FirewallRulePresentationMapper
├── log-manage/LogPresentationMapper
└── peripheral/PeripheralRecordPresentationMapper
```

依赖方向固定为：

```text
View / Component / ViewModel
             ↓
      PresentationMapper
             ↓
      Model / Constants
```

Service、Repository、Storage 不得反向依赖 View、Component、ViewModel 或 Presentation。

## 3. PermissionPage 职责拆分

### 3.1 PermissionPage 保留职责

`entry/src/main/ets/views/permission-manage/overview/PermissionPage.ets` 保留：

1. `aboutToAppear()` 初始化和页面入场刷新。
2. `TimedLoadingDialogRunner` 账号切换 loading。
3. ViewModel 方法调用及动作结果处理。
4. 失败弹窗和删除确认弹窗。
5. `SubPageHeader`、`Scroll`、`SectionCard` 等页面区块组合。
6. 当前应用快照选择、应用策略面板 render key 和动作回调连接。
7. 应用刷新按钮及刷新失败反馈。

PermissionPage 不再包含：

1. 当前策略表头、表格行、单元格和删除按钮渲染细节。
2. 策略删除按钮 hover、touch、active 局部状态。
3. 账号/目标应用下拉选项格式化和索引计算。
4. 禁止安装输入行的布局和按钮 loading 渲染。

### 3.2 新增 PermissionTargetPanel

新增：

```text
entry/src/main/ets/components/permission-manage/PermissionTargetPanel.ets
```

负责：

1. 账号选择行。
2. 禁止安装身份输入行。
3. 目标应用选择行。
4. 应用清单空状态。
5. 账号和应用下拉选项格式化。
6. 账号和应用 selectedIndex 计算。
7. 禁止安装按钮 loading 和 enabled 状态。

建议接口：

```ts
@ComponentV2
export struct PermissionTargetPanel {
  @Param accounts: PermissionManagedAccount[] = []
  @Param selectedAccountId: number = 0
  @Param appSnapshots: PermissionAppSnapshot[] = []
  @Param filteredAppKeys: string[] = []
  @Param selectedAppKey: string = ''
  @Param installBlockKeyword: string = ''
  @Param inventoryMessage: string = ''
  @Param loading: boolean = false
  @Param loadingSelectedApp: boolean = false
  @Param processingActionKey: string = ''
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT

  @Event onSelectAccount: (accountId: number) => Promise<boolean> = async () => false
  @Event onSelectApplication: (appKey: string) => Promise<boolean> = async () => false
  @Event onInstallBlockKeywordChange: (value: string) => void = () => {}
  @Event onSubmitInstallBlock: () => void = () => {}
}
```

边界：

1. 组件对外传递 `accountId` 和 `appKey`，不把下拉框 index 暴露为业务标识。
2. 组件不持有 ViewModel，不修改业务状态。
3. 组件不导入 `DialogService`、Service、Repository 或系统能力。
4. `AsyncSelectRow` 成功后的显示值继续由父级 `@Param` 驱动，组件不得缓存成功选项。
5. 禁止安装按钮只上报事件，失败提示由 PermissionPage 处理。
6. `SectionCard` 和刷新 header action 继续由 PermissionPage 组合，避免重复卡片背景和 padding。

### 3.3 新增 PermissionPolicyTable

新增：

```text
entry/src/main/ets/components/permission-manage/PermissionPolicyTable.ets
```

负责：

1. 当前策略 loading 和空状态。
2. 表头、策略行、目标详情和分隔线。
3. 删除按钮颜色、hover、touch、active 和 processing 状态。
4. 将删除意图以 `recordKey` 上报给 PermissionPage。

建议接口：

```ts
@ComponentV2
export struct PermissionPolicyTable {
  @Param records: PermissionPolicyRecord[] = []
  @Param loadingSelectedApp: boolean = false
  @Param processingActionKey: string = ''
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT

  @Event onRequestDelete: (recordKey: string) => void = () => {}
}
```

允许持有的局部状态：

```ts
@Local private hoveredRecordKey: string = ''
@Local private activeRecordKey: string = ''
```

边界：

1. 删除点击只调用 `onRequestDelete(record.key)`。
2. 确认弹窗、ViewModel 调用和失败提示继续留在 PermissionPage。
3. 组件不维护 `records` 副本，不做乐观删除。
4. 删除成功后的行消失必须来自 ViewModel 更新后的 `records` 参数。
5. `processingActionKey` 非空时，除当前动作外的删除按钮全部禁用。
6. 组件不导入 ViewModel、DialogService、Service、Repository 或系统能力。

### 3.4 明确不拆的页面内容

1. 三个摘要卡片继续由 PermissionPage 组合，不为减少行数增加一次性微型组件。
2. 现有 `PermissionApplicationPolicyPanel` 保持，不继续拆成每个策略一个组件。
3. `SectionCard` 保留在 PermissionPage。
4. 不抽取单独的表头单元格、文本单元格等无独立职责的微型组件。

## 4. PermissionViewModel 职责拆分

### 4.1 PermissionViewModel 保留职责

1. 唯一的 `PermissionPageState`。
2. 页面公开动作入口。
3. Service 调用。
4. 状态提交和成功后的精确 patch。
5. 目标应用选择、详情请求序号和过期结果丢弃。
6. `processingActionKey` 生命周期。
7. 操作结果返回。

继续由 ViewModel 暴露：

```text
loadInitialState
refreshForAccountChange
refreshApplications
refreshApplicationList
refreshAccountsAndApplicationList
switchAccount
selectApplication
selectApplicationAndLoadDetails
setSelectedUninstallProtected
setSelectedRunningPolicy
setSelectedNetworkPolicy
setSelectedThreeDPermissionState
setDisallowedInstallByKeyword
deletePolicyRecord
```

不拆成安装、运行、网络、3D 等多个 ViewModel，避免破坏以 `appSnapshots` 为唯一状态源的设计。

### 4.2 新增 PermissionRefreshCoordinator

新增：

```text
entry/src/main/ets/viewmodels/permission-manage/PermissionRefreshCoordinator.ets
```

迁入非响应式刷新协调字段：

```text
dataRefreshPromise
dataRefreshIncludesAccounts
accountChangeRefreshPromise
accountChangeRefreshPending
```

建议接口：

```ts
export class PermissionRefreshCoordinator {
  runCurrentAccount(task: () => Promise<boolean>): Promise<boolean>
  runIncludingAccounts(task: () => Promise<boolean>): Promise<boolean>
  enqueueAccountChange(task: () => Promise<boolean>): Promise<boolean>
}
```

#### runCurrentAccount 语义

1. 无刷新时立即执行 task。
2. 已有任意刷新时复用当前 Promise。
3. task 成功、返回 false 或抛异常后都必须释放 active 状态。

#### runIncludingAccounts 语义

1. 无刷新时立即执行完整刷新。
2. 已有完整刷新时复用该 Promise。
3. 已有当前账号刷新时先等待，再执行一次完整刷新。
4. 不允许把仅当前账号刷新误认为已经覆盖完整账号刷新。

#### enqueueAccountChange 语义

1. 收到账号事件时设置 pending。
2. 已有账号事件循环时复用同一 Promise。
3. 等待当前普通刷新完成，再执行完整刷新。
4. 完整刷新过程中收到多个事件，只合并为一次尾部补刷。
5. 尾部补刷开始后再收到新事件，继续安排下一次补刷。
6. 刷新返回 false 后退出当前循环并释放内部状态，下一次事件仍可重新运行。

Coordinator 禁止：

1. 持有或导入 `PermissionPageState`。
2. 导入或调用 `PermissionService`。
3. 修改账号、应用或策略状态。
4. 输出 UI 文案。
5. 使用固定延时实现串行化。

### 4.3 保持不变的辅助层

1. `PermissionStateReducer.ets`：状态提交、派生和精确 patch。
2. `PermissionAccountRefreshUseCase.ets`：账号/应用刷新结果归并。
3. `PermissionPolicyActionUseCase.ets`：写操作前账号、应用和策略记录校验。
4. `PermissionPolicyRecordMapper.ets`：3D 和本地策略记录构造。

## 5. PresentationMapper 归位

新增目录：

```text
entry/src/main/ets/presentation/firewall/
entry/src/main/ets/presentation/log-manage/
entry/src/main/ets/presentation/peripheral/
```

移动：

```text
viewmodels/firewall/rules/FirewallRulePresentationMapper.ets
→ presentation/firewall/FirewallRulePresentationMapper.ets

viewmodels/log-manage/presentation/LogPresentationMapper.ets
→ presentation/log-manage/LogPresentationMapper.ets

viewmodels/peripheral/connection-record/PeripheralRecordPresentationMapper.ets
→ presentation/peripheral/PeripheralRecordPresentationMapper.ets
```

PresentationMapper 只允许依赖 Model、Constants 和纯工具，不得依赖 ViewModel、View、Component、Service、Repository、Storage 或系统能力。

不移动：

1. `LogAuditEventMapper`、`LogCrashEventMapper`：系统日志到领域模型转换。
2. `IdentityPasswordPolicyMapper`：系统策略映射。
3. `PermissionPolicyRecordMapper`：状态快照和持久化记录构造。

## 6. 实施顺序与提交边界

### 提交 1：设计文档先行

更新权限、防火墙、日志、外设模块设计文档及总体设计 RFC 的依赖描述。只更新职责边界，不改变业务验收口径。

### 提交 2：PresentationMapper 移动

只移动三个文件并更新 import，不修改方法、输入、输出和格式化结果。

### 提交 3：PermissionPolicyTable 拆分

只迁移策略表 UI 和 hover/active 局部状态，不修改删除业务流程。

### 提交 4：PermissionTargetPanel 拆分

只迁移账号、禁止安装和目标应用选择 UI，不修改 ViewModel 状态流。

### 提交 5：PermissionRefreshCoordinator

只迁移刷新并发控制，不移动 Service 调用、状态提交和错误文案。

每个提交必须独立构建、独立验证、可以单独回滚。禁止将 UI 拆分与刷新时序重构放进同一提交。

## 7. 自动化验收

### 7.1 静态架构验收

1. `PermissionTargetPanel` 不导入 ViewModel、Service、Repository、DialogService。
2. `PermissionPolicyTable` 不导入 ViewModel、Service、Repository、DialogService。
3. `PermissionRefreshCoordinator` 不导入 PermissionModels、PermissionService 或 UI 类。
4. 三个 PresentationMapper 不再位于 `viewmodels`。
5. Component 不再通过 `viewmodels/**/PresentationMapper` 获取显示格式化方法。
6. Service、Repository、Storage 不反向导入 `presentation`。
7. 不新增测试专用生产 ID、测试分支或额外点击行为。
8. 不新增权限，不修改签名模板，不修改 ukey。

### 7.2 RefreshCoordinator 新增 UT

新增：

```text
entry/src/test/permission-manage/refresh-coordinator.test.ets
```

至少覆盖：

1. 两次当前账号刷新并发调用只执行一次 task。
2. 当前账号刷新执行中请求完整刷新，完整刷新在前者结束后执行。
3. 两次完整刷新并发调用复用同一 task。
4. 账号事件到达时存在普通刷新，事件刷新等待普通刷新结束。
5. 完整刷新期间连续收到多个事件，只执行一次尾部补刷。
6. 尾部补刷开始后收到新事件，再执行一次补刷。
7. task 返回 false 后内部状态释放，下一次刷新能执行。
8. task 抛异常后内部状态释放，下一次刷新能执行。
9. 完整刷新不能复用事件发生前启动的当前账号刷新结果。
10. 所有刷新结束后不存在 pending 或 active 泄漏。

### 7.3 现有权限 UT

`entry/src/test/permission-manage/viewmodel.test.ets` 现有 56 个用例不得删除或降低断言，重点回归：

1. 当前账号刷新与账号事件串行。
2. 连续账号事件尾部补刷。
3. 在途当前账号刷新复用。
4. 当前账号消失后的回退。
5. 目标应用卸载或身份变化后清空选择。
6. 写操作前账号/应用上下文校验。
7. 删除策略前记录与应用身份校验。
8. 写入失败保持原状态。
9. 3D 本地记录清理和默认态恢复。

### 7.4 PresentationMapper 验收

1. Mapper 移动前后的格式化结果完全一致。
2. 防火墙 IP 和端口格式化结果不变。
3. 日志类型、详情和时间显示不变。
4. 外设设备名、设备类型和策略状态显示不变。
5. 只允许 import 路径变化，不允许输出快照变化。

## 8. 页面功能验收

### 8.1 初始化与刷新

1. 首次进入只显示既有 loading，不新增多块 loading。
2. 初始化后摘要、账号、应用清单、应用策略和当前策略一致。
3. 页面重新进入只刷新当前账号应用清单，不重复初始化。
4. 刷新失败保留旧数据。

### 8.2 账号选择

1. 账号选项内容和顺序不变。
2. 切换成功后应用、摘要和当前策略全部切换。
3. 切换失败回到原账号显示值。
4. 切换期间控件置灰和 loading 行为不变。
5. 当前账号删除后的回退规则不变。

### 8.3 禁止安装

1. 输入框值仍由 ViewModel 单一维护。
2. 空输入时按钮禁用。
3. processing 时显示原有 loading。
4. 成功后输入框清空且当前策略新增记录。
5. 失败时保留状态并显示原错误提示。
6. 不接受 bundleName 和显示名的规则不变。

### 8.4 目标应用选择

1. 第一项仍为“请选择应用”。
2. 同名应用仍通过 bundleName 区分。
3. 选择后先显示选中项和局部 loading。
4. 旧详情请求晚返回时不能覆盖新应用。
5. 选择失败回滚到原应用。
6. 应用卸载或身份变化后清空旧选择。

### 8.5 应用策略

1. 卸载保护、运行、网络、3D 下拉状态不变。
2. loading 只出现在当前操作行。
3. 成功后上方策略和当前策略表同步。
4. 失败后下拉回到原值。
5. 3D 未声明或不支持项继续禁用并显示原因。

### 8.6 当前策略表

1. 表头、列宽、文字截断和分隔线与拆分前一致。
2. 空态、loading 态与拆分前一致。
3. 删除 hover、按下和禁用样式不变。
4. 点击删除先弹确认框，取消不调用 ViewModel。
5. 删除处理中只有当前记录显示 loading。
6. 删除成功后记录、摘要和应用策略同步更新。
7. 删除失败时记录不消失。
8. processing 期间其它删除按钮不可操作。

### 8.7 主题与布局

1. 深色、浅色、跟随系统三种主题无背景断层。
2. `SectionCard` 不出现嵌套卡片背景。
3. 目标应用下拉框与禁止安装输入框保持既有对齐。
4. 2in1 窗口下策略表不新增横向溢出。
5. 页面滚动位置和滚动条行为不变。

## 9. 构建与设备验收

必须执行：

```text
python scripts/check_docs_consistency.py
python scripts/e2e/tools/validate_test_assets.py
hvigorw test --mode module -p product=default -p module=entry@default
hvigorw test --mode module -p product=default -p module=entry@ohosTest
hvigorw assembleHap --mode module -p product=default -p module=entry@default
hvigorw assembleHap --mode module -p product=default -p module=entry@ohosTest
```

设备侧执行 `route_action: permission-manage` 和 `theme_menu`。手工设备验收顺序：

1. 进入权限管理。
2. 切换账号。
3. 手动刷新应用。
4. 选择目标应用。
5. 修改卸载、运行、网络任一策略。
6. 修改并恢复一项 3D 策略。
7. 从当前策略表删除一条记录。
8. 切换深色/浅色主题。
9. 返回其它模块后重新进入权限管理。

## 10. 风险分级与控制措施

| 工作包 | 风险等级 | 主要风险 | 控制措施 |
|---|---|---|---|
| PresentationMapper 移动 | 低 | import 遗漏、循环依赖 | 只移动文件和 import；Presentation 只依赖 Model/Constants；格式化 UT 全量回归 |
| PermissionPolicyTable 拆分 | 低到中 | 删除按钮局部状态、布局或主题变化 | 组件只接收参数并上报删除意图；保留原尺寸与样式；进行深浅色和删除状态验收 |
| PermissionTargetPanel 拆分 | 中 | ComponentV2 参数更新、AsyncSelectRow 回滚、下拉显示旧状态 | 禁止缓存业务选中值；父级状态作为唯一真相源；专项回归账号和应用选择失败路径 |
| PermissionRefreshCoordinator | 中到高 | 丢失账号事件、错误复用 Promise、刷新状态泄漏 | 独立提交；新增 10 类并发 UT；保留现有 56 个 ViewModel 集成用例；异常必须 finally 释放状态 |

### 10.1 总体风险结论

1. 页面组件和 Mapper 重构属于行为保持型迁移，风险可控，不涉及系统能力和数据状态。
2. RefreshCoordinator 是唯一需要重点控制的部分，因为账号事件与页面刷新存在明确时序语义。
3. 如果按五个独立提交实施，总体风险为中等；若将页面、Mapper 和刷新协调一次性改完，风险会升为高，不允许这样实施。
4. 任一阶段出现状态、布局或设备行为变化，应回滚该阶段提交，不得在后续提交中继续叠加修补。

## 11. 回滚触发条件

出现以下任一情况，当前工作包不得继续合入：

1. 现有 56 个权限 ViewModel 测试出现失败或断言被降低。
2. 账号事件刷新次数或执行顺序与现有契约不一致。
3. 账号/应用切换失败后 UI 未回滚到旧值。
4. 策略写入或删除失败后页面状态发生乐观变更。
5. 当前策略表与应用策略面板显示不一致。
6. 深浅色切换出现背景断层、下拉显示旧值或表格布局变化。
7. 新组件导入 ViewModel、Service、Repository 或 DialogService。
8. 为测试修改生产交互行为。

## 12. 完成定义

1. PermissionPage 不再包含策略表格渲染细节。
2. 新组件没有 ViewModel、Service、Repository、Dialog 依赖。
3. ViewModel 仍是唯一页面状态持有者。
4. RefreshCoordinator 只负责并发时序，不负责业务状态。
5. 三个 PresentationMapper 不再归属 viewmodels。
6. 现有 56 个权限 UT 全部保留并通过。
7. 新增刷新协调器专项测试全部通过。
8. 页面外观、交互、错误提示和 MDM 调用参数无变化。
9. 文档、UT、ohosTest 编译、HAP 构建和设备手工验证闭环通过。
