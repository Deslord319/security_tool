import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { usbManager } from '@kit.BasicServicesKit'
import { SecurityEventResult } from '../../main/ets/models/CommonModels'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import {
  PeripheralDevicePolicySnapshotRequest,
  PeripheralTraceRecord,
  PeripheralType,
  UsbStoragePolicy
} from '../../main/ets/models/PeripheralModels'
import { PeripheralTraceMaintenanceService } from '../../main/ets/services/peripheral/connection-record/PeripheralTraceMaintenanceService'
import { PeripheralTraceMutationResult } from '../../main/ets/services/peripheral/connection-record/PeripheralTraceMaintenanceService'
import {
  PeripheralPolicySnapshotTraceService,
  UsbDeviceSnapshotProvider
} from '../../main/ets/services/peripheral/connection-record/PeripheralPolicySnapshotTraceService'

class FakeUsbDeviceSnapshotProvider implements UsbDeviceSnapshotProvider {
  private readonly devices: usbManager.USBDevice[]

  constructor(devices: usbManager.USBDevice[]) {
    this.devices = devices
  }

  getDevices(): usbManager.USBDevice[] {
    return this.devices
  }
}

function usbDevice(
  vendorId: number,
  productId: number,
  manufacturerName: string,
  productName: string,
  name: string,
  clazz: number
): usbManager.USBDevice {
  return {
    vendorId: vendorId,
    productId: productId,
    manufacturerName: manufacturerName,
    productName: productName,
    name: name,
    clazz: clazz,
    subClass: 0,
    protocol: 0
  } as usbManager.USBDevice
}

function usbDeviceWithInterfaceClass(
  vendorId: number,
  productId: number,
  clazz: number,
  interfaceClass: number
): usbManager.USBDevice {
  return {
    vendorId: vendorId,
    productId: productId,
    manufacturerName: 'Acme',
    productName: 'Composite Device',
    name: 'usb-composite',
    clazz: clazz,
    subClass: 0,
    protocol: 0,
    configs: [{
      id: 1,
      attributes: 0,
      maxPower: 0,
      name: '',
      isRemoteWakeup: false,
      isSelfPowered: false,
      interfaces: [{
        id: 1,
        protocol: 0,
        clazz: interfaceClass,
        subClass: 0,
        alternateSetting: 0,
        name: '',
        endpoints: []
      } as usbManager.USBInterface]
    } as usbManager.USBConfiguration]
  } as usbManager.USBDevice
}

function successMutationResult(): PeripheralTraceMutationResult {
  return { success: true, code: 'ok' } as PeripheralTraceMutationResult
}

export default function peripheralPolicySnapshotTraceServiceTest() {
  describe('PeripheralPolicySnapshotTraceService', () => {
    let mockKit: MockKit
    let savedRecords: PeripheralTraceRecord[]

    beforeEach(() => {
      mockKit = new MockKit()
      savedRecords = []
      PeripheralPolicySnapshotTraceService.setNowProviderForTest(() => 1700000000000)
      let appendMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.appendEntries)
      when(appendMock)(ArgumentMatchers.any).afterAction((records: PeripheralTraceRecord[]) => {
        savedRecords = records
        return Promise.resolve(successMutationResult())
      })
    })

    afterEach(() => {
      PeripheralPolicySnapshotTraceService.resetForTest()
      mockKit.clearAll()
    })

    it('should append policy snapshot for current non-hub usb devices', 0, async () => {
      PeripheralPolicySnapshotTraceService.setUsbDeviceSnapshotProviderForTest(new FakeUsbDeviceSnapshotProvider([
        usbDevice(0x1234, 0x5678, 'Acme', 'Camera', 'usb-a', 0x0E)
      ]))

      const devices = PeripheralPolicySnapshotTraceService.captureCurrentUsbDevices()
      const result = await PeripheralPolicySnapshotTraceService.appendUsbGlobalDisabledSnapshot(devices)

      expect(result.success).assertTrue()
      expect(savedRecords.length).assertEqual(1)
      expect(savedRecords[0].source).assertEqual('policy_snapshot')
      expect(savedRecords[0].action).assertEqual('discover')
      expect(savedRecords[0].deviceId).assertEqual('VID:1234 PID:5678')
      expect(savedRecords[0].deviceName).assertEqual('Acme Camera')
      expect(savedRecords[0].deviceType).assertEqual(PeripheralType.USB_CAMERA)
      expect(savedRecords[0].decision).assertEqual('deny')
      expect((savedRecords[0].rawPayload ?? '').includes('"vendorId":4660')).assertTrue()
    })

    it('should append global usb disabled snapshot from devices captured before policy change', 0, async () => {
      PeripheralPolicySnapshotTraceService.setUsbDeviceSnapshotProviderForTest(new FakeUsbDeviceSnapshotProvider([
        usbDevice(0x1234, 0x5678, 'Acme', 'Security Key', 'usb-key', 0x03)
      ]))
      const captured = PeripheralPolicySnapshotTraceService.captureCurrentUsbDevices()

      const result = await PeripheralPolicySnapshotTraceService.appendUsbGlobalDisabledSnapshot(captured)

      expect(result.success).assertTrue()
      expect(savedRecords.length).assertEqual(1)
      expect(savedRecords[0].rawEventName).assertEqual('usb_global_policy')
      expect(savedRecords[0].matchedPolicyKind).assertEqual('usb_disabled')
      expect(savedRecords[0].result).assertEqual(SecurityEventResult.BLOCKED)
      expect(savedRecords[0].deviceName).assertEqual('Acme Security Key')
    })

    it('should append allow snapshot after usb global enable', 0, async () => {
      PeripheralPolicySnapshotTraceService.setUsbDeviceSnapshotProviderForTest(new FakeUsbDeviceSnapshotProvider([
        usbDevice(0x1234, 0x5678, 'Acme', 'Keyboard', 'usb-keyboard', 0x03)
      ]))
      const devices = PeripheralPolicySnapshotTraceService.captureCurrentUsbDevices()

      const result = await PeripheralPolicySnapshotTraceService.appendUsbGlobalEnabledSnapshot(devices)

      expect(result.success).assertTrue()
      expect(savedRecords.length).assertEqual(1)
      expect(savedRecords[0].decision).assertEqual('allow')
      expect(savedRecords[0].rawEventName).assertEqual('usb_global_policy')
      expect(savedRecords[0].matchedPolicyKind).assertEqual('default_allow')
    })

    it('should not use usb manager name as snapshot display name', 0, async () => {
      PeripheralPolicySnapshotTraceService.setUsbDeviceSnapshotProviderForTest(new FakeUsbDeviceSnapshotProvider([
        usbDevice(0x1234, 0x5678, '', 'Camera', 'usb-camera', 0x0E)
      ]))

      const devices = PeripheralPolicySnapshotTraceService.captureCurrentUsbDevices()
      const result = await PeripheralPolicySnapshotTraceService.appendUsbGlobalDisabledSnapshot(devices)

      expect(result.success).assertTrue()
      expect(savedRecords.length).assertEqual(1)
      expect(savedRecords[0].deviceName).assertEqual('USB 设备')
    })

    it('should fallback snapshot name when only product is present', 0, async () => {
      PeripheralPolicySnapshotTraceService.setUsbDeviceSnapshotProviderForTest(new FakeUsbDeviceSnapshotProvider([
        usbDevice(0x1234, 0x5678, '', 'Camera', '', 0x0E)
      ]))

      const devices = PeripheralPolicySnapshotTraceService.captureCurrentUsbDevices()
      const result = await PeripheralPolicySnapshotTraceService.appendUsbGlobalDisabledSnapshot(devices)

      expect(result.success).assertTrue()
      expect(savedRecords.length).assertEqual(1)
      expect(savedRecords[0].deviceName).assertEqual('USB 设备')
    })

    it('should skip hub devices and avoid appending empty snapshots', 0, async () => {
      PeripheralPolicySnapshotTraceService.setUsbDeviceSnapshotProviderForTest(new FakeUsbDeviceSnapshotProvider([
        usbDevice(0x1111, 0x2222, 'Hub', 'USB Hub', 'hub', 0x09)
      ]))

      const devices = PeripheralPolicySnapshotTraceService.captureCurrentUsbDevices()
      const result = await PeripheralPolicySnapshotTraceService.appendUsbGlobalDisabledSnapshot(devices)

      expect(result.success).assertTrue()
      expect(savedRecords.length).assertEqual(0)
    })

    it('should infer device type from interface class when device class is empty', 0, async () => {
      PeripheralPolicySnapshotTraceService.setUsbDeviceSnapshotProviderForTest(new FakeUsbDeviceSnapshotProvider([
        usbDeviceWithInterfaceClass(0x1234, 0x5678, 0, 0x0E)
      ]))

      const devices = PeripheralPolicySnapshotTraceService.captureCurrentUsbDevices()
      const result = await PeripheralPolicySnapshotTraceService.appendUsbGlobalDisabledSnapshot(devices)

      expect(result.success).assertTrue()
      expect(savedRecords.length).assertEqual(1)
      expect(savedRecords[0].deviceType).assertEqual(PeripheralType.USB_CAMERA)
    })

    it('should append single-device snapshot only when current usb device matches vid pid', 0, async () => {
      PeripheralPolicySnapshotTraceService.setUsbDeviceSnapshotProviderForTest(new FakeUsbDeviceSnapshotProvider([
        usbDevice(0x1234, 0x5678, 'Acme', 'Storage', 'usb-storage', 0x08),
        usbDevice(0x9999, 0x0001, 'Other', 'Device', 'other', 0x03)
      ]))
      const record: PeripheralDevicePolicySnapshotRequest = {
        deviceId: 'VID:1234 PID:5678',
        deviceName: 'USB Device',
        deviceType: PeripheralType.USB_STORAGE,
        policy: 'allow',
        updatedAt: 1
      }

      const result = await PeripheralPolicySnapshotTraceService.appendDevicePolicySnapshot(record)

      expect(result.success).assertTrue()
      expect(savedRecords.length).assertEqual(1)
      expect(savedRecords[0].deviceId).assertEqual('VID:1234 PID:5678')
      expect(savedRecords[0].deviceType).assertEqual(PeripheralType.USB_STORAGE)
      expect(savedRecords[0].decision).assertEqual('allow')
    })

    it('should not use policy record device type when current usb class is unavailable', 0, async () => {
      PeripheralPolicySnapshotTraceService.setUsbDeviceSnapshotProviderForTest(new FakeUsbDeviceSnapshotProvider([
        usbDevice(0x1234, 0x5678, 'Acme', 'Storage', 'usb-storage', 0)
      ]))
      const record: PeripheralDevicePolicySnapshotRequest = {
        deviceId: 'VID:1234 PID:5678',
        deviceName: 'USB Device',
        deviceType: PeripheralType.USB_STORAGE,
        policy: 'allow',
        updatedAt: 1
      }

      const result = await PeripheralPolicySnapshotTraceService.appendDevicePolicySnapshot(record)

      expect(result.success).assertTrue()
      expect(savedRecords.length).assertEqual(0)
    })

    it('should not append single-device snapshot when current usb device is absent', 0, async () => {
      PeripheralPolicySnapshotTraceService.setUsbDeviceSnapshotProviderForTest(new FakeUsbDeviceSnapshotProvider([
        usbDevice(0x9999, 0x0001, 'Other', 'Device', 'other', 0x03)
      ]))
      const record: PeripheralDevicePolicySnapshotRequest = {
        deviceId: 'VID:1234 PID:5678',
        deviceName: 'USB Device',
        deviceType: PeripheralType.USB_STORAGE,
        policy: 'deny',
        updatedAt: 1
      }

      const result = await PeripheralPolicySnapshotTraceService.appendDevicePolicySnapshot(record)

      expect(result.success).assertTrue()
      expect(savedRecords.length).assertEqual(0)
    })

    it('should append policy change snapshot for disabled usb storage policy', 0, async () => {
      PeripheralPolicySnapshotTraceService.setUsbDeviceSnapshotProviderForTest(new FakeUsbDeviceSnapshotProvider([
        usbDevice(0x1234, 0x5678, 'Acme', 'Storage', 'usb-storage', 0x08),
        usbDevice(0x9999, 0x0001, 'Other', 'HID', 'hid', 0x03)
      ]))

      const result = await PeripheralPolicySnapshotTraceService.appendUsbStoragePolicySnapshot(UsbStoragePolicy.DISABLED)

      expect(result.success).assertTrue()
      expect(savedRecords.length).assertEqual(1)
      expect(savedRecords[0].deviceType).assertEqual(PeripheralType.USB_STORAGE)
      expect(savedRecords[0].action).assertEqual('discover')
      expect(savedRecords[0].decision).assertEqual('deny')
      expect(savedRecords[0].matchedPolicyKind).assertEqual('usb_storage_disabled')
      expect(savedRecords[0].usbPolicy).assertEqual(UsbStoragePolicy.DISABLED)
    })

    it('should append policy change snapshot for read-only usb storage policy', 0, async () => {
      PeripheralPolicySnapshotTraceService.setUsbDeviceSnapshotProviderForTest(new FakeUsbDeviceSnapshotProvider([
        usbDevice(0x1234, 0x5678, 'Acme', 'Storage', 'usb-storage', 0x08)
      ]))

      const result = await PeripheralPolicySnapshotTraceService.appendUsbStoragePolicySnapshot(UsbStoragePolicy.READ_ONLY)

      expect(result.success).assertTrue()
      expect(savedRecords.length).assertEqual(1)
      expect(savedRecords[0].action).assertEqual('discover')
      expect(savedRecords[0].decision).assertEqual('allow')
      expect(savedRecords[0].matchedPolicyKind).assertEqual('usb_storage_read_only')
      expect(savedRecords[0].usbPolicy).assertEqual(UsbStoragePolicy.READ_ONLY)
    })

    it('should append policy change snapshot for read-write usb storage policy', 0, async () => {
      PeripheralPolicySnapshotTraceService.setUsbDeviceSnapshotProviderForTest(new FakeUsbDeviceSnapshotProvider([
        usbDevice(0x1234, 0x5678, 'Acme', 'Storage', 'usb-storage', 0x08)
      ]))

      const result = await PeripheralPolicySnapshotTraceService.appendUsbStoragePolicySnapshot(UsbStoragePolicy.READ_WRITE)

      expect(result.success).assertTrue()
      expect(savedRecords.length).assertEqual(1)
      expect(savedRecords[0].action).assertEqual('discover')
      expect(savedRecords[0].decision).assertEqual('allow')
      expect(savedRecords[0].matchedPolicyKind).assertEqual('default_allow')
      expect(savedRecords[0].usbPolicy).assertEqual(UsbStoragePolicy.READ_WRITE)
    })
  })
}
