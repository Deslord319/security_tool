import {
  formatLogTimestamp,
  PeripheralConnectionRecord,
  LogEventResult,
  PeripheralMatchedPolicyKind,
  PeripheralRecordPolicyHit,
  PeripheralType
} from '../../../models/DataModels'
import { LabelText, ResultText, StatusText } from '../../../constants/StringCatalog'
import {
  LogResultPresentationStrings,
  PeripheralSourcePresentationStrings
} from '../../../constants/modules/PresentationStrings'
import { FirewallDialogStrings } from '../../../constants/modules/DialogStrings'
import {
  PeripheralMatchedPolicyStrings
} from '../../../constants/modules/PeripheralStrings'

export interface PeripheralConnectionHistoryItem {
  time: string
  policy: string
  result: string
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
    case 'bluetooth_connection_event':
      return PeripheralMatchedPolicyStrings.BLUETOOTH_CONNECTION
    case 'bluetooth_discovery':
      return PeripheralMatchedPolicyStrings.BLUETOOTH_DISCOVERY
    case 'default_allow':
      return PeripheralMatchedPolicyStrings.DEFAULT_ALLOW
    case 'disconnect_event':
      return PeripheralMatchedPolicyStrings.DISCONNECT_EVENT
    default:
      return '--'
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
    return PeripheralMatchedPolicyStrings.PENDING
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
  if (record.source === 'policy_snapshot') {
    return PeripheralSourcePresentationStrings.POLICY_SNAPSHOT
  }
  switch (record.result) {
    case LogEventResult.SUCCESS:
      return ResultText.SUCCESS
    case LogEventResult.BLOCKED:
      return LogResultPresentationStrings.BLOCKED
    case LogEventResult.FAILED:
      return ResultText.FAILED
    default:
      return LabelText.UNKNOWN
  }
}

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
    history.push(nextItem)
  }
  return history
}
