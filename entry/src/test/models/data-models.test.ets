import { describe, it, expect } from '@ohos/hypium'
import {
  AuthMethod,
  DEFAULT_TOOL_SETTINGS,
  PeripheralType,
  UsbStoragePolicy,
  formatBluetoothDeviceId,
  formatUsbDeviceId,
  getPeripheralRecordActionLabel,
  getPeripheralRecordSourceLabel,
  getUsbStoragePolicyLabel,
  inferPeripheralTypeFromBaseClass,
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

    it('should keep current action and source labels populated', 0, () => {
      expect(getPeripheralRecordActionLabel('discover').length > 0).assertTrue()
      expect(getPeripheralRecordActionLabel('intercept').length > 0).assertTrue()
      expect(getPeripheralRecordSourceLabel('runtime_event').length > 0).assertTrue()
      expect(getPeripheralRecordSourceLabel('audit_event').length > 0).assertTrue()
      expect(getPeripheralRecordSourceLabel('policy_snapshot').length > 0).assertTrue()
    })

    it('should keep usb policy labels populated', 0, () => {
      expect(getUsbStoragePolicyLabel(UsbStoragePolicy.READ_WRITE).length > 0).assertTrue()
      expect(getUsbStoragePolicyLabel(UsbStoragePolicy.READ_ONLY).length > 0).assertTrue()
      expect(getUsbStoragePolicyLabel(UsbStoragePolicy.DISABLED).length > 0).assertTrue()
    })

    it('should expose the current default tool settings contract', 0, () => {
      expect(DEFAULT_TOOL_SETTINGS.startupAuthEnabled).assertFalse()
      expect(DEFAULT_TOOL_SETTINGS.authMethod).assertEqual(AuthMethod.PIN)
    })
  })
}
