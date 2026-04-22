# 防火墙用户列表账号事件同步方案

> 状态：Locked  
> 日期：2026-04-22  
> 适用范围：防火墙模块用户列表来源增强  
> 唯一判定依据：本文档

## 1. 背景

防火墙自定义模式中，【全局策略】和【新增规则】的用户列表都通过
`SystemUserProvider.loadAvailableUserIds()` 获取。

当前 `SystemUserProvider` 的用户列表机制保持为：

1. 读取系统已激活用户
2. 读取本地 tracked users
3. 合并、去重、排序
4. 生成带当前前台用户标记的用户选项

运行期账号新增 / 删除事件由 `EnterpriseAdminAbility` 接收。但
`EnterpriseAdminAbility` 与 `UIAbility` 分属不同进程，如果在
`EnterpriseAdminAbility` 中直接调用
`SystemUserProvider.trackAddedUser()` 或
`SystemUserProvider.trackRemovedUser()` 写入 tracked users，UIAbility 进程内的
页面和弹窗可能读不到最新用户数据。

因此，本轮只修正 tracked users 的写入进程：账号事件仍由
`EnterpriseAdminAbility` 接收，但 tracked users 更新必须在 `EntryAbility`
所属的 UIAbility 进程内完成。

---

## 2. 目标

本轮目标如下：

1. 保留 `SystemUserProvider.loadAvailableUserIds()` 作为用户列表唯一出口
2. 保留当前“系统已激活用户 + tracked users”的合并机制
3. 不修改 `SystemUserProvider` 当前机制
4. 不修改【全局策略】和【新增规则】弹窗的打开时加载逻辑
5. 将账号新增 / 删除事件通过 CommonEvent 从 `EnterpriseAdminAbility` 转发到 `EntryAbility`
6. 由 `EntryAbility` 在 UIAbility 进程内调用 `SystemUserProvider.trackAddedUser()` / `trackRemovedUser()`
7. 关闭并重新打开弹窗时，现有加载逻辑即可读取最新用户列表

---

## 3. 方案结论

本轮采用：

```text
系统账号新增/删除
-> EnterpriseAdminAbility 收到 MDM 回调
-> EnterpriseAdminAbility 发布 CommonEvent
-> EntryAbility 接收 CommonEvent
-> EntryAbility 在 UIAbility 进程内调用 SystemUserProvider.trackAddedUser/trackRemovedUser
-> 弹窗重新打开时继续调用 SystemUserProvider.loadAvailableUserIds()
```

明确不采用：

- 不让 `EnterpriseAdminAbility` 直接写 tracked users
- 不以账号事件链路替代旧基线用户发现逻辑
- 不修改 `SystemUserProvider` 的读写与合并机制
- 不新增弹窗打开期间实时刷新
- 不新增独立 `TrackedUserRepository.ets`
- 不新增权限
- 不修改签名模板

---

## 4. 修改文件范围

本轮只修改以下代码文件：

1. `entry/src/main/ets/services/account/AccountEventContract.ets`
2. `entry/src/main/ets/enterpriseadminability/EnterpriseAdminAbility.ets`
3. `entry/src/main/ets/entryability/EntryAbility.ets`

本轮同步以下文档文件：

1. `docs/refac/firewall/firewall-user-list-incremental-tracking-plan.md`
2. `docs/03-模块设计/防火墙管理组件设计说明.md`

---

## 5. 设计原则

### 5.1 用户列表出口不变

`SystemUserProvider.loadAvailableUserIds()` 继续作为上层唯一可见的用户列表出口。

上层调用方保持不变，包括但不限于：

- `FirewallUserDispatchViewModel`
- `FirewallRulesViewModel`
- `UserFirewallControlDialog`
- `AddRuleDialog`

### 5.2 用户列表机制不变

`SystemUserProvider` 继续负责：

- 读取系统已激活用户
- 读取 tracked users
- 合并、去重、排序
- 输出 `UserFirewallOption[]`

本轮不调整该文件内的存储结构、合并逻辑和用户标签生成逻辑。

### 5.3 EnterpriseAdminAbility 只转发事件

`EnterpriseAdminAbility` 的职责收敛为：

- 订阅 MDM 账号新增 / 删除事件
- 接收账号事件回调
- 发布账号变更 CommonEvent
- 保留现有保活相关逻辑

`EnterpriseAdminAbility` 不再直接调用：

- `SystemUserProvider.trackAddedUser(...)`
- `SystemUserProvider.trackRemovedUser(...)`

### 5.4 EntryAbility 负责 UIAbility 进程内落地

`EntryAbility` 的新增职责为：

- 订阅账号变更 CommonEvent
- 解析账号事件类型和 userId
- 在 UIAbility 进程内调用 `SystemUserProvider.trackAddedUser(...)`
- 在 UIAbility 进程内调用 `SystemUserProvider.trackRemovedUser(...)`
- 销毁时取消订阅

### 5.5 不做弹窗实时刷新

当前验收目标是“关闭并重新打开弹窗后读取最新用户列表”。

原因：

- `UserFirewallControlDialog.aboutToAppear()` 已会重新初始化并加载用户
- `AddRuleDialog.aboutToAppear()` 已会重新加载用户选项
- 本轮只解决跨进程写入导致 UIAbility 拿不到最新 tracked users 的问题

---

## 6. 具体实现

### 6.1 AccountEventContract

文件：

- `entry/src/main/ets/services/account/AccountEventContract.ets`

职责：

- 定义账号事件 CommonEvent 名称
- 定义参数 key
- 定义账号事件类型
- 定义可复用的事件 payload 类型

建议字段：

```ts
export const ACCOUNT_EVENT_COMMON_EVENT = 'com.huawei.securitytool.ACCOUNT_EVENT_CHANGED'
export const ACCOUNT_EVENT_PARAM_TYPE = 'accountEventType'
export const ACCOUNT_EVENT_PARAM_USER_ID = 'accountEventUserId'
export const ACCOUNT_EVENT_PARAM_TIMESTAMP = 'accountEventTimestamp'

export enum AccountEventType {
  ADDED = 'account_added',
  REMOVED = 'account_removed'
}
```

### 6.2 EnterpriseAdminAbility

文件：

- `entry/src/main/ets/enterpriseadminability/EnterpriseAdminAbility.ets`

职责：

- 保留账号事件订阅
- 保留现有保活逻辑
- 在账号新增 / 删除回调中发布 CommonEvent

新增用户事件流程：

```text
onAccountAdded(accountId)
-> publishAccountEvent(AccountEventType.ADDED, accountId)
-> ensureKeepAliveAppRegistered(...)
```

删除用户事件流程：

```text
onAccountRemoved(accountId)
-> removeKeepAliveAppRegistration(...)
-> publishAccountEvent(AccountEventType.REMOVED, accountId)
```

必须删除的腐败代码：

```ts
SystemUserProvider.trackAddedUser(accountId)
SystemUserProvider.trackRemovedUser(accountId)
```

删除原因：

```text
EnterpriseAdminAbility 与 UIAbility 分属不同进程，不能由 EnterpriseAdminAbility
直接写 UIAbility 后续要读取的 tracked users。
```

### 6.3 EntryAbility

文件：

- `entry/src/main/ets/entryability/EntryAbility.ets`

职责：

- 创建账号事件 CommonEvent subscriber
- 接收 `EnterpriseAdminAbility` 发布的账号事件
- 解析 `type`、`userId`、`timestamp`
- 在 UIAbility 进程内更新 tracked users
- 销毁时取消订阅

新增用户事件流程：

```text
EntryAbility 收到 account_added
-> SystemUserProvider.trackAddedUser(userId)
```

删除用户事件流程：

```text
EntryAbility 收到 account_removed
-> SystemUserProvider.trackRemovedUser(userId)
```

不得新增的腐败代码：

```ts
// 不要新增页面刷新、弹窗刷新、ViewModel listener
```

原因：

```text
本轮目标是修复跨进程写入问题。弹窗打开时已有重新加载用户列表逻辑，
不需要引入打开期间实时刷新链路。
```

---

## 7. 数据流

新增账号：

```text
1. 系统新增账号
2. EnterpriseAdminAbility 收到 onAccountAdded
3. EnterpriseAdminAbility 发布账号新增 CommonEvent
4. EntryAbility 收到 CommonEvent
5. EntryAbility 调用 SystemUserProvider.trackAddedUser(userId)
6. tracked users 在 UIAbility 进程内更新
7. 关闭并重新打开【全局策略】或【新增规则】弹窗
8. 弹窗调用 SystemUserProvider.loadAvailableUserIds()
9. 用户列表包含新增用户
```

删除账号：

```text
1. 系统删除账号
2. EnterpriseAdminAbility 收到 onAccountRemoved
3. EnterpriseAdminAbility 发布账号删除 CommonEvent
4. EntryAbility 收到 CommonEvent
5. EntryAbility 调用 SystemUserProvider.trackRemovedUser(userId)
6. tracked users 在 UIAbility 进程内更新
7. 关闭并重新打开【全局策略】或【新增规则】弹窗
8. 弹窗调用 SystemUserProvider.loadAvailableUserIds()
9. 用户列表不再包含对应 tracked user
```

---

## 8. 权限与签名要求

本轮不新增权限。

当前项目已经声明：

- `ohos.permission.ENTERPRISE_SUBSCRIBE_MANAGED_EVENT`

因此本轮不修改：

- `entry/src/main/module.json5`
- `hapsigner/UnsgnedDebugProfileTemplate.json`

---

## 9. 验收标准

满足以下条件即视为本轮完成：

1. 文档已先于代码落地并单独提交
2. `EnterpriseAdminAbility` 不再直接调用 `SystemUserProvider.trackAddedUser/trackRemovedUser`
3. `EnterpriseAdminAbility` 能发布账号新增 / 删除 CommonEvent
4. `EntryAbility` 能订阅并接收账号 CommonEvent
5. `EntryAbility` 在 UIAbility 进程内调用 `SystemUserProvider.trackAddedUser/trackRemovedUser`
6. `SystemUserProvider.ets` 无机制性改动
7. 【全局策略】弹窗关闭并重新打开后，用户列表能体现账号新增 / 删除
8. 【新增规则】弹窗关闭并重新打开后，用户列表能体现账号新增 / 删除
9. 构建通过
10. 安装并启动成功

---

## 10. 后续扩展边界

以下内容不属于本轮范围：

1. 弹窗打开期间实时刷新用户列表
2. 将 tracked users 拆成独立 repository
3. 增加离线事件持久队列
4. 给用户列表增加前置可操作性过滤
5. 为合并后的用户列表增加短时缓存

如后续需要，应单独立项评估。
