import { usbManager } from '@kit.BasicServicesKit'
import { deviceManager } from '@kit.DriverDevelopmentKit'
import { OperationResult } from '../../../models/CommonModels'
import { LockScreenUKeyDevice } from '../../../models/identity/lockscreen-auth/LockScreenAuthModels'
import { ErrorUtils } from '../../../utils/ErrorUtils'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'LockScreenUKey.DeviceService'
const USB_CLASS_HUB = 0x09
const USB_CLASS_MASS_STORAGE = 0x08
const USB_CLASS_HID = 0x03
const USB_HID_SUBCLASS_BOOT = 0x01
const USB_HID_PROTOCOL_KEYBOARD = 0x01
const USB_HID_PROTOCOL_MOUSE = 0x02
const KEYBOARD_MOUSE_NAME_KEYWORDS: string[] = [
  'KEYBOARD',
  'MOUSE',
  'TOUCHPAD',
  'TRACKPAD',
  '键盘',
  '鼠标',
  '触控板',
  '触摸板'
]

export interface LockScreenUKeyDeviceProvider {
  getCandidateDevices(): OperationResult<LockScreenUKeyDevice[]>
}

export interface DdkUsbDeviceInfo {
  ddkDeviceId: number
  vendorId: number
  productId: number
  description: string
}

export interface DdkUsbDeviceQuery {
  queryUsbDevices(): OperationResult<DdkUsbDeviceInfo[]>
}

export interface UsbDeviceDetailProbe {
  getUsbDevices(): OperationResult<usbManager.USBDevice[]>
}

export class DriverDevelopmentKitUsbDeviceQuery implements DdkUsbDeviceQuery {
  queryUsbDevices(): OperationResult<DdkUsbDeviceInfo[]> {
    try {
      let rawDevices = deviceManager.queryDevices(deviceManager.BusType.USB)
      let devices: DdkUsbDeviceInfo[] = []
      for (let raw of rawDevices) {
        let usb = raw as deviceManager.USBDevice
        devices.push({
          ddkDeviceId: DdkLockScreenUKeyDeviceService.normalizeNumber(usb.deviceId),
          vendorId: DdkLockScreenUKeyDeviceService.normalizeNumber(usb.vendorId),
          productId: DdkLockScreenUKeyDeviceService.normalizeNumber(usb.productId),
          description: DdkLockScreenUKeyDeviceService.normalizeText(usb.description)
        })
      }
      return {
        success: true,
        data: devices
      } as OperationResult<DdkUsbDeviceInfo[]>
    } catch (err) {
      let info = ErrorUtils.toBusinessErrorInfo(err)
      return {
        success: false,
        errorCode: info.code,
        errorMessage: info.message,
        stage: 'query_ddk_devices'
      } as OperationResult<DdkUsbDeviceInfo[]>
    }
  }
}

export class BasicServicesUsbDeviceDetailProbe implements UsbDeviceDetailProbe {
  getUsbDevices(): OperationResult<usbManager.USBDevice[]> {
    try {
      return {
        success: true,
        data: usbManager.getDevices() as usbManager.USBDevice[]
      } as OperationResult<usbManager.USBDevice[]>
    } catch (err) {
      let info = ErrorUtils.toBusinessErrorInfo(err)
      return {
        success: false,
        errorCode: info.code,
        errorMessage: info.message,
        stage: 'query_usb_devices'
      } as OperationResult<usbManager.USBDevice[]>
    }
  }
}

export class DdkLockScreenUKeyDeviceService implements LockScreenUKeyDeviceProvider {
  private readonly ddkQuery: DdkUsbDeviceQuery
  private readonly detailProbe: UsbDeviceDetailProbe

  constructor(
    ddkQuery: DdkUsbDeviceQuery = new DriverDevelopmentKitUsbDeviceQuery(),
    detailProbe: UsbDeviceDetailProbe = new BasicServicesUsbDeviceDetailProbe()
  ) {
    this.ddkQuery = ddkQuery
    this.detailProbe = detailProbe
  }

  getCandidateDevices(): OperationResult<LockScreenUKeyDevice[]> {
    let ddkResult = this.ddkQuery.queryUsbDevices()
    if (!ddkResult.success) {
      LogUtils.error(TAG, `[DDK_QUERY_FAIL] getCandidateDevices | code=${ddkResult.errorCode ?? -1}, message=${ddkResult.errorMessage ?? 'unknown'}`)
      return {
        success: false,
        errorCode: ddkResult.errorCode,
        errorMessage: ddkResult.errorMessage,
        stage: ddkResult.stage ?? 'query_ddk_devices'
      } as OperationResult<LockScreenUKeyDevice[]>
    }
    let ddkDevices = ddkResult.data ?? []
    let detailDevices = this.queryUsbDetailsBestEffort()
    let devices: LockScreenUKeyDevice[] = []
    for (let raw of ddkDevices) {
      let detail = DdkLockScreenUKeyDeviceService.findUsbDetail(raw, detailDevices)
      let device = DdkLockScreenUKeyDeviceService.toUKeyDevice(raw, detail)
      if (!DdkLockScreenUKeyDeviceService.isCandidateUKeyDevice(device)) {
        continue
      }
      devices.push(device)
    }
    let storageDevices = devices.filter((item: LockScreenUKeyDevice): boolean => item.clazz === USB_CLASS_MASS_STORAGE)
    let candidates = storageDevices.length > 0 ? storageDevices : devices
    return {
      success: true,
      data: candidates
    } as OperationResult<LockScreenUKeyDevice[]>
  }

  private queryUsbDetailsBestEffort(): usbManager.USBDevice[] {
    let result = this.detailProbe.getUsbDevices()
    if (!result.success) {
      LogUtils.warn(TAG, `[USB_DETAIL_SKIP] code=${result.errorCode ?? -1}, message=${result.errorMessage ?? 'unknown'}`)
      return []
    }
    return result.data ?? []
  }

  private static findUsbDetail(
    info: DdkUsbDeviceInfo,
    devices: usbManager.USBDevice[]
  ): usbManager.USBDevice | null {
    let matches: usbManager.USBDevice[] = []
    for (let item of devices) {
      let vendorId = DdkLockScreenUKeyDeviceService.normalizeNumber(item.vendorId)
      let productId = DdkLockScreenUKeyDeviceService.normalizeNumber(item.productId)
      if (vendorId === info.vendorId && productId === info.productId) {
        matches.push(item)
      }
    }
    if (matches.length === 1) {
      return matches[0]
    }
    if (matches.length > 1) {
      LogUtils.warn(TAG, `[USB_DETAIL_AMBIGUOUS] ddkDeviceId=${info.ddkDeviceId}, vid=${info.vendorId}, pid=${info.productId}, matches=${matches.length}`)
      return DdkLockScreenUKeyDeviceService.toAmbiguousUsbDetail(info, matches)
    }
    return null
  }

  private static toAmbiguousUsbDetail(info: DdkUsbDeviceInfo, matches: usbManager.USBDevice[]): usbManager.USBDevice {
    return {
      vendorId: info.vendorId,
      productId: info.productId,
      serial: '',
      manufacturerName: DdkLockScreenUKeyDeviceService.resolveCommonText(matches, (device: usbManager.USBDevice): string | undefined => device.manufacturerName),
      productName: DdkLockScreenUKeyDeviceService.resolveCommonText(matches, (device: usbManager.USBDevice): string | undefined => device.productName),
      name: DdkLockScreenUKeyDeviceService.resolveCommonText(matches, (device: usbManager.USBDevice): string | undefined => device.name),
      clazz: DdkLockScreenUKeyDeviceService.resolveCommonNumber(matches, (device: usbManager.USBDevice): number | undefined => device.clazz),
      subClass: DdkLockScreenUKeyDeviceService.resolveCommonNumber(matches, (device: usbManager.USBDevice): number | undefined => device.subClass),
      protocol: DdkLockScreenUKeyDeviceService.resolveCommonNumber(matches, (device: usbManager.USBDevice): number | undefined => device.protocol)
    } as usbManager.USBDevice
  }

  private static resolveCommonText(
    devices: usbManager.USBDevice[],
    picker: (device: usbManager.USBDevice) => string | undefined
  ): string {
    let commonValue = ''
    for (let index = 0; index < devices.length; index++) {
      let value = DdkLockScreenUKeyDeviceService.normalizeText(picker(devices[index]))
      if (index === 0) {
        commonValue = value
        continue
      }
      if (value !== commonValue) {
        return ''
      }
    }
    return commonValue
  }

  private static resolveCommonNumber(
    devices: usbManager.USBDevice[],
    picker: (device: usbManager.USBDevice) => number | undefined
  ): number {
    let commonValue = 0
    for (let index = 0; index < devices.length; index++) {
      let value = DdkLockScreenUKeyDeviceService.normalizeNumber(picker(devices[index]))
      if (index === 0) {
        commonValue = value
        continue
      }
      if (value !== commonValue) {
        return 0
      }
    }
    return commonValue
  }

  private static isCandidateUKeyDevice(device: LockScreenUKeyDevice): boolean {
    if (device.clazz === USB_CLASS_HUB) {
      return false
    }
    if (DdkLockScreenUKeyDeviceService.isKeyboardOrMouse(device)) {
      return false
    }
    return true
  }

  private static isKeyboardOrMouse(device: LockScreenUKeyDevice): boolean {
    if (device.clazz === USB_CLASS_HID &&
      device.subClass === USB_HID_SUBCLASS_BOOT &&
      (device.protocol === USB_HID_PROTOCOL_KEYBOARD || device.protocol === USB_HID_PROTOCOL_MOUSE)) {
      return true
    }
    let label = [
      device.manufacturerName,
      device.productName,
      device.deviceName
    ].join('|').toUpperCase()
    return KEYBOARD_MOUSE_NAME_KEYWORDS.some((keyword: string): boolean => label.includes(keyword))
  }

  private static toUKeyDevice(
    info: DdkUsbDeviceInfo,
    detail: usbManager.USBDevice | null
  ): LockScreenUKeyDevice {
    let vendorId = DdkLockScreenUKeyDeviceService.normalizeNumber(info.vendorId)
    let productId = DdkLockScreenUKeyDeviceService.normalizeNumber(info.productId)
    let serial = DdkLockScreenUKeyDeviceService.normalizeText(detail?.serial)
    let manufacturerName = DdkLockScreenUKeyDeviceService.normalizeText(detail?.manufacturerName)
    let productName = DdkLockScreenUKeyDeviceService.normalizeText(detail?.productName)
    let ddkDescription = DdkLockScreenUKeyDeviceService.normalizeText(info.description)
    let usbDeviceName = DdkLockScreenUKeyDeviceService.normalizeText(detail?.name)
    let deviceName = DdkLockScreenUKeyDeviceService.buildDisplayName(
      manufacturerName,
      productName.length > 0 ? productName : ddkDescription,
      usbDeviceName
    )
    let deviceId = DdkLockScreenUKeyDeviceService.formatVidPid(vendorId, productId)
    let stableIdentifier = serial.length > 0
    let weakParts: string[] = []
    if (productName.length > 0) {
      weakParts.push(productName)
    }
    if (ddkDescription.length > 0) {
      weakParts.push(ddkDescription)
    }
    let weakLabel = weakParts.length > 0 ? weakParts.join('|').toUpperCase() : 'UNKNOWN'
    let fingerprint = stableIdentifier
      ? `SN:${serial.toUpperCase()}`
      : `${deviceId}|WEAK:${weakLabel}`
    return {
      fingerprint: fingerprint,
      deviceId: deviceId,
      vendorId: vendorId,
      productId: productId,
      serial: serial,
      manufacturerName: manufacturerName,
      productName: productName.length > 0 ? productName : ddkDescription,
      deviceName: deviceName,
      clazz: DdkLockScreenUKeyDeviceService.normalizeNumber(detail?.clazz),
      subClass: DdkLockScreenUKeyDeviceService.normalizeNumber(detail?.subClass),
      protocol: DdkLockScreenUKeyDeviceService.normalizeNumber(detail?.protocol),
      stableIdentifier: stableIdentifier
    }
  }

  static normalizeText(value: string | undefined): string {
    return (value ?? '').trim()
  }

  static normalizeNumber(value: number | undefined): number {
    return typeof value === 'number' && Number.isFinite(value) ? value : 0
  }

  private static buildDisplayName(manufacturerName: string, productName: string, deviceName: string): string {
    let parts: string[] = []
    if (manufacturerName.length > 0) {
      parts.push(manufacturerName)
    }
    if (productName.length > 0 && productName !== manufacturerName) {
      parts.push(productName)
    }
    if (parts.length > 0) {
      return parts.join(' ')
    }
    return deviceName.length > 0 ? deviceName : 'DDK USB UKey'
  }

  private static formatVidPid(vendorId: number, productId: number): string {
    return `VID:${DdkLockScreenUKeyDeviceService.formatHex(vendorId)} PID:${DdkLockScreenUKeyDeviceService.formatHex(productId)}`
  }

  private static formatHex(value: number): string {
    return Math.max(0, value).toString(16).toUpperCase().padStart(4, '0')
  }
}
