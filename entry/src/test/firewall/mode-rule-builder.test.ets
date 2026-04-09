import { describe, expect, it } from '@ohos/hypium'
import { netFirewall } from '@kit.NetworkKit'

import { FirewallModeRuleBuilder } from '../../main/ets/services/firewall/mode-strategies/FirewallModeRuleBuilder'
import { FirewallRulesService } from '../../main/ets/services/firewall/rules/FirewallRulesService'

export default function firewallModeRuleBuilderTest() {
  describe('FirewallModeRuleBuilder', () => {
    it('should return empty list for custom mode', 0, () => {
      let rules = FirewallModeRuleBuilder.buildRulesForMode('custom', {
        fixedPublicIp: '1.1.1.1',
        privateCidrs: ['10.0.0.0/24'],
        privateTcpPorts: [8080],
        privateUdpPorts: [5353]
      })

      expect(rules.length).assertEqual(0)
    })

    it('should build public rules with remote manage scope when fixed ip exists', 0, () => {
      let rules = FirewallModeRuleBuilder.buildPublicRules('1.2.3.4')
      let remoteManageRules = rules.filter((rule: netFirewall.NetFirewallRule) =>
        (rule.remoteIps?.[0]?.address ?? '') === '1.2.3.4')

      expect(rules.length > 0).assertTrue()
      expect(remoteManageRules.length).assertEqual(2)
      expect(remoteManageRules[0].localPorts?.[0]?.startPort ?? 0).assertEqual(22)
      expect(FirewallRulesService.parseManagedRuleDescription(remoteManageRules[0].description)?.mode).assertEqual('public')
    })

    it('should skip private rules when no cidrs are provided', 0, () => {
      let rules = FirewallModeRuleBuilder.buildPrivateRules([], [22], [53])

      expect(rules.length).assertEqual(0)
    })

    it('should build private rules for tcp and udp ports', 0, () => {
      let rules = FirewallModeRuleBuilder.buildPrivateRules(
        ['10.0.0.0/24', '192.168.0.0/24'],
        [8080],
        [5353]
      )
      let tcpRule = rules.find((rule: netFirewall.NetFirewallRule) => (rule.localPorts?.[0]?.startPort ?? 0) === 8080)
      let udpRule = rules.find((rule: netFirewall.NetFirewallRule) => (rule.localPorts?.[0]?.startPort ?? 0) === 5353)

      expect(rules.length > 0).assertTrue()
      expect(tcpRule !== undefined).assertTrue()
      expect(udpRule !== undefined).assertTrue()
      expect((tcpRule?.remoteIps?.length ?? 0) > 0).assertTrue()
      expect(FirewallRulesService.parseManagedRuleDescription(tcpRule?.description)?.kind).assertEqual('preset')
    })

    it('should ignore invalid private cidr values', 0, () => {
      let rules = FirewallModeRuleBuilder.buildPrivateRules(['bad-cidr', '10.0.0.0/24'], [], [])

      expect(rules.length > 0).assertTrue()
      expect(rules.every((rule: netFirewall.NetFirewallRule) => (rule.remoteIps?.[0]?.address ?? '').length > 0)).assertTrue()
    })
  })
}
