import { afterEach, describe, expect, it } from '@ohos/hypium'
import { MockKit, when } from '@ohos/hamock'
import { PeripheralInterfaceFeatures } from '../../main/ets/models/PeripheralModels'
import { PeripheralService } from '../../main/ets/services/peripheral/interface-control/PeripheralService'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/peripheral/device-policy/PeripheralDevicePolicyRepository'

export default function peripheralServiceTest() {
  describe('PeripheralService', () => {
    let mockKit: MockKit = new MockKit()

    afterEach(() => {
      mockKit.clearAll()
      mockKit = new MockKit()
    })

    it('should expose the expected interface feature constants from the model layer', 0, () => {
      expect(PeripheralInterfaceFeatures.USB).assertEqual('usb')
      expect(PeripheralInterfaceFeatures.BLUETOOTH).assertEqual('bluetooth')
      expect(PeripheralInterfaceFeatures.WIFI).assertEqual('wifi')
      expect(PeripheralInterfaceFeatures.HDC).assertEqual('hdc')
    })

    it('should map network sharing to the tethering restriction feature', 0, () => {
      expect(PeripheralInterfaceFeatures.NETWORK).assertEqual('tethering')
    })

    it('should read usb interface state from local default policy', 0, () => {
      let isUsbDefaultDenyMock = mockKit.mockFunc(
        PeripheralDevicePolicyRepository,
        PeripheralDevicePolicyRepository.isUsbDefaultDeny
      )
      when(isUsbDefaultDenyMock)().afterReturn(true)

      const result = PeripheralService.getInterfaceDisabledWithResult(PeripheralInterfaceFeatures.USB)

      expect(result.success).assertTrue()
      expect(result.data).assertTrue()
    })

    it('should no-op enabled power restore for non wireless interfaces', 0, () => {
      const result = PeripheralService.restoreEnabledInterfacePowerWithResult(PeripheralInterfaceFeatures.HDC)

      expect(result.success).assertTrue()
    })
  })
}
