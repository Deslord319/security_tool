/**
 * 外设模块 - 数据模型单元测试
 * 测试外设管理相关的标签函数、设备ID解析和BaseClass映射
 */
import { describe, it, expect } from '@ohos/hypium'
import {
  PeripheralType, UsbStoragePolicy,
  getPeripheralTypeLabel, getUsbStoragePolicyLabel,
  parseUsbDeviceId, formatUsbDeviceId, formatBluetoothDeviceId,
  inferPeripheralTypeFromBaseClass
} from '../../main/ets/models/DataModels'

export default function peripheralModelsTest() {
  describe('Peripheral Models', () => {

    // ==================== 外设管理标签函数测试 ====================

    describe('getPeripheralTypeLabel', () => {
      it('should return USB 存储设备 for USB_STORAGE', 0, () => {
        expect(getPeripheralTypeLabel(PeripheralType.USB_STORAGE)).assertEqual('USB 存储设备')
      })

      it('should return USB 摄像头 for USB_CAMERA', 0, () => {
        expect(getPeripheralTypeLabel(PeripheralType.USB_CAMERA)).assertEqual('USB 摄像头')
      })

      it('should return USB 打印机 for USB_PRINTER', 0, () => {
        expect(getPeripheralTypeLabel(PeripheralType.USB_PRINTER)).assertEqual('USB 打印机')
      })

      it('should return USB 其他 for USB_OTHER', 0, () => {
        expect(getPeripheralTypeLabel(PeripheralType.USB_OTHER)).assertEqual('USB 其他')
      })

      it('should return 蓝牙设备 for BLUETOOTH', 0, () => {
        expect(getPeripheralTypeLabel(PeripheralType.BLUETOOTH)).assertEqual('蓝牙设备')
      })

      it('should return 未知 for invalid type', 0, () => {
        expect(getPeripheralTypeLabel('invalid' as PeripheralType)).assertEqual('未知')
      })
    })

    describe('getUsbStoragePolicyLabel', () => {
      it('should return 读写 for READ_WRITE', 0, () => {
        expect(getUsbStoragePolicyLabel(UsbStoragePolicy.READ_WRITE)).assertEqual('读写')
      })

      it('should return 只读 for READ_ONLY', 0, () => {
        expect(getUsbStoragePolicyLabel(UsbStoragePolicy.READ_ONLY)).assertEqual('只读')
      })

      it('should return 禁止访问 for DISABLED', 0, () => {
        expect(getUsbStoragePolicyLabel(UsbStoragePolicy.DISABLED)).assertEqual('禁止访问')
      })

      it('should return 未知 for invalid policy', 0, () => {
        expect(getUsbStoragePolicyLabel(99 as UsbStoragePolicy)).assertEqual('未知')
      })
    })

    // ==================== USB 设备 ID 解析测试 ====================

    describe('parseUsbDeviceId', () => {
      it('should parse valid USB device ID with uppercase', 0, () => {
        let result = parseUsbDeviceId('VID:2B7E PID:B5A2')
        expect(result).not().assertNull()
        expect(result!.vendorId).assertEqual(0x2B7E)
        expect(result!.productId).assertEqual(0xB5A2)
      })

      it('should parse valid USB device ID with lowercase', 0, () => {
        let result = parseUsbDeviceId('VID:abcd PID:1234')
        expect(result).not().assertNull()
        expect(result!.vendorId).assertEqual(0xABCD)
        expect(result!.productId).assertEqual(0x1234)
      })

      it('should parse USB device ID with extra whitespace', 0, () => {
        let result = parseUsbDeviceId('VID:0001   PID:0002')
        expect(result).not().assertNull()
        expect(result!.vendorId).assertEqual(1)
        expect(result!.productId).assertEqual(2)
      })

      it('should return null for invalid format', 0, () => {
        expect(parseUsbDeviceId('invalid')).assertNull()
      })

      it('should return null for empty string', 0, () => {
        expect(parseUsbDeviceId('')).assertNull()
      })

      it('should return null for partial format', 0, () => {
        expect(parseUsbDeviceId('VID:1234')).assertNull()
      })
    })

    describe('formatUsbDeviceId', () => {
      it('should format with uppercase and padding', 0, () => {
        let result = formatUsbDeviceId(0x2B7E, 0xB5A2)
        expect(result).assertEqual('VID:2B7E PID:B5A2')
      })

      it('should pad small numbers with zeros', 0, () => {
        let result = formatUsbDeviceId(1, 2)
        expect(result).assertEqual('VID:0001 PID:0002')
      })

      it('should handle zero values', 0, () => {
        let result = formatUsbDeviceId(0, 0)
        expect(result).assertEqual('VID:0000 PID:0000')
      })

      it('should handle max values', 0, () => {
        let result = formatUsbDeviceId(0xFFFF, 0xFFFF)
        expect(result).assertEqual('VID:FFFF PID:FFFF')
      })
    })

    // ==================== 蓝牙 MAC 解析测试 ====================

    describe('formatBluetoothDeviceId', () => {
      it('should normalize valid MAC address with space', 0, () => {
        let result = formatBluetoothDeviceId('AA:BB:CC:DD:EE:01')
        expect(result).assertEqual('MAC: AA:BB:CC:DD:EE:01')
      })

      it('should normalize valid MAC address without space', 0, () => {
        let result = formatBluetoothDeviceId('11:22:33:44:55:66')
        expect(result).assertEqual('MAC: 11:22:33:44:55:66')
      })

      it('should normalize dashed bluetooth ids', 0, () => {
        let result = formatBluetoothDeviceId('aa-bb-cc-dd-ee-ff')
        expect(result).assertEqual('MAC: AA:BB:CC:DD:EE:FF')
      })
    })

    describe('inferPeripheralTypeFromBaseClass', () => {
      it('should return USB_STORAGE for 0x08', 0, () => {
        expect(inferPeripheralTypeFromBaseClass(0x08)).assertEqual(PeripheralType.USB_STORAGE)
      })

      it('should return USB_CAMERA for 0x0E', 0, () => {
        expect(inferPeripheralTypeFromBaseClass(0x0E)).assertEqual(PeripheralType.USB_CAMERA)
      })

      it('should return USB_PRINTER for 0x07', 0, () => {
        expect(inferPeripheralTypeFromBaseClass(0x07)).assertEqual(PeripheralType.USB_PRINTER)
      })

      it('should return USB_OTHER for unknown class', 0, () => {
        expect(inferPeripheralTypeFromBaseClass(0xFF)).assertEqual(PeripheralType.USB_OTHER)
      })

      it('should return USB_OTHER for 0', 0, () => {
        expect(inferPeripheralTypeFromBaseClass(0)).assertEqual(PeripheralType.USB_OTHER)
      })
    })

    // ==================== 双向一致性测试 ====================

    describe('USB ID parse-format roundtrip', () => {
      it('should roundtrip correctly for standard ID', 0, () => {
        let original = 'VID:1234 PID:5678'
        let parsed = parseUsbDeviceId(original)
        let formatted = formatUsbDeviceId(parsed!.vendorId, parsed!.productId)
        expect(formatted).assertEqual(original)
      })

      it('should roundtrip correctly for max values', 0, () => {
        let original = 'VID:FFFF PID:FFFF'
        let parsed = parseUsbDeviceId(original)
        let formatted = formatUsbDeviceId(parsed!.vendorId, parsed!.productId)
        expect(formatted).assertEqual(original)
      })
    })

    describe('USB BaseClass mapping table', () => {
      it('should map USB_STORAGE correctly', 0, () => {
        let peripheralType = inferPeripheralTypeFromBaseClass(0x08)
        expect(peripheralType).assertEqual(PeripheralType.USB_STORAGE)
      })

      it('should map USB_CAMERA correctly', 0, () => {
        let peripheralType = inferPeripheralTypeFromBaseClass(0x0E)
        expect(peripheralType).assertEqual(PeripheralType.USB_CAMERA)
      })

      it('should map USB_PRINTER correctly', 0, () => {
        let peripheralType = inferPeripheralTypeFromBaseClass(0x07)
        expect(peripheralType).assertEqual(PeripheralType.USB_PRINTER)
      })
    })

  })
}
