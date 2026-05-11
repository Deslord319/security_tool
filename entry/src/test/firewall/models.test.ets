import { describe, expect, it } from '@ohos/hypium'
import { netFirewall } from '@kit.NetworkKit'
import { LabelText, ResultText } from '../../main/ets/constants/StringCatalog'
import {
  FirewallDialogStrings,
  FirewallRuleLabelStrings
} from '../../main/ets/constants/modules/FirewallStrings'
import {
  FirewallDefaultPolicyDisplayItem,
  resolveFirewallUserPolicyModeFromActions
} from '../../main/ets/services/firewall/FirewallModels'
import {
  buildFirewallDefaultPolicyEmptyHint
} from '../../main/ets/viewmodels/firewall/rules/FirewallRulesViewModel'

function buildDefaultPolicyItem(
  userId: number,
  mode: 'allowlist' | 'denylist' | 'custom' | 'unknown',
  inAction: number,
  outAction: number
): FirewallDefaultPolicyDisplayItem {
  return {
    userId: userId,
    label: `用户 ${userId}`,
    mode: mode,
    isOpen: true,
    inAction: inAction,
    outAction: outAction
  }
}

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

    it('should derive empty rule hint from multi-user default policy visibility', 0, () => {
      const items: FirewallDefaultPolicyDisplayItem[] = [
        buildDefaultPolicyItem(100, 'allowlist', netFirewall.FirewallRuleAction.RULE_DENY, netFirewall.FirewallRuleAction.RULE_DENY),
        buildDefaultPolicyItem(101, 'denylist', netFirewall.FirewallRuleAction.RULE_ALLOW, netFirewall.FirewallRuleAction.RULE_ALLOW),
        buildDefaultPolicyItem(102, 'custom', netFirewall.FirewallRuleAction.RULE_DENY, netFirewall.FirewallRuleAction.RULE_ALLOW),
        buildDefaultPolicyItem(103, 'unknown', netFirewall.FirewallRuleAction.RULE_ALLOW, netFirewall.FirewallRuleAction.RULE_ALLOW)
      ]

      expect(buildFirewallDefaultPolicyEmptyHint(items)).assertEqual('暂无自定义规则；当前存在默认阻止用户，请新增允许规则放行业务访问。')
    })
  })
}
