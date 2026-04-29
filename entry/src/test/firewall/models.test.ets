import { describe, expect, it } from '@ohos/hypium'
import { netFirewall } from '@kit.NetworkKit'
import { LabelText, ResultText } from '../../main/ets/constants/StringCatalog'
import {
  FirewallDialogStrings,
  FirewallRuleLabelStrings
} from '../../main/ets/constants/modules/FirewallStrings'

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
    })
  })
}