import { CommonStrings } from '../CommonStrings'

export class PeripheralStrings {
  static readonly INIT_FAILED: string = 'init_failed'
  static readonly ADMIN_REQUIRED: string = 'admin_required'
  static readonly INVALID_DEVICE_ID: string = 'invalid_device_id'
  static readonly EXPORT_ENV_NOT_READY: string = 'export_env_not_ready'
  static readonly EMPTY_CONNECTION_HISTORY: string = 'empty_connection_history'
  static readonly EMPTY_POLICY_RECORDS: string = 'empty_policy_records'
  static readonly TOGGLE_INTERFACE_FAILED: string = 'toggle_interface_failed'
  static readonly USB_STORAGE_POLICY_FAILED: string = 'usb_storage_policy_failed'
  static readonly POLICY_CHANGE_FAILED: string = 'policy_change_failed'
  static readonly EXPORT_CONNECTION_HISTORY_FAILED: string = 'export_connection_history_failed'
  static readonly EXPORT_POLICY_RECORDS_FAILED: string = 'export_policy_records_failed'
  static readonly READ_USB_STATUS_FAILED: string = 'read_usb_status'
  static readonly READ_USB_STORAGE_POLICY_FAILED: string = 'read_usb_storage_policy'
  static readonly SET_USB_INTERFACE_CONFLICT: string = 'set_usb_interface'
  static readonly SET_USB_STORAGE_POLICY_CONFLICT: string = 'set_usb_storage_policy'

  static readonly policyOptions: string[] = ['允许接入', '禁止接入']

  static readonly usbLoadingMessage: string = '正在更新 USB 策略，请稍候...'
  static readonly usbInterfaceLoadingMessage: string = '正在设置 USB 接口策略，请稍候...'
  static readonly usbStorageLoadingMessage: string = '正在设置 USB 存储策略，请稍候...'

  static readonly pageTitle: string = CommonStrings.modulePeripheralManage
  static readonly pageSubtitle: string = '管控 USB、蓝牙、Wi-Fi 等外设接口，配置设备访问策略'

  static readonly interfaceTabTitle: string = '接口管控'
  static readonly deviceTabTitle: string = '设备连接记录'
  static readonly policyTabTitle: string = '黑白名单'

  static readonly exportHistoryLabel: string = '导出记录'
  static readonly clearHistoryLabel: string = '清理记录'
  static readonly exportPolicyLabel: string = '导出名单'
  static readonly clearPolicyLabel: string = '清空名单'

  static readonly setInterfaceAction: string = '设置接口策略'
  static readonly setUsbStorageAction: string = '设置 USB 存储策略'
  static readonly updatePolicyAction: string = '修改黑白名单'

  static readonly clearHistoryMessage: string = '将清空当前设备连接记录，且无法恢复。是否继续？'
  static readonly clearPolicyMessage: string = '将清空当前所有黑白名单配置，设备会恢复默认允许接入。是否继续？'

  static readonly emptyHistoryToClear: string = '暂无可清理的记录'
  static readonly emptyPolicyToClear: string = '暂无可清空的黑白名单配置'
  static readonly clearFailed: string = '清理未完成，请稍后重试'
  static readonly clearHistorySuccess: string = '记录已清理'
  static readonly clearPolicySuccess: string = '黑白名单已清空，设备已恢复默认允许接入'
  static readonly emptyPolicyTitle: string = '暂无黑白名单设备'
  static readonly emptyPolicyDescription: string = '设备连接后会出现在这里，可按需设置允许或禁止接入。'
  static readonly minUsbLoadingDuration: number = 500

  static readonly adminRequiredActionSuffix: string = '未完成，请先激活企业管理员权限'

  static resolveReason(reason?: string | null): string {
    switch (reason) {
      case PeripheralStrings.ADMIN_REQUIRED:
        return '请先激活企业管理员权限'
      case PeripheralStrings.INIT_FAILED:
        return '外设管理初始化失败，请稍后重试'
      case PeripheralStrings.INVALID_DEVICE_ID:
        return '无法识别当前设备标识'
      case PeripheralStrings.EXPORT_ENV_NOT_READY:
        return '导出环境尚未初始化，请稍后重试'
      case PeripheralStrings.EMPTY_CONNECTION_HISTORY:
        return '没有可导出的设备连接记录'
      case PeripheralStrings.EMPTY_POLICY_RECORDS:
        return '暂无可导出的黑白名单配置'
      case PeripheralStrings.TOGGLE_INTERFACE_FAILED:
        return '接口管控设置失败，请稍后重试'
      case PeripheralStrings.USB_STORAGE_POLICY_FAILED:
        return '设置 USB 存储策略失败，请稍后重试'
      case PeripheralStrings.POLICY_CHANGE_FAILED:
        return '修改黑白名单失败，请稍后重试'
      case PeripheralStrings.EXPORT_CONNECTION_HISTORY_FAILED:
        return '导出记录失败，请稍后重试'
      case PeripheralStrings.EXPORT_POLICY_RECORDS_FAILED:
        return '导出策略失败，请稍后重试'
      case PeripheralStrings.READ_USB_STATUS_FAILED:
        return '读取 USB 状态失败，请稍后重试'
      case PeripheralStrings.READ_USB_STORAGE_POLICY_FAILED:
        return '读取 USB 存储策略失败，请稍后重试'
      case PeripheralStrings.SET_USB_INTERFACE_CONFLICT:
        return '系统检测到仍存在 USB 冲突规则，暂时无法完成 USB 接口设置，请稍后重试'
      case PeripheralStrings.SET_USB_STORAGE_POLICY_CONFLICT:
        return '系统检测到仍存在 USB 冲突规则，暂时无法完成存储策略设置，请稍后重试'
      default:
        return reason && reason.trim().length > 0 ? reason : '请稍后重试'
    }
  }
}
