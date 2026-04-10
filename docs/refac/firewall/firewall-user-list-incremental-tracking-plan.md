# 防火墙用户列表增量跟踪方案

> 状态：Draft  
> 日期：2026-04-10  
> 适用范围：防火墙模块用户列表来源增强  
> 唯一判定依据：本文档

## 1. 背景

当前项目中，防火墙模块“用户模式下发”链路依赖 `SystemUserProvider.loadAvailableUserIds()` 提供用户列表。

当前实现的特点是：

- 仍然需要保留现有基线取数能力
- 基线取数能支撑首次进入页面时的用户列表展示
- 但对运行期后续新增 / 删除用户的变化感知不足

本轮改造不推翻当前基线实现，不做全量替代，而是在现有实现基础上补充“事件增量维护”能力。

---

## 2. 目标

本轮目标如下：

1. 保留 `SystemUserProvider.loadAvailableUserIds()` 作为用户列表唯一出口
2. 保留当前基线用户发现逻辑
3. 增加基于企业管理员账号事件的增量用户跟踪能力
4. 将事件维护到的用户信息纳入最终用户列表
5. 不新增独立 `TrackedUserRepository.ets`
6. 不新增前置“可操作性探测”过滤步骤
7. 为 `subscribeManagedEventSync` 补齐 `ohos.permission.ENTERPRISE_SUBSCRIBE_MANAGED_EVENT`
8. 尽量缩小修改范围，只修改必要文件

---

## 3. 方案结论

本轮采用：

- 基线取数继续保留
- 账号事件做增量维护
- `SystemUserProvider` 内部直接负责 tracked users 的持久化与合并

明确不采用：

- 使用事件链路全量替代旧基线取数
- 新增 `TrackedUserRepository.ets`
- 在 `loadAvailableUserIds()` 中逐个调用 `getPolicy(userId)` 做前置过滤

---

## 4. 修改文件范围

本轮只修改以下文件：

1. `entry/src/main/ets/enterpriseadminability/EnterpriseAdminAbility.ets`
2. `entry/src/main/ets/services/firewall/providers/SystemUserProvider.ets`
3. `entry/src/main/ets/storage/preferences/PreferencesAccessor.ets`
4. `entry/src/main/module.json5`
5. `hapsigner/UnsgnedDebugProfileTemplate.json`

除此之外，其他文件不在本轮修改范围内。

---

## 5. 设计原则

### 5.1 唯一出口不变

`SystemUserProvider.loadAvailableUserIds()` 继续作为上层唯一可见的用户列表出口。

上层链路保持不变，包括但不限于：

- `FirewallUserDispatchService`
- `FirewallStore`
- `FirewallUserDispatchViewModel`

这些调用方不应感知本轮底层新增了事件增量维护逻辑。

### 5.2 保留基线能力

当前基线取数逻辑仍然保留，用于保证首次进入页面时可以拿到当前已有用户。

### 5.3 事件只做增量补充

账号新增 / 删除事件用于维护运行期变化，不承担全量基线发现职责。

### 5.4 最小改动优先

tracked users 的读写逻辑直接集成在 `SystemUserProvider` 中，不额外拆独立 repository 文件。

### 5.5 不做前置可操作过滤

本轮不在 `loadAvailableUserIds()` 中新增逐用户“可操作性探测”。

即：

- 不在生成用户列表时逐个调用 `getPolicy(userId)` 过滤用户
- 用户是否真正可用于后续操作，继续由现有状态读取和下发链路在后续步骤中体现

### 5.6 权限一致性必须同步

由于本轮引入 `adminManager.subscribeManagedEventSync`，必须同步声明：

- `ohos.permission.ENTERPRISE_SUBSCRIBE_MANAGED_EVENT`

并保持以下位置一致：

- `entry/src/main/module.json5`
- `hapsigner/UnsgnedDebugProfileTemplate.json`

若修改了签名模板，后续构建验证阶段必须重新生成 `p7b` 后再重新签名。

---

## 6. 具体实现

## 6.1 EnterpriseAdminAbility

文件：

- `entry/src/main/ets/enterpriseadminability/EnterpriseAdminAbility.ets`

职责：

- 订阅账号管理相关事件
- 接收账号新增 / 删除回调
- 将事件中的用户信息交给 `SystemUserProvider` 维护

本轮需要增加的能力：

1. 账号事件订阅
   - `MANAGED_EVENT_ACCOUNT_ADDED`
   - `MANAGED_EVENT_ACCOUNT_REMOVED`
   - 可选：`MANAGED_EVENT_ACCOUNT_SWITCHED`

2. 账号事件回调处理
   - `onAccountAdded`
   - `onAccountRemoved`

3. 在回调中调用 `SystemUserProvider` 的静态方法
   - 新增用户时写入 tracked users
   - 删除用户时移除或标记删除

4. 依赖权限前提
   - `ohos.permission.ENTERPRISE_SUBSCRIBE_MANAGED_EVENT`

## 6.2 SystemUserProvider

文件：

- `entry/src/main/ets/services/firewall/providers/SystemUserProvider.ets`

职责保持为：

- 用户列表唯一出口
- 用户策略读取入口

本轮在该文件中直接增加：

1. tracked users 数据结构定义
2. 基于 `PreferencesAccessor` 的本地读写逻辑
3. 供 `EnterpriseAdminAbility` 调用的静态写入方法
4. 在 `loadAvailableUserIds()` 中合并基线用户和 tracked users 的逻辑

## 6.3 PreferencesAccessor

文件：

- `entry/src/main/ets/storage/preferences/PreferencesAccessor.ets`

本轮仅做最小类型收口调整：

- 将 context 入参和成员类型从 `UIAbilityContext` 放宽到 `common.Context`

目的：

- 允许 `SystemUserProvider` 使用应用级上下文访问 `Preferences`
- 不改变 `PreferencesAccessor` 现有读写行为

---

## 7. 数据持久化方案

本轮直接复用项目现有 `PreferencesAccessor`。

不新增新的通用基础设施，不新增新的 repository 文件。

tracked users 持久化位置由 `SystemUserProvider` 内部统一管理，采用：

- 独立的 store name
- 独立的 key
- JSON 数组格式存储

用途：

- 记录通过账号事件维护到的增量用户数据
- 供后续 `loadAvailableUserIds()` 合并使用

---

## 8. 权限与签名要求

本轮新增权限：

- `ohos.permission.ENTERPRISE_SUBSCRIBE_MANAGED_EVENT`

必须同步到：

1. `entry/src/main/module.json5` 的 `requestPermissions`
2. `hapsigner/UnsgnedDebugProfileTemplate.json` 的 `acls.allowed-acls`
3. `hapsigner/UnsgnedDebugProfileTemplate.json` 的 `permissions.restricted-permissions`

---

## 9. loadAvailableUserIds 改造规则

`SystemUserProvider.loadAvailableUserIds()` 改造后的流程固定如下：

1. 读取当前基线用户列表
2. 读取本地 tracked users
3. 合并基线用户与 tracked users
4. 去重
5. 排序
6. 继续尝试读取前台用户
7. 计算默认选中用户
8. 返回 `UserFirewallListResult`

说明：

- 本轮允许每次调用时都重新做“合并 + 去重 + 排序”
- 这部分逻辑开销可接受
- 本轮不新增前置 `getPolicy(userId)` 过滤

---

## 10. SystemUserProvider 内建议新增的方法

本轮建议在 `SystemUserProvider` 内新增以下静态方法：

1. `loadTrackedUserIds(...)`
   - 读取本地 tracked users

2. `saveTrackedUserIds(...)`
   - 保存本地 tracked users

3. `trackAddedUser(...)`
   - 处理新增用户事件

4. `trackRemovedUser(...)`
   - 处理删除用户事件

5. `mergeUserIds(...)`
   - 合并基线用户与 tracked users
   - 去重并排序

这些方法可以根据实现需要设为 `private static` 或 `public static`。

其中：

- 给 `EnterpriseAdminAbility` 调用的事件入口方法需要对外可见
- 其余辅助方法可保持为私有

---

## 11. 数据流

本轮数据流固定如下：

1. 应用作为企业管理员运行
2. 企业管理员能力订阅账号事件
3. 系统发生用户新增 / 删除
4. `EnterpriseAdminAbility` 收到事件回调
5. `EnterpriseAdminAbility` 调用 `SystemUserProvider` 静态方法更新 tracked users
6. `SystemUserProvider` 将 tracked users 持久化到 `Preferences`
7. 业务侧调用 `SystemUserProvider.loadAvailableUserIds()`
8. `SystemUserProvider` 读取基线用户和 tracked users
9. 合并、去重、排序后返回最终用户列表
10. 上层现有 ViewModel / Service / Store 照常消费返回结果

---

## 12. 本轮明确不做的内容

本轮明确不做以下内容：

1. 不以账号事件链路全量替代旧基线用户发现逻辑
2. 不新增 `TrackedUserRepository.ets`
3. 不新增前置“可操作性探测”步骤
4. 不修改 `FirewallUserDispatchService`
5. 不修改 `FirewallStore`
6. 不修改 `FirewallUserDispatchViewModel`

---

## 13. 完成判定

满足以下条件即视为本轮完成：

1. `EnterpriseAdminAbility` 已具备账号新增 / 删除事件订阅与处理能力
2. `SystemUserProvider` 已能持久化并读取 tracked users
3. `loadAvailableUserIds()` 已能合并基线用户和 tracked users
4. 上层调用方无需改动即可拿到增强后的用户列表
5. 本轮未引入额外 repository 文件
6. 本轮未引入前置“可操作性探测”逻辑
7. `ENTERPRISE_SUBSCRIBE_MANAGED_EVENT` 已完成声明与签名模板同步

---

## 14. 后续扩展边界

如果后续发现以下问题，可以在后续轮次单独扩展：

1. 需要将 tracked users 逻辑从 `SystemUserProvider` 中拆出
2. 需要给用户列表增加前置可操作性过滤
3. 需要为合并后的用户列表增加短时缓存

但这些内容均不属于本轮范围，不得在本轮实现中提前扩张。
