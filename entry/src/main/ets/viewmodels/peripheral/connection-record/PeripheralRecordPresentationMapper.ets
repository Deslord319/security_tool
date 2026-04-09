import {
  formatLogTimestamp,
  PeripheralConnectionRecord,
  LogEventResult,
  PeripheralMatchedPolicyKind,
  PeripheralRecordPolicyHit,
  PeripheralType
} from '../../../models/DataModels'
import { PresentationStrings } from '../../../constants/modules/PresentationStrings'
import { CommonLabelStrings, FirewallDialogStrings, ResultStrings } from '../../../constants/modules/DialogStrings'
import { PeripheralStrings } from '../../../constants/modules/PeripheralStrings'

export interface PeripheralConnectionHistoryItem {
  time: string
  policy: string
  result: string
}

export function getPeripheralMatchedPolicyKindLabel(kind?: PeripheralMatchedPolicyKind): string {
  switch (kind) {
    case 'usb_disabled':
      return PeripheralStrings.matchedPolicyUsbDisabled
    case 'usb_storage_disabled':
      return PeripheralStrings.matchedPolicyUsbStorageDisabled
    case 'usb_storage_read_only':
      return PeripheralStrings.matchedPolicyUsbStorageReadOnly
    case 'device_deny':
      return PeripheralStrings.matchedPolicyDeviceDeny
    case 'bluetooth_connection_event':
      return PeripheralStrings.matchedPolicyBluetoothConnection
    case 'bluetooth_discovery':
      return PeripheralStrings.matchedPolicyBluetoothDiscovery
    case 'default_allow':
      return PeripheralStrings.matchedPolicyDefaultAllow
    case 'disconnect_event':
      return PeripheralStrings.matchedPolicyDisconnectEvent
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
      return CommonLabelStrings.UNKNOWN
  }
}

export function getPeripheralConnectionPolicyLabel(record: PeripheralConnectionRecord): string {
  if (record.source === 'policy_snapshot') {
    return PeripheralStrings.policyPending
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
    return '已禁用'
  }

  if (record.deviceType === PeripheralType.BLUETOOTH) {
    return '已启用'
  }

  return '已启用'
}

export function getPeripheralConnectionResultLabel(record: PeripheralConnectionRecord): string {
  if (record.source === 'policy_snapshot') {
      return PresentationStrings.sourcePolicySnapshot
  }
  switch (record.result) {
    case LogEventResult.SUCCESS:
      return ResultStrings.SUCCESS
    case LogEventResult.BLOCKED:
      return PresentationStrings.logResultBlocked
    case LogEventResult.FAILED:
      return ResultStrings.FAILED
    default:
      return CommonLabelStrings.UNKNOWN
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
