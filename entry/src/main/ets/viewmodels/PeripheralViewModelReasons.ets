export const REASON_INIT_FAILED = 'init_failed'
export const REASON_ADMIN_REQUIRED = 'admin_required'
export const REASON_INVALID_DEVICE_ID = 'invalid_device_id'
export const REASON_EXPORT_ENV_NOT_READY = 'export_env_not_ready'
export const REASON_EMPTY_CONNECTION_HISTORY = 'empty_connection_history'
export const REASON_EMPTY_POLICY_RECORDS = 'empty_policy_records'
export const REASON_TOGGLE_INTERFACE_FAILED = 'toggle_interface_failed'
export const REASON_USB_STORAGE_POLICY_FAILED = 'usb_storage_policy_failed'
export const REASON_POLICY_CHANGE_FAILED = 'policy_change_failed'
export const REASON_EXPORT_CONNECTION_HISTORY_FAILED = 'export_connection_history_failed'
export const REASON_EXPORT_POLICY_RECORDS_FAILED = 'export_policy_records_failed'
export const REASON_READ_USB_STATUS_FAILED = 'read_usb_status'
export const REASON_READ_USB_STORAGE_POLICY_FAILED = 'read_usb_storage_policy'
export const REASON_READ_USB_WHITELIST_FAILED = 'read_usb_whitelist'
export const REASON_READ_USB_BLACKLIST_FAILED = 'read_usb_blacklist'
export const REASON_PRECHECK_BLACKLIST_CONFLICT = 'precheck_blacklist_conflict'
export const REASON_PRECHECK_WHITELIST_CONFLICT = 'precheck_whitelist_conflict'
export const REASON_INFER_BLACKLIST_TYPE_FAILED = 'infer_blacklist_type'
export const REASON_SET_USB_INTERFACE_CONFLICT = 'set_usb_interface'
export const REASON_SET_USB_STORAGE_POLICY_CONFLICT = 'set_usb_storage_policy'

export class PeripheralViewModelReasons {
  static readonly REASON_INIT_FAILED: string = REASON_INIT_FAILED
  static readonly REASON_ADMIN_REQUIRED: string = REASON_ADMIN_REQUIRED
  static readonly REASON_INVALID_DEVICE_ID: string = REASON_INVALID_DEVICE_ID
  static readonly REASON_EXPORT_ENV_NOT_READY: string = REASON_EXPORT_ENV_NOT_READY
  static readonly REASON_EMPTY_CONNECTION_HISTORY: string = REASON_EMPTY_CONNECTION_HISTORY
  static readonly REASON_EMPTY_POLICY_RECORDS: string = REASON_EMPTY_POLICY_RECORDS
  static readonly REASON_TOGGLE_INTERFACE_FAILED: string = REASON_TOGGLE_INTERFACE_FAILED
  static readonly REASON_USB_STORAGE_POLICY_FAILED: string = REASON_USB_STORAGE_POLICY_FAILED
  static readonly REASON_POLICY_CHANGE_FAILED: string = REASON_POLICY_CHANGE_FAILED
  static readonly REASON_EXPORT_CONNECTION_HISTORY_FAILED: string = REASON_EXPORT_CONNECTION_HISTORY_FAILED
  static readonly REASON_EXPORT_POLICY_RECORDS_FAILED: string = REASON_EXPORT_POLICY_RECORDS_FAILED
  static readonly REASON_READ_USB_STATUS_FAILED: string = REASON_READ_USB_STATUS_FAILED
  static readonly REASON_READ_USB_STORAGE_POLICY_FAILED: string = REASON_READ_USB_STORAGE_POLICY_FAILED
  static readonly REASON_READ_USB_WHITELIST_FAILED: string = REASON_READ_USB_WHITELIST_FAILED
  static readonly REASON_READ_USB_BLACKLIST_FAILED: string = REASON_READ_USB_BLACKLIST_FAILED
  static readonly REASON_PRECHECK_BLACKLIST_CONFLICT: string = REASON_PRECHECK_BLACKLIST_CONFLICT
  static readonly REASON_PRECHECK_WHITELIST_CONFLICT: string = REASON_PRECHECK_WHITELIST_CONFLICT
  static readonly REASON_INFER_BLACKLIST_TYPE_FAILED: string = REASON_INFER_BLACKLIST_TYPE_FAILED
  static readonly REASON_SET_USB_INTERFACE_CONFLICT: string = REASON_SET_USB_INTERFACE_CONFLICT
  static readonly REASON_SET_USB_STORAGE_POLICY_CONFLICT: string = REASON_SET_USB_STORAGE_POLICY_CONFLICT
}

export class PeripheralPageConstant {
  static readonly policyOptions: string[] = ['允许接入', '禁止访问']

  static readonly usbLoadingMessage: string = '正在更新 USB 策略，请稍候...'
  static readonly usbInterfaceLoadingMessage: string = '正在设置 USB 接口策略，请稍候...'
  static readonly usbStorageLoadingMessage: string = '正在设置 USB 存储策略，请稍候...'

  static readonly pageTitle: string = '外设管理'
  static readonly pageSubtitle: string = '管控 USB、蓝牙、Wi-Fi 等外设接口，配置设备访问策略'

  static readonly interfaceTabTitle: string = '接口管控'
  static readonly deviceTabTitle: string = '设备连接记录'
  static readonly policyTabTitle: string = '黑白名单'

  static readonly exportHistoryLabel: string = '导出历史记录'
  static readonly clearHistoryLabel: string = '清理历史记录'
  static readonly exportPolicyLabel: string = '导出策略记录'
  static readonly clearPolicyLabel: string = '删除策略记录'

  static readonly setInterfaceAction: string = '设置接口策略'
  static readonly setUsbStorageAction: string = '设置 USB 存储策略'
  static readonly updatePolicyAction: string = '修改设备策略'

  static readonly clearHistoryTitle: string = '清理历史记录'
  static readonly clearHistoryMessage: string = '将清空当前设备连接历史记录，且无法恢复。是否继续？'
  static readonly clearPolicyTitle: string = '删除策略记录'
  static readonly clearPolicyMessage: string = '将清空当前策略记录列表，且无法恢复。是否继续？'

  static readonly cancelLabel: string = '取消'
  static readonly clearLabel: string = '清理'
  static readonly deleteLabel: string = '删除'

  static readonly emptyHistoryToClear: string = '暂无可清理的历史记录'
  static readonly emptyPolicyToClear: string = '暂无可清理的策略记录'
  static readonly clearFailed: string = '清理未完成，请稍后重试'
  static readonly clearHistorySuccess: string = '历史记录已清理'
  static readonly clearPolicySuccess: string = '策略记录已清理'
  static readonly exportHistorySuccess: string = '历史记录已导出，保存位置：下载/安全管理中心'
  static readonly exportPolicySuccess: string = '策略记录已导出，保存位置：下载/安全管理中心'
  static readonly minUsbLoadingDuration: number = 500
}

export function resolvePeripheralReason(reason?: string | null): string {
  switch (reason) {
    case REASON_ADMIN_REQUIRED:
      return '请先激活企业管理员权限'
    case REASON_INIT_FAILED:
      return '外设管理初始化失败，请稍后重试'
    case REASON_INVALID_DEVICE_ID:
      return '无法识别当前设备标识'
    case REASON_EXPORT_ENV_NOT_READY:
      return '导出环境尚未初始化，请稍后重试'
    case REASON_EMPTY_CONNECTION_HISTORY:
      return '没有可导出的设备连接记录'
    case REASON_EMPTY_POLICY_RECORDS:
      return '暂无可导出的设备策略记录'
    case REASON_TOGGLE_INTERFACE_FAILED:
      return '接口管控设置失败，请稍后重试'
    case REASON_USB_STORAGE_POLICY_FAILED:
      return '设置 USB 存储策略失败，请稍后重试'
    case REASON_POLICY_CHANGE_FAILED:
      return '修改设备策略失败，请稍后重试'
    case REASON_EXPORT_CONNECTION_HISTORY_FAILED:
      return '导出历史记录失败，请稍后重试'
    case REASON_EXPORT_POLICY_RECORDS_FAILED:
      return '导出策略记录失败，请稍后重试'
    case REASON_READ_USB_STATUS_FAILED:
      return '读取 USB 状态失败，请稍后重试'
    case REASON_READ_USB_STORAGE_POLICY_FAILED:
      return '读取 USB 存储策略失败，请稍后重试'
    case REASON_READ_USB_WHITELIST_FAILED:
      return '读取 USB 白名单失败，请稍后重试'
    case REASON_READ_USB_BLACKLIST_FAILED:
      return '读取 USB 黑名单失败，请稍后重试'
    case REASON_PRECHECK_BLACKLIST_CONFLICT:
      return '当前存在 USB 禁止访问规则冲突，请先清理后再设置允许接入'
    case REASON_PRECHECK_WHITELIST_CONFLICT:
      return '当前存在 USB 允许接入规则冲突，请先清理后再设置禁止访问'
    case REASON_INFER_BLACKLIST_TYPE_FAILED:
      return '当前设备类型暂不支持设置为禁止访问'
    case REASON_SET_USB_INTERFACE_CONFLICT:
      return '系统检测到仍存在 USB 冲突规则，暂时无法完成 USB 接口设置，请稍后重试'
    case REASON_SET_USB_STORAGE_POLICY_CONFLICT:
      return '系统检测到仍存在 USB 冲突规则，暂时无法完成存储策略设置，请稍后重试'
    default:
      return reason && reason.trim().length > 0 ? reason : '请稍后重试'
  }
}
