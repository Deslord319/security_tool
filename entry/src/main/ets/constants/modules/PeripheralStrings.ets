import { FirewallDialogStrings } from './FirewallStrings'
import { LabelText, MessageText, StorageAccessText } from '../StringCatalog'

export class PeripheralReasonCodes {
  static readonly INIT_FAILED: string = 'init_failed'
  static readonly ADMIN_REQUIRED: string = 'admin_required'
  static readonly INVALID_DEVICE_ID: string = 'invalid_device_id'
  static readonly EXPORT_ENV_NOT_READY: string = 'export_env_not_ready'
  static readonly EMPTY_CONNECTION_HISTORY: string = 'empty_connection_history'
  static readonly EMPTY_POLICY_RECORDS: string = 'empty_policy_records'
  static readonly TOGGLE_INTERFACE_FAILED: string = 'toggle_interface_failed'
  static readonly USB_STORAGE_POLICY_FAILED: string = 'usb_storage_policy_failed'
  static readonly POLICY_CHANGE_FAILED: string = 'policy_change_failed'
  static readonly UNSUPPORTED_POLICY_DISPATCH: string = 'unsupported_policy'
  static readonly UNSUPPORTED_DEVICE_TYPE_DISPATCH: string = 'unsupported_device_type'
  static readonly DEVICE_POLICY_DISPATCH_NOT_IMPLEMENTED: string = 'device_policy_dispatch_not_implemented'
  static readonly USB_CONFLICT_ACCOUNT_STORAGE: string = 'usb_conflict_account_storage'
  static readonly USB_DISPATCH_FAILED: string = 'usb_dispatch_failed'
  static readonly USB_DISPATCH_CONFLICT_UNRESOLVED: string = 'usb_dispatch_conflict_unresolved'
  static readonly EXPORT_CONNECTION_HISTORY_FAILED: string = 'export_connection_history_failed'
  static readonly EXPORT_POLICY_RECORDS_FAILED: string = 'export_policy_records_failed'
  static readonly READ_USB_STATUS_FAILED: string = 'read_usb_status'
  static readonly READ_USB_STORAGE_POLICY_FAILED: string = 'read_usb_storage_policy'
  static readonly SET_USB_INTERFACE_CONFLICT: string = 'set_usb_interface'
  static readonly SET_USB_STORAGE_POLICY_CONFLICT: string = 'set_usb_storage_policy'
}

export class PeripheralOptionStrings {
  static readonly POLICY_OPTIONS: string[] = ['允许接入', '禁止接入']
  static readonly INTERFACE_TOGGLE_OPTIONS: string[] = ['启用', '禁用']
  static readonly USB_STORAGE_OPTIONS: string[] = [
    StorageAccessText.READ_ONLY,
    StorageAccessText.READ_WRITE,
    StorageAccessText.BLOCKED
  ]
}

export class PeripheralInterfaceToggleOptionIndexes {
  static readonly ENABLED: number = 0
  static readonly DISABLED: number = 1
  static readonly DEFAULT: number = PeripheralInterfaceToggleOptionIndexes.ENABLED
}

export class PeripheralTabIndexes {
  static readonly INTERFACE_CONTROL: number = 0
  static readonly CONNECTION_RECORD: number = 1
  static readonly DEVICE_POLICY: number = 2
  static values(): number[] {
    return [
      PeripheralTabIndexes.INTERFACE_CONTROL,
      PeripheralTabIndexes.CONNECTION_RECORD,
      PeripheralTabIndexes.DEVICE_POLICY
    ]
  }

  static normalize(index: number): number {
    if (index < PeripheralTabIndexes.INTERFACE_CONTROL) {
      return PeripheralTabIndexes.INTERFACE_CONTROL
    }
    if (index > PeripheralTabIndexes.DEVICE_POLICY) {
      return PeripheralTabIndexes.DEVICE_POLICY
    }
    return index
  }

  static isValid(index: number): boolean {
    return PeripheralTabIndexes.values().includes(index)
  }
}

export class PeripheralPolicyOptionIndexes {
  static readonly ALLOW: number = 0
  static readonly DENY: number = 1
  static readonly DEFAULT: number = 0
}

export class PeripheralLoadingStrings {
  static readonly USB_INTERFACE: string = '正在设置 USB 接口策略，请稍候...'
  static readonly USB_STORAGE: string = '正在设置 USB 存储策略，请稍候...'
}

export class PeripheralPageStrings {
  static readonly SUBTITLE: string = '管控 USB、蓝牙、Wi-Fi 等外设接口，配置设备黑白名单策略'
  static readonly INTERFACE_TAB: string = '接口管控'
  static readonly DEVICE_TAB: string = '设备连接记录'
  static readonly POLICY_TAB: string = '黑白名单'
  static readonly ACTION_LABEL: string = '操作'
  static readonly POLICY_LABEL: string = '策略'
  static readonly DEVICE_NAME_LABEL: string = '设备名称'
  static readonly DEVICE_TYPE_LABEL: string = '设备类型'
  static readonly CONNECTION_TIME_LABEL: string = '连接时间'
  static readonly LATEST_CONNECTION_TIME_LABEL: string = '最近连接时间'
}

export class PeripheralInterfaceStrings {
  static readonly USB_INTERFACE_TITLE: string = 'USB 接口'
  static readonly USB_INTERFACE_DESCRIPTION: string = '启用或禁用 USB 接口。禁用后，USB 接口相关外设将无法接入。'
  static readonly BLUETOOTH_TITLE: string = '蓝牙'
  static readonly BLUETOOTH_DESCRIPTION: string = '启用或禁用蓝牙接口。'
  static readonly WIFI_TITLE: string = 'Wi-Fi'
  static readonly WIFI_DESCRIPTION: string = '启用或禁用 Wi-Fi 接口。'
  static readonly HDC_TITLE: string = 'HDC 调试'
  static readonly HDC_DESCRIPTION: string = '启用或禁用 HDC 调试接口。'
  static readonly NETWORK_SHARING_TITLE: string = '网络共享'
  static readonly NETWORK_SHARING_DESCRIPTION: string = '启用或禁用网络共享接口。'
  static readonly PRINTER_TITLE: string = '打印机'
  static readonly PRINTER_DESCRIPTION: string = '启用或禁用打印机接口。'
  static readonly MICROPHONE_TITLE: string = '麦克风'
  static readonly MICROPHONE_DESCRIPTION: string = '启用或禁用麦克风接口。'
  static readonly CAMERA_TITLE: string = '摄像头'
  static readonly CAMERA_DESCRIPTION: string = '启用或禁用摄像头接口。'
  static readonly USB_STORAGE_DESCRIPTION: string = '设置 USB 存储设备的访问权限，可选只读、读写或禁止访问。'
}

export class PeripheralMatchedPolicyStrings {
  static readonly USB_DISABLED: string = 'USB 接口已禁用'
  static readonly USB_STORAGE_DISABLED: string = 'USB 存储已禁用'
  static readonly USB_STORAGE_READ_ONLY: string = 'USB 存储只读'
  static readonly DEVICE_DENY: string = '命中单设备禁止接入'
  static readonly BLUETOOTH_CONNECTION: string = '蓝牙连接事件'
  static readonly BLUETOOTH_DISCOVERY: string = '蓝牙运行期发现'
  static readonly DEFAULT_ALLOW: string = '默认允许接入'
  static readonly DISCONNECT_EVENT: string = '设备断开连接'
  static readonly PENDING: string = '待判定'
  static readonly UNKNOWN_DEVICE: string = '未知设备'
}

export class PeripheralConnectionRecordStrings {
  static readonly UNNAMED_BLUETOOTH: string = '未命名蓝牙设备'
  static readonly BLUETOOTH_CONNECTED: string = '蓝牙设备已连接'
  static readonly BLUETOOTH_DISCONNECTED: string = '蓝牙设备已断开'
  static readonly USB_DISCONNECTED: string = '设备已断开'
  static readonly USB_INTERFACE_DISABLED_DETAIL: string = 'USB 接口已被总控禁用，设备接入被阻止。'
  static readonly USB_STORAGE_DISABLED_DETAIL: string = 'USB 存储策略为禁止访问，设备接入被阻止。'
  static readonly USB_STORAGE_READ_ONLY_DETAIL: string = 'USB 存储策略为只读模式。'
  static readonly DEFAULT_ALLOW: string = '按当前策略允许接入'
  static readonly DEFAULT_ALLOW_DETAIL: string = '未命中更高优先级的阻断策略，按默认规则允许接入。'
  static readonly USB_DEVICE: string = 'USB 设备'
  static readonly UNRECOGNIZED_USB_DEVICE: string = '未识别 USB 设备'
  static readonly DEVICE_DENY_DETAIL_TEMPLATE: string = '设备 {deviceId} 命中禁止接入策略，已被阻止。'
  static readonly DISCONNECT_DETAIL_TEMPLATE: string = '{deviceName} 已断开连接，断开前生效策略为：{policyLabel}。'
  static readonly FIRST_CONNECT_AUTO_DENY_DETAIL: string = '首次接入已自动加入黑名单'
  static readonly FIRST_CONNECT_AUTO_DENY_FAILED_PREFIX: string = '自动加入黑名单失败：'

  static buildDeviceDenyDetail(deviceId: string): string {
    return PeripheralConnectionRecordStrings.DEVICE_DENY_DETAIL_TEMPLATE.replace('{deviceId}', deviceId)
  }

  static buildDisconnectDetail(deviceName: string, policyLabel: string): string {
    return PeripheralConnectionRecordStrings.DISCONNECT_DETAIL_TEMPLATE
      .replace('{deviceName}', deviceName)
      .replace('{policyLabel}', policyLabel)
  }

  static appendAutoDenySavedDetail(detail: string): string {
    return `${detail}; ${PeripheralConnectionRecordStrings.FIRST_CONNECT_AUTO_DENY_DETAIL}`
  }

  static appendAutoDenyFailedDetail(detail: string, reason?: string): string {
    return `${detail}; ${PeripheralConnectionRecordStrings.FIRST_CONNECT_AUTO_DENY_FAILED_PREFIX}${reason ?? 'unknown'}`
  }
}

export class PeripheralExportStrings {
  static readonly CONNECTION_HISTORY_FILE_PREFIX: string = 'peripheral_connection_history'
  static readonly POLICY_LIST_FILE_PREFIX: string = 'peripheral_policy_list'
  static readonly DOWNLOAD_PATH_PREFIX: string = '下载'
  static readonly SUCCESS_PREFIX: string = '导出成功：'
  static readonly HISTORY_LABEL: string = '导出记录'
  static readonly CLEAR_HISTORY_LABEL: string = '清理记录'
  static readonly EXPORT_POLICY_LABEL: string = '导出名单'
  static readonly CLEAR_POLICY_LABEL: string = '还原策略'
  static readonly CLEAR_HISTORY_MESSAGE: string = '将清空当前设备连接记录，且无法恢复。是否继续？'
  static readonly CLEAR_POLICY_MESSAGE: string = '将还原当前所有黑白名单配置，设备会恢复默认允许接入。是否继续？'
  static get CONNECTION_HISTORY_CSV_HEADERS(): string[] {
    return [
    LabelText.TIME,
    PeripheralPageStrings.DEVICE_NAME_LABEL,
    PeripheralPageStrings.DEVICE_TYPE_LABEL,
    DeviceDetailStrings.DEVICE_ID,
    DeviceDetailStrings.CONNECTION_EVENT,
    '策略命中',
    DeviceDetailStrings.RESULT_STATUS,
    DeviceDetailStrings.EVENT_SOURCE
    ]
  }
  static get POLICY_LIST_CSV_HEADERS(): string[] {
    return [
    PeripheralPageStrings.DEVICE_NAME_LABEL,
    PeripheralPageStrings.DEVICE_TYPE_LABEL,
    DeviceDetailStrings.DEVICE_ID,
    '最近出现时间',
    FirewallDialogStrings.CURRENT_STATUS
    ]
  }
}

export class PeripheralActionStrings {
  static readonly SET_INTERFACE: string = '设置接口策略'
  static readonly SET_USB_STORAGE: string = '设置 USB 存储策略'
  static readonly UPDATE_POLICY: string = '修改黑白名单'
}

export class PeripheralEmptyStateStrings {
  static readonly HISTORY_TO_CLEAR: string = '暂无可清理的记录'
  static readonly POLICY_TO_CLEAR: string = '暂无可还原的黑白名单配置'
  static readonly CLEAR_FAILED: string = '清理未完成，请稍后重试'
  static readonly CLEAR_HISTORY_SUCCESS: string = '记录已清理'
  static readonly CLEAR_POLICY_SUCCESS: string = '黑白名单已还原，设备已恢复默认允许接入'
}

export const PERIPHERAL_ADMIN_REQUIRED_ACTION_SUFFIX: string = '未完成，请先激活企业管理员权限'

function buildPeripheralRetryMessage(prefix: string): string {
  return `${prefix}，${MessageText.RETRY_LATER}`
}

export function resolvePeripheralReason(reason?: string | null): string {
  switch (reason) {
    case PeripheralReasonCodes.ADMIN_REQUIRED:
      return '请先激活企业管理员权限'
    case PeripheralReasonCodes.INIT_FAILED:
      return buildPeripheralRetryMessage('外设管理初始化失败')
    case PeripheralReasonCodes.INVALID_DEVICE_ID:
      return '无法识别当前设备标识'
    case PeripheralReasonCodes.EXPORT_ENV_NOT_READY:
      return buildPeripheralRetryMessage('导出环境尚未初始化')
    case PeripheralReasonCodes.EMPTY_CONNECTION_HISTORY:
      return '没有可导出的设备连接记录'
    case PeripheralReasonCodes.EMPTY_POLICY_RECORDS:
      return '暂无可导出的黑白名单配置'
    case PeripheralReasonCodes.TOGGLE_INTERFACE_FAILED:
      return buildPeripheralRetryMessage('接口管控设置失败')
    case PeripheralReasonCodes.USB_STORAGE_POLICY_FAILED:
      return buildPeripheralRetryMessage('设置 USB 存储策略失败')
    case PeripheralReasonCodes.POLICY_CHANGE_FAILED:
      return buildPeripheralRetryMessage('修改黑白名单失败')
    case PeripheralReasonCodes.UNSUPPORTED_POLICY_DISPATCH:
      return buildPeripheralRetryMessage('当前策略类型暂不支持下发')
    case PeripheralReasonCodes.UNSUPPORTED_DEVICE_TYPE_DISPATCH:
      return buildPeripheralRetryMessage('当前设备类型暂不支持下发')
    case PeripheralReasonCodes.DEVICE_POLICY_DISPATCH_NOT_IMPLEMENTED:
      return buildPeripheralRetryMessage('当前设备策略下发能力尚未接入')
    case PeripheralReasonCodes.USB_CONFLICT_ACCOUNT_STORAGE:
      return '系统检测到 USB 存储账户级冲突策略，暂时无法修改单设备策略'
    case PeripheralReasonCodes.USB_DISPATCH_FAILED:
      return buildPeripheralRetryMessage('USB 单设备策略下发失败')
    case PeripheralReasonCodes.USB_DISPATCH_CONFLICT_UNRESOLVED:
      return '系统检测到 USB 冲突规则未完成消解，暂时无法修改单设备策略'
    case PeripheralReasonCodes.EXPORT_CONNECTION_HISTORY_FAILED:
      return buildPeripheralRetryMessage('导出记录失败')
    case PeripheralReasonCodes.EXPORT_POLICY_RECORDS_FAILED:
      return buildPeripheralRetryMessage('导出策略失败')
    case PeripheralReasonCodes.READ_USB_STATUS_FAILED:
      return buildPeripheralRetryMessage('读取 USB 状态失败')
    case PeripheralReasonCodes.READ_USB_STORAGE_POLICY_FAILED:
      return buildPeripheralRetryMessage('读取 USB 存储策略失败')
    case PeripheralReasonCodes.SET_USB_INTERFACE_CONFLICT:
      return buildPeripheralRetryMessage('系统检测到仍存在 USB 冲突规则，暂时无法完成 USB 接口设置')
    case PeripheralReasonCodes.SET_USB_STORAGE_POLICY_CONFLICT:
      return buildPeripheralRetryMessage('系统检测到仍存在 USB 冲突规则，暂时无法完成存储策略设置')
    default:
      return reason && reason.trim().length > 0 ? reason : MessageText.RETRY_LATER
  }
}

export class DeviceDetailStrings {
  static readonly TITLE: string = '设备详情'
  static readonly KEY_INFO: string = '关键信息'
  static readonly HISTORY_TITLE: string = '历史连接记录'
  static readonly NO_HISTORY: string = '暂无历史连接记录'
  static readonly NO_RECORDS: string = '当前没有可展示的连接记录'
  static readonly HISTORY_COUNT_SUFFIX: string = '条'
  static readonly DEVICE_ID: string = '设备标识'
  static readonly RECENT_TIME: string = '最近时间'
  static readonly CONNECTION_EVENT: string = '连接事件'
  static readonly EVENT_SOURCE: string = '事件来源'
  static readonly POLICY_RESULT: string = '策略结论'
  static readonly EFFECTIVE_POLICY: string = '执行策略'
  static readonly MATCH_TYPE: string = '命中类型'
  static readonly RESULT_STATUS: string = '结果状态'
}

export class DeviceTypeLabels {
  static readonly USB_STORAGE: string = 'USB 存储设备'
  static readonly USB_CAMERA: string = 'USB 摄像头'
  static readonly USB_PRINTER: string = 'USB 打印机'
  static readonly USB_HID: string = 'USB 人机输入设备'
  static readonly USB_OTHER: string = 'USB 其他设备'
  static readonly BLUETOOTH: string = '蓝牙设备'
}

export class PeripheralSourcePresentationStrings {
  static readonly RUNTIME_EVENT: string = '运行时事件'
  static readonly AUDIT_EVENT: string = '审计事件'
  static readonly POLICY_SNAPSHOT: string = '策略快照'
  static readonly UNKNOWN: string = '未知来源'
}

export class PeripheralRecordActionPresentationStrings {
  static readonly CONNECT: string = '连接'
  static readonly DISCONNECT: string = '断开'
  static readonly DISCOVER: string = '发现'
  static readonly INTERCEPT: string = '拦截'
  static readonly UNKNOWN: string = '未知动作'
}

export class PeripheralRecordResultPresentationStrings {
  static readonly BLOCKED: string = '已阻止'
}
