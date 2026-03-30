import {
  formatLogTimestamp,
  getPeripheralRecordPolicyHitLabel,
  PeripheralConnectionRecord,
  LogEventResult,
  PeripheralMatchedPolicyKind
} from '../models/DataModels'

export interface PeripheralConnectionHistoryItem {
  time: string
  policy: string
  result: string
}

export function getPeripheralMatchedPolicyKindLabel(kind?: PeripheralMatchedPolicyKind): string {
  switch (kind) {
    case 'usb_disabled':
      return 'USB 接口已禁用'
    case 'usb_storage_disabled':
      return 'USB 存储已禁用'
    case 'usb_storage_read_only':
      return 'USB 存储只读'
    case 'device_deny':
      return '命中单设备禁止接入'
    case 'default_allow':
      return '默认允许接入'
    case 'disconnect_event':
      return '设备断开连接'
    default:
      return '--'
  }
}

export function getPeripheralConnectionPolicyLabel(record: PeripheralConnectionRecord): string {
  if (record.source === 'policy_snapshot') {
    return '待判定'
  }
  if (record.matchedPolicyKind && record.matchedPolicyKind !== 'unknown') {
    return getPeripheralMatchedPolicyKindLabel(record.matchedPolicyKind)
  }
  return getPeripheralRecordPolicyHitLabel(record.policyHit)
}

export function getPeripheralConnectionResultLabel(record: PeripheralConnectionRecord): string {
  if (record.source === 'policy_snapshot') {
    return '策略快照'
  }
  switch (record.result) {
    case LogEventResult.SUCCESS:
      return '成功'
    case LogEventResult.BLOCKED:
      return '已阻止'
    case LogEventResult.FAILED:
      return '失败'
    default:
      return '未知'
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
    const duplicated = history.some((existing: PeripheralConnectionHistoryItem) => {
      return existing.time === nextItem.time &&
        existing.policy === nextItem.policy &&
        existing.result === nextItem.result
    })
    if (!duplicated) {
      history.push(nextItem)
    }
  }
  return history
}
