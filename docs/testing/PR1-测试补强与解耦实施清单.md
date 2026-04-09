# PR1 测试补强与解耦实施清单

> 状态：Draft  
> 最后更新：2026-04-09  
> 适用范围：`PR1 - 补足有效测试覆盖，不修改业务规则`

## 1. PR1 目标

PR1 只做两类事情：

- 把当前“测 mock 不测业务”的测试改成真正打生产代码的业务测试
- 为零覆盖或低覆盖的核心模块补上最小必要场景

PR1 明确不做的事情：

- 不修改业务规则
- 不修改页面功能行为
- 不做大规模重构
- 不删除生产代码里的 `ForTest` / `setRecordsForTest` 入口

说明：

- `ForTest` 入口清理放到 PR2/PR3
- PR1 允许继续临时依赖现有测试入口，但新增测试优先通过公开 API 驱动

## 2. PR1 交付范围

### 2.1 核心交付文件

- 重写 [entry/src/test/firewall/service.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/firewall/service.test.ets)
- 新增 [entry/src/test/firewall/auth-service.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/firewall/auth-service.test.ets)
- 新增 [entry/src/test/firewall/rules-service.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/firewall/rules-service.test.ets)
- 新增 [entry/src/test/auth/auth-service.behavior.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/auth/auth-service.behavior.test.ets)
- 新增 [entry/src/test/tool-settings/system-settings-service.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/tool-settings/system-settings-service.test.ets)
- 新增 [entry/src/test/__fakes__/FakeNowProvider.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/__fakes__/FakeNowProvider.ets)
- 新增 [entry/src/test/__fakes__/FakePreferenceStore.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/__fakes__/FakePreferenceStore.ets)
- 新增 [entry/src/test/__fakes__/FakeFirewallPort.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/__fakes__/FakeFirewallPort.ets)
- 新增 [entry/src/test/__fakes__/FakeAuthPort.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/__fakes__/FakeAuthPort.ets)
- 新增 [entry/src/test/__fakes__/FakeSystemSettingsPort.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/__fakes__/FakeSystemSettingsPort.ets)

### 2.2 可选交付文件

- 补强 [entry/src/test/dashboard/viewmodel.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/dashboard/viewmodel.test.ets)
- 补强 [entry/src/test/peripheral/device-policy-dispatch-service.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/peripheral/device-policy-dispatch-service.test.ets)

## 3. 当前问题拆解

### 3.1 当前测试的主要问题

- 业务关键模块零覆盖，例如：
  - [entry/src/main/ets/services/identity/auth/AuthService.ets](/Users/mu/Desktop/code/security_tool/entry/src/main/ets/services/identity/auth/AuthService.ets)
  - [entry/src/main/ets/services/firewall/auth/FirewallAuthService.ets](/Users/mu/Desktop/code/security_tool/entry/src/main/ets/services/firewall/auth/FirewallAuthService.ets)
  - [entry/src/main/ets/services/firewall/rules/FirewallRulesService.ets](/Users/mu/Desktop/code/security_tool/entry/src/main/ets/services/firewall/rules/FirewallRulesService.ets)
  - [entry/src/main/ets/services/firewall/FirewallService.ets](/Users/mu/Desktop/code/security_tool/entry/src/main/ets/services/firewall/FirewallService.ets)
  - [entry/src/main/ets/services/tool-settings/system-settings/SystemSettingsService.ets](/Users/mu/Desktop/code/security_tool/entry/src/main/ets/services/tool-settings/system-settings/SystemSettingsService.ets)
- 现有防火墙测试大量直接调用 mock API，而不是 service/repository 公开方法
- 一些测试只验证默认值或“不抛异常”，业务价值偏低
- 用例数量不少，但有效覆盖率不高

### 3.2 PR1 要解决的判断标准

PR1 完成后应满足：

- 防火墙链路不再主要依赖“直接测 mock”
- `AuthService` 至少覆盖成功、取消、失败、异常、不可用场景
- `SystemSettingsService` 至少覆盖读取、默认值回退、保存成功、保存失败
- 关键模块不再是 `0%` 行覆盖

## 4. 测试设计总原则

### 4.1 被测对象与替身对象边界

- 被测对象必须是生产代码中的 service / repository / viewmodel 公开边界
- 替身对象只能是系统依赖、数据源、时间源、设备能力源
- 不能把 fake/mocks 本身当成主要断言目标

### 4.2 数据策略

- 所有不存在的测试数据一律使用 mock/fake 构造
- 时间统一固定
- 错误码统一显式构造
- 不使用真实设备状态
- 不依赖真实 preferences 或真实认证状态

### 4.3 用例结构

每个业务测试都按以下结构组织：

1. Arrange：设置 fake 依赖与输入
2. Act：调用生产公开方法
3. Assert：断言可观察业务结果

伪码模板：

```ts
it('should map dependency failure into stable service result', async () => {
  const fakePort = new FakeXxxPort()
  fakePort.failMode = 'throw'
  const service = createService(fakePort)

  const result = await service.someMethod(input)

  expect(result.success).assertFalse()
  expect(result.code).assertEqual('expected_code')
})
```

## 5. 文件级改造清单

## 5.1 防火墙测试重写

### 文件

- [entry/src/test/firewall/service.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/firewall/service.test.ets)

### 当前问题

- 大量直接调用 `getNetFirewallPolicy`、`setNetFirewallPolicy`、`getNetFirewallRules`、`addNetFirewallRule` 等 mock API
- 前半段更像在验证 mock 数据行为，不是在验证 [entry/src/main/ets/services/firewall/FirewallService.ets](/Users/mu/Desktop/code/security_tool/entry/src/main/ets/services/firewall/FirewallService.ets) 或 [entry/src/main/ets/services/firewall/repositories/FirewallRepository.ets](/Users/mu/Desktop/code/security_tool/entry/src/main/ets/services/firewall/repositories/FirewallRepository.ets)

### 改造目标

- 以 `FirewallRepository` 和 `FirewallService` 的公开方法为主驱动
- mock 只作为 `NetworkKit` / 防火墙系统能力替身
- 保留现有 `MockNetFirewall` 资产，但改变用法

### 具体动作

1. 删除纯 mock 计数类用例
2. 把策略读取、策略保存、规则查询、规则新增、规则删除、规则更新改成通过 repository/service 公开方法调用
3. 统一增加成功、空态、失败态、输入非法四类分支

### 拆分后的测试组

- `describe('FirewallRepository policy behaviors', ...)`
- `describe('FirewallRepository rule query behaviors', ...)`
- `describe('FirewallService overview behaviors', ...)`
- `describe('FirewallService mutation failure mapping', ...)`

### 伪码骨架

```ts
describe('FirewallRepository policy behaviors', () => {
  beforeEach(() => {
    resetMock()
  })

  it('should load firewall policy through repository', async () => {
    setMockPolicy(createPolicy(true, 1, 0))

    const policy = await FirewallRepository.getFirewallPolicy(100)

    expect(policy.isOpen).assertTrue()
    expect(policy.inAction).assertEqual(1)
    expect(policy.outAction).assertEqual(0)
  })

  it('should map policy read failure into fallback result', async () => {
    setFailMode('getPolicy')

    try {
      await FirewallRepository.getFirewallPolicy(100)
      expect().assertFail()
    } catch (err) {
      expect(true).assertTrue()
    }
  })
})
```

```ts
describe('FirewallService overview behaviors', () => {
  beforeEach(() => {
    resetMock()
  })

  it('should build overview from repository data', async () => {
    setMockPolicy(createPolicy(true, 0, 1))
    setMockRules([
      createRule(100, 'allow-ip', 1, 0, MockNetFirewallRuleType.RULE_IP, true),
      createRule(100, 'deny-domain', 2, 1, MockNetFirewallRuleType.RULE_DOMAIN, true)
    ])

    const result = await FirewallService.getFirewallStatus(100)

    expect(result.success).assertTrue()
    expect(result.data.ruleCount).assertEqual(2)
  })
})
```

### 新增场景矩阵

| 组 | 场景 | 断言 |
|---|---|---|
| policy | 策略读取成功 | 返回值字段正确 |
| policy | 策略读取失败 | 返回稳定错误 |
| policy | 策略保存成功 | mock 状态被更新 |
| rules | 空规则列表 | `data.length=0` |
| rules | 正常分页 | 总数与分页结果正确 |
| rules | 新增规则成功 | 返回新 ruleId |
| rules | 删除规则成功 | 后续查询不存在 |
| rules | 更新规则成功 | 字段被替换 |
| rules | 依赖失败 | 错误稳定映射 |

## 5.2 新增 FirewallAuthService 测试

### 文件

- 新增 [entry/src/test/firewall/auth-service.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/firewall/auth-service.test.ets)
- 被测文件：[entry/src/main/ets/services/firewall/auth/FirewallAuthService.ets](/Users/mu/Desktop/code/security_tool/entry/src/main/ets/services/firewall/auth/FirewallAuthService.ets)
- 相关状态文件：[entry/src/main/ets/services/firewall/stores/FirewallAuthStateStore.ets](/Users/mu/Desktop/code/security_tool/entry/src/main/ets/services/firewall/stores/FirewallAuthStateStore.ets)

### 改造目标

- 覆盖授权状态初始化、授权成功、授权失败、清空授权、重复授权状态读取

### 依赖策略

- 如当前实现依赖 store，则使用 fake state store 或显式 reset store
- 不触碰真实 UI 授权链

### 伪码骨架

```ts
describe('FirewallAuthService', () => {
  beforeEach(() => {
    FirewallAuthStateStore.clear()
  })

  it('should report unauthorized by default', async () => {
    const result = FirewallAuthService.getAuthState()
    expect(result.authorized).assertFalse()
  })

  it('should persist authorized state after success', async () => {
    const result = await FirewallAuthService.markAuthorized()

    expect(result.success).assertTrue()
    expect(FirewallAuthService.getAuthState().authorized).assertTrue()
  })

  it('should clear auth state', async () => {
    await FirewallAuthService.markAuthorized()
    FirewallAuthService.clearAuthState()

    expect(FirewallAuthService.getAuthState().authorized).assertFalse()
  })
})
```

### 场景矩阵

| 场景 | 断言 |
|---|---|
| 默认未授权 | `authorized=false` |
| 成功授权 | 状态切换为已授权 |
| 重复读取状态 | 状态保持稳定 |
| 清空授权 | 回到未授权 |
| store 异常 | 返回稳定错误态 |

## 5.3 新增 FirewallRulesService 测试

### 文件

- 新增 [entry/src/test/firewall/rules-service.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/firewall/rules-service.test.ets)
- 被测文件：[entry/src/main/ets/services/firewall/rules/FirewallRulesService.ets](/Users/mu/Desktop/code/security_tool/entry/src/main/ets/services/firewall/rules/FirewallRulesService.ets)

### 改造目标

- 让规则层具备独立用例，不再把规则行为都塞进 `service.test.ets`

### 重点覆盖

- 列表读取
- 新建规则入参校验
- 更新规则
- 删除规则
- 规则字段规范化
- 仓储失败映射

### 伪码骨架

```ts
describe('FirewallRulesService', () => {
  beforeEach(() => {
    resetMock()
  })

  it('should list normalized rules', async () => {
    setMockRules([
      createRule(100, 'rule-a', 1, 0, MockNetFirewallRuleType.RULE_IP, true)
    ])

    const result = await FirewallRulesService.getAllRules(100, 1, 20)

    expect(result.success).assertTrue()
    expect(result.data.length).assertEqual(1)
  })

  it('should reject invalid rule payload', async () => {
    const result = await FirewallRulesService.addRule({
      name: ' ',
      userId: 100
    } as Object)

    expect(result.success).assertFalse()
  })
})
```

### 场景矩阵

| 场景 | 断言 |
|---|---|
| 规则列表成功 | 返回规则数组 |
| 空列表 | 返回空数组 |
| 规则新增成功 | 返回成功及 ruleId |
| 规则新增非法 | 返回校验失败 |
| 规则更新成功 | 更新后字段可见 |
| 规则删除成功 | 查询不再命中 |
| 依赖抛错 | 返回稳定错误码 |

## 5.4 新增 AuthService 行为测试

### 文件

- 新增 [entry/src/test/auth/auth-service.behavior.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/auth/auth-service.behavior.test.ets)
- 被测文件：[entry/src/main/ets/services/identity/auth/AuthService.ets](/Users/mu/Desktop/code/security_tool/entry/src/main/ets/services/identity/auth/AuthService.ets)

### 改造目标

- 把当前 `AuthService` 从 `0%` 拉起来
- 覆盖能力探测、标签映射、认证成功、取消、失败、异常

### 依赖策略

- 如认证 SDK 直接绑死在 service 中，PR1 先使用局部 fake 包装现有公开方法输入输出
- 不改业务规则
- 如必须替换外部能力，优先在测试文件内局部 mock 能力返回值

### 伪码骨架

```ts
describe('AuthService behavior', () => {
  it('should return unavailable when auth method is unsupported', async () => {
    mockCheckAvailability(false)

    const result = await AuthService.checkAuthMethodAvailability('fingerprint')

    expect(result).assertFalse()
  })

  it('should map auth method label correctly', () => {
    expect(AuthService.getAuthMethodLabel('password')).assertEqual('密码')
  })

  it('should resolve success when authentication passes', async () => {
    mockAuthenticateResolve({ success: true })

    const result = await AuthService.authenticate('password')

    expect(result.success).assertTrue()
  })

  it('should map user cancel into stable result', async () => {
    mockAuthenticateReject({ code: 'cancel' })

    const result = await AuthService.authenticate('fingerprint')

    expect(result.success).assertFalse()
    expect(result.code).assertEqual('cancelled')
  })
})
```

### 场景矩阵

| 场景 | 断言 |
|---|---|
| 认证能力可用 | 返回 `true` |
| 认证能力不可用 | 返回 `false` |
| method label 映射 | 中文文案正确 |
| 认证成功 | `success=true` |
| 用户取消 | 返回 `cancelled` |
| 认证失败 | 返回稳定失败码 |
| 系统异常 | 返回稳定错误态 |

## 5.5 新增 SystemSettingsService 测试

### 文件

- 新增 [entry/src/test/tool-settings/system-settings-service.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/tool-settings/system-settings-service.test.ets)
- 被测文件：[entry/src/main/ets/services/tool-settings/system-settings/SystemSettingsService.ets](/Users/mu/Desktop/code/security_tool/entry/src/main/ets/services/tool-settings/system-settings/SystemSettingsService.ets)
- 关联文件：[entry/src/main/ets/services/tool-settings/system-settings/ToolSettingsRepository.ets](/Users/mu/Desktop/code/security_tool/entry/src/main/ets/services/tool-settings/system-settings/ToolSettingsRepository.ets)

### 改造目标

- 覆盖设置读取、默认值回退、保存成功、保存失败、边界值规范化

### 依赖策略

- 如果 repository 直接读写系统 store，测试侧使用 fake preferences 数据
- 如现阶段无法完全注入，PR1 可通过 mock repository 公开接口覆盖 service 行为

### 伪码骨架

```ts
describe('SystemSettingsService', () => {
  it('should load settings from repository', async () => {
    mockRepositoryLoad({
      autoStart: true,
      theme: 'light'
    })

    const result = await SystemSettingsService.loadSettings()

    expect(result.success).assertTrue()
    expect(result.data.autoStart).assertTrue()
  })

  it('should fallback to default values when repository returns invalid data', async () => {
    mockRepositoryLoad({
      autoStart: 'bad',
      theme: 999
    } as Object)

    const result = await SystemSettingsService.loadSettings()

    expect(result.success).assertTrue()
    expect(result.data.theme).assertEqual('light')
  })

  it('should map save failure into stable result', async () => {
    mockRepositorySaveThrow()

    const result = await SystemSettingsService.saveSettings(validSettings)

    expect(result.success).assertFalse()
  })
})
```

### 场景矩阵

| 场景 | 断言 |
|---|---|
| 读取成功 | 返回 settings |
| repository 空值 | 默认值回退 |
| repository 非法值 | 规范化结果 |
| 保存成功 | 返回成功 |
| 保存失败 | 返回稳定错误 |

## 5.6 Fake 基础设施

### 文件

- 新增 [entry/src/test/__fakes__/FakeNowProvider.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/__fakes__/FakeNowProvider.ets)
- 新增 [entry/src/test/__fakes__/FakePreferenceStore.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/__fakes__/FakePreferenceStore.ets)
- 新增 [entry/src/test/__fakes__/FakeFirewallPort.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/__fakes__/FakeFirewallPort.ets)
- 新增 [entry/src/test/__fakes__/FakeAuthPort.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/__fakes__/FakeAuthPort.ets)
- 新增 [entry/src/test/__fakes__/FakeSystemSettingsPort.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/__fakes__/FakeSystemSettingsPort.ets)

### 目标

- 避免每个测试文件自己内联一套伪对象
- 控制测试数据一致性
- 减少重复逻辑

### FakeNowProvider 伪码

```ts
export class FakeNowProvider {
  private current: number

  constructor(seed: number = 1700000000000) {
    this.current = seed
  }

  now(): number {
    return this.current
  }

  set(value: number): void {
    this.current = value
  }
}
```

### FakePreferenceStore 伪码

```ts
export class FakePreferenceStore {
  private store: Map<string, Object> = new Map()
  public failGet: boolean = false
  public failPut: boolean = false

  async get(key: string, defaultValue?: Object): Promise<Object> {
    if (this.failGet) {
      throw new Error('fake_get_failed')
    }
    return this.store.has(key) ? this.store.get(key)! : defaultValue!
  }

  async put(key: string, value: Object): Promise<void> {
    if (this.failPut) {
      throw new Error('fake_put_failed')
    }
    this.store.set(key, value)
  }

  async flush(): Promise<void> {}
}
```

### FakeFirewallPort 伪码

```ts
export class FakeFirewallPort {
  public policy = defaultPolicy()
  public rules: MockNetFirewallRule[] = []
  public failMode: string | null = null

  async getPolicy(userId: number): Promise<MockNetFirewallPolicy> {
    if (this.failMode === 'getPolicy') {
      throw new Error('getPolicy failed')
    }
    return this.policy
  }
}
```

### 使用原则

- fake 只承载外部依赖
- fake 不复制生产业务逻辑
- fake 的失败模式必须简单可控

## 6. 测试目录组织调整

PR1 不要求重排所有目录，但新增文件应遵循下面的组织方式：

```text
entry/src/test/
  __fakes__/
    FakeNowProvider.ets
    FakePreferenceStore.ets
    FakeFirewallPort.ets
    FakeAuthPort.ets
    FakeSystemSettingsPort.ets
  auth/
    auth-service.behavior.test.ets
  firewall/
    service.test.ets
    auth-service.test.ets
    rules-service.test.ets
  tool-settings/
    system-settings-service.test.ets
```

## 7. 具体实施步骤

### Step 1

先重写 [entry/src/test/firewall/service.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/firewall/service.test.ets)

动作：

- 删除只测 mock 的计数用例
- 把查询、写入、失败映射改成 repository/service 驱动
- 保留 `MockNetFirewall.ets` 作为外部替身

### Step 2

新增防火墙授权与规则服务测试

动作：

- 新建 `auth-service.test.ets`
- 新建 `rules-service.test.ets`
- 把规则行为从 `service.test.ets` 中拆出去

### Step 3

新增认证服务行为测试

动作：

- 能力探测
- 标签映射
- 认证成功/取消/失败/异常

### Step 4

新增系统设置服务测试

动作：

- 读取成功
- 空值与非法值回退
- 保存成功
- 保存失败

### Step 5

执行单测并对比覆盖率

命令：

```bash
hvigorw test --mode module -p product=default -p module=entry@default
```

检查点：

- 新增测试全部通过
- 防火墙、认证、系统设置模块覆盖率不再为 0

## 8. 验收标准

### 8.1 代码层

- 不引入新的生产测试入口
- 不修改业务规则
- 新增测试以生产公开 API 为主入口

### 8.2 测试层

- 防火墙测试不再主要围绕 mock API 本身展开
- `AuthService` 和 `SystemSettingsService` 至少具备完整基础行为覆盖
- 每个新增测试文件都覆盖成功、失败、边界至少三类分支

### 8.3 覆盖率层

- 核心目标模块不再是 `0%`
- 总体覆盖率有可见提升
- 分支覆盖率也应提升，不能只堆 happy path

## 9. 风险与回避策略

### 风险 1：现有服务过度依赖静态系统能力，测试注入困难

回避：

- PR1 先在测试侧用已有 mock 能力包裹公开调用
- 注入式结构重构推迟到 PR2/PR3

### 风险 2：防火墙测试重写后，部分旧断言失效

回避：

- 旧断言若只验证 mock，不保留
- 只保留与业务输出相关的断言

### 风险 3：设置服务和认证服务外部依赖太强

回避：

- 先测结果映射与错误回退
- 再在下一阶段做可测试结构提纯

## 10. PR1 完成后的下一步

PR1 完成后，进入 PR2：

- 抽离 log-manage 的解析函数
- 清理 `parseAuditEventForTest`
- 清理 `mapCrashInfoForTest`

PR3：

- repository 支持 fake store
- 清理 `setStorageConfigForTest`
- 清理 `setRecordsForTest`

## 11. 简化版任务清单

- [ ] 重写 [entry/src/test/firewall/service.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/firewall/service.test.ets)
- [ ] 新增 [entry/src/test/firewall/auth-service.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/firewall/auth-service.test.ets)
- [ ] 新增 [entry/src/test/firewall/rules-service.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/firewall/rules-service.test.ets)
- [ ] 新增 [entry/src/test/auth/auth-service.behavior.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/auth/auth-service.behavior.test.ets)
- [ ] 新增 [entry/src/test/tool-settings/system-settings-service.test.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/tool-settings/system-settings-service.test.ets)
- [ ] 新增 [entry/src/test/__fakes__/FakeNowProvider.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/__fakes__/FakeNowProvider.ets)
- [ ] 新增 [entry/src/test/__fakes__/FakePreferenceStore.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/__fakes__/FakePreferenceStore.ets)
- [ ] 新增 [entry/src/test/__fakes__/FakeFirewallPort.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/__fakes__/FakeFirewallPort.ets)
- [ ] 新增 [entry/src/test/__fakes__/FakeAuthPort.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/__fakes__/FakeAuthPort.ets)
- [ ] 新增 [entry/src/test/__fakes__/FakeSystemSettingsPort.ets](/Users/mu/Desktop/code/security_tool/entry/src/test/__fakes__/FakeSystemSettingsPort.ets)
- [ ] 运行 `entry@default` 单测
- [ ] 检查覆盖率变化
