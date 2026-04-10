import { describe, expect, it } from '@ohos/hypium'
import {
  DeviceDetailStrings,
  DeviceTypeLabels,
  FirewallDialogStrings,
  FirewallRuleLabelStrings,
  LoadingStrings,
  ValidationErrorStrings
} from '../../main/ets/constants/modules/DialogStrings'
import { ActionText, LabelText, MessageText, ResultText } from '../../main/ets/constants/StringCatalog'

export default function dialogStringsTest() {
  describe('DialogStrings', () => {
    it('should expose shared button, loading and empty-state copy', 0, () => {
      expect(ActionText.CONFIRM.length > 0).assertTrue()
      expect(ActionText.CANCEL.length > 0).assertTrue()
      expect(LoadingStrings.LOADING_POLICY.length > 0).assertTrue()
      expect(MessageText.CHECK_PERMISSIONS.length > 0).assertTrue()
      expect(ResultText.SAVE_SUCCESS.length > 0).assertTrue()
    })

    it('should expose firewall dialog labels and builders', 0, () => {
      expect(FirewallDialogStrings.RULE_NAME_PLACEHOLDER.length > 0).assertTrue()
      expect(FirewallDialogStrings.MODE_ALLOWLIST.length > 0).assertTrue()
      expect(FirewallDialogStrings.buildPolicySummary(true, 'allow', 'deny').length > 0).assertTrue()
      expect(FirewallDialogStrings.buildApplyModeSuccess(3).length > 0).assertTrue()
    })

    it('should expose device detail and shared label strings', 0, () => {
      expect(DeviceDetailStrings.TITLE.length > 0).assertTrue()
      expect(DeviceDetailStrings.HISTORY_COUNT_SUFFIX.length > 0).assertTrue()
      expect(DeviceTypeLabels.BLUETOOTH.length > 0).assertTrue()
      expect(LabelText.ALL.length > 0).assertTrue()
      expect(FirewallRuleLabelStrings.DOMAIN_RULE.length > 0).assertTrue()
    })

    it('should expose validation copy used by pages', 0, () => {
      expect(ValidationErrorStrings.PIN_FAILED.length > 0).assertTrue()
      expect(ValidationErrorStrings.PERMISSION_DENIED.length > 0).assertTrue()
      expect(ValidationErrorStrings.STATUS_UNKNOWN.length > 0).assertTrue()
    })
  })
}
