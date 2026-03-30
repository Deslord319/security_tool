import {
  PeripheralConnectionRecord,
  PeripheralDevicePolicyRecord,
  PeripheralPolicyRecord,
  PeripheralType,
  formatUsbDeviceId,
  parseUsbDeviceId
} from '../models/DataModels'
import { formatPeripheralTimestamp } from '../viewmodels/PeripheralRecordPresentationMapper'

const USB_RECORD_TYPES: PeripheralType[] = [
  PeripheralType.USB_STORAGE,
  PeripheralType.USB_CAMERA,
  PeripheralType.USB_PRINTER,
  PeripheralType.USB_HID,
  PeripheralType.USB_OTHER
]

export class PeripheralPolicyService {
  static buildPolicyRecords(
    connectionRecords: PeripheralConnectionRecord[],
    devicePolicies: PeripheralDevicePolicyRecord[]
  ): PeripheralPolicyRecord[] {
    const policyMap: Map<string, PeripheralDevicePolicyRecord> = new Map()
    devicePolicies.forEach((item: PeripheralDevicePolicyRecord) => {
      policyMap.set(item.deviceId.toUpperCase(), item)
    })

    const items: Map<string, PeripheralPolicyRecord> = new Map()
    for (const record of connectionRecords) {
      if (!USB_RECORD_TYPES.includes(record.deviceType)) {
        continue
      }
      const parsed = parseUsbDeviceId(record.deviceId)
      if (!parsed) {
        continue
      }
      const deviceId = formatUsbDeviceId(parsed.vendorId, parsed.productId)
      const deviceKey = deviceId.toUpperCase()
      const existing = items.get(deviceKey)
      if (existing && existing.lastSeenAt >= record.timestamp) {
        continue
      }
      const policy = policyMap.get(deviceKey)
      items.set(deviceKey, {
        deviceName: record.deviceName,
        deviceType: record.deviceType,
        deviceId: deviceId,
        lastSeenAt: record.timestamp,
        lastSeenLabel: formatPeripheralTimestamp(record.timestamp),
        policyIndex: policy?.policy === 'deny' ? 1 : 0
      })
    }

    return Array.from(items.values()).sort((left: PeripheralPolicyRecord, right: PeripheralPolicyRecord) => {
      return right.lastSeenAt - left.lastSeenAt
    })
  }
}
