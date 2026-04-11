# SecurityTool 可复用 UI 组件说明

## 1. 文档定位

本文档用于沉淀当前项目内已经落地、可在多个页面或模块中复用的 UI 组件，统一记录以下内容：

- 组件定位与分层
- 设计目标与适用场景
- 交互约束与使用方式
- 已接入页面与维护注意事项

这份文档不再只做"组件名单"，而是作为可持续维护的"组件档案库"。后续每新增一个可复用组件，应同步在这里补齐一份标准条目。

统计范围：

- `entry/src/main/ets/components`
- `entry/src/main/ets/components/peripheral`
- `entry/src/main/ets/components/log-manage`
- `entry/src/main/ets/components/firewall`
- 与组件强绑定、用于统一调用或状态编排的 UI 工具封装

不纳入本清单的内容：

- 页面级布局代码
- 仅服务于单个页面、且未沉淀为独立组件的临时 UI 结构
- 纯业务 service、viewmodel、model

## 2. 维护规则

### 2.1 何时需要更新本文档

出现以下任一情况时，需要同步更新本文档：

- 新增了一个可复用 UI 组件
- 现有组件的视觉规范、交互规则或适用边界发生变化
- 组件的推荐接入方式、依赖关系或使用限制发生变化
- 组件从"模块内复用"升级为"跨模块通用"

### 2.2 每次新增组件时至少补齐的信息

每个新组件至少需要补齐以下字段：

- 组件名称
- 组件分层
- 文件位置
- 组件职责
- 适用场景 / 不适用场景
- 设计规则
- 使用方式
- 已接入页面或模块
- 维护注意事项

### 2.3 推荐录入流程

新增一个可复用组件后，按以下顺序维护本文档：

1. 先在"组件索引"里登记一条摘要记录。
2. 再在"组件档案"里新增完整条目。
3. 若组件依赖调用封装、控制器或辅助工具，需要一并写明。
4. 若组件只适合模块内复用，要明确标注，避免误当成全局通用组件。

## 3. 组件分层约定

为了方便持续扩展，本文档将组件分为三层：

| 分层 | 含义 | 放置建议 |
| --- | --- | --- |
| 全局通用组件 | 可跨页面、跨模块复用，主要承载统一视觉或统一交互模式 | `entry/src/main/ets/components` |
| 模块复用组件 | 在单个业务域内可复用，具备明确模块语义 | `entry/src/main/ets/components/<module>` |
| 组件配套封装 | 不直接渲染 UI，但与某个可复用组件强绑定，用于统一控制打开、关闭、状态编排或日志 | `entry/src/main/ets/utils` 等 |

说明：

- "组件配套封装"不是独立视觉组件，但如果没有它就无法形成稳定复用能力，也需要纳入组件档案。
- 如果一个组件同时包含视觉层和调用层，应在同一个组件条目中说明二者职责分工。

## 4. 组件索引

这部分用于快速查找已有组件。详细设计和使用说明统一放在"组件档案"章节。

### 4.1 全局通用组件

| 组件 | 文件 | 类型 | 作用 | 典型场景 |
| --- | --- | --- | --- | --- |
| BaseCard | `components/BaseCard.ets` | 视觉容器 | 卡片基础容器，统一圆角、边框、阴影、悬浮动效和点击行为 | 首页功能卡、摘要卡、模块入口卡 |
| ToolCard | `components/ToolCard.ets` | 业务入口卡 | 基于 `BaseCard` 的功能入口卡，支持图标、标题、悬浮态 | 首页模块导航入口 |
| MetricSummaryCard | `components/MetricSummaryCard.ets` | 摘要卡 | 图标 + 主指标 + 辅助说明的摘要卡 | 总览指标、防火墙或日志状态摘要 |
| CompactSummaryCard | `components/CompactSummaryCard.ets` | 摘要卡 | `MetricSummaryCard` 的紧凑版，支持 `default` / `log` 预设 | 页面头部二级摘要、紧凑信息卡 |
| SectionCard | `components/SettingsSectionCard.ets` | 分组容器 | 带标题和内容区的分组卡片容器 | 设置分区、配置项集合 |
| EmptyStatePanel | `components/EmptyStatePanel.ets` | 状态反馈 | 空状态提示面板 | 无数据、无记录、权限不足提示 |
| SubPageHeader | `components/SubPageHeader.ets` | 导航头部 | 子页面统一头部，包含返回、标题、副标题和可选操作区 | 二级详情页、设置页、帮助页 |
| SideBar | `components/SideBar.ets` | 导航组件 | 左侧主导航栏 | 主框架页导航 |
| InteractiveMenuRow | `components/ThemeMenuPopup.ets` | 菜单行 | 图标 + 文本的交互菜单行 | 侧边栏项、弹出菜单项、返回按钮 |
| ThemeMenuPopup | `components/ThemeMenuPopup.ets` | 菜单弹层 | 主题切换与帮助/关于菜单 | 顶部主题菜单 |
| AboutDialogContent | `components/ThemeMenuPopup.ets` | 关于弹窗 | 应用关于信息弹窗 | 主题菜单 > 关于 |
| IconTextActionButton | `components/IconTextActionButton.ets` | 操作按钮 | 图标 + 文本按钮，支持 primary / info / danger 风格 | 保存、删除、执行类操作 |
| CommonLoadingDialog | `components/CommonLoadingDialog.ets` | 反馈弹层 | 统一等待弹窗视觉 | 异步提交、模式切换、策略切换 |
| DetailDialogShell | `components/DetailDialogShell.ets` | 弹层壳组件 | 标准详情弹层内容壳，带标题、关闭和滚动区 | 详情查看、信息确认 |
| DetailDialogOverlay | `components/DetailDialogShell.ets` | 遮罩层 | 全屏遮罩承载层 | 非 `@CustomDialog` 场景的自定义弹层（当前未使用） |

### 4.2 组合式表单 / 配置行

这组组件统一沉淀在 `components/SectionRows.ets`：

| 组件 | 作用 | 典型场景 |
| --- | --- | --- |
| SectionLabel | 标题 + 说明的标签区 | 配置行左侧标签，被其它 SectionRow 复用 |
| SectionToggleRow | 标题 + 说明 + 开关 | 启停类配置项 |
| SectionSelectRow | 标题 + 说明 + 下拉选择 | 策略、模式、枚举值配置（同步模式） |
| SectionActionRow | 标题 + 说明 + 操作按钮 | 立即执行类设置项 |
| SectionSelectInputRow | 标题 + 说明 + 下拉 + 数字输入 | 组合型配置项 |

另外，异步选择行独立沉淀在 `components/AsyncSelectRow.ets`：

| 组件 | 作用 | 典型场景 |
| --- | --- | --- |
| AsyncSelectRow | 标题 + 说明 + 异步下拉选择，支持乐观更新与失败回退 | 选择后立即调用系统接口、失败需回退的配置行 |

使用建议：

- 优先用于"设置项列表"，而不是复杂业务表格。
- 标题和说明文案应短句化，避免在行内放过长解释。
- 同步场景使用 `SectionSelectRow`，异步场景使用 `AsyncSelectRow`，不要在 `SectionSelectRow` 上自行拼装异步逻辑。
- 若场景是"选择后立即调用系统接口，失败后需要恢复到原值"，优先使用 `AsyncSelectRow` 的异步模式。

### 4.3 模块复用组件

#### 防火墙模块

| 组件 | 文件 | 作用 | 典型场景 |
| --- | --- | --- | --- |
| AddRuleDialog | `components/firewall/rules/AddRuleDialog.ets` | 防火墙规则新增/编辑弹窗 | 自定义规则维护 |
| UserFirewallControlDialog | `components/firewall/user-dispatch/UserFirewallControlDialog.ets` | 按用户维度下发防火墙策略的业务弹窗 | 防火墙按用户控制 |

#### 外设管理模块

| 组件 | 文件 | 作用 | 典型场景 |
| --- | --- | --- | --- |
| InterfaceControlTab | `components/peripheral/interface-control/InterfaceControlTab.ets` | 外设接口管控页主体，封装接口启停和 USB 存储策略选择 | 外设管理 > 接口管控 |
| DeviceRecordList | `components/peripheral/connection-record/DeviceRecordList.ets` | 连接记录列表和"详情"入口 | 外设管理 > 连接记录 |
| PolicyList | `components/peripheral/device-policy/PolicyList.ets` | 设备策略表格和策略变更操作 | 外设管理 > 策略列表 |
| ConnectionDetailDialog | `components/peripheral/connection-record/ConnectionDetailDialog.ets` | 连接记录详情弹层 | 外设管理 > 记录详情 |

#### 日志管理模块

| 组件 | 文件 | 作用 | 典型场景 |
| --- | --- | --- | --- |
| LogDetailDialog | `components/log-manage/detail/LogDetailDialog.ets` | 日志条目详情弹层 | 日志管理 > 条目详情 |
| LogEntriesPanel | `components/log-manage/entries/LogEntriesPanel.ets` | 日志条目列表和空状态展示 | 日志管理 > 条目列表 |
| LogPaginationBar | `components/log-manage/entries/LogPaginationBar.ets` | 日志分页控制栏 | 日志管理 > 分页导航 |
| LogStorageSettingsPanel | `components/log-manage/storage-settings/LogStorageSettingsPanel.ets` | 日志存储配置面板（保留天数、最大条目数） | 日志管理 > 存储设置 |

说明：

- 模块复用组件可以在同一业务域内反复复用，但默认不视为全局通用资产。
- 若其它模块只想复用"壳子"或"基础交互模式"，优先复用基础组件，不直接搬用业务语义过重的模块组件。

### 4.4 组件配套封装

| 名称 | 文件 | 绑定组件 | 作用 |
| --- | --- | --- | --- |
| TimedLoadingDialogRunner | `utils/TimedLoadingDialogRunner.ets` | CommonLoadingDialog | 统一控制等待弹窗打开、最短展示时长、关闭和日志输出 |
| DialogService | `utils/DialogService.ets` | 通用对话框 | 统一确认弹窗和结果弹窗的打开、样式和日志 |

## 5. 新增组件录入模板

后续每新增一个可复用组件，建议直接复制以下模板追加到"组件档案"章节。

````md
## X. 组件名称

### X.1 基本信息

| 字段 | 内容 |
| --- | --- |
| 组件名称 |  |
| 分层 | 全局通用组件 / 模块复用组件 / 组件配套封装 |
| 文件 |  |
| 配套封装 | 无 / 相关文件路径 |
| 当前状态 | 已接入 / 待接入 / 待替换 |

### X.2 组件职责

- 说明这个组件解决什么问题。
- 说明它与页面代码、业务逻辑的边界。

### X.3 设计规则

- 视觉结构
- 核心交互
- 文案规范
- 主题 / 尺寸 / 状态规则

### X.4 适用场景

- 

### X.5 不适用场景

- 

### X.6 使用方式

```ts
// 推荐接入示例
```

接入要求：

- 

### X.7 已接入页面

| 页面 / 模块 | 场景 | 备注 |
| --- | --- | --- |
|  |  |  |

### X.8 维护注意事项

- 
````

## 6. 组件档案

本章节用于沉淀重点组件的完整设计与使用说明。后续新增组件时，直接按统一模板在这里追加新条目。

### 6.1 等待弹窗组件

#### 6.1.1 基本信息

| 字段 | 内容 |
| --- | --- |
| 组件名称 | CommonLoadingDialog |
| 分层 | 全局通用组件 |
| 文件 | `components/CommonLoadingDialog.ets` |
| 配套封装 | `utils/TimedLoadingDialogRunner.ets` |
| 当前状态 | 已接入 |

#### 6.1.2 组件职责

等待弹窗组件由两部分组成：

- 视觉组件：`CommonLoadingDialog`
- 调用封装：`TimedLoadingDialogRunner`

职责分工如下：

- `CommonLoadingDialog` 负责统一视觉表现，保证不同页面的等待反馈样式一致。
- `TimedLoadingDialogRunner` 负责统一打开、最短展示时长、关闭和日志输出，避免各页面重复写弹窗时序控制代码。

这个组件解决的是"用户已经触发动作，但结果尚未返回"的短等待反馈问题，不负责确认、结果提示或错误解释。

#### 6.1.3 设计规则

当前等待弹窗采用以下统一设计：

- 展示位置：页面中央
- 弹窗宽度：`280`
- 内边距：左右 `24`，上下 `28`
- 视觉主体：`44 x 44` 的 `LoadingProgress`
- 文案布局：单行或短句，居中显示
- 组件间距：`14`
- 背景：跟随主题的卡片背景色
- 圆角：`AppStyles.RADIUS_LG`
- 阴影：浅色 / 深色主题分别使用轻阴影和深阴影

设计目标：

- 在"操作已开始，但还未完成"的阶段给出稳定反馈
- 避免切换动作过快时完全无感知
- 避免各模块各自实现等待层，导致样式和节奏不一致

#### 6.1.4 交互规则

等待弹窗当前统一遵循以下规则：

- 默认最短展示时长为 `500ms`
- 打开和关闭由 `TimedLoadingDialogRunner` 统一控制
- 同一时刻同一 runner 只允许存在一个等待弹窗
- 页面组件负责创建 `CustomDialogController`
- runner 负责执行任务、补足最短展示时长、关闭弹窗和输出日志
- 对"弹窗打开后立即进入同步重任务"的场景，runner 可按场景启用可选的渲染让步时间，先让弹窗稳定显示，再执行业务任务

注意：

- `CustomDialogController` 必须在页面组件上下文内创建，不能在普通工具类中直接构造后期望其稳定挂载到页面
- 等待弹窗只负责"处理中"反馈，不承担确认、结果提示或错误解释
- 渲染让步时间不是全局固定延时，默认值应保持为 `0`，只允许在已确认存在首帧可见性问题的场景按需开启，避免扩大修改面

#### 6.1.5 适用场景

建议使用等待弹窗的场景：

- 触发系统接口调用，用户需要明确感知"已开始处理"
- 操作可能在 `100ms` 到数秒之间完成，直接静默切换会造成"没反应"的误解
- 模式、策略、权限或设备状态切换类操作

#### 6.1.6 不适用场景

不建议使用等待弹窗的场景：

- 纯本地状态切换且能即时完成的操作
- 需要用户二次确认的操作
- 需要展示百分比、进度条、步骤状态的长任务
- 需要在等待过程中允许取消、重试或查看详情的复杂任务

#### 6.1.7 使用方式

页面内推荐按以下模式接入：

```ts
private readonly loadingRunner: TimedLoadingDialogRunner =
  new TimedLoadingDialogRunner(TAG, DOMAIN)

private createLoadingDialogController(message: string): CustomDialogController {
  return new CustomDialogController({
    builder: CommonLoadingDialog({ message }),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: true
  })
}

await this.loadingRunner.run(
  'scene-tag',
  '正在处理，请稍候...',
  async () => {
    await this.executeBusinessTask()
  },
  (dialogMessage: string): CustomDialogController =>
    this.createLoadingDialogController(dialogMessage)
)
```

若当前场景存在"弹窗刚打开就进入同步系统调用，导致首帧可见时间被压缩"的问题，可按场景启用可选渲染让步：

```ts
await this.loadingRunner.run(
  'peripheral-usb-interface',
  '正在设置 USB 接口策略，请稍候...',
  async () => {
    await this.executeBusinessTask()
  },
  (dialogMessage: string): CustomDialogController =>
    this.createLoadingDialogController(dialogMessage),
  500,
  180
)
```

接入要求：

- `scene-tag` 需要是明确、可搜索的业务场景标识
- 等待文案只描述当前动作，不写结果承诺
- 业务成功和失败提示仍由原有结果链路负责
- 页面销毁或离开时，若存在未关闭实例，应显式调用 `closeIfOpen`
- 若启用了渲染让步，必须在接入说明或场景备注中标明原因，避免后续误以为是通用默认行为

#### 6.1.8 已接入页面

当前项目中已接入统一等待弹窗的场景如下：

| 页面 / 模块 | 场景 | 备注 |
| --- | --- | --- |
| 防火墙管理首页 | 公共网络模式 / 私有网络模式 / 自定义模式切换 | 等待文案：`正在应用防火墙模式...` |
| 外设管理 > 接口管控 | `USB 接口` 启用 / 禁用切换 | 等待文案：`正在设置 USB 接口策略，请稍候...` |
| 外设管理 > 接口管控 | `USB 存储设备` 策略切换 | 等待文案：`正在设置 USB 存储策略，请稍候...` |

#### 6.1.9 日志要求

等待弹窗相关链路应输出以下非敏感日志：

- 等待弹窗打开
- 等待弹窗关闭
- 为满足最短展示时长而等待的剩余时间
- 打开失败或关闭失败的错误摘要

允许记录：

- 页面名
- 场景标识
- 展示时长
- 错误码
- 布尔状态、策略枚举、规则数量

禁止记录：

- 用户账户名
- 密码、PIN、口令
- 规则明细全文
- 用户输入的敏感文本

#### 6.1.10 维护注意事项

- 若后续出现第二类等待反馈样式，例如带进度百分比或可取消任务，应作为新组件类型单独定义，不与当前 `CommonLoadingDialog` 混用。
- 若等待弹窗的视觉规范变化，需要同时评估所有接入页面的感知一致性。
- 若未来出现跨页面统一的 loading service，可在本条目下补充"调用层升级方案"，而不是另起一套未归档实现。

#### 6.1.11 当前实现状态与待完成项

当前等待弹窗方案已经统一了以下内容：

- 统一视觉样式：居中卡片、`44 x 44` 圆形加载动画、统一宽度和阴影
- 统一时序控制：打开、最短展示 `500ms`、关闭、重复打开保护
- 统一日志输出：打开、关闭、最短时长补齐、异常摘要

当前已确认的已知限制：

- 在"外设管理 > 接口管控 > USB 接口启用/禁用"场景中，等待弹窗打开后会很快进入同步系统接口调用
- 该类同步调用可能占用 UI 渲染线程，导致弹窗虽然可见，但中间 `LoadingProgress` 动画不够流畅，甚至出现"圆圈不转"的体感
- 为改善首帧可见性，当前仅对 `USB 接口` 场景启用了按场景的渲染让步时间；这只能改善"先看见弹窗"，不能从根本上保证后续动画持续流畅

待完成项：

- 需要进一步评估并推进"将重型同步系统调用搬离 UI 线程"的方案，优先针对 `USB 接口` 场景验证可行性
- 若 `MDMKit / restrictions / usbManager` 相关调用允许在后台线程执行，应将 USB 接口切换链路迁移到后台执行，再由 UI 线程只负责更新状态和结果提示
- 若相关系统接口受限，必须保留在 UI 线程执行，则应在组件说明和场景说明中明确：该场景的等待弹窗主要保证"处理中可见反馈"，不承诺加载动画全程流畅

结论：

- 当前等待弹窗组件设计可继续复用
- "调用搬离 UI 线程"属于等待弹窗能力的后续完善项，应继续在配套封装和具体场景链路上推进，而不是通过修改视觉组件规避问题

### 6.2 配置选择行组件

#### 6.2.1 基本信息

| 字段 | 内容 |
| --- | --- |
| 组件名称 | SectionSelectRow |
| 分层 | 全局通用组件 |
| 文件 | `components/SectionRows.ets` |
| 配套封装 | 无 |
| 当前状态 | 已接入 |

#### 6.2.2 组件职责

`SectionSelectRow` 是设置页统一使用的"标题 + 说明 + 下拉选择"配置行组件，仅支持同步模式。

职责边界如下：

- 负责统一选择行的视觉结构、间距、主题色和选择器尺寸。
- 负责把用户选中的索引透传给页面或 ViewModel。
- 不负责异步提交、失败回退、业务校验、系统接口调用、成功失败提示和业务状态持久化。

异步场景请使用 `AsyncSelectRow`（见 6.3）。

#### 6.2.3 设计规则

当前 `SectionSelectRow` 遵循以下规则：

- 左侧固定为标题和一行短说明（由 `SectionLabel` 承载）。
- 右侧为单个 `Select` 控件，默认宽度 `140`，可按场景覆写。
- 跟随主题切换边框、背景、文本和箭头颜色。
- 仅支持同步模式：用户选择后直接触发 `onSelect(index)`，是否更新最终状态由外层决定。
- 当 `processing=true` 时，`Select` 禁用并降低透明度。

#### 6.2.4 交互规则

- 页面传入 `selectedIndex`、`value`、`onSelect`。
- 组件在用户选择后直接触发 `onSelect(index)`。
- 是否更新最终状态由外层页面或 ViewModel 决定。
- 异步场景（选择后立即提交、失败需回退）请使用 `AsyncSelectRow`。

#### 6.2.5 适用场景

推荐使用 `SectionSelectRow` 的场景：

- 日志管理、工具设置、身份鉴别等"标题 + 说明 + 枚举值选择"的标准设置页。
- 策略、模式、等级、期限等固定选项的单值选择。
- 选择后由页面统一处理提交的场景。

#### 6.2.6 不适用场景

不建议使用 `SectionSelectRow` 的场景：

- 选择后需要立即异步提交、失败需回退（请用 `AsyncSelectRow`）。
- 需要表格、多列或批量编辑的复杂配置界面。
- 需要在一行内同时编辑多个字段的复合表单。
- 需要展示树形层级、搜索、远程分页的大型选项集合。
- 只服务某一个模块且行布局差异很大的业务私有表格。

#### 6.2.7 使用方式

同步接入示例：

```ts
SectionSelectRow({
  title: '日志保留天数',
  description: '设置本地日志默认保留时长。',
  options: retentionOptions,
  selectedIndex: this.retentionDaysIndex,
  value: retentionOptions[this.retentionDaysIndex]?.value ?? '',
  onSelect: (index: number) => {
    this.retentionDaysIndex = index
  }
})
```

接入要求：

- `value` 应始终与 `selectedIndex` 指向的选项文本保持一致，避免出现显示值和索引错位。
- 若页面本身已存在全局等待弹窗，可与 `processing` 同时使用；等待弹窗负责"处理中提示"，组件负责"选择禁用"。
- 不要在 `SectionSelectRow` 上自行拼装异步逻辑，异步场景请使用 `AsyncSelectRow`。

#### 6.2.8 已接入页面

| 页面 / 模块 | 场景 | 备注 |
| --- | --- | --- |
| 日志管理 | 日志保留天数、最大日志数量等枚举配置 | 同步模式 |
| 工具设置 | 启动认证方式等枚举配置 | 同步模式 |
| 身份鉴别 | 密码长度、有效期等枚举配置 | 同步模式 |

#### 6.2.9 维护注意事项

- `SectionSelectRow` 仍是"设置行组件"，不是通用复杂下拉框；不要继续往里叠加搜索、联动表格等重交互。
- 异步能力已独立为 `AsyncSelectRow`，不要在 `SectionSelectRow` 中重新引入异步逻辑。
- 修改 `SectionSelectRow` 的默认行为时，必须回归验证日志管理、工具设置、身份鉴别这些同步场景，避免影响旧页面。

### 6.3 异步选择行组件

#### 6.3.1 基本信息

| 字段 | 内容 |
| --- | --- |
| 组件名称 | AsyncSelectRow |
| 分层 | 全局通用组件 |
| 文件 | `components/AsyncSelectRow.ets` |
| 配套封装 | 无 |
| 当前状态 | 已接入 |

#### 6.3.2 组件职责

`AsyncSelectRow` 是"标题 + 说明 + 异步下拉选择"配置行组件，专为"选择后立即调用系统接口，失败需回退"的场景设计。

职责边界如下：

- 负责统一异步选择行的视觉结构、间距、主题色和选择器尺寸。
- 内部维护 `displayIndex`，与外部 `selectedIndex` 分离，实现乐观更新与失败回退。
- 处理中自动禁用选择器并展示 `LoadingProgress` 指示器。
- 不负责具体业务校验、成功失败提示和业务状态持久化。

#### 6.3.3 设计规则

- 左侧为 `SectionLabel`（标题 + 说明），与 `SectionSelectRow` 保持一致。
- 右侧为 `Select` 控件 + 可选 `LoadingProgress` 指示器。
- 异步等待期间：选择器禁用、透明度降至 `0.72`、行整体透明度降至 `0.8`、展示 `18 x 18` 的 `LoadingProgress`。
- 跟随主题切换边框、背景、文本和箭头颜色。
- 行背景使用卡片背景色，与 `SectionSelectRow` 的透明背景有所区别。

#### 6.3.4 交互规则

- 页面传入 `selectedIndex`（已提交成功的真实值）和 `onSelectAsync(nextIndex): Promise<boolean>`。
- 组件在用户选择后记录旧值，并进入异步等待态。
- 若 `optimistic=true`（默认），组件先展示新值，再等待异步结果。
- 异步返回 `true` 时，组件保持当前显示，等待父层回写新的 `selectedIndex`。
- 异步返回 `false` 或抛出异常时，组件自动把显示值回退成旧值。
- 当用户重复选择当前项时，组件直接忽略，不触发额外提交。
- `processing` 参数可由外部传入，用于与全局等待弹窗联动。

#### 6.3.5 适用场景

推荐使用 `AsyncSelectRow` 的场景：

- 选择后立即调用系统接口，失败需要恢复原值的配置行。
- 策略、模式切换等"选即生效"的配置项。
- 外设管理中 USB 存储策略切换等需要异步提交的场景。

#### 6.3.6 不适用场景

不建议使用 `AsyncSelectRow` 的场景：

- 纯同步选择，不需要异步提交（请用 `SectionSelectRow`）。
- 需要表格、多列或批量编辑的复杂配置界面。
- 需要在一行内同时编辑多个字段的复合表单。

#### 6.3.7 使用方式

异步失败回退接入示例：

```ts
AsyncSelectRow({
  label: 'USB 存储设备',
  description: '设置 USB 存储设备的访问权限，可选只读、读写或禁止访问。',
  options: usbStorageOptions,
  selectedIndex: this.usbStoragePolicyIndex,
  processing: this.interfaceControlProcessingKey === this.usbStorageControlKey,
  optimistic: true,
  currentTheme: this.currentTheme,
  onSelectAsync: async (nextIndex: number): Promise<boolean> => {
    return await this.handleUsbStoragePolicyChange(nextIndex)
  }
})
```

接入要求：

- 父层必须只在提交成功后更新 `selectedIndex`，失败时返回 `false` 交给组件回退。
- `optimistic` 默认为 `true`，若不希望乐观更新，显式传入 `false`。
- 若页面本身已存在全局等待弹窗，可与 `processing` 同时使用；等待弹窗负责"处理中提示"，组件负责"选择禁用与失败回退"。

#### 6.3.8 已接入页面

| 页面 / 模块 | 场景 | 备注 |
| --- | --- | --- |
| 外设管理 > 接口管控 | `USB 存储设备` 策略切换 | 异步模式，乐观更新，失败自动回退 |

#### 6.3.9 日志要求

`AsyncSelectRow` 自身输出以下非敏感日志：

- 异步选择异常（error 级别）
- 异步选择失败并回退（warn 级别）

允许记录：

- 组件标签
- 回退索引、失败索引

禁止记录：

- 账户名
- 密码、PIN、口令
- 页面表单中的敏感输入

#### 6.3.10 维护注意事项

- `AsyncSelectRow` 与 `SectionSelectRow` 是互补关系，不是替代关系：同步场景用 `SectionSelectRow`，异步场景用 `AsyncSelectRow`。
- 若后续再出现"选择后异步提交、失败需回退"的场景，应优先复用 `AsyncSelectRow`，而不是再造业务私有 Select。
- 修改 `AsyncSelectRow` 的回退逻辑时，必须回归验证外设管理中 USB 存储策略切换场景。

### 6.4 对话框服务

#### 6.4.1 基本信息

| 字段 | 内容 |
| --- | --- |
| 组件名称 | DialogService |
| 分层 | 组件配套封装 |
| 文件 | `utils/DialogService.ets` |
| 绑定组件 | 通用确认弹窗 / 结果弹窗 |
| 当前状态 | 已接入 |

#### 6.4.2 组件职责

`DialogService` 是统一对话框服务，封装确认弹窗和结果弹窗的打开、样式和日志。

职责边界如下：

- 提供静态方法 `openConfirm` / `openResult` / `openSuccess` / `openFailure`，统一弹窗样式和交互。
- 负责弹窗标题、文案、按钮文本的默认值和主题适配。
- 不负责业务逻辑校验、系统接口调用和状态持久化。

#### 6.4.3 适用场景

- 需要用户二次确认的操作（如删除、重置）。
- 操作结果反馈（成功 / 失败提示）。
- 需要统一弹窗样式和交互的各类确认 / 结果场景。

#### 6.4.4 已接入页面

`DialogService` 在项目中被广泛使用，主要接入场景包括：

- 防火墙规则新增/编辑的校验失败提示
- 外设管理的策略变更结果反馈
- 身份鉴别的配置操作确认与结果提示
- 工具设置的配置操作确认与结果提示

## 7. 复用原则

- 优先复用现有基础组件，再决定是否新增新组件。
- 新组件若只服务单一业务页面，优先在业务模块内部沉淀，不直接放入通用层。
- 新增全局通用组件时，需要同时补充本说明文档，注明用途、场景和限制。
- 修改已有组件样式时，应优先确认是否会影响其它已接入页面，避免组件升级引入跨页面视觉回归。
- 同步选择场景使用 `SectionSelectRow`，异步选择场景使用 `AsyncSelectRow`，不要在组件上自行拼装异步逻辑。

## 8. 后续维护建议

- 后续若身份鉴别、工具设置模块继续沉淀出可跨模块复用的弹层、表格或配置组件，应先补"组件索引"，再补"组件档案"。
- 如果某个组件开始承载较重的业务语义，应从"全局通用组件"下沉到"模块复用组件"，避免通用层失真。
- 如果后续有多个组件开始采用一致的录入字段，可继续在本文档顶部增加"字段约定"或"命名约定"，但不要为单个组件再单独发明章节结构。
- `DetailDialogOverlay` 当前未被任何业务代码使用。若后续出现非 `@CustomDialog` 场景需要全屏遮罩层，可启用该组件；否则考虑在后续清理中移除。
