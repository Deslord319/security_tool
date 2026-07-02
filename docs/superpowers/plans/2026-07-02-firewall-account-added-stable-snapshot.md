# 防火墙新增账号稳定快照同步方案

## 背景

公共网络或私有网络模式下，系统设置页新增账号后，`EnterpriseAdminAbility.onAccountAdded(accountId)` 会收到触发账号 ID。实际复现中，新增账号 `123` 的回调已到达，但防火墙本地 `firewall_last_applied_user_ids_signature` 仍停留在旧集合 `100,112,122`，导致新增账号没有获得当前模式 policy 和预置规则。

根因是账号新增回调和 `SystemUserProvider.loadAvailableUserIds()` 可见完整账号列表之间存在时序差。当前 `AccountChangeCoordinator` 只读取一次账号快照；如果这次读取仍返回旧集合，`FirewallAccountChangeHandler` 会认为账号集合签名未变化并跳过补下发。

## 目标

- `account-added` 场景必须等到账号快照包含 `triggerAccountId` 后，才分发给防火墙 Handler。
- 等待窗口控制在防抖后的约 1 秒内，避免 EnterpriseAdmin Extension 长时间占用。
- 如果超时仍不可见，不更新 `previousUserIds`，不发布 `ACCOUNT_CHANGE` CommonEvent，不把旧快照当作成功同步。
- 删除账号和手动同步场景保持现有全量快照处理边界。

## 修改范围

- `docs/03-模块设计/防火墙管理组件设计说明.md`
- `entry/src/main/ets/services/account/AccountChangeCoordinator.ets`
- `entry/src/test/firewall/account-change-coordinator.test.ets`

## 设计方案

`AccountChangeCoordinator.schedule()` 保留 400ms 防抖。`runOnce()` 不再直接用第一次读取结果进入 Handler，而是先解析稳定账号快照：

```ts
snapshot = await loadSnapshot()

if (source === 'account-added' && triggerAccountId is present) {
  while (!snapshot.currentUserIds.includes(triggerAccountId) && retryCount < 5) {
    await delay(200)
    snapshot = await loadSnapshot()
  }

  if (!snapshot.currentUserIds.includes(triggerAccountId)) {
    warn()
    return false
  }
}

previousUserIds = snapshot.currentUserIds
success = await dispatchHandlers(snapshot)
if (success) {
  publishSnapshot(snapshot)
}
```

## 腐败代码处理

需要移除 `runOnce()` 中“读取一次快照后无条件更新 `previousUserIds`、分发 Handler、发布事件”的路径。该路径在账号新增列表尚未稳定时会把旧集合误判为成功同步。

## 验收标准

- 新增账号快照首次不包含 `triggerAccountId`、后续重试包含时，Handler 只收到包含新增账号的快照。
- 新增账号在 1 秒重试窗口内仍不可见时，Handler 不执行，`ACCOUNT_CHANGE` 不发布，`previousUserIds` 不更新为旧快照。
- `account-removed` 和 `manual` 同步不等待 `triggerAccountId`，继续按当前一次全量快照流程处理。
- `python scripts/check_docs_consistency.py` 通过。
- `hvigorw test --mode module -p product=default -p module=entry@default` 通过，若本地工具链不可用需记录原因。
