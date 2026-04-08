import { describe, expect, it } from '@ohos/hypium'
import { CommonLabelStrings, FirewallDialogStrings, FirewallRuleLabelStrings, ResultStrings } from '../../main/ets/constants/modules/DialogStrings'
import {
  ProtocolType,
  RuleAction,
  RuleDirection,
  RuleType,
  getActionLabel,
  getDirectionLabel,
  getProtocolLabel,
  getRuleTypeLabel
} from '../../main/ets/models/DataModels'

export default function firewallModelsTest() {
  describe('Firewall Models', () => {
    it('should map rule types to current shared labels', 0, () => {
      expect(getRuleTypeLabel(RuleType.IP)).assertEqual(FirewallRuleLabelStrings.IP_RULE)
      expect(getRuleTypeLabel(RuleType.DOMAIN)).assertEqual(FirewallRuleLabelStrings.DOMAIN_RULE)
      expect(getRuleTypeLabel(RuleType.DNS)).assertEqual(FirewallRuleLabelStrings.DNS_RULE)
      expect(getRuleTypeLabel(99 as RuleType)).assertEqual(CommonLabelStrings.UNKNOWN)
    })

    it('should map directions to current dialog labels', 0, () => {
      expect(getDirectionLabel(RuleDirection.IN)).assertEqual(FirewallDialogStrings.DIRECTION_INBOUND)
      expect(getDirectionLabel(RuleDirection.OUT)).assertEqual(FirewallDialogStrings.DIRECTION_OUTBOUND)
      expect(getDirectionLabel(99 as RuleDirection)).assertEqual(CommonLabelStrings.UNKNOWN)
    })

    it('should map protocol values to current labels', 0, () => {
      expect(getProtocolLabel(ProtocolType.ALL)).assertEqual(CommonLabelStrings.ALL)
      expect(getProtocolLabel(ProtocolType.TCP)).assertEqual('TCP')
      expect(getProtocolLabel(ProtocolType.UDP)).assertEqual('UDP')
      expect(getProtocolLabel(ProtocolType.ICMP)).assertEqual('ICMP')
      expect(getProtocolLabel(99 as ProtocolType)).assertEqual(CommonLabelStrings.ALL)
    })

    it('should map actions to current labels', 0, () => {
      expect(getActionLabel(RuleAction.ALLOW)).assertEqual(FirewallDialogStrings.ACTION_ALLOW)
      expect(getActionLabel(RuleAction.DENY)).assertEqual('拒绝')
      expect(ResultStrings.FAILED).assertEqual('失败')
      expect(getActionLabel(99 as RuleAction)).assertEqual(CommonLabelStrings.UNKNOWN)
    })
  })
}
