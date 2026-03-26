import {
  getLogEventResultLabel,
  getPeripheralRecordPolicyHitLabel,
  PeripheralConnectionRecord,
  PeripheralMatchedPolicyKind
} from '../models/DataModels'

export function getPeripheralMatchedPolicyKindLabel(kind?: PeripheralMatchedPolicyKind): string {
  switch (kind) {
    case 'usb_disabled':
      return 'USB 接口禁用'
    case 'usb_storage_disabled':
      return 'USB 存储已禁用'
    case 'usb_storage_read_only':
      return 'USB 存储只读'
    case 'usb_whitelist':
      return '命中 USB 白名单'
    case 'usb_blacklist':
      return '命中 USB 黑名单'
    case 'default_allow':
      return '默认允许'
    case 'disconnect_event':
      return '断开事件'
    default:
      return '--'
  }
}

export function getPeripheralConnectionPolicyLabel(record: PeripheralConnectionRecord): string {
  if (record.source === 'policy_snapshot') {
    return '未审计'
  }
  if (record.matchedPolicyKind && record.matchedPolicyKind !== 'unknown') {
    return getPeripheralMatchedPolicyKindLabel(record.matchedPolicyKind)
  }
  return getPeripheralRecordPolicyHitLabel(record.policyHit)
}

export function getPeripheralConnectionResultLabel(record: PeripheralConnectionRecord): string {
  if (record.source === 'policy_snapshot') {
    return '快照'
  }
  return getLogEventResultLabel(record.result)
}
