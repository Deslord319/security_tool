# 测试用例基线 UT 补充计划

## 工作区与分支

- 工作区：`C:\Users\squarefive\.codex\worktrees\75b0\security_tool`
- 工作分支：`codex/test-case-generation-docs`
- 当前阶段：文档先行。先更新测试用例基线和 UT 调研矩阵并提交；代码修改在文档提交之后执行。

## 背景

当前 `测试用例基线.xlsx` 已沉淀 105 条手工测试基线。现在的目标不是补 UI 或设备侧测试，而是确认哪些基线场景需要由本地 UT 支撑，并补齐可单元化的业务逻辑缺口。

本轮讨论已确认以下边界：

- 页面渲染、导航、弹窗、菜单交互、真实设备接入、系统设置触发、权限变更真实触发、真实崩溃和应用生命周期集成场景，不进入 UT 补充范围。
- 日志管理的人工触发步骤只作为手工说明；UT 已覆盖事件映射和采集处理时，不再额外补 UT。
- `PER-025/PER-026` 的 Select 显示回滚属于 `AsyncSelectRow` 组件本地交互状态，本轮不补 UT。
- 远程 `origin/master` 已覆盖 `PER-005` 和 `PER-023`，本轮不再重复补充。

## 目的

- 在 `测试用例基线.xlsx` 中新增 UT 覆盖结论列，形成可追踪基线。
- 将“待补 UT”的范围收敛到确实可单元化的业务逻辑。
- 代码实现阶段只修改严格列出的测试文件，不做无关重构。

## 文档修改范围

- `docs/04-测试文档/手工测试用例/测试用例基线.xlsx`
  - 新增 `UT覆盖状态` 列。
  - 新增 `UT覆盖位置/不覆盖原因` 列。
- `docs/04-测试文档/手工测试用例/测试用例基线_UT支撑调研矩阵.md`
  - 同步最终讨论结论。
  - 将结论收敛为 `已有UT覆盖 / 待补UT / 不补UT`。
- `docs/04-测试文档/手工测试用例/测试用例基线_UT补充计划.md`
  - 固化本计划。

## 代码修改范围

后续代码阶段严格只修改以下测试文件：

- `entry/src/test/firewall/rule-utils.test.ets`
- `entry/src/test/firewall/service.test.ets`
- `entry/src/test/firewall/system-user-provider.test.ets`
- `entry/src/test/entryability/entryability.test.ets`
- `entry/src/test/viewmodels/InterfaceControlViewModel.test.ets`
- `entry/src/test/viewmodels/PeripheralPolicyViewModel.test.ets`

## 待补 UT 与设计

### 防火墙规则 wildcard 重叠

覆盖用例：`FW-017`

修改文件：`entry/src/test/firewall/rule-utils.test.ets`

伪代码：

```ts
it('should classify single wildcard domain and exact subdomain as overlap conflict', 0, () => {
  const existing = buildDomainIntent('wildcard', '*.baidu.com', RULE_ALLOW)
  const target = buildDomainIntent('exact', 'www.baidu.com', RULE_DENY)

  const conflict = FirewallRuleUtils.findRuleConflict([existing], target)

  expect(conflict?.kind).assertEqual('overlap_conflict')
})

it('should not classify single wildcard domain as matching multi-level subdomain', 0, () => {
  const existing = buildDomainIntent('wildcard', '*.baidu.com', RULE_ALLOW)
  const target = buildDomainIntent('deep', 'a.b.baidu.com', RULE_DENY)

  expect(FirewallRuleUtils.findRuleConflict([existing], target)).assertEqual(null)
})
```

### 用户级策略下发 + PIN

覆盖用例：`FW-019`、`FW-020`

修改文件：`entry/src/test/firewall/service.test.ets`

伪代码：

```ts
it('should apply allowlist policy for selected user after PIN succeeds', 0, async () => {
  mockPinAuthSuccess()
  mockAvailableUsers([100, 101])
  mockPolicyWriteSuccess(101)

  const result = await FirewallService.applyUserPolicyMode(context, 101, 'allowlist')

  expect(result.success).assertTrue()
  expect(policyWriteFor(101).mode).assertEqual('allowlist')
})

it('should apply denylist policy for selected user after PIN succeeds', 0, async () => {
  mockPinAuthSuccess()
  mockAvailableUsers([100, 101])
  mockPolicyWriteSuccess(101)

  const result = await FirewallService.applyUserPolicyMode(context, 101, 'denylist')

  expect(result.success).assertTrue()
  expect(policyWriteFor(101).mode).assertEqual('denylist')
})

it('should not write user policy when PIN fails', 0, async () => {
  mockPinAuthFailure()

  const result = await FirewallService.applyUserPolicyMode(context, 101, 'allowlist')

  expect(result.success).assertFalse()
  expect(policyWriteCount()).assertEqual(0)
})
```

### 账户新增/删除事件影响可用用户列表

覆盖用例：`FW-029`、`FW-030`、`FW-031`、`FW-032`

修改文件：

- `entry/src/test/entryability/entryability.test.ets`
- `entry/src/test/firewall/system-user-provider.test.ets`

伪代码：

```ts
it('should dispatch account added event to SystemUserProvider', 0, async () => {
  mock(SystemUserProvider.trackAddedUser)

  await callPrivateHandleAccountEvent(ability, buildAccountAddedEvent(101))

  expect(trackAddedUserCalledWith(101)).assertTrue()
})

it('should dispatch account removed event to SystemUserProvider', 0, async () => {
  mock(SystemUserProvider.trackRemovedUser)

  await callPrivateHandleAccountEvent(ability, buildAccountRemovedEvent(101))

  expect(trackRemovedUserCalledWith(101)).assertTrue()
})

it('should merge tracked added user into available user list', 0, async () => {
  mockActivatedUsers([100])
  await SystemUserProvider.trackAddedUser(101)

  const result = await SystemUserProvider.loadAvailableUserIds()

  expect(result.users.some(user => user.userId === 101)).assertTrue()
})

it('should remove tracked user from available user list after removed event', 0, async () => {
  mockActivatedUsers([100])
  await SystemUserProvider.trackAddedUser(101)
  await SystemUserProvider.trackRemovedUser(101)

  const result = await SystemUserProvider.loadAvailableUserIds()

  expect(result.users.some(user => user.userId === 101)).assertFalse()
})
```

### 外设接口与存储策略

覆盖用例：`PER-006`、`PER-007`、`PER-008`

修改文件：`entry/src/test/viewmodels/InterfaceControlViewModel.test.ets`

伪代码：

```ts
it('should reject usb storage policy change when usb interface is disabled', 0, async () => {
  setUsbInterfaceState('disabled')

  const result = await viewModel.updateUsbStoragePolicy('read_only')

  expect(result.success).assertFalse()
  expect(result.reason).assertEqual('interface_disabled_conflict')
})

it('should toggle bluetooth interface policy', 0, async () => {
  const result = await viewModel.toggleInterface('bluetooth', false)

  expect(result.success).assertTrue()
})

it('should toggle wifi interface policy', 0, async () => {
  const result = await viewModel.toggleInterface('wifi', false)

  expect(result.success).assertTrue()
})
```

### 外设单设备策略冲突与蓝牙策略

覆盖用例：`PER-015`、`PER-024`

修改文件：`entry/src/test/viewmodels/PeripheralPolicyViewModel.test.ets`

伪代码：

```ts
it('should reject single-device policy change when usb interface conflict exists', 0, async () => {
  setUsbInterfaceState('disabled')

  const result = await viewModel.changeDevicePolicy('usb-device-1', 'deny')

  expect(result.success).assertFalse()
  expect(result.reason).assertEqual('interface_disabled_conflict')
})

it('should restore bluetooth device allow policy with normalized id', 0, async () => {
  await viewModel.changeDevicePolicy('AA:BB:CC:DD:EE:FF', 'deny')

  const result = await viewModel.changeDevicePolicy('aa:bb:cc:dd:ee:ff', 'allow')

  expect(result.success).assertTrue()
})
```

## 腐败代码与删除计划

当前文档阶段不修改代码，因此没有新增腐败代码。

代码阶段的删除原则：

- 不删除现有有效 UT。
- 不引入仅为测试服务的生产代码分支。
- 如果发现新增 UT 与已有空泛 UT 重复，只合并或改名重复测试；删除前必须在提交说明中明确列出。

当前计划删除项：无。

## 验收标准

- `测试用例基线.xlsx` 已包含 `UT覆盖状态` 和 `UT覆盖位置/不覆盖原因` 两列。
- UT 覆盖统计为：`已有UT覆盖 71`、`待补UT 12`、`不补UT 22`。
- UT 调研矩阵与 Excel 中的覆盖结论一致。
- 文档提交后，再进入代码补 UT 阶段。
- 代码阶段完成后运行本地 UT：`hvigorw test --mode module -p product=default -p module=entry@default`。
