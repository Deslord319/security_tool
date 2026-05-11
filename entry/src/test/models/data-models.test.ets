import { describe, it, expect } from '@ohos/hypium'
import {
  AuthMethod,
  DEFAULT_TOOL_SETTINGS,
  PeripheralType,
  formatBluetoothDeviceId,
  formatUsbDeviceId,
  getUsbPeripheralBaseClass,
  inferPeripheralTypeFromBaseClass,
  isUsbPeripheralType,
  parseUsbDeviceId
} from '../../main/ets/models/DataModels'

export default function dataModelsTest() {
  describe('DataModels', () => {
    it('should parse and format USB ids with stable uppercase formatting', 0, () => {
      let parsed = parseUsbDeviceId('VID:1a2b PID:00ff')
      expect(!!parsed).assertTrue()
      expect(parsed!.vendorId).assertEqual(0x1A2B)
      expect(parsed!.productId).assertEqual(0x00FF)
      expect(formatUsbDeviceId(parsed!.vendorId, parsed!.productId)).assertEqual('VID:1A2B PID:00FF')
    })

    it('should return null for malformed USB ids', 0, () => {
      let parsed = parseUsbDeviceId('invalid-device-id')
      expect(parsed === null).assertTrue()
    })

    it('should normalize bluetooth ids with MAC prefix and uppercase separators', 0, () => {
      expect(formatBluetoothDeviceId('aa-bb-cc-dd-ee-ff')).assertEqual('MAC: AA:BB:CC:DD:EE:FF')
    })

    it('should map hardware base classes into final peripheral categories', 0, () => {
      expect(inferPeripheralTypeFromBaseClass(0x08)).assertEqual(PeripheralType.USB_STORAGE)
      expect(inferPeripheralTypeFromBaseClass(0x0E)).assertEqual(PeripheralType.USB_CAMERA)
      expect(inferPeripheralTypeFromBaseClass(0x07)).assertEqual(PeripheralType.USB_PRINTER)
      expect(inferPeripheralTypeFromBaseClass(0x03)).assertEqual(PeripheralType.USB_HID)
      expect(inferPeripheralTypeFromBaseClass(0xFF)).assertEqual(PeripheralType.USB_OTHER)
    })

    it('should expose one USB peripheral mapping contract', 0, () => {
      expect(isUsbPeripheralType(PeripheralType.USB_STORAGE)).assertTrue()
      expect(isUsbPeripheralType(PeripheralType.USB_OTHER)).assertTrue()
      expect(isUsbPeripheralType(PeripheralType.BLUETOOTH)).assertFalse()
      expect(getUsbPeripheralBaseClass(PeripheralType.USB_CAMERA)).assertEqual(0x0E)
      expect(getUsbPeripheralBaseClass(PeripheralType.USB_OTHER) === null).assertTrue()
    })

    it('should expose the current default tool settings contract', 0, () => {
      expect(DEFAULT_TOOL_SETTINGS.startupAuthEnabled).assertFalse()
      expect(DEFAULT_TOOL_SETTINGS.authMethod).assertEqual(AuthMethod.PIN)
    })
  })
}
