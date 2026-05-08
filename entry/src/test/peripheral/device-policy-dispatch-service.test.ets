import restrictions from '@ohos.enterprise.restrictions'
import { usbManager } from '@kit.MDMKit'
import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { PeripheralType } from '../../main/ets/models/DataModels'
import { PeripheralDevicePolicyDispatchService } from '../../main/ets/services/peripheral/device-policy/peripheral_device_policy_dispatch_service'

export default function peripheralDevicePolicyDispatchServiceTest() {
  describe('PeripheralDevicePolicyDispatchService', () => {
    let mockKit: MockKit
    let usbDenyDispatchCount: number
    let usbStoragePolicyMock: Function

    beforeEach(() => {
      mockKit = new MockKit()
      usbDenyDispatchCount = 0
      let usbDisabledMock = mockKit.mockFunc(restrictions, restrictions.getDisallowedPolicy)
      usbStoragePolicyMock = mockKit.mockFunc(usbManager, usbManager.getUsbStorageDeviceAccessPolicy)
      let addDisallowedUsbMock = mockKit.mockFunc(usbManager, usbManager.addDisallowedUsbDevices)
      when(usbDisabledMock)(ArgumentMatchers.any, 'usb').afterReturn(false)
      when(usbStoragePolicyMock)(ArgumentMatchers.any).afterReturn(usbManager.UsbPolicy.READ_WRITE)
      when(addDisallowedUsbMock)(ArgumentMatchers.any, ArgumentMatchers.any).afterAction(() => {
        usbDenyDispatchCount += 1
      })
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should reject unsupported policy before touching system managers', 0, async () => {
      const result = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: 'VID:1234 PID:5678',
        deviceType: PeripheralType.USB_STORAGE,
        policy: 'noop' as 'allow' | 'deny'
      })

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('unsupported_policy')
      expect(result.stage).assertEqual('device_policy_dispatch')
    })

    it('should reject unsupported device type before dispatch', 0, async () => {
      const result = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: 'SERIAL:1234',
        deviceType: 'serial' as PeripheralType,
        policy: 'allow'
      })

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('unsupported_device_type')
      expect(result.stage).assertEqual('device_policy_dispatch')
    })

    it('should reject usb storage deny when usb storage account policy is disabled', 0, async () => {
      when(usbStoragePolicyMock)(ArgumentMatchers.any).afterReturn(usbManager.UsbPolicy.DISABLED)

      const result = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: 'VID:1234 PID:5678',
        deviceType: PeripheralType.USB_STORAGE,
        policy: 'deny'
      })

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('usb_conflict_account_storage')
      expect(result.stage).assertEqual('device_policy_dispatch')
      expect(usbDenyDispatchCount).assertEqual(0)
    })
  })
}
