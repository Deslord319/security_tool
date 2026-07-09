import { describe, expect, it } from '@ohos/hypium'
import { UsbDeviceIdentityResolver } from '../../main/ets/services/peripheral/device-policy/UsbDeviceIdentityResolver'

export default function usbDeviceIdentityResolverTest() {
  describe('UsbDeviceIdentityResolver', () => {
    it('should prefer serial number as strong fingerprint', 0, () => {
      const identity = UsbDeviceIdentityResolver.resolve({
        vendorId: 0x1234,
        productId: 0x5678,
        baseClass: 0x08,
        deviceName: 'USB Disk',
        serialNumber: ' sn-001 ',
        description: 'Disk Description'
      })

      expect(identity?.fingerprintType).assertEqual('serial')
      expect(identity?.fingerprintKey).assertEqual('USB-SN:SN-001')
      expect(identity?.serialNumber).assertEqual('SN-001')
    })

    it('should build weak fingerprint from VID PID and description when serial is missing', 0, () => {
      const first = UsbDeviceIdentityResolver.resolve({
        vendorId: 0x1234,
        productId: 0x5678,
        baseClass: 0x08,
        deviceName: 'USB Disk',
        description: 'Disk Description'
      })
      const second = UsbDeviceIdentityResolver.resolve({
        vendorId: 0x1234,
        productId: 0x5678,
        baseClass: 0x08,
        deviceName: 'USB Disk',
        description: 'Disk Description'
      })

      expect(first?.fingerprintType).assertEqual('weak')
      expect(first?.fingerprintKey).assertEqual(second?.fingerprintKey)
      expect(first?.fingerprintKey.startsWith('USB-WEAK:1234:5678:')).assertTrue()
    })

    it('should reject invalid VID PID input', 0, () => {
      const identity = UsbDeviceIdentityResolver.resolve({
        vendorId: Number.NaN,
        productId: 0x5678,
        baseClass: 0x08,
        deviceName: 'USB Disk',
        description: 'Disk Description'
      })

      expect(identity).assertNull()
    })
  })
}

