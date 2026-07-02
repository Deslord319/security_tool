# 防火墙账号变化策略同步方案

日期：2026-07-02

## 目标

账号新增或删除后，防火墙业务状态必须以最新账号集合为准完成同步：

- 公共网络 / 私有网络模式下，新增账号必须补下发当前模式的通用 policy 和预置规则。
- 账号删除后，本地防火墙规则作用域、deployments 和用户历史策略记录必须移除被删账号。
- 自定义模式下，不把旧规则自动扩展到新增账号，但需要给新增账号同步账号级默认 policy，并继续做删除账号清理和后续正常展示联动。
- UI 不做独立强制刷新补丁；页面只响应 ViewModel / 数据源变化，核心是先保证策略和本地数据正确。

## 当前问题

现有账号读取能力已经收敛到 `SystemUserProvider.loadAvailableUserIds()`，该方法可以实时读取完整账号列表和账号名。但它只是读取入口，不会主动通知防火墙，也不应该在 Provider 内部直接执行防火墙策略下发。

现有 `EnterpriseAdminAbility` 已订阅：

- `MANAGED_EVENT_ACCOUNT_ADDED`
- `MANAGED_EVENT_ACCOUNT_REMOVED`

但当前回调只处理 keepAlive 注册 / 移除，没有把账号变化接入防火墙策略同步。因此会出现：

- 公共网络模式下新增账号后，新账号未及时获得公共网络 policy 和预置规则。
- 私有网络模式下新增账号后，新账号未及时获得私有网络 policy 和预置规则。
- 删除账号后，本地规则作用域、deployments、用户历史模式记录可能继续引用被删用户，直到后续某些懒清理路径触发。
- 自定义规则页四卡只是展示层，刷新四卡不能解决策略没有正确下发或本地数据未清理的问题。

## 设计原则

1. `SystemUserProvider` 是账号真相源，只负责全量读取账号，不承载防火墙副作用。
2. 账号事件只作为触发器，不能只信事件传入的单个账号 ID；每次同步都必须通过 `SystemUserProvider.loadAvailableUserIds()` 重新读取完整账号集合。
3. 防火墙策略同步优先保证系统 policy、系统规则和本地 repository 正确；UI 只跟随 ViewModel 数据变化联动。
4. 账号读取失败或返回空列表时，不执行 prune、不重放模式，避免误删本地防火墙数据。
5. 公共 / 私有模式是“当前模式对最新账号集合生效”；自定义模式不是动态 ALL，不能自动把旧规则扩展到新增账号，但账号级默认 policy 仍需对新增账号生效。

## 整体结构

```text
EnterpriseAdminAbility 账号事件
-> AccountChangeCoordinator
-> SystemUserProvider.loadAvailableUserIds()
-> 计算账号集合签名 / added / removed
-> FirewallAccountChangeHandler
   -> prune 已删除账号本地数据
   -> public/private 模式补下发当前模式
   -> custom 模式同步默认 policy，不扩规则
-> ViewModel 下次正常读取时联动展示最新数据
```

后续权限管理需要接入时，在 `AccountChangeCoordinator` 下新增 `PermissionAccountChangeHandler`，不要再改账号事件源，也不要把权限逻辑写进 `SystemUserProvider`。

## 具体修改点

### 1. 公共账号协调层

新增：

- `entry/src/main/ets/services/account/AccountChangeCoordinator.ets`
- `entry/src/main/ets/services/account/AccountSnapshotModels.ets`

职责：

- 接收账号新增 / 删除事件触发。
- 做 300-500ms 防抖，合并连续账号事件。
- 串行执行，避免和手动模式切换、本地清理并发互相覆盖。
- 调用 `SystemUserProvider.loadAvailableUserIds()` 全量读取最新账号。
- 基于排序后的账号 ID 生成签名，例如 `100,101,102`。
- 计算 `currentUserIds`、`addedUserIds`、`removedUserIds`。
- 将账号变化快照分发给模块 Handler。

### 2. EnterpriseAdminAbility 接入协调层

修改 `entry/src/main/ets/enterpriseadminability/EnterpriseAdminAbility.ets`：

- `onAccountAdded(accountId)` 保留 `ensureKeepAliveAppRegistered`，随后触发 `AccountChangeCoordinator.schedule('account-added', accountId)`。
- `onAccountRemoved(accountId)` 保留 `removeKeepAliveAppRegistration`，随后触发 `AccountChangeCoordinator.schedule('account-removed', accountId)`。
- 回调中不直接写防火墙策略，不直接操作本地规则。

### 3. 防火墙账号变化 Handler

新增：

- `entry/src/main/ets/services/firewall/FirewallAccountChangeHandler.ets`

职责：

- 读取当前防火墙模式。
- 账号列表非空时调用 `FirewallLocalRepository.pruneUnavailableUsers(context, currentUserIds)`。
- 当前模式为 `public/private` 时，如果账号集合签名变化，补下发当前模式到最新账号集合。
- 当前模式为 `custom` 时，同步账号级默认 policy，但不自动扩展旧自定义规则到新增账号。
- 同步成功后保存最新账号签名。

### 4. 防火墙期望状态持久化

修改 `FirewallLocalRepository`，新增或扩展本地状态：

- `desiredEnabled`：用户期望防火墙开关状态。
- `lastAppliedMode`：上一次成功应用到账号集合的模式。
- `lastAppliedUserIdsSignature`：上一次成功应用模式时的账号集合签名。

写入时机：

- 总开关成功后保存 `desiredEnabled`。
- 模式切换成功后保存 `lastAppliedMode + lastAppliedUserIdsSignature`。
- 账号变化后 public/private 补下发成功，再更新 `lastAppliedUserIdsSignature`。

注意：新增账号补下发时不能只保留新账号当前 `isOpen`。应使用 `desiredEnabled`，否则新账号默认关闭时会导致公共 / 私有模式策略不完整。

### 5. 模式应用逻辑抽取

调整 `FirewallModeSwitchService`：

- 保留现有手动 `switchMode(context, targetMode)` 的事务和 rollback 语义。
- 抽取内部模式应用能力，例如 `applyModeToUsers(context, mode, users, desiredEnabled, saveMode)`。
- 手动切换模式时继续执行完整快照、清规则、写 policy、下发规则、保存模式。
- 账号变化补同步时复用同一套事务边界，但以最新账号集合为目标。

public/private 补同步时：

- 对当前账号集合清理旧系统规则。
- 按当前模式写入 policy，`isOpen = desiredEnabled`。
- 下发当前模式预置规则。
- 成功后保存模式账号签名。
- 失败时使用快照 rollback，不保存新签名。

custom 模式下：

- 只 prune 本地无效用户。
- 对当前账号集合同步账号级默认 policy。
- 不把新增账号自动加入旧 rule intent。
- 不自动对新增账号下发旧自定义规则。

### 6. 用户策略弹窗提交前校验

修改 `FirewallUserDispatchViewModel`：

- 打开弹窗时调用 `SystemUserProvider.loadAvailableUserIds()` 获取最新账号。
- 点击确定前再次读取完整账号列表。
- 如果当前选中账号不存在：
  - 不调用 `FirewallService.applyUserPolicyMode`。
  - 不下发 MDM。
  - 返回“账号列表已变化，请重新选择用户”。
- 如果账号存在，再继续 PIN + policy-only 下发。

### 7. UI 联动边界

不新增“MainPage 强制刷新四卡”的补丁逻辑。

正确边界是：

- 账号变化先完成防火墙业务 reconcile。
- ViewModel 后续通过现有加载链路读取最新 `FirewallLocalRepository`、系统 policy 和系统规则。
- `defaultPolicyItems`、`rules`、`userOptions` 变化后，ArkUI 根据 `@Trace` 联动刷新。

四卡是验收结果，不是修复手段。不能用单纯刷新四卡来掩盖 public/private 策略未下发或删除账号本地数据未清理的问题。

## 验收点

### 公共网络模式新增账号

- 前置：防火墙已开启，当前模式为公共网络。
- 操作：系统设置中新增账号。
- 预期：
  - `EnterpriseAdminAbility.onAccountAdded` 被触发。
  - 协调层通过 `SystemUserProvider` 读取到新增账号后的完整账号列表。
  - 新账号被写入公共网络模式 policy，`isOpen` 使用 `desiredEnabled`。
  - 新账号获得公共网络预置规则。
  - 本地 `lastAppliedMode=public`，`lastAppliedUserIdsSignature` 更新为最新账号集合。

### 私有网络模式新增账号

- 前置：防火墙已开启，当前模式为私有网络。
- 操作：系统设置中新增账号。
- 预期：
  - 新账号被写入私有网络模式 policy。
  - 新账号获得私有网络预置规则。
  - 本地模式账号签名更新。

### 自定义模式新增账号

- 前置：当前模式为自定义，已有自定义规则作用于旧账号集合。
- 操作：系统设置中新增账号。
- 预期：
  - 新账号出现在后续账号列表读取结果中。
  - 旧自定义规则的 `targetUserIds` 不自动增加新账号。
  - 不自动给新增账号下发旧自定义规则。
  - 默认策略展示后续按最新账号集合联动更新。

### 删除账号

- 前置：本地存在包含待删账号的 rule intents、deployments 或用户历史模式记录。
- 操作：系统设置中删除账号。
- 预期：
  - `EnterpriseAdminAbility.onAccountRemoved` 被触发。
  - 协调层通过 `SystemUserProvider` 读取删除后的完整账号列表。
  - `FirewallLocalRepository.pruneUnavailableUsers` 移除被删账号：
    - 多用户规则仅移除被删用户。
    - 仅作用于被删用户的规则被删除。
    - 被删用户 deployments 被删除。
    - 被删用户 `firewall_user_policy` 历史模式记录被删除。
  - 不对被删账号调用系统防火墙接口。

### 账号读取失败或空列表

- 前置：账号 API 临时失败，或返回空账号集合。
- 预期：
  - 不执行 prune。
  - 不重放 public/private 模式。
  - 不误删本地规则、deployments、用户历史模式。
  - 记录日志，等待下一次账号事件或页面业务读取再恢复。

### 并发和重复事件

- 操作：连续新增 / 删除多个账号，或账号事件短时间内重复触发。
- 预期：
  - 协调层防抖合并事件。
  - 同一时间只有一个账号同步任务运行。
  - 同步运行期间再次收到事件，标记 pending，当前任务结束后再基于最新账号集合跑一轮。
  - 不出现多次并发清规则 / 下发规则互相覆盖。

### UI 联动

- 前置：业务 reconcile 已成功。
- 预期：
  - 防火墙首页再次读取时展示正确开关和当前模式。
  - 自定义规则页再次读取时，四卡基于最新 policy、本地规则和账号列表展示。
  - 没有为了四卡单独增加 MainPage 强制刷新补丁。

## 非目标

- 不在 `SystemUserProvider` 内部执行防火墙策略下发或本地清理。
- 不在自定义模式下把历史“全部用户”规则升级为动态 ALL。
- 不用 UI 强制刷新替代策略同步。
- 不在本次方案中实现权限管理账号变化处理；只保留协调层扩展点。
