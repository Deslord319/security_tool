# 外设管理-USB 接口 AsyncSelectRow 对齐方案

> 状态：Draft
> 日期：2026-04-09
> 适用范围：仅处理“接口管控 > USB 接口”切换失败时的 Select 回退，不扩展到其它接口项
> 本轮目标：在不破坏当前 MVVM 架构的前提下，让 `USB 接口` 与 `USB 存储设备` 使用同一套异步选择交互

## 1. 背景

当前“外设管理 -> 接口管控”页签中已经出现两条不同的选择控件链路：

- `USB 存储设备` 已接入 `AsyncSelectRow`
- `USB 接口` 仍使用 `InterfaceControlTab.ets` 内部的普通 `Select`

这导致同一页签内交互能力不一致：

- `USB 存储设备` 在策略下发失败时可以自动回退到原选项
- `USB 接口` 在策略下发失败时不具备同等回退能力

本轮讨论已确认接受 `AsyncSelectRow` 作为异步选择组件，不再回退到“增强 `SectionSelectRow`”方案。

## 2. 目的

1. 让 `USB 接口` 复用 `AsyncSelectRow`
2. 让 `USB 接口` 在切换失败时自动回退到旧选项
3. 保留当前页面层的 USB loading dialog 和失败提示
4. 保持现有 MVVM 分层不变，不改 ViewModel / Service 业务职责

## 3. 修改代码文件范围

- `entry/src/main/ets/components/peripheral/interface-control/InterfaceControlTab.ets`
- `entry/src/main/ets/views/peripheral/overview/PeripheralPage.ets`

## 4. 设计约束

### 4.1 必须保持的分层

- `InterfaceControlTab.ets`
  - 只负责渲染和抛出用户操作事件
- `PeripheralPage.ets`
  - 负责页面交互编排、USB 专属 loading、失败弹窗
- `PeripheralViewModel` / `InterfaceControlViewModel`
  - 继续负责业务状态和策略调用
- `PeripheralService`
  - 继续负责系统能力下发

### 4.2 本轮禁止事项

- 不修改 `ViewModel` 层返回模型
- 不修改 `PeripheralService` 的策略下发逻辑
- 不一次性迁移蓝牙、Wi-Fi、HDC 等其它接口项
- 不重新设计通用组件体系

## 5. 当前代码现状

### 5.1 `handleInterfaceToggle` 的职责

`PeripheralPage.ets` 中的 `handleInterfaceToggle(feature, disallow)` 当前承担页面层接口切换编排职责：

- 接收接口标识和启用/禁用状态
- 调用 `this.viewModel.toggleInterface(feature, disallow)`
- 对 USB 分支额外包裹 `usbLoadingRunner.run(...)`
- 在失败时弹出错误提示

当前它返回 `Promise<void>`，适合普通 `Select` 事件，不适合 `AsyncSelectRow` 这种需要布尔结果驱动“保留 / 回退”的异步组件。

### 5.2 `USB 存储设备` 的现有链路

当前 `USB 存储设备` 已经走完整的异步布尔返回链：

```text
InterfaceControlTab.storageItem()
  -> AsyncSelectRow
    -> onUsbStoragePolicyChange(index)
      -> PeripheralPage.handleUsbStoragePolicyChange(index)
        -> this.viewModel.setUsbStoragePolicy(index)
```

这条链路已经满足：

- 成功返回 `true`
- 失败返回 `false`
- 失败时页面层负责弹窗
- `AsyncSelectRow` 负责自动回退

本轮目标不是重做新链路，而是让 `USB 接口` 与其保持一致。

## 6. 方案设计

### 6.1 总体方案

采用“最小改动、只改接线”的方案：

1. `USB 接口` 不再走 `toggleItem() -> controlRow() -> Select`
2. `USB 接口` 改为单独使用 `AsyncSelectRow`
3. `PeripheralPage.ets` 新增 USB 专用异步处理方法，返回 `Promise<boolean>`
4. 原有 `handleInterfaceToggle(feature, disallow)` 保留，继续服务其它接口项

### 6.2 `InterfaceControlTab.ets` 调整方案

新增 USB 专用异步事件：

```ts
@Event onUsbInterfaceToggleAsync?: (disallow: boolean) => Promise<boolean>
```

新增 USB 专用 builder，例如：

```ts
@Builder
private usbInterfaceItem() {
  AsyncSelectRow({
    label: PeripheralStrings.usbInterfaceTitle,
    description: PeripheralStrings.usbInterfaceDescription,
    options: PeripheralStrings.interfaceToggleOptions,
    selectedIndex: this.usbDisabled ? 1 : 0,
    processing: this.interfaceControlProcessingKey === PeripheralService.FEATURE_USB,
    currentTheme: this.currentTheme,
    optimistic: true,
    onSelectAsync: async (nextIndex: number): Promise<boolean> => {
      if (!this.onUsbInterfaceToggleAsync) {
        return false
      }
      return await this.onUsbInterfaceToggleAsync(nextIndex === 1)
    }
  })
}
```

页面结构调整为：

- `USB 接口` 使用 `usbInterfaceItem()`
- `USB 存储设备` 继续使用 `storageItem()`
- 其它接口项继续使用 `toggleItem()`

### 6.3 `PeripheralPage.ets` 调整方案

保留现有：

```ts
private async handleInterfaceToggle(feature: string, disallow: boolean): Promise<void>
```

新增 USB 专用异步方法：

```ts
private async handleUsbInterfaceToggle(disallow: boolean): Promise<boolean>
```

该方法内部复用当前 `handleInterfaceToggle` 中 USB 分支的既有逻辑：

- 使用 `usbLoadingRunner.run(...)`
- 调用 `this.viewModel.toggleInterface(PeripheralService.FEATURE_USB, disallow)`
- 失败时沿用现有错误提示逻辑
- 成功返回 `true`
- 失败返回 `false`

`InterfaceControlTab({...})` 调用处新增：

```ts
onUsbInterfaceToggleAsync: async (disallow: boolean): Promise<boolean> =>
  this.handleUsbInterfaceToggle(disallow)
```

### 6.4 状态映射约定

`USB 接口` 选择项与业务值映射固定如下：

- `启用`：`selectedIndex = 0`，`disallow = false`
- `禁用`：`selectedIndex = 1`，`disallow = true`

该映射只在组件层进行一次，不向下扩散到 ViewModel / Service。

## 7. 实施步骤

### 步骤 A：补齐 USB 接口的异步事件契约

输入：

- `InterfaceControlTab.ets` 当前参数定义
- `PeripheralPage.ets` 当前 `InterfaceControlTab({...})` 调用方式

输出：

- `InterfaceControlTab.ets` 新增 `onUsbInterfaceToggleAsync`
- 页面层可向 USB 行传入 `Promise<boolean>` 事件

验收标准：

- USB 行具备独立异步事件入口
- 原有 `onInterfaceToggle` 不受影响

### 步骤 B：将 USB 接口行切换到 `AsyncSelectRow`

输入：

- 步骤 A 的事件契约
- 当前 `usbDisabled` 状态

输出：

- `USB 接口` 改为 `AsyncSelectRow`
- 选项展示与 `USB 存储设备` 保持同类交互

验收标准：

- `USB 接口` 不再走 `controlRow()`
- `USB 接口` 切换行为由 `AsyncSelectRow` 驱动

### 步骤 C：页面层新增 USB 专用布尔返回方法

输入：

- 当前 `handleInterfaceToggle`
- 当前 `usbLoadingRunner`

输出：

- `PeripheralPage.ets` 新增 `handleUsbInterfaceToggle(disallow): Promise<boolean>`
- 保留现有 loading 和失败弹窗

验收标准：

- USB 成功时返回 `true`
- USB 失败时返回 `false`
- 失败提示与现状一致

### 步骤 D：联调状态映射与回退行为

输入：

- 步骤 B、步骤 C 的实现结果

输出：

- 确认 `启用/禁用` 与 `false/true` 映射正确
- 确认失败回退正确

验收标准：

- 成功时保留新值
- 失败时自动回退旧值
- 处理期间控件禁用

## 8. 并行执行建议

可并行：

- 步骤 B
- 步骤 C

前提：

- 步骤 A 已先明确 USB 专用异步事件签名

不可并行：

- 步骤 D

说明：

- `InterfaceControlTab.ets` 与 `PeripheralPage.ets` 可由不同 session 分别改动
- 但必须先统一 `onUsbInterfaceToggleAsync` 的签名和布尔返回语义

## 9. 完成判定

满足以下条件才算本轮完成：

1. `USB 接口` 已接入 `AsyncSelectRow`
2. USB 切换成功时，Select 保留新值
3. USB 切换失败时，Select 自动回退旧值
4. 失败时页面仍弹出原有错误提示
5. `USB 存储设备` 现有行为不受影响
6. 其它接口项现有行为不受影响

## 10. 后续建议

本轮完成后，再单独评估以下问题，不在本轮内处理：

1. 是否将蓝牙、Wi-Fi、HDC 等接口项也迁移到 `AsyncSelectRow`
2. `InterfaceControlTab.ets` 中 `controlRow()` 与 `AsyncSelectRow` 是否需要进一步统一
3. `AsyncSelectRow` 是否应沉淀为全局异步选择行组件规范
