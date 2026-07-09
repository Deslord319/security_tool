import {
  UsbDeviceFingerprintType,
  UsbDeviceIdentity
} from '../../../models/PeripheralModels'

export interface UsbDeviceIdentityResolveInput {
  vendorId: number
  productId: number
  baseClass: number
  deviceName: string
  serialNumber?: string
  description?: string
}

export class UsbDeviceIdentityResolver {
  static resolve(input: UsbDeviceIdentityResolveInput): UsbDeviceIdentity | null {
    if (!Number.isFinite(input.vendorId) || !Number.isFinite(input.productId)) {
      return null
    }
    const serialNumber = UsbDeviceIdentityResolver.normalizeToken(input.serialNumber)
    const description = UsbDeviceIdentityResolver.normalizeDescription(input.description)
    const fingerprintType: UsbDeviceFingerprintType = serialNumber.length > 0 ? 'serial' : 'weak'
    const fingerprintKey = fingerprintType === 'serial'
      ? `USB-SN:${serialNumber}`
      : UsbDeviceIdentityResolver.buildWeakFingerprintKey(input.vendorId, input.productId, description)

    return {
      fingerprintKey: fingerprintKey,
      fingerprintType: fingerprintType,
      vendorId: Math.floor(input.vendorId),
      productId: Math.floor(input.productId),
      baseClass: Number.isFinite(input.baseClass) ? Math.floor(input.baseClass) : 0,
      deviceName: (input.deviceName || '').trim(),
      serialNumber: serialNumber.length > 0 ? serialNumber : undefined,
      description: description.length > 0 ? description : undefined
    }
  }

  private static buildWeakFingerprintKey(vendorId: number, productId: number, description: string): string {
    const vid = UsbDeviceIdentityResolver.formatHex4(vendorId)
    const pid = UsbDeviceIdentityResolver.formatHex4(productId)
    const hash = UsbDeviceIdentityResolver.hash(description)
    return `USB-WEAK:${vid}:${pid}:${hash}`
  }

  private static normalizeToken(value?: string): string {
    return (value || '').trim().replace(/\s+/g, ' ').toUpperCase()
  }

  private static normalizeDescription(value?: string): string {
    return (value || '').trim().replace(/\s+/g, ' ')
  }

  private static formatHex4(value: number): string {
    return Math.floor(value).toString(16).toUpperCase().padStart(4, '0')
  }

  private static hash(value: string): string {
    let hash = 2166136261
    for (let index = 0; index < value.length; index++) {
      hash = hash ^ value.charCodeAt(index)
      hash = Math.imul(hash, 16777619)
    }
    return (hash >>> 0).toString(16).toUpperCase().padStart(8, '0')
  }
}

