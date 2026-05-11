import {
  PeripheralConnectionRecord,
  PeripheralDevicePolicyRecord,
  PeripheralPolicyRecord,
  PeripheralType,
  formatBluetoothDeviceId,
  formatUsbDeviceId,
  parseUsbDeviceId
} from '../../../models/PeripheralModels'
import { PeripheralPolicyOptionIndexes } from '../../../constants/modules/PeripheralStrings'
import { PLACEHOLDER_TEXT } from '../../../constants/StringCatalog'
import { formatStandardDateTimeOrFallback } from '../../../utils/DateTimeFormatUtils'

const POLICY_CANDIDATE_RECORD_TYPES: PeripheralType[] = [
  PeripheralType.USB_STORAGE,
  PeripheralType.USB_CAMERA,
  PeripheralType.USB_PRINTER,
  PeripheralType.USB_HID,
  PeripheralType.USB_OTHER,
  PeripheralType.BLUETOOTH
]

export class PeripheralPolicyService {
  static buildPolicyRecords(
    connectionRecords: PeripheralConnectionRecord[],
    devicePolicies: PeripheralDevicePolicyRecord[]
  ): PeripheralPolicyRecord[] {
    const latestConnectionMap: Map<string, PeripheralConnectionRecord> = new Map()
    for (const record of connectionRecords) {
      if (!POLICY_CANDIDATE_RECORD_TYPES.includes(record.deviceType)) {
        continue
      }
      const deviceId = PeripheralPolicyService.normalizeDeviceIdForPolicy(record.deviceId, record.deviceType)
      if (deviceId.length === 0) {
        continue
      }
      const deviceKey = deviceId.toUpperCase()
      const existing = latestConnectionMap.get(deviceKey)
      if (existing && existing.timestamp >= record.timestamp) {
        continue
      }
      latestConnectionMap.set(deviceKey, record)
    }

    const policyMap: Map<string, PeripheralDevicePolicyRecord> = new Map()
    for (const policy of devicePolicies) {
      const normalizedDeviceId = PeripheralPolicyService.normalizeDeviceIdForPolicy(policy.deviceId, policy.deviceType)
      if (normalizedDeviceId.length === 0) {
        continue
      }
      policyMap.set(normalizedDeviceId, policy)
    }

    const items: PeripheralPolicyRecord[] = Array.from(latestConnectionMap.entries()).map((entry) => {
      const deviceKey = entry[0]
      const latestConnection = entry[1] as PeripheralConnectionRecord
      const policy = policyMap.get(deviceKey)
      const lastSeenAt = latestConnection.timestamp
      return {
        deviceName: latestConnection.deviceName?.trim().length ? latestConnection.deviceName : deviceKey,
        deviceType: latestConnection.deviceType,
        deviceId: deviceKey,
        lastSeenAt: lastSeenAt,
        lastSeenLabel: formatStandardDateTimeOrFallback(lastSeenAt, PLACEHOLDER_TEXT),
        policyIndex: policy?.policy === 'deny' ? PeripheralPolicyOptionIndexes.DENY : PeripheralPolicyOptionIndexes.ALLOW
      } as PeripheralPolicyRecord
    })

    return items.sort((left: PeripheralPolicyRecord, right: PeripheralPolicyRecord) => {
      return right.lastSeenAt - left.lastSeenAt
    })
  }

  static normalizeDeviceIdForPolicy(deviceId: string, deviceType?: PeripheralType): string {
    const parsed = parseUsbDeviceId(deviceId)
    if (parsed) {
      return formatUsbDeviceId(parsed.vendorId, parsed.productId).toUpperCase()
    }

    const normalizedRaw = (deviceId || '').trim().replace(/\s+/g, ' ')
    if (normalizedRaw.length === 0) {
      return ''
    }

    if (deviceType === PeripheralType.BLUETOOTH || PeripheralPolicyService.looksLikeBluetoothDeviceId(normalizedRaw)) {
      return PeripheralPolicyService.normalizeBluetoothDeviceId(normalizedRaw)
    }

    return normalizedRaw.toUpperCase()
  }

  private static looksLikeBluetoothDeviceId(deviceId: string): boolean {
    const normalized = deviceId.trim().replace(/^MAC:\s*/i, '').replace(/-/g, ':')
    return /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(normalized)
  }

  private static normalizeBluetoothDeviceId(deviceId: string): string {
    const normalized = deviceId.trim().replace(/^MAC:\s*/i, '')
    if (!PeripheralPolicyService.looksLikeBluetoothDeviceId(normalized)) {
      return ''
    }
    return formatBluetoothDeviceId(normalized).toUpperCase()
  }
}
