# SecurityTool 可复用 UI 组件说明

## 1. 文档目的

本文档用于沉淀当前项目内已经落地、可在多个页面或模块中复用的 UI 组件，统一说明组件职责、适用场景和使用约束，避免重复造轮子和样式漂移。

统计范围：

- `entry/src/main/ets/components`
- `entry/src/main/ets/components/peripheral`
- 与等待弹窗配套的调用封装：`entry/src/main/ets/utils/TimedLoadingDialogRunner.ets`

不纳入本清单的内容：

- 页面级布局代码
- 仅服务于单个页面、且未沉淀为独立组件的临时 UI 结构
- 纯业务 service、viewmodel、model

## 2. 通用基础组件

| 组件 | 文件 | 作用 | 典型场景 |
| --- | --- | --- | --- |
| BaseCard | `entry/src/main/ets/components/BaseCard.ets` | 卡片基础容器，统一圆角、边框、阴影、悬浮动效和点击行为 | 首页功能卡、摘要卡、模块入口卡 |
| ToolCard | `entry/src/main/ets/components/ToolCard.ets` | 基于 `BaseCard` 的功能入口卡，支持图标、标题、悬浮态 | 首页模块导航入口 |
| MetricSummaryCard | `entry/src/main/ets/components/MetricSummaryCard.ets` | 图标 + 主指标 + 辅助说明的摘要卡 | 总览指标、防火墙或日志状态摘要 |
| CompactSummaryCard | `entry/src/main/ets/components/CompactSummaryCard.ets` | `MetricSummaryCard` 的紧凑版 | 页面头部二级摘要、紧凑信息卡 |
| SectionCard | `entry/src/main/ets/components/SettingsSectionCard.ets` | 带标题和内容区的分组卡片容器 | 设置分区、配置项集合 |
| EmptyStatePanel | `entry/src/main/ets/components/EmptyStatePanel.ets` | 空状态提示面板 | 无数据、无记录、权限不足提示 |
| SubPageHeader | `entry/src/main/ets/components/SubPageHeader.ets` | 子页面统一头部，包含返回、标题、副标题和可选操作区 | 二级详情页、设置页、帮助页 |

### 2.1 组合式表单/配置行

这些组件统一沉淀在 `entry/src/main/ets/components/SectionRows.ets`：

| 组件 | 作用 | 典型场景 |
| --- | --- | --- |
| SectionToggleRow | 标题 + 说明 + 开关 | 启停类配置项 |
| SectionSelectRow | 标题 + 说明 + 下拉选择 | 策略、模式、枚举值配置 |
| SectionActionRow | 标题 + 说明 + 操作按钮 | 立即执行类设置项 |
| SectionSelectInputRow | 标题 + 说明 + 下拉 + 数字输入 | 组合型配置项 |

使用建议：

- 优先用于“设置项列表”而不是复杂业务表格。
- 标题和说明文案应短句化，避免在行内放过长解释。

## 3. 交互与导航组件

| 组件 | 文件 | 作用 | 典型场景 |
| --- | --- | --- | --- |
| SideBar | `entry/src/main/ets/components/SideBar.ets` | 左侧主导航栏 | 主框架页导航 |
| InteractiveMenuRow | `entry/src/main/ets/components/ThemeMenuPopup.ets` | 图标 + 文本的交互菜单行 | 侧边栏项、弹出菜单项、返回按钮 |
| ThemeMenuPopup | `entry/src/main/ets/components/ThemeMenuPopup.ets` | 主题切换与帮助/关于菜单 | 顶部主题菜单 |
| IconTextActionButton | `entry/src/main/ets/components/IconTextActionButton.ets` | 图标 + 文本按钮，支持主按钮和危险按钮风格 | 保存、删除、执行类操作 |

## 4. 弹层与反馈组件

| 组件 | 文件 | 作用 | 典型场景 |
| --- | --- | --- | --- |
| CommonLoadingDialog | `entry/src/main/ets/components/CommonLoadingDialog.ets` | 统一等待弹窗视觉 | 异步提交、模式切换、策略切换 |
| DetailDialogShell | `entry/src/main/ets/components/DetailDialogShell.ets` | 标准详情弹层内容壳，带标题、关闭和滚动区 | 详情查看、信息确认 |
| DetailDialogOverlay | `entry/src/main/ets/components/DetailDialogShell.ets` | 全屏遮罩承载层 | 自定义详情弹层 |
| AddRuleDialog | `entry/src/main/ets/components/AddRuleDialog.ets` | 防火墙规则新增/编辑弹窗 | 自定义规则维护 |
| UserFirewallControlDialog | `entry/src/main/ets/components/UserFirewallControlDialog.ets` | 按用户维度下发防火墙策略的业务弹窗 | 防火墙按用户控制 |

说明：

- `CommonLoadingDialog` 是通用反馈组件。
- `AddRuleDialog`、`UserFirewallControlDialog` 属于业务复用组件，适合在同模块内复用，不建议直接当作全局通用组件使用。

## 5. 外设管理模块内可复用组件

| 组件 | 文件 | 作用 | 典型场景 |
| --- | --- | --- | --- |
| InterfaceControlTab | `entry/src/main/ets/components/peripheral/InterfaceControlTab.ets` | 外设接口管控页主体，封装接口启停和 USB 存储策略选择 | 外设管理 > 接口管控 |
| DeviceRecordList | `entry/src/main/ets/components/peripheral/DeviceRecordList.ets` | 连接记录列表和“详情”入口 | 外设管理 > 连接记录 |
| PolicyList | `entry/src/main/ets/components/peripheral/PolicyList.ets` | 设备策略表格和策略变更操作 | 外设管理 > 策略列表 |
| ConnectionDetailDialog | `entry/src/main/ets/components/peripheral/ConnectionDetailDialog.ets` | 连接记录详情弹层 | 外设管理 > 记录详情 |

说明：

- 这一组组件当前围绕外设管理沉淀，具有明确模块语义。
- 若其它模块只想复用“表格壳子”或“详情壳子”，优先复用 `DetailDialogShell`、`EmptyStatePanel` 等更基础组件，不直接搬用外设模块业务组件。

## 6. 等待弹窗设计说明

### 6.1 组件定义

等待弹窗由两部分组成：

- 视觉组件：`entry/src/main/ets/components/CommonLoadingDialog.ets`
- 调用封装：`entry/src/main/ets/utils/TimedLoadingDialogRunner.ets`

其中：

- `CommonLoadingDialog` 负责统一视觉表现
- `TimedLoadingDialogRunner` 负责统一打开、最短展示时长、关闭和日志输出

### 6.2 设计规范

当前等待弹窗采用以下统一设计：

- 展示位置：页面中央
- 弹窗宽度：`280`
- 内边距：左右 `24`，上下 `28`
- 视觉主体：`44 x 44` 的 `LoadingProgress`
- 文案布局：单行或短句，居中显示
- 背景：跟随主题的卡片背景色
- 圆角：`AppStyles.RADIUS_LG`
- 阴影：浅色/深色主题分别使用轻阴影和深阴影

设计目标：

- 在“操作已开始，但还未完成”的阶段给出稳定反馈
- 避免切换动作过快时完全无感知
- 避免各模块各自实现等待层，导致样式和节奏不一致

### 6.3 交互规则

等待弹窗当前统一遵循以下规则：

- 默认最短展示时长为 `500ms`
- 打开和关闭由 `TimedLoadingDialogRunner` 统一控制
- 同一时刻同一 runner 只允许存在一个等待弹窗
- 页面组件负责创建 `CustomDialogController`
- runner 负责执行任务、补足最短展示时长、关闭弹窗和输出日志

注意：

- `CustomDialogController` 必须在页面组件上下文内创建，不能在普通工具类中直接构造后期望其稳定挂载到页面
- 等待弹窗只负责“处理中”反馈，不承担确认、结果提示或错误解释

### 6.4 当前已接入场景

当前项目中已接入统一等待弹窗的场景如下：

| 页面 | 场景 | 等待文案 |
| --- | --- | --- |
| 防火墙管理首页 | 公共网络模式 / 私有网络模式 / 自定义模式切换 | `正在应用防火墙模式...` |
| 外设管理 > 接口管控 | `USB 接口` 启用/禁用切换 | `正在设置 USB 接口策略，请稍候...` |
| 外设管理 > 接口管控 | `USB 存储设备` 策略切换 | `正在设置 USB 存储策略，请稍候...` |

### 6.5 推荐使用场景

建议使用等待弹窗的场景：

- 触发系统接口调用，用户需要明确感知“已开始处理”
- 操作可能在 `100ms` 到数秒之间完成，直接静默切换会造成“没反应”的误解
- 模式、策略、权限或设备状态切换类操作

不建议使用等待弹窗的场景：

- 纯本地状态切换且能即时完成的操作
- 需要用户二次确认的操作
- 需要展示百分比、进度条、步骤状态的长任务
- 需要在等待过程中允许取消、重试或查看详情的复杂任务

### 6.6 使用方式

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

接入要求：

- `scene-tag` 需要是明确、可搜索的业务场景标识
- 等待文案只描述当前动作，不写结果承诺
- 业务成功和失败提示仍由原有结果链路负责

### 6.7 日志要求

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

## 7. 复用原则

- 优先复用现有基础组件，再决定是否新增新组件。
- 新组件若只服务单一业务页面，优先在业务模块内部沉淀，不直接放入通用层。
- 新增全局通用组件时，需要同时补充本说明文档，注明用途、场景和限制。
- 修改已有组件样式时，应优先确认是否会影响其它已接入页面，避免组件升级引入跨页面视觉回归。

## 8. 后续维护建议

- 后续若日志管理、身份鉴别、工具设置模块继续沉淀出可跨模块复用的弹层、表格或配置组件，应增补到本清单。
- 若后续出现第二类等待反馈样式，例如带进度百分比或可取消任务，应作为新组件类型单独定义，不与当前 `CommonLoadingDialog` 混用。
