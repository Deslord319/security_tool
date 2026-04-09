import { DeviceDetailStrings, FirewallDialogStrings } from './DialogStrings'
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
  static readonly USB_CONFLICT_GLOBAL_DISABLED: string = 'usb_conflict_global_disabled'
  static readonly USB_CONFLICT_ACCOUNT_STORAGE: string = 'usb_conflict_account_storage'
  static readonly USB_DISPATCH_FAILED: string = 'usb_dispatch_failed'
  static readonly USB_DISPATCH_CONFLICT_UNRESOLVED: string = 'usb_dispatch_conflict_unresolved'
  static readonly BLUETOOTH_CONFLICT_GLOBAL_DISABLED: string = 'bluetooth_conflict_global_disabled'
  static readonly BLUETOOTH_DISPATCH_FAILED: string = 'bluetooth_dispatch_failed'
  static readonly BLUETOOTH_DISPATCH_CONFLICT_UNRESOLVED: string = 'bluetooth_dispatch_conflict_unresolved'
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

export class PeripheralLoadingStrings {
  static readonly USB: string = '正在更新 USB 策略，请稍候...'
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
  static readonly LATEST_SEEN_TIME_LABEL: string = '最近出现时间'
  static readonly POLICY_HIT_LABEL: string = '策略命中'
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
  static readonly CONNECTION_HISTORY_CSV_HEADERS: string[] = [
    LabelText.TIME,
    PeripheralPageStrings.DEVICE_NAME_LABEL,
    PeripheralPageStrings.DEVICE_TYPE_LABEL,
    DeviceDetailStrings.DEVICE_ID,
    DeviceDetailStrings.CONNECTION_EVENT,
    PeripheralPageStrings.POLICY_HIT_LABEL,
    DeviceDetailStrings.RESULT_STATUS,
    DeviceDetailStrings.EVENT_SOURCE
  ]
  static readonly POLICY_LIST_CSV_HEADERS: string[] = [
    PeripheralPageStrings.DEVICE_NAME_LABEL,
    PeripheralPageStrings.DEVICE_TYPE_LABEL,
    DeviceDetailStrings.DEVICE_ID,
    PeripheralPageStrings.LATEST_SEEN_TIME_LABEL,
    FirewallDialogStrings.CURRENT_STATUS
  ]
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
  static readonly EMPTY_POLICY_TITLE: string = '暂无黑白名单设备'
  static readonly EMPTY_POLICY_DESCRIPTION: string = '设备连接后会出现在这里，可按需设置允许或禁止接入。'
}

export class PeripheralRuntimeStrings {
  static readonly UNNAMED_BLUETOOTH_DEVICE: string = '未命名蓝牙设备'
  static readonly DEVICE_DISCONNECTED: string = '设备已断开'
  static readonly USB_INTERFACE_DISABLED_DETAIL: string = 'USB 接口已被总控禁用，设备接入被阻止。'
  static readonly USB_STORAGE_DISABLED_DETAIL: string = 'USB 存储策略为禁止访问，设备接入被阻止。'
  static readonly USB_STORAGE_READ_ONLY_DETAIL: string = 'USB 存储策略为只读模式。'
  static readonly DEFAULT_ALLOW_SUMMARY: string = '按当前策略允许接入'
  static readonly DEFAULT_ALLOW_DETAIL: string = '未命中更高优先级的阻断策略，按默认规则允许接入。'
  static readonly USB_DEVICE_NAME: string = 'USB 设备'
  static readonly UNKNOWN_USB_DEVICE_NAME: string = '未识别 USB 设备'
  static readonly BLUETOOTH_CONNECTED: string = '蓝牙设备已连接'
  static readonly BLUETOOTH_DISCONNECTED: string = '蓝牙设备已断开'
}

export const PERIPHERAL_ADMIN_REQUIRED_ACTION_SUFFIX: string = '未完成，请先激活企业管理员权限'

export function resolvePeripheralReason(reason?: string | null): string {
  switch (reason) {
    case PeripheralReasonCodes.ADMIN_REQUIRED:
      return '请先激活企业管理员权限'
    case PeripheralReasonCodes.INIT_FAILED:
      return '外设管理初始化失败，请稍后重试'
    case PeripheralReasonCodes.INVALID_DEVICE_ID:
      return '无法识别当前设备标识'
    case PeripheralReasonCodes.EXPORT_ENV_NOT_READY:
      return '导出环境尚未初始化，请稍后重试'
    case PeripheralReasonCodes.EMPTY_CONNECTION_HISTORY:
      return '没有可导出的设备连接记录'
    case PeripheralReasonCodes.EMPTY_POLICY_RECORDS:
      return '暂无可导出的黑白名单配置'
    case PeripheralReasonCodes.TOGGLE_INTERFACE_FAILED:
      return '接口管控设置失败，请稍后重试'
    case PeripheralReasonCodes.USB_STORAGE_POLICY_FAILED:
      return '设置 USB 存储策略失败，请稍后重试'
    case PeripheralReasonCodes.POLICY_CHANGE_FAILED:
      return '修改黑白名单失败，请稍后重试'
    case PeripheralReasonCodes.UNSUPPORTED_POLICY_DISPATCH:
      return '当前策略类型暂不支持下发，请稍后重试'
    case PeripheralReasonCodes.UNSUPPORTED_DEVICE_TYPE_DISPATCH:
      return '当前设备类型暂不支持下发，请稍后重试'
    case PeripheralReasonCodes.DEVICE_POLICY_DISPATCH_NOT_IMPLEMENTED:
      return '当前设备策略下发能力尚未接入，请稍后重试'
    case PeripheralReasonCodes.USB_CONFLICT_GLOBAL_DISABLED:
      return 'USB 接口当前处于更高层禁用状态，暂时无法修改单设备策略'
    case PeripheralReasonCodes.USB_CONFLICT_ACCOUNT_STORAGE:
      return '系统检测到 USB 存储账户级冲突策略，暂时无法修改单设备策略'
    case PeripheralReasonCodes.USB_DISPATCH_FAILED:
      return 'USB 单设备策略下发失败，请稍后重试'
    case PeripheralReasonCodes.USB_DISPATCH_CONFLICT_UNRESOLVED:
      return '系统检测到 USB 冲突规则未完成消解，暂时无法修改单设备策略'
    case PeripheralReasonCodes.BLUETOOTH_CONFLICT_GLOBAL_DISABLED:
      return '蓝牙当前处于更高层禁用状态，暂时无法修改单设备策略'
    case PeripheralReasonCodes.BLUETOOTH_DISPATCH_FAILED:
      return '蓝牙单设备策略下发失败，请稍后重试'
    case PeripheralReasonCodes.BLUETOOTH_DISPATCH_CONFLICT_UNRESOLVED:
      return '系统检测到蓝牙冲突规则未完成消解，暂时无法修改单设备策略'
    case PeripheralReasonCodes.EXPORT_CONNECTION_HISTORY_FAILED:
      return '导出记录失败，请稍后重试'
    case PeripheralReasonCodes.EXPORT_POLICY_RECORDS_FAILED:
      return '导出策略失败，请稍后重试'
    case PeripheralReasonCodes.READ_USB_STATUS_FAILED:
      return '读取 USB 状态失败，请稍后重试'
    case PeripheralReasonCodes.READ_USB_STORAGE_POLICY_FAILED:
      return '读取 USB 存储策略失败，请稍后重试'
    case PeripheralReasonCodes.SET_USB_INTERFACE_CONFLICT:
      return '系统检测到仍存在 USB 冲突规则，暂时无法完成 USB 接口设置，请稍后重试'
    case PeripheralReasonCodes.SET_USB_STORAGE_POLICY_CONFLICT:
      return '系统检测到仍存在 USB 冲突规则，暂时无法完成存储策略设置，请稍后重试'
    default:
      return reason && reason.trim().length > 0 ? reason : MessageText.RETRY_LATER
  }
}

export function buildPeripheralRuntimeDeviceDenyDetail(deviceId: string): string {
  return `设备 ${deviceId} 命中禁止接入策略，已被阻止。`
}

export function buildPeripheralDisconnectDetail(deviceName: string, effectivePolicyLabel: string): string {
  return `${deviceName} 已断开连接，断开前生效策略为：${effectivePolicyLabel}。`
}
