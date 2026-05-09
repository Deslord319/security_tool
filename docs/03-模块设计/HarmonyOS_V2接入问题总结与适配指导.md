# SecurityTool HarmonyOS V2 接入问题总结与适配指导

## 1. 目的

本文档基于日志管理模块从 V1/V2 混用迁移到纯 V2 链路的实际过程，总结已经遇到的问题、已验证有效的处理方式，以及后续页面或公共组件继续维护 V2 响应式链路时的适配建议。当前主页面、业务页、主要公共组件和主要 ViewModel 已完成 V2 化；后续如果新增页面、组件或重构状态链路，应优先参考本文档，避免重新引入 V1/V2 混用和中间镜像态。

时间：2026-04-03  
项目：`security_tool`

## 2. 本次迁移中暴露的核心问题

### 2.1 V1 宿主下挂 V2 页面，首次进入响应式链不稳定

现象：

- 从“安全总览”或其它 tab 首次进入日志管理页时，列表和分页已有真实数据，但统计卡不刷新，或“上一页”按钮状态异常。
- 从“存储设置”返回日志页后，同一页面又恢复正常。

原因判断：

- 外层路由宿主和公共容器仍有 V1 状态与 V1 组件链，日志页虽然已切到 V2，但首次挂载时依赖收集不稳定。
- 二次进入或从设置页返回时，页面发生完整重建，异常表象消失。

结论：

- V2 页面即使内部实现正确，只要仍挂在 V1 宿主和 V1 公共链下，首屏状态同步仍可能不稳定。

### 2.2 中间状态拷贝会导致 UI 停留在旧值

现象：

- 实际日志已经入库，底部总数和列表刷新了，但统计卡仍然显示旧值。
- 切出当前界面再回来，统计卡才刷新。

典型错误模式：

- 页面维护一份镜像状态或 renderVersion。
- ViewModel 内部 `cloneState() -> setState(nextState)` 整体替换。
- 父组件先派生一份中间数据，再传给子组件。

结论：

- 在 V2 下，复制状态、镜像状态、桥接状态都容易让局部 UI 错过依赖收集。
- 直接读 `viewModel.state.xxx` 比“先拷贝一份再渲染”稳定得多。

### 2.3 `@Builder` 和方法级桥接会吞掉响应式边界

现象：

- 分页栏页码会更新，但“上一页/下一页”按钮启用态不更新。
- 统计卡通过 `getSummaryTotalCount()` 这类方法取值时不刷新，直接内联读取原始状态后恢复正常。

已经证实存在风险的模式：

- `@Builder actionButton(label, enabled, onTap)` 这类把状态先算成普通参数再转发。
- `getSummaryTotalCount()`、`getCurrentPageSize()` 这类把状态读取包在中间方法里再让 UI 调用。

结论：

- V2 下最稳的方式是：在渲染路径直接读取被 `@Trace` 标记的字段。
- 不要假设“中间计算函数”或“Builder 参数”能稳定保留响应式依赖。

### 2.4 详情弹窗若依赖实时列表二次解析，容易失稳

现象：

- 点击日志详情时存在崩溃/打不开/状态不一致风险。

原因判断：

- 详情层如果只存 `entryId`，弹层打开时再从实时刷新的列表里按 id 回查数据，弹层和列表刷新之间容易互相干扰。

已验证更稳的模式：

- 参考外设管理：
  - 点击时先保存当前记录快照。
  - 使用 `CustomDialogController + @CustomDialog` 打开详情。
  - 弹窗展示稳定数据，不在弹层内部继续依赖实时列表二次解析。

### 2.5 旧包残留会干扰真机结论

现象：

- 本地明明改了代码，但设备上现象像旧逻辑。

结论：

- 每次 fresh deploy 前必须先删除：
  - `hapsigner/entry-default-unsigned.hap`
  - `hapsigner/signApp.hap`
- 再重新拷贝 unsigned、重新签名、重新安装，避免包残留造成误判。

## 3. 这次已经验证有效的做法

### 3.1 页面直接基于 ViewModel 原始状态渲染

已验证有效：

- 在 `LogManagePage.ets` 里直接读取 `this.viewModel.state.list...` 渲染统计卡。
- 不再通过 `LogSummaryCards.ets` 组件中转。
- 不再通过 `getSummary...()` 方法派生。

效果：

- 停留当前页时，日志入库后统计卡和底部总数都能即时刷新。

### 3.2 去掉分页按钮的中间 Builder

已验证有效：

- 在 `LogPaginationBar.ets` 中直接渲染分页按钮。
- 让 `isEnabled` 直接绑定 `this.paginationState.currentPage > 1` 等原始表达式。

效果：

- 从“安全总览”首次进入日志页时，“上一页/下一页”状态恢复正常。

### 3.3 详情弹窗改用稳定快照 + 控制器模式

已切换为：

- 页面在点击日志项时先保存当前 `entry`。
- 使用 `CustomDialogController` 打开 `LogDetailDialog`。
- 详情弹窗改为 `@CustomDialog`。

说明：

- 这套模式与外设管理保持一致，结构上比“页面内联 overlay + 实时回查列表”更稳。

## 4. V2 接入的硬性建议

### 4.1 禁止保留这些过渡写法

- 不要保留 renderVersion、uiRefreshListeners、镜像列表、镜像统计值。
- 不要在页面和子组件之间复制一份 state 再传。
- 不要依赖 `cloneState() -> setState(nextState)` 这种整体替换。
- 不要把关键响应式值先塞进 `@Builder` 参数。
- 不要把关键统计值封装到 `getXxxCount()` 之类的方法后再在 UI 中读取。

### 4.2 V2 推荐写法

- 页面直接持有一个 V2 ViewModel。
- UI 在渲染路径直接读取 `viewModel.state` 的原始字段。
- 复杂状态拆分到 `@ObservedV2 + @Trace` 模型上。
- 详情弹窗、确认弹窗等交互优先用 `CustomDialogController + @CustomDialog`。
- 子组件优先传基础值，少传大对象，避免把状态订阅边界藏进封装层。
- 页面局部态只允许保留“引导显示”语义，例如 `listReady` 这类首屏 loading 开关；它不能承载业务真值，也不能和 `summary/list/pagination/detail` 重叠。

### 4.3 迁移顺序建议

推荐顺序：

1. 先切宿主页面或路由入口
2. 再切该页的 ViewModel 和状态模型
3. 再切该页直接使用的公共组件
4. 最后再清除旧 V1 残留和中间桥接逻辑

原因：

- 先把子组件切成 V2，但仍挂在 V1 宿主下，容易出现“局部看起来好了、首屏仍不稳定”的问题。

## 5. 后续 V2 维护与新增页面适配指导

### 5.1 建议优先级

优先保证公共宿主和跨页面公用链继续保持 V2，再处理具体业务页或新增组件。

推荐顺序：

1. `MainPage.ets`
2. `SideBar.ets`
3. `ThemeMenuPopup.ets`
4. 各业务页及其 ViewModel

### 5.2 当前 V2 基线

当前实现已经完成以下 V2 化基线：

- 页面宿主：`entry/src/main/ets/pages/MainPage.ets`
- 业务页：`entry/src/main/ets/views/**`
- 主要公共组件：`entry/src/main/ets/components/**`
- 主要 ViewModel：`entry/src/main/ets/viewmodels/**`

维护要求：

- 新增页面和可复用组件默认使用 `@ComponentV2`。
- 新增 ViewModel 或页面状态容器默认使用 `@ObservedV2 + @Trace`。
- 不要恢复旧的绝对路径清单；路径统一使用仓库相对路径。
- 如果确实需要 V1 组件或 `@State` 局部态，必须限定为弹窗、输入框、hover、局部动画等 UI 层临时状态，且不得作为业务状态真源。

### 5.3 单页迁移模板

每个页面建议按以下步骤迁移：

1. 把页面切到 `@ComponentV2`
2. 把 ViewModel 切到 `@ObservedV2 + @Trace`
3. 清理 `@State viewModel = new XxxViewModel()` + 额外镜像状态
4. 把 UI 中间方法派生收回到直接状态读取
5. 把直接依赖的公共组件一起切到 V2
6. 对话框、详情层统一改成 `CustomDialogController + @CustomDialog`
7. 真机验证首屏、停留刷新、切页返回、弹窗开关

## 6. 验证清单

每个页面接入 V2 后，至少验证：

- 首次从其它 tab 进入时是否正常
- 停留当前页时异步数据更新是否立即反映到 UI
- 返回上一页/再进入后状态是否一致
- 详情弹窗是否稳定打开与关闭
- 关键按钮的 enable/disable 状态是否即时更新
- 真机错误日志最近 60 秒内无新增 `E` 级错误

## 7. 构建、签名、安装建议流程

1. 构建 HAP
2. 删除旧包：
   - `hapsigner/entry-default-unsigned.hap`
   - `hapsigner/signApp.hap`
3. 拷贝新的 unsigned HAP 到 `hapsigner`
4. 重新签名
5. 覆盖安装到真机
6. 启动应用并验证目标页面

## 8. 当前结论

日志管理模块的 V2 接入已经证明几件事：

- 纯 V2 状态链是可行的。
- 问题主要出在 V1/V2 混用、状态拷贝、Builder 桥接、方法级派生。
- 当前公共宿主和主要业务页面已完成 V2 化；后续维护重点是防止新增代码重新引入 V1/V2 混用、跨层镜像态和不稳定的 Builder 桥接。
- 当前日志管理里保留的 `listReady` 属于页面首屏引导态，不是业务中间态；后续可以继续并回 `loading/initialized`，但它不应扩散成新的镜像状态模式。
