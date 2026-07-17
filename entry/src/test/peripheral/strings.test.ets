import { describe, expect, it } from '@ohos/hypium'
import {
  PeripheralExportStrings,
  PeripheralOptionStrings,
  PeripheralPageStrings,
  PeripheralReasonCodes,
  resolvePeripheralReason
} from '../../main/ets/constants/modules/PeripheralStrings'
import { MessageText } from '../../main/ets/constants/StringCatalog'

export default function peripheralStringsTest() {
  describe('PeripheralStrings', () => {
    it('should keep commercial page copy and tab labels stable', 0, () => {
      expect(PeripheralPageStrings.SUBTITLE.length > 0).assertTrue()
      expect(PeripheralPageStrings.INTERFACE_TAB.length > 0).assertTrue()
      expect(PeripheralPageStrings.DEVICE_TAB.length > 0).assertTrue()
      expect(PeripheralPageStrings.POLICY_TAB.length > 0).assertTrue()
    })

    it('should expose stable operator labels for toolbar actions', 0, () => {
      expect(PeripheralExportStrings.HISTORY_LABEL.length > 0).assertTrue()
      expect(PeripheralExportStrings.CLEAR_HISTORY_LABEL.length > 0).assertTrue()
      expect(PeripheralExportStrings.EXPORT_POLICY_LABEL.length > 0).assertTrue()
      expect(PeripheralExportStrings.CLEAR_POLICY_LABEL.length > 0).assertTrue()
    })

    it('should map common failure reasons to actionable messages', 0, () => {
      expect(resolvePeripheralReason(PeripheralReasonCodes.ADMIN_REQUIRED).length > 0).assertTrue()
      expect(resolvePeripheralReason(PeripheralReasonCodes.TOGGLE_INTERFACE_FAILED).length > 0).assertTrue()
      expect(resolvePeripheralReason(PeripheralReasonCodes.SET_USB_INTERFACE_CONFLICT).length > 0).assertTrue()
      expect(resolvePeripheralReason(PeripheralReasonCodes.USB_CONFLICT_ACCOUNT_STORAGE))
        .assertEqual('USB 存储当前已禁止访问，请先将 USB 存储访问模式设置为只读或读写')
      expect(resolvePeripheralReason(PeripheralReasonCodes.SET_USB_STORAGE_POLICY_CONFLICT))
        .assertEqual('USB 接口当前已开启，但设备黑白名单限制与 USB 存储访问模式冲突，请先还原黑白名单策略后再设置')
      expect(resolvePeripheralReason('custom error')).assertEqual('custom error')
      expect(resolvePeripheralReason('')).assertEqual(MessageText.RETRY_LATER)
    })

    it('should keep policy option order stable for the UI layer', 0, () => {
      expect(PeripheralOptionStrings.POLICY_OPTIONS.length).assertEqual(2)
      expect(PeripheralOptionStrings.INTERFACE_TOGGLE_OPTIONS.length).assertEqual(2)
    })
  })
}
