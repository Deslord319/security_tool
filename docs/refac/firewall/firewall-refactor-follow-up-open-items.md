# 防火墙重构后续未完成工作

> 状态：Open
> 日期：2026-04-07
> 关联文档：
> - `docs/refac/firewall/firewall-refactor-single-source-of-truth.md`
> - `docs/refac/firewall/firewall-refactor-rfc-story-rounds.md`

## 1. 文档目的

本文用于记录防火墙重构完成后的后续收口项和可继续抽象的公共能力。

这些事项不属于本轮“单一真相收口、旧链路删除、目录对齐、fresh verify”范围，但已经在当前设计中显露出进一步抽象或合并的机会，后续可以按专项重构继续推进。

## 2. 未完成工作总表

| 编号 | 主题 | 当前位置 | 后续方向 |
|---|---|---|---|
| F1 | rules 冲突判断能力 | `entry/src/main/ets/services/firewall/rules/**` | 评估是否提取为通用 `utils` |
| F2 | provider 用户能力 | `entry/src/main/ets/services/firewall/providers/**` | 评估是否提取为公共用户防火墙能力 |
| F3 | Auth + PIN 鉴权能力 | `entry/src/main/ets/services/firewall/auth/**` | 评估是否和系统 PIN 认证抽为公共模块 |
| F4 | user-dispatch 用户级级联下发 | `entry/src/main/ets/services/firewall/user-dispatch/**` | 评估是否和其他防火墙模块职责合并 |

## 3. 明细

### F1：rules（规则冲突判断）是否可以提取成 utils

- 当前位置：
  - `entry/src/main/ets/services/firewall/rules/FirewallRulesService.ets`
- 当前职责：
  - 规则冲突判断
  - 规则冲突汇总
  - 规则方向 / 类型统计
  - 管理规则描述解析与拼装
- 后续问题：
  - 其中“规则冲突判断”和“规则统计”是否仍应归属于防火墙 service 语义，还是已经更接近纯函数工具能力。
- 建议评估方向：
  - 把与业务流程无关、只依赖入参规则集合的逻辑抽成 `utils`
  - 保留强业务语义逻辑在 `services/firewall/rules/**`
- 进入后续专项前的判断标准：
  - 是否完全无状态
  - 是否不依赖 `context`
  - 是否不依赖 repository / store / auth / provider
  - 是否可被非防火墙页面或测试复用

### F2：provider（读取用户列表等，服务按用户 ID 控制防火墙）提取成公共能力

- 当前位置：
  - `entry/src/main/ets/services/firewall/providers/SystemUserProvider.ets`
- 当前职责：
  - 读取系统用户列表
  - 识别前台用户
  - 按用户 ID 读取当前防火墙策略
- 后续问题：
  - 这部分能力本质上是否属于“公共系统用户能力”，而不是仅属于 firewall。
- 建议评估方向：
  - 区分“系统用户读取能力”和“防火墙用户策略读取能力”
  - 前者可考虑沉到更公共的 provider / capability 层
  - 后者仍保留在 firewall 领域内
- 进入后续专项前的判断标准：
  - 是否已有其他模块需要按用户 ID 读取系统态信息
  - 是否存在跨模块复用需求
  - 抽出后是否能降低 firewall 领域目录的职责密度

### F3：Auth（在执行防火墙开关和用户模式应用前做 PIN 鉴权）与系统 pin 码认证提取成公共模块

- 当前位置：
  - `entry/src/main/ets/services/firewall/auth/FirewallAuthService.ets`
  - 依赖系统 PIN 认证能力
- 当前职责：
  - 防火墙开关前 PIN 鉴权
  - 用户模式应用前 PIN 鉴权
  - 鉴权失败计数、锁定态和审计联动
- 后续问题：
  - 当前实现已经不只是 firewall 业务逻辑，其中“PIN 前置保护动作”的模式具备公共模块化潜力。
- 建议评估方向：
  - 把“受保护动作 + PIN 鉴权 + 失败锁定”抽成公共安全能力
  - firewall 仅保留具体业务 apply action 和审计语义
- 进入后续专项前的判断标准：
  - 是否已有其他模块存在同类“PIN 前置保护动作”
  - 抽象后是否能减少重复锁定逻辑和审计逻辑
  - 抽象后是否还能保留 firewall 的业务语义日志

### F4：user-dispatch（服务按用户 ID 控制防火墙，自定义规则更新后负责级联更新）看是否能跟当前其他防火墙模块进行合并

- 当前位置：
  - `entry/src/main/ets/services/firewall/user-dispatch/FirewallUserDispatchService.ets`
- 当前职责：
  - 按用户 ID 读取模式状态
  - 按用户 ID 执行用户模式应用
  - 自定义规则更新后触发级联重下发
- 后续问题：
  - 当前 `user-dispatch` 已经成为单独目录，但其职责边界和 `stores`、`providers`、`auth`、`mode-strategies` 的关系仍可继续优化。
- 建议评估方向：
  - 评估是否应继续保留为独立子域
  - 或与其他防火墙模块职责合并，减少跨目录跳转
- 进入后续专项前的判断标准：
  - 是否存在明显重复的“用户级策略应用”编排逻辑
  - `user-dispatch` 是否只是流程胶水，而不是稳定子域
  - 合并后是否能降低理解成本，而不破坏单一职责

## 4. 建议后续顺序

建议按以下顺序继续评估：

1. F3：先看 Auth + PIN 是否能抽公共模块
2. F2：再看 provider 用户能力是否可公共化
3. F4：再看 user-dispatch 是否应与其他 firewall 子域合并
4. F1：最后处理 rules 冲突判断是否应下沉 utils

说明：

- F3 / F2 更偏跨模块公共能力抽象，越早定越能减少后续重复实现。
- F4 属于 firewall 领域内结构优化，应在公共能力边界较清晰后再判断。
- F1 最适合最后处理，因为它更多是纯职责下沉和文件归位问题，不影响主业务真相。

## 5. 退出标准

本文中的事项后续若启动专项重构，建议每项至少补齐：

- 一份是否值得抽象 / 合并的结论
- 一份 In Scope / Out of Scope
- 一份迁移步骤
- 一份风险与回归点
- 一份完成后的目录职责说明
