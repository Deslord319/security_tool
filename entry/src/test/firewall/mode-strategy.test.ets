import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { FirewallLocalRepository } from '../../main/ets/services/firewall/FirewallLocalRepository'
import { FirewallRuleIntent, UserFirewallListResult, UserFirewallOption } from '../../main/ets/services/firewall/FirewallModels'
import { FirewallModeStrategy } from '../../main/ets/services/firewall/FirewallModeStrategy'
import { SystemUserProvider } from '../../main/ets/services/firewall/providers/SystemUserProvider'

class FakeResourceManager {
  failRead: boolean = false
  content: Uint8Array = new Uint8Array(0)

  async getRawFileContent(_fileName: string): Promise<Uint8Array> {
    if (this.failRead) {
      throw new Error('fake_rawfile_failed')
    }
    return this.content
  }
}

class FakeAbilityContext {
  resourceManager: FakeResourceManager = new FakeResourceManager()
}

function buildUsers(): UserFirewallOption[] {
  return [
    { userId: 100, label: '用户 100' },
    { userId: 101, label: '用户 101' }
  ]
}

function buildUserResult(users: UserFirewallOption[]): UserFirewallListResult {
  return {
    users: users,
    selectedUserId: users[0]?.userId
  }
}

function buildIntent(localRuleId: string, targetUserIds: number[]): FirewallRuleIntent {
  return {
    localRuleId: localRuleId,
    name: localRuleId,
    type: netFirewall.NetFirewallRuleType.RULE_IP,
    direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
    action: netFirewall.FirewallRuleAction.RULE_ALLOW,
    isEnabled: true,
    targetUserIds: targetUserIds,
    protocol: 6,
    remoteIps: [{
      type: 1,
      family: 1,
      address: '8.8.8.8',
      mask: 32
    }],
    remotePorts: [{ startPort: 443, endPort: 443 }],
    createdAt: 1,
    updatedAt: 1
  }
}

function asciiBytes(value: string): Uint8Array {
  let result = new Uint8Array(value.length)
  for (let i = 0; i < value.length; i++) {
    result[i] = value.charCodeAt(i)
  }
  return result
}

export default function firewallModeStrategyTest() {
  describe('FirewallModeStrategy', () => {
    let mockKit: MockKit
    let fakeContext: FakeAbilityContext

    beforeEach(() => {
      mockKit = new MockKit()
      fakeContext = new FakeAbilityContext()
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should return empty prepared rules for empty custom intents', 0, async (done: Function) => {
      let listIntentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listRuleIntents)
      when(listIntentsMock)(ArgumentMatchers.any).afterReturn([])

      let rules = await FirewallModeStrategy.buildRulesForMode(fakeContext as never as common.UIAbilityContext, 'custom')

      expect(rules.length).assertEqual(0)
      done()
    })

    it('should expand custom intents to normalized target users and preserve local rule id', 0, async (done: Function) => {
      let listIntentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listRuleIntents)
      when(listIntentsMock)(ArgumentMatchers.any).afterReturn([
        buildIntent('rule-1', [101, 100, 101]),
        buildIntent('rule-2', [102])
      ])

      let rules = await FirewallModeStrategy.buildRulesForMode(fakeContext as never as common.UIAbilityContext, 'custom')

      expect(rules.length).assertEqual(3)
      expect(rules[0].localRuleId).assertEqual('rule-1')
      expect(rules[0].userId).assertEqual(100)
      expect(rules[1].localRuleId).assertEqual('rule-1')
      expect(rules[1].userId).assertEqual(101)
      expect(rules[2].localRuleId).assertEqual('rule-2')
      expect(rules[2].userId).assertEqual(102)
      done()
    })

    it('should build public rules as valid prepared rules without asserting exact strategy details', 0, async (done: Function) => {
      let userMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
      fakeContext.resourceManager.content = asciiBytes('{"fixedPublicIp":"","privateCidrs":[],"privateTcpPorts":[],"privateUdpPorts":[]}')
      when(userMock)().afterReturn(buildUserResult(buildUsers()))

      let rules = await FirewallModeStrategy.buildRulesForMode(fakeContext as never as common.UIAbilityContext, 'public')

      expect(rules.length > 0).assertTrue()
      expect(rules[0].userId === 100 || rules[0].userId === 101).assertTrue()
      expect(typeof rules[0].rule.name === 'string').assertTrue()
      expect(typeof rules[0].rule.direction === 'number').assertTrue()
      expect(typeof rules[0].rule.action === 'number').assertTrue()
      expect(typeof rules[0].rule.type === 'number').assertTrue()
      done()
    })

    it('should build private rules without throwing when preset config falls back', 0, async (done: Function) => {
      let userMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
      fakeContext.resourceManager.failRead = true
      when(userMock)().afterReturn(buildUserResult(buildUsers()))

      let rules = await FirewallModeStrategy.buildRulesForMode(fakeContext as never as common.UIAbilityContext, 'private')

      expect(Array.isArray(rules)).assertTrue()
      done()
    })
  })
}
