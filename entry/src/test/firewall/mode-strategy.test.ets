import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { FirewallPresetRuleNameStrings } from '../../main/ets/constants/modules/FirewallStrings'
import { FirewallLocalRepository } from '../../main/ets/services/firewall/FirewallLocalRepository'
import {
  FIREWALL_PROTOCOL_TCP,
  FirewallPreparedRule,
  FirewallRuleIntent,
  UserFirewallListResult,
  UserFirewallOption
} from '../../main/ets/services/firewall/FirewallModels'
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

    it('should deny public remote access ports for every available user without limiting remote ips', 0, async (done: Function) => {
      let userMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
      when(userMock)().afterReturn(buildUserResult(buildUsers()))

      let rules = await FirewallModeStrategy.buildRulesForMode(fakeContext as never as common.UIAbilityContext, 'public')
      let remoteRules = rules.filter((item: FirewallPreparedRule): boolean =>
        item.rule.name === FirewallPresetRuleNameStrings.PUBLIC_DENY_REMOTE_ACCESS)
      let expectedPorts: number[] = [22, 23, 3389, 5900]

      expect(remoteRules.length).assertEqual(buildUsers().length)
      expect(remoteRules.some((item: FirewallPreparedRule): boolean => item.userId === 100)).assertTrue()
      expect(remoteRules.some((item: FirewallPreparedRule): boolean => item.userId === 101)).assertTrue()
      for (let i = 0; i < remoteRules.length; i++) {
        let rule = remoteRules[i].rule
        let localPorts = rule.localPorts ?? []
        let remoteIps = rule.remoteIps ?? []
        expect(rule.direction).assertEqual(netFirewall.NetFirewallRuleDirection.RULE_IN)
        expect(rule.action).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)
        expect(rule.type).assertEqual(netFirewall.NetFirewallRuleType.RULE_IP)
        expect(rule.isEnabled).assertTrue()
        expect(rule.protocol).assertEqual(FIREWALL_PROTOCOL_TCP)
        expect(localPorts.length).assertEqual(expectedPorts.length)
        for (let portIndex = 0; portIndex < expectedPorts.length; portIndex++) {
          expect(localPorts[portIndex].startPort).assertEqual(expectedPorts[portIndex])
          expect(localPorts[portIndex].endPort).assertEqual(expectedPorts[portIndex])
        }
        expect(remoteIps.length).assertEqual(0)
      }
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
