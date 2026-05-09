import { describe, expect, it } from '@ohos/hypium'
import {
  buildFirewallConflictNotice,
  buildFirewallToggleFailedMessage,
  FirewallDialogStrings,
  FirewallPageStrings,
  FirewallRuleStrings,
  getFirewallModeDescription,
  getFirewallModeTitle
} from '../../main/ets/constants/modules/FirewallStrings'

export default function firewallStringsTest() {
  describe('FirewallStrings', () => {
    it('should keep current page copy populated and scoped to custom rules', 0, () => {
      expect(FirewallPageStrings.SUBTITLE.length > 0).assertTrue()
      expect(FirewallRuleStrings.CUSTOM_RULES_SUBTITLE.length > 0).assertTrue()
    })

    it('should expose preset mode titles and descriptions for each scenario', 0, () => {
      expect(getFirewallModeTitle('public').length > 0).assertTrue()
      expect(getFirewallModeTitle('private').length > 0).assertTrue()
      expect(getFirewallModeTitle('custom')).assertEqual(FirewallRuleStrings.CUSTOM_MODE_TITLE)
      expect(getFirewallModeDescription('public').length > 0).assertTrue()
      expect(getFirewallModeDescription('private').length > 0).assertTrue()
      expect(getFirewallModeDescription('custom').length > 0).assertTrue()
    })

    it('should build conflict summaries with concrete counts', 0, () => {
      expect(buildFirewallConflictNotice(0, 0, 0)).assertEqual('')
      expect(buildFirewallConflictNotice(1, 0, 0).length > 0).assertTrue()
      expect(buildFirewallConflictNotice(1, 2, 3).length > 0).assertTrue()
    })

    it('should map toggle rejection reasons to actionable copy', 0, () => {
      expect(buildFirewallToggleFailedMessage('lockout', 30).length > 0).assertTrue()
      expect(buildFirewallToggleFailedMessage('pin_unavailable', undefined).length > 0).assertTrue()
      expect(buildFirewallToggleFailedMessage('no_available_users', undefined).length > 0).assertTrue()
      expect(buildFirewallToggleFailedMessage('policy_apply_failed', undefined).length > 0).assertTrue()
      expect(buildFirewallToggleFailedMessage(undefined, undefined).length > 0).assertTrue()
    })

    it('should expose updated firewall dialog placeholders and validation copy for ip rules', 0, () => {
      expect(FirewallDialogStrings.LOCAL_ADDRESS).assertEqual('本地地址')
      expect(FirewallDialogStrings.IP_PLACEHOLDER.includes('110.110.110.1-110.110.110.254')).assertTrue()
      expect(FirewallDialogStrings.PORT_PLACEHOLDER).assertEqual('例如 80,443,1000-2000')
      expect(FirewallDialogStrings.ERROR_INVALID_IP_RANGE.length > 0).assertTrue()
      expect(FirewallDialogStrings.ERROR_INVALID_PORT_RANGE.length > 0).assertTrue()
      expect(FirewallDialogStrings.ERROR_PORT_ITEM_LIMIT.length > 0).assertTrue()
    })
  })
}
