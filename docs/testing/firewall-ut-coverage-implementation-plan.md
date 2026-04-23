# 防火墙 UT 补强实施计划

最后更新：2026-04-22

## 1. 工作区与分支

- 工作区：`D:\project\ai\security_tool`
- 工作分支：`codex/firewall-ut-coverage`
- 计划确认表：`docs/testing/firewall-ut-scope-confirmation.xlsx`

本计划先于代码改动落地并提交，用于锁定本轮 UT 补强范围、语义边界和执行验收方式。后续 UT 实施必须遵守本文档，若需要调整范围，必须先更新本文档并重新确认。

## 2. 背景

当前防火墙本地 UT 已覆盖基础 label、文案、少量 `FirewallRuleUtils` 行为、`FirewallService.switchMode` 部分 happy path，以及 `SystemUserProvider` 的结构性返回。

现有缺口集中在：

- 全局开启/关闭防火墙。
- 本地规则意图、部署记录、当前模式、用户策略模式的 repository 读写。
- 规则新增、更新、删除、展示的 service 编排。
- IP、Domain exact、DNS primaryDns 冲突判断。
- public/private/custom 模式规则生成的公开行为。

## 3. 目的

以“小步闭环”的方式补强防火墙本地 UT。每一步新增或修改 UT 后，必须立即运行本地 UT，确认通过后才能进入下一步。

目标覆盖：

- `FirewallService.setFirewallEnabledForAllUsers` 全局开关主链路和已确认失败路径。
- `FirewallLocalRepository` 本地状态读写、过滤、兜底。
- `FirewallService` 规则展示、创建、更新、删除主流程。
- `FirewallRuleUtils` 明确输入校验、IP 冲突、Domain exact 冲突、DNS primaryDns 冲突和统计。
- `FirewallModeStrategy` custom 模式、多用户展开、public/private 公开行为。

## 4. 严格修改范围

本轮 UT 实施只允许修改或新增以下文件：

| 文件 | 操作 | 说明 |
|---|---|---|
| `entry/src/test/firewall/service.test.ets` | 修改 | 补全局开关、规则 CRUD 主流程 |
| `entry/src/test/firewall/local-repository.test.ets` | 新增 | 补 `FirewallLocalRepository` UT |
| `entry/src/test/firewall/rule-utils.test.ets` | 修改 | 扩展输入校验、冲突矩阵、统计 |
| `entry/src/test/firewall/mode-strategy.test.ets` | 新增 | 补 `FirewallModeStrategy` UT |
| `entry/src/test/List.test.ets` | 修改 | 注册新增测试 |

本轮不修改：

- `entry/src/main/**`
- `entry/src/ohosTest/**`
- `entry/src/main/module.json5`
- `AppScope/app.json5`
- `hapsigner/**`
- `.github/**`

若实施中发现必须修改生产代码，立即停止当前执行，先输出原因、影响和新计划，不允许直接扩大范围。

## 5. 已确认语义边界

以下结论来自 `docs/testing/firewall-ut-scope-confirmation.xlsx`。

### 5.1 本轮不纳入 UT 的场景

| 场景 | 结论 |
|---|---|
| 用户列表为空时全局开关行为 | 不测；业务确认不存在该场景 |
| 删除系统规则部分失败后本地 deployment 是否删除 | 不测；业务确认不存在该场景 |
| update 时旧规则删除失败后是否继续创建 | 不测；业务确认不存在该场景 |
| 本地保存 intent/deployment 失败后是否回滚系统规则 | 不测；业务确认不存在该场景 |
| Domain wildcard 冲突 | 不测；本轮只测 exact domain |
| public/private 具体规则数量、名称、端口强断言 | 不测；本轮只测公开行为 |
| rawfile 非 ASCII/UTF-8 编码风险 | 不测；本轮只测读取失败兜底 |

### 5.2 本轮需要固化的语义

| 语义 | 确认结果 |
|---|---|
| 多用户创建规则部分成功 | 保留成功 deployment，返回 `success=false` |
| DNS 冲突判断 | 只按 `primaryDns` 判断 |
| IP 空地址/空端口 | 空 IP 表示全 IPv4，空端口表示全端口 |
| public/private policy | `isOpen=true`，`inAction=ALLOW`，`outAction=ALLOW` |
| custom allowlist policy | `isOpen=true`，`inAction=DENY`，`outAction=DENY` |
| custom denylist/default policy | `isOpen=true`，`inAction=ALLOW`，`outAction=ALLOW` |
| private/public 规则生成 | 只断言不抛异常、按用户展开、字段合法，不强断言策略细节 |

## 6. 统一验证命令

每一步完成后运行：

```powershell
hvigorw test --mode module -p product=default -p module=entry@default
```

若找不到 `hvigorw`，按项目约定依次定位：

1. 环境变量 `DEVECOSTUDIO_HOME`
2. `C:\Program Files\Huawei\DevEco Studio`
3. IDE 根目录下 `tools\hvigor\bin\hvigorw.bat`

## 7. 腐败代码禁止项

每一步验收前必须检查，禁止出现：

```ts
expect(true).assertTrue()
```

```ts
if (result.success || true) {
  expect(true).assertTrue()
}
```

```ts
// 半真半假：测试仍触碰真实 preferences、netFirewall 或 PIN
await FirewallLocalRepository.listRuleIntents({} as common.Context)
```

```ts
// fake preferences 不按 storeName 隔离
when(ofMock)(ArgumentMatchers.any).afterReturn(fakeAccessor as never as PreferencesAccessor)
```

允许测试内 fake，但必须按 `storeName` 隔离 preferences store。

## 8. 代码变动伪代码

本轮计划涉及测试代码新增和修改。实施时应以本节伪代码为结构约束；伪代码不是最终代码，但用于锁定新增测试的组织方式、mock 边界和禁止生成的腐败代码。

### 8.1 `entry/src/test/firewall/service.test.ets`

目标：在既有 `FirewallService` 测试中增加 `global toggle` 和 `rule mutations` 分组，保留现有 `switchMode` 测试。

允许生成的伪代码：

```ts
export default function firewallServiceTest() {
  describe('FirewallService', () => {
    let mockKit: MockKit
    let context: common.UIAbilityContext

    beforeEach(() => {
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    describe('global toggle', () => {
      it('should reject toggle when PIN auth is unavailable', async () => {
        // mock AuthService.authenticate => { success: false, reason: 'unavailable' }
        // mock SystemUserProvider.loadAvailableUserIds and assert it is not reached by observable result
        // call FirewallService.setFirewallEnabledForAllUsers(context, true)
        // expect success=false
        // expect reason='pin_unavailable'
      })

      it('should enable firewall for every user while keeping existing actions', async () => {
        // mock auth success
        // mock users: 100, 101
        // mock getPolicy per user with different inAction/outAction
        // capture setPolicy payloads
        // call setFirewallEnabledForAllUsers(context, true)
        // expect success=true
        // expect captured policies have isOpen=true
        // expect captured policies keep original inAction/outAction
      })

      it('should report policy_apply_failed when one user policy cannot be read or written', async () => {
        // mock auth success
        // mock users
        // one getPolicy returns null OR one setPolicy returns false
        // call setFirewallEnabledForAllUsers
        // expect success=false
        // expect reason='policy_apply_failed'
        // expect failedItems include userId and expected errorMessage
      })
    })

    describe('mode switch', () => {
      // keep existing switchMode public/private/custom tests
      // add only confirmed assertions if needed:
      // public/private => ALLOW/ALLOW
      // custom allowlist => DENY/DENY
      // custom denylist/default => ALLOW/ALLOW
    })

    describe('rule mutations', () => {
      it('should list display rules from local intents and deployments', async () => {
        // mock FirewallLocalRepository.loadRuleIntentMappingData
        // call FirewallService.listRulesForDisplay(context)
        // expect display item includes localRuleId, targetUserIds, deployments
      })

      it('should create a rule for one or more users', async () => {
        // mock FirewallSystemRepository.addRule returns positive systemRuleId
        // mock FirewallLocalRepository.saveRuleIntent returns true
        // mock FirewallLocalRepository.replaceRuleDeployments returns true
        // call FirewallService.createRule(context, input)
        // expect success=true
        // expect successDeployments match users and systemRuleIds
      })

      it('should keep successful deployments when multi-user create partially fails', async () => {
        // mock one addRule success and one addRule failure
        // call createRule
        // expect success=false
        // expect successDeployments contains successful user
        // expect failedItems contains failed user
      })

      it('should update an existing rule by deleting old deployments and creating new deployments', async () => {
        // mock getRuleIntent existing
        // mock listRuleDeployments old deployments
        // mock removeRule success
        // mock removeRuleDeployments success
        // mock addRule success for new input
        // expect result localRuleId unchanged
      })

      it('should delete a rule and remove local intent', async () => {
        // mock listRuleDeployments
        // mock removeRule success for each deployment
        // mock removeRuleDeployments success
        // mock removeRuleIntent success
        // expect success=true
      })
    })
  })
}
```

不得生成的腐败伪代码：

```ts
// CORRUPT_CODE_DELETE: 空断言，未验证业务行为
it('should toggle firewall', () => {
  expect(true).assertTrue()
})
```

```ts
// CORRUPT_CODE_DELETE: 制造已确认不存在的场景
it('should fail when user list is empty', async () => {
  // 本轮不写：用户列表为空已确认不存在
})
```

```ts
// CORRUPT_CODE_DELETE: 制造已确认不存在的失败分支
it('should keep deployment when removeRule fails', async () => {
  // 本轮不写：删除系统规则部分失败已确认不存在
})
```

### 8.2 `entry/src/test/firewall/local-repository.test.ets`

目标：新增 repository UT，使用 fake `PreferencesAccessor`，不触碰真实 Harmony preferences。

允许生成的伪代码：

```ts
class FakePreferencesAccessor {
  private values: Map<string, Object> = new Map()
  failSet: boolean = false

  async getString(key: string, defaultValue: string): Promise<string> {
    // return stored string or defaultValue
  }

  async getJsonObject<T>(key: string, defaultValue: T): Promise<T> {
    // parse stored string as object
    // return defaultValue on empty, invalid JSON, or non-object
  }

  async getJsonArray<T>(key: string, defaultValue: T[]): Promise<T[]> {
    // parse stored string as array
    // return defaultValue on empty, invalid JSON, or non-array
  }

  async setValue(key: string, value: Object): Promise<boolean> {
    // failSet => false
    // store value
  }

  async setJson(key: string, value: object | object[]): Promise<boolean> {
    // JSON.stringify and delegate to setValue
  }
}

class FakePreferencesProvider {
  private stores: Map<string, FakePreferencesAccessor> = new Map()

  accessorFor(storeName: string): FakePreferencesAccessor {
    // return one accessor per storeName
  }
}

export default function firewallLocalRepositoryTest() {
  describe('FirewallLocalRepository', () => {
    beforeEach(() => {
      // mock PreferencesAccessor.of(context, storeName)
      // return fakeProvider.accessorFor(storeName)
    })

    it('should default current mode to custom and persist legal modes', async () => {
      // getCurrentMode => custom
      // save public/private/custom then read back
    })

    it('should persist and normalize user policy modes', async () => {
      // save allowlist/denylist
      // overwrite same userId
      // seed invalid records
      // expect invalid records filtered
    })

    it('should persist rule intents and deployments independently', async () => {
      // save intent
      // replace deployments for one localRuleId
      // ensure other localRuleId deployments remain
    })

    it('should recover from corrupted mapping JSON', async () => {
      // seed invalid JSON into rule mapping store
      // loadRuleIntentMappingData => empty mapping data
    })
  })
}
```

不得生成的腐败伪代码：

```ts
// CORRUPT_CODE_DELETE: 单一 fake accessor 串所有 store
when(ofMock)(ArgumentMatchers.any).afterReturn(fakeAccessor as never as PreferencesAccessor)
```

```ts
// CORRUPT_CODE_DELETE: 半真半假，仍可能触碰真实 preferences
let result = await FirewallLocalRepository.listRuleIntents({} as common.Context)
expect(result.length >= 0).assertTrue()
```

### 8.3 `entry/src/test/firewall/rule-utils.test.ets`

目标：扩展纯函数 UT，不使用 mock。

允许生成的伪代码：

```ts
function buildIpIntent(options): FirewallRuleIntent {
  // construct RULE_IP intent with targetUserIds, action, direction,
  // active IP fields and active port fields
}

function buildDomainIntent(domain: string, action: number): FirewallRuleIntent {
  // construct RULE_DOMAIN exact domain intent
}

function buildDnsIntent(primaryDns: string, action: number): FirewallRuleIntent {
  // construct RULE_DNS intent
}

describe('FirewallRuleUtils', () => {
  describe('validation and normalization', () => {
    it('should reject empty name, missing users, missing domain and missing primary dns', () => {
      // assert exact error messages
    })

    it('should normalize user ids by filtering, deduplicating and sorting', () => {
      // [101, -1, 100, 101, 1.5] => [100, 101]
    })
  })

  describe('ip conflicts', () => {
    it('should classify duplicate, hard conflict, overlap and none', () => {
      // pure function assertions
    })

    it('should treat empty ip and ports as all IPv4 and all ports', () => {
      // confirmed semantics
    })
  })

  describe('domain exact and dns primary conflicts', () => {
    it('should classify exact domain conflicts without wildcard cases', () => {
      // exact domain only
    })

    it('should classify dns conflicts by primaryDns only', () => {
      // primaryDns same/different
    })
  })
})
```

不得生成的腐败伪代码：

```ts
// CORRUPT_CODE_DELETE: 本轮不测 wildcard domain
expect(conflictFor('*.example.com', 'a.example.com')).assertEqual('overlap_conflict')
```

```ts
// CORRUPT_CODE_DELETE: DNS standbyDns 语义未纳入本轮
expect(conflictByStandbyDns).assertEqual('hard_conflict')
```

### 8.4 `entry/src/test/firewall/mode-strategy.test.ets`

目标：新增 `FirewallModeStrategy` UT，只测试公开行为，不强断言 public/private 具体规则策略细节。

允许生成的伪代码：

```ts
export default function firewallModeStrategyTest() {
  describe('FirewallModeStrategy', () => {
    beforeEach(() => {
      // mock SystemUserProvider.loadAvailableUserIds
      // mock FirewallLocalRepository.listRuleIntents for custom
    })

    it('should return empty prepared rules for empty custom intents', async () => {
      // listRuleIntents => []
      // buildRulesForMode(context, 'custom') => []
    })

    it('should expand custom intents to normalized target users', async () => {
      // targetUserIds [101, 100, 101]
      // expect prepared userIds [100, 101]
      // expect localRuleId preserved
    })

    it('should build public rules as valid prepared rules without asserting exact strategy details', async () => {
      // users [100, 101]
      // resourceManager can return valid minimal config or throw for fallback
      // assert every result has userId, rule, direction/type/action/isEnabled fields
      // do not assert exact count/name/ports
    })

    it('should build private rules without throwing when preset config falls back', async () => {
      // getRawFileContent throws
      // assert result is an array and each item is structurally valid
    })
  })
}
```

不得生成的腐败伪代码：

```ts
// CORRUPT_CODE_DELETE: 强行固化 public 具体规则数量
expect(publicRules.length).assertEqual(7)
```

```ts
// CORRUPT_CODE_DELETE: 强行固化 private 具体端口策略
expect(privateRules[0].rule.localPorts?.[0].startPort).assertEqual(3389)
```

### 8.5 `entry/src/test/List.test.ets`

目标：只注册新增测试，不调整其他 suite 顺序和行为。

允许生成的伪代码：

```ts
import firewallLocalRepositoryTest from './firewall/local-repository.test'
import firewallModeStrategyTest from './firewall/mode-strategy.test'

export default function testsuite() {
  // keep existing tests
  firewallLocalRepositoryTest()
  firewallModeStrategyTest()
}
```

不得生成的腐败伪代码：

```ts
// CORRUPT_CODE_DELETE: 为了让新增测试通过而跳过既有测试
export default function testsuite() {
  firewallLocalRepositoryTest()
}
```

## 9. 小步执行计划

### 步骤 0：基线确认

修改文件：无

输入：

- 当前仓库。
- 当前本地 UT。

动作：

1. 执行 `git status --short`。
2. 确认当前分支为 `codex/firewall-ut-coverage`。
3. 执行本地 UT，建立基线。

输出：

- 当前本地 UT 基线结果。
- 当前工作区状态。

验收标准：

- 基线结果明确。
- 若基线失败，先记录失败项，不进入新增 UT。
- 不修改任何文件。

### 步骤 1：补全局开关成功与鉴权失败 UT

修改文件：

- `entry/src/test/firewall/service.test.ets`

输入：

- `FirewallService.setFirewallEnabledForAllUsers`
- `AuthService.authenticate`
- `SystemUserProvider.loadAvailableUserIds`
- `FirewallSystemRepository.getPolicy`
- `FirewallSystemRepository.setPolicy`

新增用例：

1. PIN 不可用：返回 `reason='pin_unavailable'`，不继续调用用户/策略接口。
2. PIN 校验失败：返回 `reason='pin_failed'`。
3. 全局开启成功：所有用户 `isOpen=true`，保留原 `inAction/outAction`。
4. 全局关闭成功：所有用户 `isOpen=false`，保留原 `inAction/outAction`。

输出：

- `service.test.ets` 新增 `global toggle` 分组。
- 本地 UT 通过。

验收标准：

- 不调用真实 PIN。
- 不调用真实 netFirewall。
- 不包含用户列表为空场景。
- 本步新增和既有 UT 全部通过。

### 步骤 2：补全局开关策略应用失败 UT

修改文件：

- `entry/src/test/firewall/service.test.ets`

输入：

- 步骤 1 已通过的 mock 结构。

新增用例：

1. 某用户 `getPolicy` 返回 `null`：`failedItems` 包含 `read policy failed`。
2. 某用户 `setPolicy` 返回 `false`：`failedItems` 包含 `set policy failed`。
3. 多用户部分失败：成功用户仍应用，整体 `success=false`，`reason='policy_apply_failed'`。

不写：

- 用户列表为空。

输出：

- 全局开关成功和失败主路径覆盖完成。
- 本地 UT 通过。

验收标准：

- `failedItems` 断言包含 `userId` 和错误信息。
- 本步新增和既有 UT 全部通过。

### 步骤 3：新增 LocalRepository 模式与用户策略 UT

修改文件：

- `entry/src/test/firewall/local-repository.test.ets`
- `entry/src/test/List.test.ets`

输入：

- `FirewallLocalRepository`
- `PreferencesAccessor.of`

新增测试基础设施：

- 测试内 `FakePreferencesAccessor`。
- 按 `storeName` 分 Map 的 fake provider。
- `MockKit` mock `PreferencesAccessor.of(context, storeName)`。

新增用例：

1. 空存储 `getCurrentMode` 返回 `custom`。
2. 保存/读取 `public/private/custom`。
3. 非法 mode 回落 `custom`。
4. 保存/读取 `allowlist/denylist`。
5. 同 `userId` 覆盖保存。
6. `listUserPolicyModes` 过滤非法记录。

输出：

- 新增并注册 `local-repository.test.ets`。
- 本地 UT 通过。

验收标准：

- 不触碰真实 preferences。
- fake preferences 按 `storeName` 隔离。
- 本步新增和既有 UT 全部通过。

### 步骤 4：补 LocalRepository 规则映射与 deployment UT

修改文件：

- `entry/src/test/firewall/local-repository.test.ets`

输入：

- 步骤 3 已通过的 fake preferences 基础设施。

新增用例：

1. 空存储返回空 `ruleIntents` 和 `ruleDeployments`。
2. 保存并读取 rule intent。
3. 同 `localRuleId` 覆盖保存。
4. 删除 rule intent。
5. `replaceRuleDeployments` 只替换目标 `localRuleId`。
6. `removeRuleDeployments` 只删除目标 `localRuleId`。
7. `clearAllRuleDeployments` 清空 deployments 但保留 intents。
8. 损坏 JSON 兜底为空结构。
9. 写入失败返回 `false`。

输出：

- `FirewallLocalRepository` 核心读写覆盖完成。
- 本地 UT 通过。

验收标准：

- 每个断言验证真实 repository 行为。
- 不碰真实 preferences。
- 本步新增和既有 UT 全部通过。

### 步骤 5：补 Service 规则展示与 createRule 主流程 UT

修改文件：

- `entry/src/test/firewall/service.test.ets`

输入：

- `FirewallService.listRulesForDisplay`
- `FirewallService.createRule`
- `FirewallLocalRepository`
- `FirewallSystemRepository`

新增用例：

1. `listRulesForDisplay` 从本地 intent + deployment 生成展示项。
2. `createRule` 单用户成功：调用 `addRule`、保存 intent、保存 deployment。
3. `createRule` 多用户成功：每个用户都有 deployment。
4. `createRule` 输入校验失败：不调用 `addRule`，不保存本地状态。

输出：

- `service.test.ets` 新增或扩展 `rule mutations` 分组。
- 本地 UT 通过。

验收标准：

- 不调用真实 netFirewall。
- 不包含本地保存失败回滚场景。
- 本步新增和既有 UT 全部通过。

### 步骤 6：补 Service createRule 部分成功、update/delete 主流程 UT

修改文件：

- `entry/src/test/firewall/service.test.ets`

输入：

- 步骤 5 已通过的 `rule mutations` 分组。

新增用例：

1. `createRule` 多用户部分成功：保留成功 deployment，返回 `success=false`。
2. `createRule` 所有 `addRule` 失败：返回失败，不保存本地状态。
3. `updateRule` 找不到 intent：返回 `rule intent not found`。
4. `updateRule` 成功：删除旧 deployment，重新创建并保存。
5. `deleteRule` 成功：删除系统规则，移除 intent 和 deployment。

不写：

- 删除系统规则部分失败。
- update 旧规则删除失败后是否继续创建。
- 本地保存失败后是否回滚系统规则。

输出：

- `FirewallService` 规则 CRUD 主流程覆盖完成。
- 本地 UT 通过。

验收标准：

- 部分成功语义按确认结果固化。
- 不制造已确认“不存在”的失败场景。
- 本步新增和既有 UT 全部通过。

### 步骤 7：扩展 RuleUtils 明确输入与 IP 冲突 UT

修改文件：

- `entry/src/test/firewall/rule-utils.test.ets`

输入：

- `FirewallRuleUtils.validateRuleIntentInput`
- `FirewallRuleUtils.normalizeUserIds`
- `FirewallRuleUtils.findRuleConflict`

新增用例：

1. validate：空名称失败。
2. validate：无有效用户失败。
3. validate：domain 缺 domain 失败。
4. validate：dns 缺 primaryDns 失败。
5. `normalizeUserIds` 过滤、去重、排序。
6. IP duplicate。
7. IP hard conflict。
8. IP none。
9. IP CIDR vs 单 IP overlap。
10. IP 空地址/空端口按全量范围参与冲突。
11. IP 协议不同 none。
12. IP 用户范围不相交 none。

输出：

- RuleUtils 输入校验和 IP 冲突矩阵增强。
- 本地 UT 通过。

验收标准：

- 纯函数测试，不依赖 mock。
- 空 IP/空端口按确认结果固化。
- 本步新增和既有 UT 全部通过。

### 步骤 8：补 Domain exact、DNS primaryDns、冲突汇总 UT

修改文件：

- `entry/src/test/firewall/rule-utils.test.ets`

输入：

- `FirewallRuleUtils.findRuleConflict`
- `FirewallRuleUtils.summarizeConflicts`

新增用例：

1. Domain exact duplicate。
2. Domain exact hard conflict。
3. Domain exact none。
4. DNS primaryDns duplicate。
5. DNS primaryDns hard conflict。
6. DNS primaryDns 不同 none。
7. `summarizeConflicts` 统计 duplicate/hard/overlap。

不写：

- Domain wildcard。

输出：

- RuleUtils 冲突覆盖完成。
- 本地 UT 通过。

验收标准：

- DNS 只按 `primaryDns` 固化。
- 不包含 wildcard domain。
- 本步新增和既有 UT 全部通过。

### 步骤 9：新增 ModeStrategy custom UT

修改文件：

- `entry/src/test/firewall/mode-strategy.test.ets`
- `entry/src/test/List.test.ets`

输入：

- `FirewallModeStrategy.buildRulesForMode('custom')`
- `FirewallLocalRepository.listRuleIntents`

新增用例：

1. custom 空规则返回空数组。
2. custom 单规则多用户展开，保留 `localRuleId`。
3. custom 多规则展开，`userId` 和 rule 字段合法。

输出：

- 新增并注册 `mode-strategy.test.ets`。
- 本地 UT 通过。

验收标准：

- 不测私有 helper。
- 不调用真实 preferences。
- 本步新增和既有 UT 全部通过。

### 步骤 10：补 ModeStrategy public/private 公开行为 UT

修改文件：

- `entry/src/test/firewall/mode-strategy.test.ets`

输入：

- `FirewallModeStrategy.buildRulesForMode('public')`
- `FirewallModeStrategy.buildRulesForMode('private')`
- `SystemUserProvider.loadAvailableUserIds`
- `context.resourceManager.getRawFileContent`

新增用例：

1. public 模式不抛异常，结果按用户展开，字段合法。
2. private 模式不抛异常，结果字段合法。
3. 配置读取失败时使用默认兜底，不抛异常。
4. 不强断言具体规则数量、名称、端口。

输出：

- public/private/custom 三种模式均有测试。
- 本地 UT 通过。

验收标准：

- 不固化策略细节。
- 不测试 rawfile 非 ASCII。
- 本步新增和既有 UT 全部通过。

### 步骤 11：最终清理与全量验证

修改文件：

- 无新增业务变更，仅清理必要测试辅助问题。

动作：

1. 搜索腐败代码：
   - `expect(true).assertTrue`
   - `CORRUPT_CODE_DELETE`
   - `preferences.getPreferences`
   - 裸 `hilog`
2. 确认修改文件范围。
3. 执行本地 UT。
4. 查看 `git diff --stat` 和关键 diff。

输出：

- 可提交的 UT 补强变更。

验收标准：

- 本地 UT 全部通过。
- 修改文件仅限计划范围。
- 没有生产代码变更。
- 没有签名、权限、包名变更。
- 没有中文乱码。

## 10. 最终交付说明要求

完成 UT 实施后，最终说明必须包含：

- 每一步 UT 是否跑通。
- 新增/修改的测试文件。
- 覆盖的防火墙链路。
- 未覆盖场景及原因，需引用本计划第 5 节的确认结果。
