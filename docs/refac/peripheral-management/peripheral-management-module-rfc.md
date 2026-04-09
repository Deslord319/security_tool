# RFC v1：外设管理模块收口与演进设计

> 状态：Draft
> 日期：2026-04-08
> 关联设计：`docs/03-模块设计/外设管理组件设计说明.md`
> 本文定位：外设管理模块执行层总 RFC，作为接口管控、设备连接记录、单设备策略三条子链路的总纲

## 1. 背景

外设管理是当前模块设计最完整、子链路也最多的模块之一。现有文档已经覆盖了：

- 接口管控
- 设备连接记录
- 单设备策略

但 `docs/refac/peripheral-management/` 目前主要聚焦“设备连接记录”子链路，缺少整个模块级总 RFC，导致后续很容易只优化局部链路，而忽略外设管理作为一个整体模块的边界和阶段目标。

## 2. 目标

1. 固定外设管理模块的三条核心子域边界。
2. 明确 `PeripheralViewModel` 与各子 ViewModel 的职责划分。
3. 把接口管控、连接记录、单设备策略三条链路的后续演进统一纳入同一个总纲。
4. 让后续专项文档继续挂靠在模块总 RFC 之下，而不是彼此并列失联。

## 3. 范围

### 3.1 In Scope

- `entry/src/main/ets/views/peripheral/**`
- `entry/src/main/ets/viewmodels/peripheral/**`
- `entry/src/main/ets/services/peripheral/**`
- `entry/src/main/ets/components/peripheral/**`
- 外设管理相关模型、mapper、repository

### 3.2 Out of Scope

- 新增新的外设类型支持
- 完整蓝牙运行时管控能力落地
- 非外设模块的首页摘要逻辑
- 企业管理员激活机制本身的系统实现

## 4. 模块边界

### 4.1 三条子域

#### 接口管控

- 负责 USB、蓝牙等接口级开关与策略下发
- 关注的是“接口是否可用”

#### 设备连接记录

- 负责运行时连接事件采集、落库、列表展示、详情查看和清理
- 关注的是“发生过什么”

#### 单设备策略

- 负责黑白名单或设备级策略配置与清理
- 关注的是“某个具体设备应该如何被对待”

### 4.2 禁止混用

禁止把以下语义混在一起：

- 用连接记录替代设备策略
- 用接口开关状态推断单设备策略结论
- 用单设备策略列表直接代替运行时连接记录

## 5. 目标调用链

```text
PeripheralPage
  -> PeripheralViewModel
    -> InterfaceControlViewModel
    -> PeripheralRecordViewModel
    -> PeripheralPolicyViewModel
      -> services/peripheral/**
```

说明：

- `PeripheralViewModel` 负责页面级协调与组合态。
- 三个子 ViewModel 各自对自己的业务真相负责。
- 页面层不直接编排 service。

## 6. Story 拆分

### Story A：模块级状态边界收口

- 目标：
  - 固定主 ViewModel 与三个子 ViewModel 的职责
  - 页面只持有必要局部态
- 验收：
  - 页面不直接混写三条业务链路

### Story B：接口管控链路稳定化

- 目标：
  - 固定接口状态读取、切换、失败提示和刷新口径
  - 明确权限不足或能力降级时的 UI 语义
- 验收：
  - 接口控制结果可回显
  - 降级场景有明确提示

#### Story B 补充设计：接口管控行组件统一

- 现状问题：
  - `InterfaceControlTab.ets` 中大部分接口行使用本地 `controlRow()` 渲染。
  - `USB 存储设备` 这一行单独复用 `SectionSelectRow`。
  - 结果是同一页签内部出现两套行样式，导致 `USB 存储设备` 在 Select 宽度、留白、圆角和处理态表现上与其它接口项不一致。

- 已确认约束：
  - 当前 `SectionSelectRow` 的异步选择 / optimistic / 失败回退能力，实际只有 `外设管理 > 接口管控 > USB 存储设备` 在使用。
  - `工具设置`、`身份鉴别`、`日志管理` 中对 `SectionSelectRow` 的使用均为同步 `onSelect` 场景，不依赖异步回退。

- 设计决策：
  - 本次不修改通用组件 `SectionSelectRow` 的视觉样式，以避免把外设管理页面内的局部 UI 问题扩散到其它模块。
  - `USB 存储设备` 行改为与其它接口项统一，由 `InterfaceControlTab.ets` 内部同一套行模板负责渲染。
  - 原先附着在 `SectionSelectRow` 中、仅被 `USB 存储设备` 使用的异步回退逻辑，下沉到 `InterfaceControlTab.ets` 本地实现。
  - `SectionSelectRow` 回归为同步配置行组件；若其异步分支在迁移后无其它调用方，可一并删除相关代码，避免通用组件长期承载单页特例逻辑。

- 预期收益：
  - 接口管控页内所有行保持统一视觉结构。
  - 改动影响面限制在外设管理页签内部，不波及 `工具设置`、`身份鉴别`、`日志管理`。
  - `USB 存储设备` 的“下发失败后自动回退到原值”能力继续保留，但归属到真正需要它的业务页面。

### Story C：连接记录链路持续收口

- 目标：
  - 以现有 `device-connection-record-*` 文档为子计划，继续推进运行时、仓储、测试和清理
- 验收：
  - 连接记录链路遵循已有专项计划
  - 与模块总 RFC 的边界一致

### Story D：单设备策略链路补强

- 目标：
  - 固定单设备策略加载、编辑、保存、清理和列表呈现边界
  - 区分策略页记录与连接记录
- 验收：
  - 单设备策略刷新后可恢复
  - 清理语义与连接记录清理不混淆

### Story E：页面组合态与回归测试补齐

- 目标：
  - 覆盖三条子域同时存在时的页面组合态
  - 避免局部链路正确但整页组合错乱
- 验收：
  - 页面切页、刷新、清理后组合态稳定

## 7. Round 划分

### Round 1：模块边界和主从 ViewModel 收口

- 处理 Story A

### Round 2：接口管控和单设备策略补强

- 处理 Story B、Story D

### Round 3：连接记录专项继续推进

- 处理 Story C
- 继续复用并引用现有 `device-connection-record-*` 文档

### Round 4：整页组合回归

- 处理 Story E
- 强化页面组合态验证

## 8. 与现有专项文档关系

以下文档继续有效，但它们都属于本模块总 RFC 之下的专项子计划：

- `device-connection-record-runtime-service-migration-plan.md`
- `device-connection-record-runtime-service-migration-report.md`
- `device-connection-record-mock-test-design.md`
- `device-connection-record-mock-test-implementation-plan.md`
- `device-connection-record-mock-test-tracker.md`

## 9. 风险

1. 外设管理最容易因为子域多而退化成“大页面 + 多 service 直连”。
2. 接口状态、连接事件、设备策略三者语义不同，如果状态模型不分层，很容易互相污染。
3. 当前专项文档过于聚焦连接记录，可能掩盖单设备策略和接口管控的长期维护缺口。

## 10. 验收信号

- 外设管理作为一个整体模块有明确总纲。
- 三条子域职责清晰，不互相替代。
- 连接记录专项文档能在本 RFC 中找到挂靠关系。
- 页面层不再成为三条链路的临时编排中心。

## 11. 后续建议

1. 后续若新增其它外设类型，优先在本模块总 RFC 中补范围，再拆专项文档。
2. 若要继续拆 Session / PR / Round，可针对单设备策略链路补独立专项 RFC，但应以本文为模块总纲。
