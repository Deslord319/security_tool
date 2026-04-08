# RFC v1：日志管理模块状态收敛与持续演进设计

> 状态：Draft
> 日期：2026-04-08
> 关联设计：
> - `docs/03-模块设计/日志管理模块V2状态收敛与实施设计.md`
> - `docs/03-模块设计/日志管理模块重构方案.md`
> 本文定位：日志管理模块执行层 RFC，作为后续状态收口、测试补齐和性能稳定化的统一入口

## 1. 背景

日志管理是当前代码中状态最复杂的模块之一。它同时覆盖：

- 运行时采集
- 查询筛选
- 分页列表
- 详情弹窗
- 导出与存储设置

现有设计文档已经给出较完整的状态收敛原则，但 `docs/refac/` 下缺少一个面向执行的统一 RFC，导致后续修改容易只修局部症状，不按单一真相源原则推进。

## 2. 目标

1. 固定 `LogManageViewModel` 为页面业务状态唯一真相源。
2. 明确列表、筛选、分页、详情、采集状态的边界。
3. 约束页面和子组件不得重新维护镜像业务态。
4. 为日志采集稳定性、导出链路和测试补齐提供 Story / Round 计划。

## 3. 范围

### 3.1 In Scope

- `entry/src/main/ets/views/log-manage/**`
- `entry/src/main/ets/viewmodels/log-manage/**`
- `entry/src/main/ets/services/log-manage/**`
- `entry/src/main/ets/components/log-manage/**`
- 日志管理相关模型、mapper、repository

### 3.2 Out of Scope

- 系统审计 API 能力变更
- 文件导出格式扩展为多种模板
- 非日志模块的首页摘要逻辑
- 帮助反馈文案调整

## 4. 核心约束

### 4.1 单一真相源

固定调用链：

```text
LogManagePage
  -> LogManageViewModel
    -> LogRepository / LogCollectorService / LogExportService / LogConfigRepository
```

禁止：

- 页面层维护和 ViewModel 重复的筛选态
- 子组件自行缓存完整列表业务态
- 详情弹窗二次从实时列表“反查”业务对象

### 4.2 状态分层

状态必须至少拆分为：

- 总状态
- 采集状态
- 筛选状态
- 分页状态
- 列表状态
- 详情状态
- 统计状态

### 4.3 详情稳定性

详情弹窗使用稳定快照，不依赖实时列表二次解析，避免刷新过程中出现错位详情。

## 5. Story 拆分

### Story A：页面与 ViewModel 责任收口

- 目标：
  - 页面退出业务拼装
  - ViewModel 成为唯一刷新与交互入口
- 验收：
  - 页面仅保留局部 UI 态
  - 业务方法不再散落在页面层

### Story B：筛选、分页、列表一致性收口

- 目标：
  - 固定筛选变更如何驱动分页重置与列表刷新
  - 固定自动刷新与用户交互的优先级
- 验收：
  - 筛选后列表与分页信息一致
  - 切页不会污染筛选态

### Story C：详情弹窗快照化

- 目标：
  - 详情从“根据当前列表索引/对象反查”改为“打开瞬间快照”
  - 降低刷新导致的详情错乱风险
- 验收：
  - 自动刷新期间详情仍稳定
  - 关闭详情不会影响主列表状态

### Story D：导出与存储设置链路补强

- 目标：
  - 固定导出入口、结果返回结构和失败提示
  - 明确存储设置由哪个 VM 或子 VM 管理
- 验收：
  - 导出动作有明确结论
  - 存储配置修改不干扰主列表态

### Story E：高频刷新稳定性与测试补齐

- 目标：
  - 面向采集频繁、筛选切换、分页跳转等组合场景补测试
  - 收敛刷新节流和激活态控制
- 验收：
  - 高频刷新时页面不出现镜像态错乱
  - 关键组合场景有最小自动化覆盖

## 6. Round 划分

### Round 1：页面瘦身

- 处理 Story A
- 把业务交互集中到 `LogManageViewModel`

### Round 2：核心状态关系定稿

- 处理 Story B、Story C
- 重点收口筛选、分页、列表、详情四类状态

### Round 3：导出与设置链路定稿

- 处理 Story D
- 明确导出和存储设置的子链路边界

### Round 4：稳定性与测试

- 处理 Story E
- 补组合场景测试与性能回归口径

## 7. 文件白名单建议

| Story | 主要文件范围 |
|---|---|
| A | `views/log-manage/**`、`viewmodels/log-manage/overview/**` |
| B | `viewmodels/log-manage/overview/**`、`services/log-manage/repository/**` |
| C | `components/log-manage/detail/**`、`viewmodels/log-manage/overview/**` |
| D | `services/log-manage/export/**`、`viewmodels/log-manage/storage-settings/**` |
| E | `entry/src/test/**log**`、必要的 `viewmodels/log-manage/**` |

## 8. 风险

1. 日志模块最容易在“为了修一个 bug”时重新引入页面镜像态。
2. 导出、采集和分页刷新是三条异步链路，若没有统一结果结构，错误处理会继续分散。
3. 若详情依赖当前列表中的可变对象，自动刷新时仍可能出现详情内容漂移。

## 9. 验收信号

- 页面业务态单点收口到 `LogManageViewModel`。
- 详情弹窗基于稳定快照，而不是依赖实时列表再解析。
- 筛选、分页、自动刷新三者关系有固定顺序和回归测试建议。
- 导出与存储设置链路不再破坏主页面状态收敛原则。

## 10. 后续建议

1. 后续若继续拆子 ViewModel，仍应保证对页面暴露一个统一主入口。
2. 若要补模块级 RFC story rounds，可在本文基础上继续细化 Session 和测试文件，不再另起总纲。
