import {
  PeripheralConnectionRecord,
  PeripheralMatchedPolicyKind,
  PeripheralRecordAction,
  PeripheralRecordPolicyHit,
  PeripheralRecordSource,
  PeripheralType
} from '../../../models/PeripheralModels'
import { SecurityEventResult } from '../../../models/CommonModels'
import { LabelText, PLACEHOLDER_TEXT, ResultText, StatusText } from '../../../constants/StringCatalog'
import { FirewallDialogStrings } from '../../../constants/modules/FirewallStrings'
import {
  DeviceTypeLabels,
  PeripheralMatchedPolicyStrings,
  PeripheralRecordActionPresentationStrings,
  PeripheralRecordResultPresentationStrings,
  PeripheralSourcePresentationStrings
} from '../../../constants/modules/PeripheralStrings'
import { formatStandardDateTimeOrFallback } from '../../../utils/DateTimeFormatUtils'

export interface PeripheralConnectionHistoryItem {
  time: string
  policy: string
  result: string
}

export function getPeripheralTypeLabel(type: PeripheralType): string {
  switch (type) {
    case PeripheralType.USB_STORAGE:
      return DeviceTypeLabels.USB_STORAGE
    case PeripheralType.USB_CAMERA:
      return DeviceTypeLabels.USB_CAMERA
    case PeripheralType.USB_PRINTER:
      return DeviceTypeLabels.USB_PRINTER
    case PeripheralType.USB_HID:
      return DeviceTypeLabels.USB_HID
    case PeripheralType.USB_OTHER:
      return DeviceTypeLabels.USB_OTHER
    case PeripheralType.BLUETOOTH:
      return DeviceTypeLabels.BLUETOOTH
    default:
      return LabelText.UNKNOWN
  }
}

export function getPeripheralRecordSourceLabel(source: PeripheralRecordSource): string {
  switch (source) {
    case 'runtime_event':
      return PeripheralSourcePresentationStrings.RUNTIME_EVENT
    case 'audit_event':
      return PeripheralSourcePresentationStrings.AUDIT_EVENT
    case 'policy_snapshot':
      return PeripheralSourcePresentationStrings.POLICY_SNAPSHOT
    default:
      return PeripheralSourcePresentationStrings.UNKNOWN
  }
}

export function getPeripheralRecordActionLabel(action: PeripheralRecordAction): string {
  switch (action) {
    case 'connect':
      return PeripheralRecordActionPresentationStrings.CONNECT
    case 'disconnect':
      return PeripheralRecordActionPresentationStrings.DISCONNECT
    case 'discover':
      return PeripheralRecordActionPresentationStrings.DISCOVER
    case 'intercept':
      return PeripheralRecordActionPresentationStrings.INTERCEPT
    default:
      return PeripheralRecordActionPresentationStrings.UNKNOWN
  }
}

export function getPeripheralConnectionActionLabel(record: PeripheralConnectionRecord): string {
  if (record.source === 'policy_snapshot') {
    return PeripheralRecordActionPresentationStrings.POLICY_CHANGE
  }
  return getPeripheralRecordActionLabel(record.action)
}

export function getPeripheralMatchedPolicyKindLabel(kind?: PeripheralMatchedPolicyKind): string {
  switch (kind) {
    case 'usb_disabled':
      return PeripheralMatchedPolicyStrings.USB_DISABLED
    case 'usb_storage_disabled':
      return PeripheralMatchedPolicyStrings.USB_STORAGE_DISABLED
    case 'usb_storage_read_only':
      return PeripheralMatchedPolicyStrings.USB_STORAGE_READ_ONLY
    case 'device_deny':
      return PeripheralMatchedPolicyStrings.DEVICE_DENY
    case 'bluetooth_disabled':
      return PeripheralMatchedPolicyStrings.BLUETOOTH_DISABLED
    case 'bluetooth_connection':
      return PeripheralMatchedPolicyStrings.BLUETOOTH_CONNECTION
    case 'default_allow':
      return PeripheralMatchedPolicyStrings.DEFAULT_ALLOW
    case 'disconnect_event':
      return PeripheralMatchedPolicyStrings.DISCONNECT_EVENT
    default:
      return PLACEHOLDER_TEXT
  }
}

function getPolicyHitLabel(policyHit: PeripheralRecordPolicyHit): string {
  switch (policyHit) {
    case 'allow':
      return FirewallDialogStrings.ACTION_ALLOW
    case 'deny':
      return FirewallDialogStrings.ACTION_DENY
    default:
      return LabelText.UNKNOWN
  }
}

export function getPeripheralConnectionPolicyLabel(record: PeripheralConnectionRecord): string {
  if (record.source === 'policy_snapshot') {
    return getPolicyHitLabel(record.policyHit)
  }
  if (record.matchedPolicyKind && record.matchedPolicyKind !== 'unknown') {
    return getPeripheralMatchedPolicyKindLabel(record.matchedPolicyKind)
  }
  return getPolicyHitLabel(record.policyHit)
}

export function getPeripheralConnectionListPolicyLabel(record: PeripheralConnectionRecord): string {
  if (record.effectivePolicyLabel && record.effectivePolicyLabel.trim().length > 0) {
    return record.effectivePolicyLabel
  }

  if (record.matchedPolicyKind === 'device_deny' || record.policyHit === 'deny') {
    return StatusText.DISABLED
  }
  return StatusText.ENABLED
}

export function getPeripheralConnectionResultLabel(record: PeripheralConnectionRecord): string {
  switch (record.result) {
    case SecurityEventResult.SUCCESS:
      return ResultText.SUCCESS
    case SecurityEventResult.BLOCKED:
      return PeripheralRecordResultPresentationStrings.BLOCKED
    case SecurityEventResult.FAILED:
      return ResultText.FAILED
    default:
      return LabelText.UNKNOWN
  }
}

export function formatPeripheralTimestamp(timestamp: number): string {
  return formatStandardDateTimeOrFallback(timestamp, PLACEHOLDER_TEXT)
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
    history.push(nextItem)
  }
  return history
}
