import { describe, expect, it } from '@ohos/hypium'
import { netFirewall } from '@kit.NetworkKit'
import { LabelText, ResultText } from '../../main/ets/constants/StringCatalog'
import {
  buildFirewallUserLabel,
  FirewallDialogStrings,
  FirewallRuleLabelStrings
} from '../../main/ets/constants/modules/FirewallStrings'
import {
  resolveFirewallUserPolicyModeFromActions
} from '../../main/ets/models/firewall/FirewallModels'

export default function firewallModelsTest() {
  describe('Firewall Models', () => {
    it('should verify system rule type constants', 0, () => {
      expect(netFirewall.NetFirewallRuleType.RULE_IP).assertEqual(1)
      expect(netFirewall.NetFirewallRuleType.RULE_DOMAIN).assertEqual(2)
      expect(netFirewall.NetFirewallRuleType.RULE_DNS).assertEqual(3)
    })

    it('should verify system rule direction constants', 0, () => {
      expect(netFirewall.NetFirewallRuleDirection.RULE_IN).assertEqual(1)
      expect(netFirewall.NetFirewallRuleDirection.RULE_OUT).assertEqual(2)
    })

    it('should verify system rule action constants', 0, () => {
      expect(netFirewall.FirewallRuleAction.RULE_ALLOW).assertEqual(0)
      expect(netFirewall.FirewallRuleAction.RULE_DENY).assertEqual(1)
    })

    it('should verify firewall strings are defined', 0, () => {
      expect(FirewallRuleLabelStrings.IP_RULE.length > 0).assertTrue()
      expect(FirewallRuleLabelStrings.DOMAIN_RULE.length > 0).assertTrue()
      expect(FirewallRuleLabelStrings.DNS_RULE.length > 0).assertTrue()
      expect(FirewallDialogStrings.DIRECTION_INBOUND.length > 0).assertTrue()
      expect(FirewallDialogStrings.DIRECTION_OUTBOUND.length > 0).assertTrue()
      expect(FirewallDialogStrings.ACTION_ALLOW.length > 0).assertTrue()
      expect(FirewallDialogStrings.ACTION_DENY.length > 0).assertTrue()
      expect(LabelText.UNKNOWN.length > 0).assertTrue()
      expect(ResultText.FAILED).assertEqual('失败')
      expect(buildFirewallUserLabel(100, true, '张三')).assertEqual('张三（当前）')
      expect(buildFirewallUserLabel(101, false, '李四')).assertEqual('李四')
      expect(buildFirewallUserLabel(102, false, '')).assertEqual('用户 102')
    })

    it('should infer user policy mode from default actions', 0, () => {
      expect(resolveFirewallUserPolicyModeFromActions(
        netFirewall.FirewallRuleAction.RULE_DENY,
        netFirewall.FirewallRuleAction.RULE_DENY
      )).assertEqual('allowlist')
      expect(resolveFirewallUserPolicyModeFromActions(
        netFirewall.FirewallRuleAction.RULE_ALLOW,
        netFirewall.FirewallRuleAction.RULE_ALLOW
      )).assertEqual('denylist')
      expect(resolveFirewallUserPolicyModeFromActions(
        netFirewall.FirewallRuleAction.RULE_DENY,
        netFirewall.FirewallRuleAction.RULE_ALLOW
      )).assertEqual(undefined)
    })

  })
}
