import { BusinessError, usbManager } from '@kit.BasicServicesKit'
import { OperationResult } from '../../../models/CommonModels'
import { LockScreenUKeyDevice } from '../../../models/identity/lockscreen-auth/LockScreenAuthModels'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'LockScreenUKey.DeviceService'
const USB_CLASS_HUB = 0x09
const USB_CLASS_MASS_STORAGE = 0x08

export interface LockScreenUKeyDeviceProvider {
  getCandidateDevices(): OperationResult<LockScreenUKeyDevice[]>
}

export class UsbLockScreenUKeyDeviceService implements LockScreenUKeyDeviceProvider {
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
