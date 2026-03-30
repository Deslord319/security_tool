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
    const latestConnectionMap: Map<string, PeripheralConnectionRecord> = new Map()
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
      const existing = latestConnectionMap.get(deviceKey)
      if (existing && existing.timestamp >= record.timestamp) {
        continue
      }
      latestConnectionMap.set(deviceKey, record)
    }

    const items: PeripheralPolicyRecord[] = devicePolicies.map((policy: PeripheralDevicePolicyRecord) => {
      const normalizedDeviceId = PeripheralPolicyService.normalizeUsbDeviceId(policy.deviceId)
      const latestConnection = normalizedDeviceId.length > 0 ? latestConnectionMap.get(normalizedDeviceId) : undefined
      const lastSeenAt = latestConnection?.timestamp ?? policy.updatedAt
      const item: PeripheralPolicyRecord = {
        deviceName: latestConnection?.deviceName ?? (policy.deviceName?.trim().length ? policy.deviceName : normalizedDeviceId),
        deviceType: latestConnection?.deviceType ?? policy.deviceType ?? PeripheralType.USB_OTHER,
        deviceId: normalizedDeviceId.length > 0 ? normalizedDeviceId : policy.deviceId,
        lastSeenAt: lastSeenAt,
        lastSeenLabel: formatPeripheralTimestamp(lastSeenAt),
        policyIndex: policy.policy === 'deny' ? 1 : 0
      } as PeripheralPolicyRecord
      return item
    })

    return items.sort((left: PeripheralPolicyRecord, right: PeripheralPolicyRecord) => {
      return right.lastSeenAt - left.lastSeenAt
    })
  }

  private static normalizeUsbDeviceId(deviceId: string): string {
    const parsed = parseUsbDeviceId(deviceId)
    if (!parsed) {
      return (deviceId || '').trim().replace(/\s+/g, ' ').toUpperCase()
    }
    return formatUsbDeviceId(parsed.vendorId, parsed.productId).toUpperCase()
  }
}
