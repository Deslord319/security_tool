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

    const policyMap: Map<string, PeripheralDevicePolicyRecord> = new Map()
    for (const policy of devicePolicies) {
      const normalizedDeviceId = PeripheralPolicyService.normalizeUsbDeviceId(policy.deviceId)
      if (normalizedDeviceId.length === 0) {
        continue
      }
      policyMap.set(normalizedDeviceId, policy)
    }

    const items: PeripheralPolicyRecord[] = Array.from(latestConnectionMap.entries()).map((
      [deviceKey, latestConnection]: [string, PeripheralConnectionRecord]
    ) => {
      const policy = policyMap.get(deviceKey)
      const lastSeenAt = latestConnection.timestamp
      return {
        deviceName: latestConnection.deviceName?.trim().length ? latestConnection.deviceName : deviceKey,
        deviceType: latestConnection.deviceType,
        deviceId: deviceKey,
        lastSeenAt: lastSeenAt,
        lastSeenLabel: formatPeripheralTimestamp(lastSeenAt),
        policyIndex: policy?.policy === 'deny' ? 1 : 0
      } as PeripheralPolicyRecord
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
