import {
  formatLogTimestamp,
  formatUsbDeviceId,
  inferUsbBaseClass,
  parseUsbDeviceId,
  PeripheralConnectionRecord,
  PeripheralPolicyRecord,
  PeripheralType
} from '../models/DataModels'
import {
  getPeripheralConnectionPolicyLabel,
  getPeripheralConnectionResultLabel
} from './PeripheralRecordDisplayUtils'

export interface PeripheralConnectionHistoryItem {
  time: string
  policy: string
  result: string
}

export interface PeripheralUsbWhitelistDevice {
  vendorId: number
  productId: number
}

export interface PeripheralUsbBlacklistType {
  baseClass: number
  subClass: number
  protocol: number
}

const USB_RECORD_TYPES: PeripheralType[] = [
  PeripheralType.USB_STORAGE,
  PeripheralType.USB_CAMERA,
  PeripheralType.USB_PRINTER,
  PeripheralType.USB_HID,
  PeripheralType.USB_OTHER
]

export function formatPeripheralTimestamp(timestamp: number): string {
  if (timestamp <= 0) {
    return '--'
  }
  return formatLogTimestamp(timestamp)
}

export function buildConnectionHistoryItems(
  records: PeripheralConnectionRecord[],
  selectedRecord: PeripheralConnectionRecord | null
): PeripheralConnectionHistoryItem[] {
  if (!selectedRecord) {
    return []
  }

  const deviceKey = selectedRecord.deviceId.replace(/\s+/g, '').toUpperCase()
  const history: PeripheralConnectionHistoryItem[] = []
  for (const item of records) {
    if (item.timestamp <= 0) {
      continue
    }
    if (item.deviceId.replace(/\s+/g, '').toUpperCase() !== deviceKey) {
      continue
    }
    const nextItem: PeripheralConnectionHistoryItem = {
      time: formatPeripheralTimestamp(item.timestamp),
      policy: getPeripheralConnectionPolicyLabel(item),
      result: getPeripheralConnectionResultLabel(item)
    }
    if (!history.some((existing: PeripheralConnectionHistoryItem) => {
      return existing.time === nextItem.time &&
        existing.policy === nextItem.policy &&
        existing.result === nextItem.result
    })) {
      history.push(nextItem)
    }
  }
  return history
}

export function buildPeripheralPolicyRecords(
  records: PeripheralConnectionRecord[],
  usbWhitelist: PeripheralUsbWhitelistDevice[],
  usbBlacklist: PeripheralUsbBlacklistType[]
): PeripheralPolicyRecord[] {
  const whitelistKeys: Set<string> = new Set(
    usbWhitelist.map((device: PeripheralUsbWhitelistDevice) => {
      return formatUsbDeviceId(device.vendorId, device.productId).toUpperCase()
    })
  )
  const blacklistKeys: Set<string> = new Set(
    usbBlacklist.map((deviceType: PeripheralUsbBlacklistType) => {
      return `${deviceType.baseClass}|${deviceType.subClass}|${deviceType.protocol}`
    })
  )
  const items: Map<string, PeripheralPolicyRecord> = new Map()

  for (const record of records) {
    if (USB_RECORD_TYPES.indexOf(record.deviceType) < 0) {
      continue
    }
    const parsed = parseUsbDeviceId(record.deviceId)
    if (!parsed) {
      continue
    }
    const deviceKey = formatUsbDeviceId(parsed.vendorId, parsed.productId).toUpperCase()
    const existing = items.get(deviceKey)
    if (existing && existing.lastSeenAt >= record.timestamp) {
      continue
    }

    let policyIndex = 0
    const baseClass = inferUsbBaseClass(record.deviceType)
    if (baseClass > 0 && blacklistKeys.has(`${baseClass}|0|0`)) {
      policyIndex = 1
    } else if (whitelistKeys.has(deviceKey)) {
      policyIndex = 0
    }

    items.set(deviceKey, {
      deviceName: record.deviceName,
      deviceType: record.deviceType,
      deviceId: formatUsbDeviceId(parsed.vendorId, parsed.productId),
      lastSeenAt: record.timestamp,
      lastSeenLabel: formatPeripheralTimestamp(record.timestamp),
      policyIndex: policyIndex
    })
  }

  return Array.from(items.values()).sort((left: PeripheralPolicyRecord, right: PeripheralPolicyRecord) => {
    return right.lastSeenAt - left.lastSeenAt
  })
}
