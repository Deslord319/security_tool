import { describe, expect, it } from '@ohos/hypium'
import {
  LoadingStrings
} from '../../main/ets/constants/modules/DialogStrings'
import { IdentityAuthStrings } from '../../main/ets/constants/modules/IdentityStrings'
import {
  buildFirewallConflictNotice,
  FirewallDialogStrings,
  FirewallRuleLabelStrings
} from '../../main/ets/constants/modules/FirewallStrings'
import { DeviceDetailStrings, DeviceTypeLabels } from '../../main/ets/constants/modules/PeripheralStrings'
import { ActionText, LabelText, MessageText, ResultText } from '../../main/ets/constants/StringCatalog'

export default function dialogStringsTest() {
  describe('DialogStrings', () => {
    it('should expose shared button, loading and empty-state copy', 0, () => {
      expect(ActionText.CONFIRM.length > 0).assertTrue()
      expect(ActionText.CANCEL.length > 0).assertTrue()
      expect(LoadingStrings.LOADING.length > 0).assertTrue()
      expect(MessageText.CHECK_PERMISSIONS.length > 0).assertTrue()
      expect(ResultText.SUCCESS.length > 0).assertTrue()
    })

    it('should expose firewall dialog labels and builders', 0, () => {
      expect(FirewallDialogStrings.RULE_NAME_PLACEHOLDER.length > 0).assertTrue()
      expect(FirewallDialogStrings.MODE_ALLOWLIST.length > 0).assertTrue()
      expect(buildFirewallConflictNotice(1, 1, 1).length > 0).assertTrue()
      expect(FirewallDialogStrings.APPLY_MODE_SUCCESS.length > 0).assertTrue()
    })

    it('should expose device detail and shared label strings', 0, () => {
      expect(DeviceDetailStrings.TITLE.length > 0).assertTrue()
      expect(DeviceDetailStrings.HISTORY_COUNT_SUFFIX.length > 0).assertTrue()
      expect(DeviceTypeLabels.BLUETOOTH.length > 0).assertTrue()
      expect(LabelText.ALL.length > 0).assertTrue()
      expect(FirewallRuleLabelStrings.DOMAIN_RULE.length > 0).assertTrue()
    })

    it('should expose validation and auth copy used by pages', 0, () => {
      expect(IdentityAuthStrings.PERMISSION_DENIED.length > 0).assertTrue()
      expect(IdentityAuthStrings.INVALID_PARAMS.length > 0).assertTrue()
      expect(IdentityAuthStrings.FAILED_OR_CANCELED.length > 0).assertTrue()
    })
  })
}
