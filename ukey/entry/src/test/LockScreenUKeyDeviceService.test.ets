import { usbManager } from '@kit.BasicServicesKit'
import { describe, it, expect } from '@ohos/hypium'
import { OperationResult } from '../main/ets/models/CommonModels'
import {
  DdkLockScreenUKeyDeviceService,
  DdkUsbDeviceInfo,
  DdkUsbDeviceQuery,
  UsbDeviceDetailProbe
} from '../main/ets/services/identity/lockscreen-auth/LockScreenUKeyDeviceService'

class FakeDdkUsbDeviceQuery implements DdkUsbDeviceQuery {
  private readonly devices: DdkUsbDeviceInfo[]

  constructor(devices: DdkUsbDeviceInfo[]) {
    this.devices = devices
  }

  queryUsbDevices(): OperationResult<DdkUsbDeviceInfo[]> {
    return {
      success: true,
      data: this.devices
    } as OperationResult<DdkUsbDeviceInfo[]>
  }
}

class FakeUsbDeviceDetailProbe implements UsbDeviceDetailProbe {
  private readonly devices: usbManager.USBDevice[]

  constructor(devices: usbManager.USBDevice[]) {
    this.devices = devices
  }

  getUsbDevices(): OperationResult<usbManager.USBDevice[]> {
    return {
      success: true,
      data: this.devices
    } as OperationResult<usbManager.USBDevice[]>
  }
}

function ddkDevice(
  ddkDeviceId: number,
  vendorId: number,
  productId: number,
  description: string
): DdkUsbDeviceInfo {
  return {
    ddkDeviceId: ddkDeviceId,
    vendorId: vendorId,
    productId: productId,
    description: description
  }
}

function usbDevice(
  vendorId: number,
  productId: number,
  serial: string,
  manufacturerName: string,
  productName: string,
  name: string,
  clazz: number,
  subClass: number,
  protocol: number,
  interfaces: usbManager.USBInterface[] = []
): usbManager.USBDevice {
  let configs: usbManager.USBConfiguration[] = []
  if (interfaces.length > 0) {
    configs.push({
      interfaces: interfaces
    } as usbManager.USBConfiguration)
  }
  return {
    vendorId: vendorId,
    productId: productId,
    serial: serial,
    manufacturerName: manufacturerName,
    productName: productName,
    name: name,
    clazz: clazz,
    subClass: subClass,
    protocol: protocol,
    configs: configs
  } as usbManager.USBDevice
}

function usbInterface(
  clazz: number,
  subClass: number,
  protocol: number,
  name: string = ''
): usbManager.USBInterface {
  return {
    clazz: clazz,
    subClass: subClass,
    protocol: protocol,
    name: name
  } as usbManager.USBInterface
}

export default function lockScreenUKeyDeviceServiceTest() {
  describe('LockScreenUKeyDeviceService', () => {
    it('filters_keyboard_mouse_and_hub_from_ddk_candidates', 0, () => {
      let service = new DdkLockScreenUKeyDeviceService(
        new FakeDdkUsbDeviceQuery([
          ddkDevice(1, 0x055C, 0xE618, 'Longmai-GM3000'),
          ddkDevice(2, 0x1000, 0x0002, 'USB Keyboard'),
          ddkDevice(3, 0x1000, 0x0003, 'USB Mouse'),
          ddkDevice(4, 0x1000, 0x0004, 'USB Hub')
        ]),
        new FakeUsbDeviceDetailProbe([
          usbDevice(0x055C, 0xE618, '', 'Longmai Technologies', 'Longmai-GM3000', 'gm3000', 0x00, 0, 0,
            [usbInterface(0x03, 0x00, 0x00)]),
          usbDevice(0x1000, 0x0002, '', 'Input', 'USB Keyboard', 'keyboard0', 0x03, 0x01, 0x01),
          usbDevice(0x1000, 0x0003, '', 'Input', 'USB Mouse', 'mouse0', 0x03, 0x01, 0x02),
          usbDevice(0x1000, 0x0004, '', 'Hub', 'USB Hub', 'hub0', 0x09, 0, 0)
        ])
      )

      let result = service.getCandidateDevices()
      let devices = result.data ?? []
      expect(result.success).assertEqual(true)
      expect(devices.length).assertEqual(1)
      expect(devices[0].deviceName).assertContain('Longmai-GM3000')
    })

    it('filters_keyboard_mouse_names_even_for_otherwise_supported_classes', 0, () => {
      let service = new DdkLockScreenUKeyDeviceService(
        new FakeDdkUsbDeviceQuery([
          ddkDevice(1, 0x2000, 0x0001, 'USB Receiver Mouse'),
          ddkDevice(2, 0x2000, 0x0002, 'USB Keyboard'),
          ddkDevice(3, 0x055C, 0xE618, 'Longmai-GM3000')
        ]),
        new FakeUsbDeviceDetailProbe([
          usbDevice(0x2000, 0x0001, '', 'Input', 'USB Receiver Mouse', 'receiver0', 0x08, 0x06, 0x50),
          usbDevice(0x2000, 0x0002, '', 'Input', 'USB Keyboard', 'keyboard0', 0x08, 0x06, 0x50),
          usbDevice(0x055C, 0xE618, '', 'Longmai Technologies', 'Longmai-GM3000', 'gm3000', 0x00, 0, 0,
            [usbInterface(0x03, 0x00, 0x00)])
        ])
      )

      let result = service.getCandidateDevices()
      let devices = result.data ?? []
      expect(result.success).assertEqual(true)
      expect(devices.length).assertEqual(1)
      expect(devices[0].productName).assertEqual('Longmai-GM3000')
    })

    it('accepts_storage_and_non_keyboard_mouse_hid_without_device_profile', 0, () => {
      let service = new DdkLockScreenUKeyDeviceService(
        new FakeDdkUsbDeviceQuery([
          ddkDevice(1, 0x3000, 0x0001, 'Mass Storage'),
          ddkDevice(2, 0x3000, 0x0002, 'Composite Storage'),
          ddkDevice(3, 0x055C, 0xE618, 'Longmai-GM3000'),
          ddkDevice(4, 0x3000, 0x0004, 'Other HID UKey'),
          ddkDevice(5, 0x3000, 0x0005, 'Gamepad')
        ]),
        new FakeUsbDeviceDetailProbe([
          usbDevice(0x3000, 0x0001, 'DISK-1', 'Storage', 'USB Disk', 'disk0', 0x08, 0x06, 0x50),
          usbDevice(0x3000, 0x0002, 'DISK-2', 'Storage', 'Composite Disk', 'disk1', 0x00, 0, 0,
            [usbInterface(0x08, 0x06, 0x50)]),
          usbDevice(0x055C, 0xE618, '', 'Longmai Technologies', 'Longmai-GM3000', 'gm3000', 0x00, 0, 0,
            [usbInterface(0x03, 0x00, 0x00)]),
          usbDevice(0x3000, 0x0004, '', 'Other Vendor', 'Other HID UKey', 'ukey1', 0x00, 0, 0,
            [usbInterface(0x03, 0x00, 0x00)]),
          usbDevice(0x3000, 0x0005, '', 'Input', 'Gamepad', 'gamepad0', 0x00, 0, 0,
            [usbInterface(0x03, 0x00, 0x00)])
        ])
      )

      let result = service.getCandidateDevices()
      let devices = result.data ?? []
      expect(result.success).assertEqual(true)
      expect(devices.length).assertEqual(5)
      expect(devices[2].productId).assertEqual(0xE618)
    })

    it('rejects_ccid_vendor_specific_and_non_storage_non_hid_usb_functions', 0, () => {
      let service = new DdkLockScreenUKeyDeviceService(
        new FakeDdkUsbDeviceQuery([
          ddkDevice(1, 0x5000, 0x0001, 'Printer'),
          ddkDevice(2, 0x5000, 0x0002, 'Camera'),
          ddkDevice(3, 0x5000, 0x0003, 'Audio'),
          ddkDevice(4, 0x5000, 0x0004, 'Communication'),
          ddkDevice(5, 0x5000, 0x0005, 'Generic Input'),
          ddkDevice(6, 0x5000, 0x0006, 'CCID Token'),
          ddkDevice(7, 0x5000, 0x0007, 'Vendor Token')
        ]),
        new FakeUsbDeviceDetailProbe([
          usbDevice(0x5000, 0x0001, '', 'Office', 'Printer', 'printer0', 0x07, 0, 0),
          usbDevice(0x5000, 0x0002, '', 'Vision', 'Camera', 'camera0', 0x0E, 0, 0),
          usbDevice(0x5000, 0x0003, '', 'Sound', 'Audio', 'audio0', 0x01, 0, 0),
          usbDevice(0x5000, 0x0004, '', 'Network', 'Communication', 'network0', 0x02, 0, 0),
          usbDevice(0x5000, 0x0005, '', 'Input', 'Generic Input', 'input0', 0x00, 0, 0,
            [usbInterface(0x03, 0x01, 0x01, 'Boot Input')]),
          usbDevice(0x5000, 0x0006, '', 'Secure', 'CCID Token', 'ccid0', 0x0B, 0, 0),
          usbDevice(0x5000, 0x0007, '', 'Secure', 'Vendor Token', 'vendor0', 0xFF, 0, 0)
        ])
      )

      let result = service.getCandidateDevices()
      expect(result.success).assertEqual(true)
      expect((result.data ?? []).length).assertEqual(0)
    })

    it('does_not_reuse_first_serial_when_vid_pid_detail_is_ambiguous', 0, () => {
      let service = new DdkLockScreenUKeyDeviceService(
        new FakeDdkUsbDeviceQuery([
          ddkDevice(10, 0x4000, 0x0001, 'Token A'),
          ddkDevice(11, 0x4000, 0x0001, 'Token B')
        ]),
        new FakeUsbDeviceDetailProbe([
          usbDevice(0x4000, 0x0001, 'SNA', 'Storage', 'Token A', 'token-a', 0x08, 0x06, 0x50),
          usbDevice(0x4000, 0x0001, 'SNB', 'Storage', 'Token B', 'token-b', 0x08, 0x06, 0x50)
        ])
      )

      let result = service.getCandidateDevices()
      let devices = result.data ?? []
      expect(result.success).assertEqual(true)
      expect(devices.length).assertEqual(2)
      expect(devices[0].stableIdentifier).assertEqual(false)
      expect(devices[1].stableIdentifier).assertEqual(false)
      expect(devices[0].fingerprint).assertContain('WEAK:TOKEN A')
      expect(devices[1].fingerprint).assertContain('WEAK:TOKEN B')
    })
  })
}
