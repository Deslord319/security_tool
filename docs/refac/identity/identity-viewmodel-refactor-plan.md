# 身份鉴别模块详细改造计划

> 状态：Draft
> 日期：2026-04-11
> 关联 RFC：`docs/refac/identity/identity-module-rfc.md`
> 关联设计：`docs/03-模块设计/身份鉴别组件设计说明.md`
> 本文定位：面向实现的详细改造计划，聚焦“身份鉴别”页面作为口令策略配置页的职责收口和 MVVM 纯化

## 0. 当前完成度

基于 2026-04-11 最近一轮实现，当前计划执行状态如下：

- 阶段 1：已完成
- 阶段 2：已完成
- 阶段 3：已完成基础收口
- 阶段 4：已部分完成

当前已落地结果：

- `IdentityPage` 已收口为纯 UI 编排层
- `IdentitySettingsViewModel` 已成为唯一业务入口
- `IdentityService` 已承担 `PasswordPolicy <-> PasswordComplexityConfig` 的基础转换职责
- 已补 `initialized / loading / saving / adminActivated / adminMessage / canSave / validationMessage`
- 身份鉴别相关 unit test 已同步到最新接口并通过模块测试
- 已完成真机构建、签名、安装与启动验证

当前仍未完全闭合的部分：

- 设备侧 ohosTest 仍以页面展示冒烟为主，未覆盖完整保存链路
- 对 `canSave / validationMessage / saving` 的 UI 绑定尚未启用，本次保留为 ViewModel 内部派生状态

## 1. 改造前提

本次不讨论“身份鉴别”名称是否过大，也不调整产品入口命名。

固定前提如下：

- 页面仍然叫“身份鉴别”
- 当前实现范围只覆盖账户口令策略配置
- 页面职责就是“配置不同字段，然后下发系统密码策略”
- 不把启动认证、PIN/指纹、修改密码入口重新并入本页

换句话说，本次不是扩功能，而是把现有简单业务做成边界清晰、职责稳定、便于维护的标准配置页。

## 2. 改造目标

### 2.1 业务目标

- 维持当前用户可见字段和交互语义不变
- 维持“读取当前系统策略并回显”能力不变
- 维持“保存时下发系统 `PasswordPolicy`”能力不变
- 维持“管理员未激活时不可真实下发”的约束不变

### 2.2 架构目标

- `IdentityPage` 只负责 UI 绑定、事件转发、弹层展示
- `IdentitySettingsViewModel` 成为页面唯一业务入口
- `IdentityService` 只负责策略模型转换和系统读写
- 页面态、领域态、系统态三层边界清晰

### 2.3 维护目标

- 后续新增口令策略字段时，优先扩展 ViewModel 和 Service，不再把逻辑散落在页面
- 让身份鉴别页与工具设置页形成一致的“request -> dialog”交互风格
- 把管理员状态、脏态、校验态都沉淀为可观察状态，避免页面自己拼业务判断

## 3. 改造范围

### 3.1 In Scope

- `entry/src/main/ets/views/identity/settings/IdentityPage.ets`
- `entry/src/main/ets/viewmodels/identity/settings/IdentitySettingsViewModel.ets`
- `entry/src/main/ets/services/identity/settings/IdentityService.ets`
- 身份鉴别相关常量和必要的类型定义

### 3.2 Out of Scope

- `entry/src/main/ets/services/identity/auth/AuthService.ets`
- `entry/src/main/ets/services/identity/auth/UserAuthAdapter.ets`
- 启动认证流程
- 工具设置页认证方式选择
- 修改密码入口
- 新增生物识别、人脸、多因子等能力
- 改页面名称、改路由名称、改导航结构

## 4. 现状问题清单

## 4.1 页面层承担了过多业务逻辑

当前 `IdentityPage` 直接负责：

- 管理员状态探测
- 页面初始化读取
- 保存前管理员检查
- 保存前风险确认判定
- 保存结果语义拼装

这些逻辑本应由 ViewModel 统一承接。

## 4.2 ViewModel 不是完整业务入口

当前 `IdentitySettingsViewModel` 已承担表单编辑和保存，但尚未完整承担：

- 初始化
- 管理员状态感知
- 加载失败时的状态组织
- 保存前统一决策

结果是页面和 ViewModel 共同组成业务入口，职责边界不稳定。

## 4.3 表单态与系统态映射边界不够清楚

当前实现里：

- 页面关心部分初始化流程
- ViewModel 直接处理部分系统策略细节
- Service 负责 `PasswordPolicy` 读写和 regex 构造

虽然功能可用，但后续新增字段时，容易出现多个位置同步改动。

## 4.4 模块语义容易被误读

“身份鉴别”这个名字容易让人预期模块会负责：

- 认证方式选择
- PIN/指纹能力
- 修改密码
- 账户认证流程

但当前代码实际上只做口令策略配置。由于本次不改名称，就更需要在架构上把这个事实表达清楚。

## 5. 目标职责模型

## 5.1 View：只保留编排职责

`IdentityPage` 改造后只负责：

- 页面出现时触发 `viewModel.initialize()`
- 基于 `viewModel.state` 渲染字段
- 将交互事件转发给 `viewModel`
- 在点击保存时调用 `viewModel.requestSave()`
- 根据返回结果弹结果框或确认框

明确禁止页面继续直接承担：

- 管理员探测
- 系统策略读取
- 业务校验
- 保存前业务分支判断
- 系统服务调用

## 5.2 ViewModel：唯一业务入口

`IdentitySettingsViewModel` 改造后负责：

- 初始化页面状态
- 探测管理员状态
- 读取系统口令策略
- 将系统态映射为表单态
- 管理用户编辑态
- 统一脏态判定
- 统一字段校验
- 统一保存前确认逻辑
- 发起保存请求
- 保存成功后刷新初始快照

页面与服务层之间不再直接通信。

## 5.3 Service：纯领域转换和系统调用

`IdentityService` 改造后负责：

- 读取系统 `PasswordPolicy`
- 下发系统 `PasswordPolicy`
- 构建复杂度 regex
- 在领域配置与系统策略之间做转换

Service 不感知页面索引、弹窗文案、按钮行为等 UI 语义。

## 6. 目标状态模型

建议将当前 ViewModel 状态整理为三层。

## 6.1 生命周期状态

用于描述页面当前处于什么阶段：

- `initialized`
- `loading`
- `saving`

作用：

- 页面可以统一决定是否展示骨架态、空白占位或禁用保存按钮
- 后续调试时更容易判断问题发生在“初始化”还是“保存”

## 6.2 管理员状态

用于描述是否具备真实读写口令策略的前提：

- `adminActivated`
- `adminMessage`
- 可选：`adminErrorCode`

作用：

- 页面不再自己探测管理员状态
- 保存可用性和提示文案统一由 ViewModel 推导

## 6.3 编辑态

用于描述当前页面字段值、初始快照和派生校验结果：

- `config`
- `initialConfig`
- `hasChanges`
- `canSave`
- `validationMessage`

其中 `config` 建议只表达页面编辑字段，不直接承载系统态语义。

## 6.4 建议表单字段结构

建议保留现有字段能力，但显式建模：

- `minLengthIndex`
- `requireUppercase`
- `requireLowercase`
- `requireDigit`
- `requireSpecialChar`
- `validityMode`
- `presetValidityIndex`
- `customValidityDays`

说明：

- `validityMode` 用来表达“预置 / 永久 / 自定义”三态
- 这样比单纯依赖一个下拉索引更清楚
- 页面字段如何展示仍可保持现有交互，不强制改 UI 组件

## 7. 目标交互模型

## 7.1 初始化流程

目标流程如下：

1. 页面 `aboutToAppear`
2. 页面调用 `viewModel.initialize()`
3. ViewModel 探测管理员状态
4. 若管理员未激活，则进入默认编辑态并输出原因
5. 若管理员已激活，则读取系统口令策略
6. 将系统策略映射为表单态
7. 记录 `initialConfig`
8. 更新 `initialized/loading/hasChanges/canSave`

预期结果：

- 页面不再知道“管理员探测”和“读取当前策略”的细节
- 初始化失败时仍保留一个可解释的 UI 状态

## 7.2 编辑流程

用户修改任一字段时：

1. 页面触发 `viewModel.setXxx()`
2. ViewModel 修改 `config`
3. ViewModel 重新计算 `hasChanges`
4. ViewModel 重新计算 `validationMessage`
5. ViewModel 更新 `canSave`

预期结果：

- 所有保存可用性都由 ViewModel 派生
- 页面不再做任何“能不能保存”的业务判断

## 7.3 保存流程

目标流程如下：

1. 页面点击保存
2. 页面调用 `viewModel.requestSave()`
3. ViewModel 统一检查：
   - 是否正在保存
   - 是否有变更
   - 管理员是否已激活
   - 自定义有效期是否合法
   - 是否命中“有效期为 0”的风险确认
4. 如需确认，则返回 `confirm`
5. 页面弹确认框
6. 用户确认后，页面再次调用保存
7. ViewModel 构建领域配置并调用 Service 下发
8. 保存成功后刷新 `initialConfig`
9. 返回成功或失败结果给页面展示

## 7.4 返回结果模型

建议和工具设置页对齐，统一为 action request 模式：

- `none`
- `result`
- `confirm`

这样页面层只处理三种结果，不承担业务语义判断。

## 8. 领域模型与映射规划

## 8.1 页面表单态

表单态只表达用户正在编辑的字段，不应该直接表达系统 `PasswordPolicy`。

例如：

- 使用 `customValidityDays: string` 保留输入态
- 使用 `minLengthIndex` 对应 UI 下拉

## 8.2 领域配置态

建议固定一个稳定的领域配置模型，例如：

- `minLength`
- `requireUppercase`
- `requireLowercase`
- `requireDigit`
- `requireSpecialChar`
- `validityPeriod`

这个模型不依赖页面下拉索引，也不依赖系统 regex 文本。

## 8.3 系统策略态

系统态由 `securityManager.PasswordPolicy` 表示。

Service 负责：

- `PasswordPolicy -> 领域配置`
- `领域配置 -> PasswordPolicy`

ViewModel 负责：

- `表单态 -> 领域配置`
- `领域配置 -> 表单态`

通过这层拆分，可以把“UI 结构变化”和“系统 API 变化”解耦。

## 9. 文件级改造清单

## 9.1 `IdentityPage.ets`

计划改动：

- 删除页面内的管理员状态探测逻辑
- 删除页面内的策略读取逻辑
- 删除页面内的保存前业务判断逻辑
- 保留字段布局和现有组件结构
- 改为只调用 `viewModel.initialize()`
- 改为只调用 `viewModel.requestSave()`
- 根据返回结果统一弹确认框和结果框

预期结果：

- 页面成为纯 UI 编排层
- 页面代码体积明显缩小

## 9.2 `IdentitySettingsViewModel.ets`

计划改动：

- 增加初始化入口，接管管理员探测和策略读取
- 增加统一 UI 状态模型
- 增加统一校验与 `canSave` 推导
- 增加 `requestSave()` 风格接口
- 增加保存确认分支
- 保留现有字段设置方法，但内部全部走统一刷新逻辑

预期结果：

- ViewModel 成为身份鉴别页面唯一业务入口
- 页面与服务层完全解耦

## 9.3 `IdentityService.ets`

计划改动：

- 保留 `buildComplexityRegex()`
- 保留 `getPasswordPolicyWithResult()`
- 保留 `setPasswordPolicyWithResult()`
- 视需要新增或收口：
  - `toConfig()`
  - `toPasswordPolicy()`

预期结果：

- Service 不再感知页面字段结构
- 系统策略映射逻辑集中到服务层

## 9.4 `DataModels.ets` 和常量文件

计划改动：

- 仅在确有必要时补充纯类型定义
- 尽量不把页面专属状态塞回公共 `DataModels`

原则：

- 页面专属状态优先放在 ViewModel 文件内
- 领域共享配置再进入公共模型

## 10. 分阶段实施计划

## 阶段 1：收口 ViewModel 入口

目标：

- 把初始化、管理员感知、读取策略、保存前判断都移入 ViewModel

实施项：

- 为 ViewModel 增加 `initialize()`
- 为 ViewModel 增加统一 action request 返回结构
- 页面保存入口改为只调用 ViewModel

验收信号：

- 页面不再直接依赖 `IdentityService`
- 页面不再直接调用管理员探测
- 保存前业务决策不再散落在页面

## 阶段 2：整理状态模型

目标：

- 明确生命周期状态、管理员状态、编辑态

实施项：

- 引入统一的 `UiState`
- 收口 `hasChanges`
- 增加 `validationMessage`
- 增加 `canSave`

验收信号：

- 是否允许保存只由 ViewModel 决定
- 页面不再拼接“无改动 / 无管理员 / 输入非法”等业务语义

## 阶段 3：收口映射层

目标：

- 明确表单态、领域态、系统态三层映射

实施项：

- 整理表单态与领域配置态的转换方法
- 整理领域配置态与 `PasswordPolicy` 的转换方法
- 固定 regex 构造唯一出口

验收信号：

- 新增字段时，不需要跨页面、ViewModel、Service 到处找映射点

## 阶段 4：补文档与维护约束

目标：

- 让后续维护者直接知道模块真实边界

实施项：

- 更新身份鉴别模块设计说明
- 补充本计划与 RFC 之间的引用关系
- 在必要位置注明“当前模块仅覆盖口令策略配置”

验收信号：

- 文档不再让维护者误以为本页负责认证方式和启动鉴权

## 11. 验证计划

本次虽然不扩功能，但必须验证原行为不回归。

### 11.1 初始化回显

- 管理员已激活时，可正确读取系统策略并回显
- 管理员未激活时，页面能进入默认态且提示清晰
- 读取失败时，不导致页面崩溃

### 11.2 字段编辑

- 每个开关和下拉项都能正确更新编辑态
- 自定义有效期仅允许数字输入
- 切换自定义和非自定义模式时，字段值行为符合预期

### 11.3 保存行为

- 无改动时阻止保存
- 自定义有效期非法时阻止保存
- 自定义有效期为 `0` 时弹确认
- 管理员未激活时不可真实保存
- 保存成功后 `hasChanges` 复位
- 保存失败后不丢用户编辑内容

### 11.4 映射行为

- regex 构造保持与当前规则一致
- 预置有效期和自定义有效期回显正确

## 11.5 自动化覆盖现状

截至 2026-04-11，自动化覆盖状态如下：

- `entry/src/test/identity/service-behavior.test.ets`
  - 覆盖了 `buildComplexityRegex`、`buildDescription`、基础读写结果结构
- `entry/src/test/identity/service.test.ets`
  - 已改为真实映射测试，覆盖 `toConfig`、`toPasswordPolicy`、描述和 regex 关键路径
- `entry/src/test/identity/settings-viewmodel.test.ets`
  - 已同步到最新实现，覆盖 `initialize()`、`requestSave()`、管理员状态、立即过期确认、无变更拦截、保存成功和失败分支
- `entry/src/ohosTest/ets/test/identity/page.test.ets`
  - 当前仅覆盖页面标题和字段冒烟，不覆盖管理员状态、保存确认和结果反馈

最近验证结果：

- `hvigorw test --mode module -p product=default -p module=entry@default` 已通过
- 身份鉴别相关 unit test 已与当前接口保持一致

结论：

- 自动化测试覆盖已明显补强，但仍未覆盖完整设备侧保存链路
- 当前可以认为“开发态 + unit test 已闭环”
- 若要继续补全，应优先增强 `entry/src/ohosTest/ets/test/identity/page.test.ets`

## 12. 主要风险与控制措施

## 12.1 风险：初始化迁移后回显异常

表现：

- 页面字段默认值覆盖系统真实值

控制措施：

- 先写清 `initialize()` 顺序
- 避免初始化中重复重置状态

## 12.2 风险：永久有效期语义丢失

表现：

- `undefined`、预置值、自定义值三者混淆

控制措施：

- 显式建模有效期模式
- 保留映射单元测试或最小回归验证

## 12.3 风险：保存后脏态不正确

表现：

- 保存成功后仍显示有变更
- 或修改后 `hasChanges` 不触发

控制措施：

- 固定 `initialConfig` 刷新时机
- 统一由同一快照比较函数计算脏态

## 12.4 风险：页面仍残留业务判断

表现：

- 改完后业务规则一部分在页面，一部分在 ViewModel

控制措施：

- 代码评审时重点检查 Page 是否还直接依赖 Service 或管理员探测能力

## 13. 最终验收标准

满足以下条件即可视为本次改造完成：

- “身份鉴别”页面仍保持当前功能范围和用户可见字段
- 页面层不再直接承担管理员探测、系统读取、保存前决策
- `IdentitySettingsViewModel` 成为唯一业务入口
- `IdentityService` 仅承担策略转换和系统读写
- 保存、校验、确认、脏态逻辑统一收口
- 后续如果仅新增一个口令策略字段，不需要重写页面业务框架

## 14. 建议的后续顺序

建议按以下顺序实施：

1. 先改 `IdentitySettingsViewModel`
2. 再瘦身 `IdentityPage`
3. 再整理 `IdentityService`
4. 最后补文档和回归验证

理由：

- 先固定业务入口，后续页面和服务层改造才不会反复横跳
- 这个顺序对现有行为影响最可控

## 15. 备注

本计划故意不讨论是否把模块改名为“账户策略”或“口令策略”。

当前决策是：

- 名称保留“身份鉴别”
- 实现范围收口为“账户口令策略配置页”

如果后续产品层面要重新统一“身份鉴别”的语义，再单独开一轮信息架构讨论，不和本次 MVVM 改造混做一件事。
