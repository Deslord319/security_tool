export interface UsbDeviceNameFields {
  manufacturerName?: string
  productName?: string
  deviceName?: string
}

export class UsbDeviceNameResolver {
  static resolve(fields: UsbDeviceNameFields, fallbackName: string): string {
    const manufacturerName = UsbDeviceNameResolver.normalize(fields.manufacturerName)
    const productName = UsbDeviceNameResolver.normalize(fields.productName)
    const deviceName = UsbDeviceNameResolver.normalize(fields.deviceName)

    if (manufacturerName.length > 0 && productName.length > 0) {
      return `${manufacturerName} ${productName}`
    }
    if (deviceName.length > 0) {
      return deviceName
    }
    return fallbackName
  }

  private static normalize(value: string | undefined): string {
    return (value ?? '').trim()
  }
}
