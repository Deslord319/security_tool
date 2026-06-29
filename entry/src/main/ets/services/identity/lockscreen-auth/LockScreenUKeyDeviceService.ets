import { BusinessError, usbManager } from '@kit.BasicServicesKit'
import { deviceManager } from '@kit.DriverDevelopmentKit'
import { OperationResult } from '../../../models/CommonModels'
import { LockScreenUKeyDevice } from '../../../models/identity/lockscreen-auth/LockScreenAuthModels'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'LockScreenUKey.DeviceService'
const USB_CLASS_HUB = 0x09
const USB_CLASS_MASS_STORAGE = 0x08

export interface LockScreenUKeyDeviceProvider {
  getCandidateDevices(): OperationResult<LockScreenUKeyDevice[]>
}

export interface UKeyDeviceBackend extends LockScreenUKeyDeviceProvider {
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
      let error = err as Error
      let errorCode = typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
      let errorMessage = typeof error?.message === 'string' && error.message.length > 0 ? error.message : 'unknown'
      return {
        success: false,
        errorCode: errorCode,
        errorMessage: errorMessage,
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
      let error = err as Error
      let errorCode = typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
      let errorMessage = typeof error?.message === 'string' && error.message.length > 0 ? error.message : 'unknown'
      return {
        success: false,
        errorCode: errorCode,
        errorMessage: errorMessage,
        stage: 'query_usb_devices'
      } as OperationResult<usbManager.USBDevice[]>
    }
  }
}

export class DdkLockScreenUKeyDeviceService implements UKeyDeviceBackend {
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
      if (device.clazz === USB_CLASS_HUB) {
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
    for (let item of devices) {
      let vendorId = DdkLockScreenUKeyDeviceService.normalizeNumber(item.vendorId)
      let productId = DdkLockScreenUKeyDeviceService.normalizeNumber(item.productId)
      if (vendorId === info.vendorId && productId === info.productId) {
        return item
      }
    }
    return null
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
    let fallbackDescription = ddkDescription.length > 0 ? ddkDescription : 'UNKNOWN'
    let weakParts: string[] = [fallbackDescription]
    if (deviceName.length > 0) {
      weakParts.push(deviceName)
    }
    weakParts.push(`DDK:${info.ddkDeviceId}`)
    let weakLabel = weakParts.join('|').toUpperCase()
    let fingerprint = stableIdentifier
      ? `${deviceId}|SN:${serial.toUpperCase()}`
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

export class UsbLockScreenUKeyDeviceService implements UKeyDeviceBackend {
  getCandidateDevices(): OperationResult<LockScreenUKeyDevice[]> {
    try {
      let rawDevices = usbManager.getDevices()
      let devices: LockScreenUKeyDevice[] = []
      for (let raw of rawDevices) {
        let device = UsbLockScreenUKeyDeviceService.toUKeyDevice(raw as usbManager.USBDevice)
        if (device.clazz === USB_CLASS_HUB) {
          continue
        }
        devices.push(device)
      }
      let storageDevices = devices.filter((item: LockScreenUKeyDevice) => item.clazz === USB_CLASS_MASS_STORAGE)
      let candidates = storageDevices.length > 0 ? storageDevices : devices
      return {
        success: true,
        data: candidates
      } as OperationResult<LockScreenUKeyDevice[]>
    } catch (err) {
      let error = err as Error
      let errorCode = typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
      let errorMessage = typeof error?.message === 'string' && error.message.length > 0 ? error.message : 'unknown'
      LogUtils.error(TAG, `[QUERY_FAIL] getCandidateDevices | code=${errorCode}, message=${errorMessage}`)
      return {
        success: false,
        errorCode: errorCode,
        errorMessage: errorMessage,
        stage: 'query_usb_devices'
      } as OperationResult<LockScreenUKeyDevice[]>
    }
  }

  private static toUKeyDevice(device: usbManager.USBDevice): LockScreenUKeyDevice {
    let vendorId = UsbLockScreenUKeyDeviceService.normalizeNumber(device.vendorId)
    let productId = UsbLockScreenUKeyDeviceService.normalizeNumber(device.productId)
    let serial = UsbLockScreenUKeyDeviceService.normalizeText(device.serial)
    let manufacturerName = UsbLockScreenUKeyDeviceService.normalizeText(device.manufacturerName)
    let productName = UsbLockScreenUKeyDeviceService.normalizeText(device.productName)
    let deviceName = UsbLockScreenUKeyDeviceService.normalizeText(device.name)
    let deviceId = UsbLockScreenUKeyDeviceService.formatVidPid(vendorId, productId)
    let fallbackLabel = `${manufacturerName}|${productName}|${deviceName}`.toUpperCase()
    let stableIdentifier = serial.length > 0
    let fingerprint = stableIdentifier
      ? `${deviceId}|SN:${serial.toUpperCase()}`
      : `${deviceId}|WEAK:${fallbackLabel}`
    return {
      fingerprint: fingerprint,
      deviceId: deviceId,
      vendorId: vendorId,
      productId: productId,
      serial: serial,
      manufacturerName: manufacturerName,
      productName: productName,
      deviceName: UsbLockScreenUKeyDeviceService.buildDisplayName(manufacturerName, productName, deviceName),
      clazz: UsbLockScreenUKeyDeviceService.normalizeNumber(device.clazz),
      subClass: UsbLockScreenUKeyDeviceService.normalizeNumber(device.subClass),
      protocol: UsbLockScreenUKeyDeviceService.normalizeNumber(device.protocol),
      stableIdentifier: stableIdentifier
    }
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
    return deviceName.length > 0 ? deviceName : 'USB UKey'
  }

  private static normalizeText(value: string | undefined): string {
    return (value ?? '').trim()
  }

  private static normalizeNumber(value: number | undefined): number {
    return typeof value === 'number' && Number.isFinite(value) ? value : 0
  }

  private static formatVidPid(vendorId: number, productId: number): string {
    return `VID:${UsbLockScreenUKeyDeviceService.formatHex(vendorId)} PID:${UsbLockScreenUKeyDeviceService.formatHex(productId)}`
  }

  private static formatHex(value: number): string {
    return Math.max(0, value).toString(16).toUpperCase().padStart(4, '0')
  }
}
