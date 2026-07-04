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
  protocol: number
): usbManager.USBDevice {
  return {
    vendorId: vendorId,
    productId: productId,
    serial: serial,
    manufacturerName: manufacturerName,
    productName: productName,
    name: name,
    clazz: clazz,
    subClass: subClass,
    protocol: protocol
  } as usbManager.USBDevice
}

export default function lockScreenUKeyDeviceServiceTest() {
  describe('LockScreenUKeyDeviceService', () => {
    it('filters_keyboard_mouse_and_hub_from_ddk_candidates', 0, () => {
      let service = new DdkLockScreenUKeyDeviceService(
        new FakeDdkUsbDeviceQuery([
          ddkDevice(1, 0x1000, 0x0001, 'Secure UKey'),
          ddkDevice(2, 0x1000, 0x0002, 'USB Keyboard'),
          ddkDevice(3, 0x1000, 0x0003, 'USB Mouse'),
          ddkDevice(4, 0x1000, 0x0004, 'USB Hub')
        ]),
        new FakeUsbDeviceDetailProbe([
          usbDevice(0x1000, 0x0001, 'UK001', 'Secure', 'Secure UKey', 'ukey0', 0xFF, 0, 0),
          usbDevice(0x1000, 0x0002, '', 'Input', 'USB Keyboard', 'keyboard0', 0x03, 0x01, 0x01),
          usbDevice(0x1000, 0x0003, '', 'Input', 'USB Mouse', 'mouse0', 0x03, 0x01, 0x02),
          usbDevice(0x1000, 0x0004, '', 'Hub', 'USB Hub', 'hub0', 0x09, 0, 0)
        ])
      )

      let result = service.getCandidateDevices()
      let devices = result.data ?? []
      expect(result.success).assertEqual(true)
      expect(devices.length).assertEqual(1)
      expect(devices[0].deviceName).assertContain('Secure UKey')
    })

    it('filters_keyboard_mouse_names_when_usb_class_is_missing', 0, () => {
      let service = new DdkLockScreenUKeyDeviceService(
        new FakeDdkUsbDeviceQuery([
          ddkDevice(1, 0x2000, 0x0001, 'USB Receiver Mouse'),
          ddkDevice(2, 0x2000, 0x0002, 'USB Keyboard'),
          ddkDevice(3, 0x2000, 0x0003, 'Token UKey')
        ]),
        new FakeUsbDeviceDetailProbe([])
      )

      let result = service.getCandidateDevices()
      let devices = result.data ?? []
      expect(result.success).assertEqual(true)
      expect(devices.length).assertEqual(1)
      expect(devices[0].productName).assertEqual('Token UKey')
    })
  })
}
