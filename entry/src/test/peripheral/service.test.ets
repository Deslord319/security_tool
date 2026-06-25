import { afterEach, describe, expect, it } from '@ohos/hypium'
import { MockKit, when } from '@ohos/hamock'
import { PeripheralService } from '../../main/ets/services/peripheral/interface-control/PeripheralService'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/peripheral/device-policy/PeripheralDevicePolicyRepository'

export default function peripheralServiceTest() {
  describe('PeripheralService', () => {
    let mockKit: MockKit = new MockKit()

    afterEach(() => {
      mockKit.clearAll()
      mockKit = new MockKit()
    })

    it('should expose the expected interface feature constants', 0, () => {
      expect(PeripheralService.FEATURE_USB).assertEqual('usb')
      expect(PeripheralService.FEATURE_BLUETOOTH).assertEqual('bluetooth')
      expect(PeripheralService.FEATURE_WIFI).assertEqual('wifi')
      expect(PeripheralService.FEATURE_HDC).assertEqual('hdc')
    })

    it('should read usb interface state from local default policy', 0, () => {
      let isUsbDefaultDenyMock = mockKit.mockFunc(
        PeripheralDevicePolicyRepository,
        PeripheralDevicePolicyRepository.isUsbDefaultDeny
      )
      when(isUsbDefaultDenyMock)().afterReturn(true)

      const result = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_USB)

      expect(result.success).assertTrue()
      expect(result.data).assertTrue()
    })

    it('should no-op enabled power restore for non wireless interfaces', 0, () => {
      const result = PeripheralService.restoreEnabledInterfacePowerWithResult(PeripheralService.FEATURE_HDC)

      expect(result.success).assertTrue()
    })
  })
}
