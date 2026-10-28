import { FirewallDialogStrings } from './FirewallStrings'
import { LabelText, MessageText, StorageAccessText } from '../StringCatalog'
import { AppStrings } from '../AppStrings'

/**
 * 外设管理模块文案资源门面
 *
 * 文案唯一来源为 resources/{base,en_US}/element/string.json 中的
 * peripheral_* / device_* 资源，经 AppStrings 资源管理器按当前 locale 解析。
 * PeripheralReasonCodes 只保存稳定原因码；连接记录详情模板使用 %1$s / %2$s
 * 位置占位符；选项数组以惰性 getter 提供，不在模块顶层常量中读取文案门面。
 *
 * 单元测试环境（AppStrings 未初始化）下门面返回资源名；相关断言必须经门面
 * 构造，不得断言中文或英文字面量。
 */
export class PeripheralReasonCodes {
  static readonly INIT_FAILED: string = 'init_failed'
  static readonly ADMIN_REQUIRED: string = 'admin_required'
  static readonly INVALID_DEVICE_ID: string = 'invalid_device_id'
  static readonly EXPORT_ENV_NOT_READY: string = 'export_env_not_ready'
  static readonly EMPTY_CONNECTION_HISTORY: string = 'empty_connection_history'
  static readonly EMPTY_POLICY_RECORDS: string = 'empty_policy_records'
  static readonly TOGGLE_INTERFACE_FAILED: string = 'toggle_interface_failed'
  static readonly WIRED_NETWORK_NOT_CONNECTED: string = 'wired_network_not_connected'
  static readonly USB_STORAGE_POLICY_FAILED: string = 'usb_storage_policy_failed'
  static readonly POLICY_CHANGE_FAILED: string = 'policy_change_failed'
  static readonly UNSUPPORTED_POLICY_DISPATCH: string = 'unsupported_policy'
  static readonly UNSUPPORTED_DEVICE_TYPE_DISPATCH: string = 'unsupported_device_type'
  static readonly DEVICE_POLICY_DISPATCH_NOT_IMPLEMENTED: string = 'device_policy_dispatch_not_implemented'
  static readonly USB_CONFLICT_ACCOUNT_STORAGE: string = 'usb_conflict_account_storage'
  static readonly USB_DISPATCH_FAILED: string = 'usb_dispatch_failed'
  static readonly USB_DISPATCH_CONFLICT_UNRESOLVED: string = 'usb_dispatch_conflict_unresolved'
  static readonly USB_GLOBAL_DISABLED: string = 'usb_global_disabled'
  static readonly DEVICE_POLICY_OFFLINE: string = 'device_policy_offline'
  static readonly EXPORT_CONNECTION_HISTORY_FAILED: string = 'export_connection_history_failed'
  static readonly EXPORT_POLICY_RECORDS_FAILED: string = 'export_policy_records_failed'
  static readonly READ_USB_STATUS_FAILED: string = 'read_usb_status'
  static readonly READ_USB_STORAGE_POLICY_FAILED: string = 'read_usb_storage_policy'
  static readonly SET_USB_INTERFACE_CONFLICT: string = 'set_usb_interface'
  static readonly SET_USB_STORAGE_POLICY_CONFLICT: string = 'set_usb_storage_policy'
  static readonly TURN_ON_WIFI_FAILED: string = 'turn_on_wifi'
  static readonly TURN_ON_BLUETOOTH_FAILED: string = 'turn_on_bluetooth'
}

export class PeripheralOptionStrings {
  static get POLICY_OPTIONS(): string[] {
    return [AppStrings.get('peripheral_option_policy_allow'), AppStrings.get('peripheral_option_policy_deny')]
  }

  static get INTERFACE_TOGGLE_OPTIONS(): string[] {
    return [AppStrings.get('peripheral_option_toggle_enabled'), AppStrings.get('peripheral_option_toggle_disabled')]
  }

  static get USB_STORAGE_OPTIONS(): string[] {
    return [
      StorageAccessText.READ_ONLY,
      StorageAccessText.READ_WRITE,
      StorageAccessText.BLOCKED
    ]
  }
}

export class PeripheralInterfaceToggleOptionIndexes {
  static readonly ENABLED: number = 0
  static readonly DISABLED: number = 1
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
  static get USB_INTERFACE(): string {
    return AppStrings.get('peripheral_loading_usb_interface')
  }

  static get USB_STORAGE(): string {
    return AppStrings.get('peripheral_loading_usb_storage')
  }
}

export class PeripheralPageStrings {
  static get SUBTITLE(): string {
    return AppStrings.get('peripheral_page_subtitle')
  }

  static get INTERFACE_TAB(): string {
    return AppStrings.get('peripheral_page_interface_tab')
  }

  static get DEVICE_TAB(): string {
    return AppStrings.get('peripheral_page_device_tab')
  }

  static get POLICY_TAB(): string {
    return AppStrings.get('peripheral_page_policy_tab')
  }

  static get ACTION_LABEL(): string {
    return AppStrings.get('peripheral_page_action_label')
  }

  static get POLICY_LABEL(): string {
    return AppStrings.get('peripheral_page_policy_label')
  }

  static get DEVICE_NAME_LABEL(): string {
    return AppStrings.get('peripheral_page_device_name_label')
  }

  static get DEVICE_TYPE_LABEL(): string {
    return AppStrings.get('peripheral_page_device_type_label')
  }

  static get CONNECTION_TIME_LABEL(): string {
    return AppStrings.get('peripheral_page_connection_time_label')
  }

  static get LATEST_CONNECTION_TIME_LABEL(): string {
    return AppStrings.get('peripheral_page_latest_connection_time_label')
  }

}

export class PeripheralInterfaceStrings {

  static get BLUETOOTH_TITLE(): string {
    return AppStrings.get('peripheral_interface_bluetooth_title')
  }

  static get BLUETOOTH_DESCRIPTION(): string {
    return AppStrings.get('peripheral_interface_bluetooth_description')
  }

  static get WIFI_TITLE(): string {
    return AppStrings.get('peripheral_interface_wifi_title')
  }

  static get WIFI_DESCRIPTION(): string {
    return AppStrings.get('peripheral_interface_wifi_description')
  }

  static get ETHERNET_TITLE(): string {
    return AppStrings.get('peripheral_interface_ethernet_title')
  }

  static get ETHERNET_DESCRIPTION(): string {
    return AppStrings.get('peripheral_interface_ethernet_description')
  }

  static get HDC_TITLE(): string {
    return AppStrings.get('peripheral_interface_hdc_title')
  }

  static get HDC_DESCRIPTION(): string {
    return AppStrings.get('peripheral_interface_hdc_description')
  }

  static get NETWORK_SHARING_TITLE(): string {
    return AppStrings.get('peripheral_interface_network_sharing_title')
  }

  static get NETWORK_SHARING_DESCRIPTION(): string {
    return AppStrings.get('peripheral_interface_network_sharing_description')
  }

  static get PRINTER_TITLE(): string {
    return AppStrings.get('peripheral_interface_printer_title')
  }

  static get PRINTER_DESCRIPTION(): string {
    return AppStrings.get('peripheral_interface_printer_description')
  }

  static get MICROPHONE_TITLE(): string {
    return AppStrings.get('peripheral_interface_microphone_title')
  }

  static get MICROPHONE_DESCRIPTION(): string {
    return AppStrings.get('peripheral_interface_microphone_description')
  }

  static get CAMERA_TITLE(): string {
    return AppStrings.get('peripheral_interface_camera_title')
  }

  static get CAMERA_DESCRIPTION(): string {
    return AppStrings.get('peripheral_interface_camera_description')
  }

}

export class PeripheralMatchedPolicyStrings {
  static get USB_DISABLED(): string {
    return AppStrings.get('peripheral_matched_usb_disabled')
  }

  static get USB_STORAGE_DISABLED(): string {
    return AppStrings.get('peripheral_matched_usb_storage_disabled')
  }

  static get USB_STORAGE_READ_ONLY(): string {
    return AppStrings.get('peripheral_matched_usb_storage_read_only')
  }

  static get DEVICE_DENY(): string {
    return AppStrings.get('peripheral_matched_device_deny')
  }

  static get BLUETOOTH_DISABLED(): string {
    return AppStrings.get('peripheral_matched_bluetooth_disabled')
  }

  static get BLUETOOTH_CONNECTION(): string {
    return AppStrings.get('peripheral_matched_bluetooth_connection')
  }

  static get DEFAULT_ALLOW(): string {
    return AppStrings.get('peripheral_matched_default_allow')
  }

  static get DISCONNECT_EVENT(): string {
    return AppStrings.get('peripheral_matched_disconnect_event')
  }

  static get UNKNOWN_DEVICE(): string {
    return AppStrings.get('peripheral_matched_unknown_device')
  }
}

export class PeripheralConnectionRecordStrings {
  static get BLUETOOTH_DEVICE(): string {
    return AppStrings.get('peripheral_record_bluetooth_device')
  }

  static get BLUETOOTH_CONNECTED(): string {
    return AppStrings.get('peripheral_record_bluetooth_connected')
  }

  static get BLUETOOTH_DISCONNECTED(): string {
    return AppStrings.get('peripheral_record_bluetooth_disconnected')
  }

  static get BLUETOOTH_POLICY_SNAPSHOT_SUMMARY(): string {
    return AppStrings.get('peripheral_record_bluetooth_policy_snapshot_summary')
  }

  static get USB_DISCONNECTED(): string {
    return AppStrings.get('peripheral_record_usb_disconnected')
  }

  static get USB_STORAGE_DISABLED_DETAIL(): string {
    return AppStrings.get('peripheral_record_usb_storage_disabled_detail')
  }

  static get USB_STORAGE_READ_ONLY_DETAIL(): string {
    return AppStrings.get('peripheral_record_usb_storage_read_only_detail')
  }

  static get DEFAULT_ALLOW(): string {
    return AppStrings.get('peripheral_record_default_allow')
  }

  static get DEFAULT_ALLOW_DETAIL(): string {
    return AppStrings.get('peripheral_record_default_allow_detail')
  }

  static get USB_DEVICE(): string {
    return AppStrings.get('peripheral_record_usb_device')
  }

  static get UNRECOGNIZED_USB_DEVICE(): string {
    return AppStrings.get('peripheral_record_unrecognized_usb_device')
  }

  static get POLICY_SNAPSHOT_SUMMARY(): string {
    return AppStrings.get('peripheral_record_policy_snapshot_summary')
  }

  static get FIRST_CONNECT_AUTO_DENY_DETAIL(): string {
    return AppStrings.get('peripheral_record_first_connect_auto_deny_detail')
  }

  static get FIRST_CONNECT_AUTO_DENY_FAILED_PREFIX(): string {
    return AppStrings.get('peripheral_record_first_connect_auto_deny_failed_prefix')
  }

  static buildPolicySnapshotDetail(deviceId: string, policyLabel: string): string {
    return AppStrings.format('peripheral_record_policy_snapshot_detail', deviceId, policyLabel)
  }

  static buildBluetoothPolicySnapshotDetail(deviceId: string, policyLabel: string): string {
    return AppStrings.format('peripheral_record_bluetooth_policy_snapshot_detail', deviceId, policyLabel)
  }

  static buildDeviceDenyDetail(deviceId: string): string {
    return AppStrings.format('peripheral_record_device_deny_detail', deviceId)
  }

  static buildDisconnectDetail(deviceName: string, policyLabel: string): string {
    return AppStrings.format('peripheral_record_disconnect_detail', deviceName, policyLabel)
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

  static get DOWNLOAD_PATH_PREFIX(): string {
    return AppStrings.get('peripheral_export_download_path_prefix')
  }

  static get SUCCESS_PREFIX(): string {
    return AppStrings.get('peripheral_export_success_prefix')
  }

  static get HISTORY_LABEL(): string {
    return AppStrings.get('peripheral_export_history_label')
  }

  static get CLEAR_HISTORY_LABEL(): string {
    return AppStrings.get('peripheral_export_clear_history_label')
  }

  static get EXPORT_POLICY_LABEL(): string {
    return AppStrings.get('peripheral_export_policy_label')
  }

  static get CLEAR_POLICY_LABEL(): string {
    return AppStrings.get('peripheral_export_clear_policy_label')
  }

  static get CLEAR_HISTORY_MESSAGE(): string {
    return AppStrings.get('peripheral_export_clear_history_message')
  }

  static get CLEAR_POLICY_MESSAGE(): string {
    return AppStrings.get('peripheral_export_clear_policy_message')
  }

  static get CONNECTION_HISTORY_CSV_HEADERS(): string[] {
    return [
      LabelText.TIME,
      PeripheralPageStrings.DEVICE_NAME_LABEL,
      PeripheralPageStrings.DEVICE_TYPE_LABEL,
      DeviceDetailStrings.DEVICE_ID,
      DeviceDetailStrings.CONNECTION_EVENT,
      AppStrings.get('peripheral_export_csv_policy_hit'),
      DeviceDetailStrings.RESULT_STATUS,
      DeviceDetailStrings.EVENT_SOURCE
    ]
  }

  static get POLICY_LIST_CSV_HEADERS(): string[] {
    return [
      PeripheralPageStrings.DEVICE_NAME_LABEL,
      PeripheralPageStrings.DEVICE_TYPE_LABEL,
      DeviceDetailStrings.DEVICE_ID,
      AppStrings.get('peripheral_export_csv_last_seen_time'),
      FirewallDialogStrings.CURRENT_STATUS
    ]
  }
}

export class PeripheralMessageStrings {
  static get SET_INTERFACE_ADMIN_REQUIRED(): string {
    return AppStrings.get('peripheral_message_admin_required_set_interface')
  }

  static get SET_USB_STORAGE_ADMIN_REQUIRED(): string {
    return AppStrings.get('peripheral_message_admin_required_set_usb_storage')
  }

  static get UPDATE_POLICY_ADMIN_REQUIRED(): string {
    return AppStrings.get('peripheral_message_admin_required_update_policy')
  }
}

export class PeripheralEmptyStateStrings {
  static get CLEAR_FAILED(): string {
    return AppStrings.get('peripheral_empty_clear_failed')
  }

  static get CLEAR_HISTORY_SUCCESS(): string {
    return AppStrings.get('peripheral_empty_clear_history_success')
  }

  static get CLEAR_POLICY_SUCCESS(): string {
    return AppStrings.get('peripheral_empty_clear_policy_success')
  }
}

export function resolvePeripheralReason(reason?: string | null): string {
  switch (reason) {
    case PeripheralReasonCodes.ADMIN_REQUIRED:
      return AppStrings.get('peripheral_reason_admin_required')
    case PeripheralReasonCodes.INIT_FAILED:
      return buildPeripheralRetryMessage('peripheral_reason_prefix_init_failed')
    case PeripheralReasonCodes.INVALID_DEVICE_ID:
      return AppStrings.get('peripheral_reason_invalid_device_id')
    case PeripheralReasonCodes.EXPORT_ENV_NOT_READY:
      return buildPeripheralRetryMessage('peripheral_reason_prefix_export_env_not_ready')
    case PeripheralReasonCodes.EMPTY_CONNECTION_HISTORY:
      return AppStrings.get('peripheral_reason_empty_connection_history')
    case PeripheralReasonCodes.EMPTY_POLICY_RECORDS:
      return AppStrings.get('peripheral_reason_empty_policy_records')
    case PeripheralReasonCodes.TOGGLE_INTERFACE_FAILED:
      return buildPeripheralRetryMessage('peripheral_reason_prefix_toggle_interface_failed')
    case PeripheralReasonCodes.WIRED_NETWORK_NOT_CONNECTED:
      return AppStrings.get('peripheral_reason_wired_network_not_connected')
    case PeripheralReasonCodes.USB_STORAGE_POLICY_FAILED:
      return buildPeripheralRetryMessage('peripheral_reason_prefix_usb_storage_policy_failed')
    case PeripheralReasonCodes.POLICY_CHANGE_FAILED:
      return buildPeripheralRetryMessage('peripheral_reason_prefix_policy_change_failed')
    case PeripheralReasonCodes.UNSUPPORTED_POLICY_DISPATCH:
      return buildPeripheralRetryMessage('peripheral_reason_prefix_unsupported_policy_dispatch')
    case PeripheralReasonCodes.UNSUPPORTED_DEVICE_TYPE_DISPATCH:
      return buildPeripheralRetryMessage('peripheral_reason_prefix_unsupported_device_type_dispatch')
    case PeripheralReasonCodes.DEVICE_POLICY_DISPATCH_NOT_IMPLEMENTED:
      return buildPeripheralRetryMessage('peripheral_reason_prefix_device_policy_dispatch_not_implemented')
    case PeripheralReasonCodes.USB_CONFLICT_ACCOUNT_STORAGE:
      return AppStrings.get('peripheral_reason_usb_conflict_account_storage')
    case PeripheralReasonCodes.USB_GLOBAL_DISABLED:
      return AppStrings.get('peripheral_reason_usb_global_disabled')
    case PeripheralReasonCodes.USB_DISPATCH_FAILED:
      return buildPeripheralRetryMessage('peripheral_reason_prefix_usb_dispatch_failed')
    case PeripheralReasonCodes.USB_DISPATCH_CONFLICT_UNRESOLVED:
      return AppStrings.get('peripheral_reason_usb_dispatch_conflict_unresolved')
    case PeripheralReasonCodes.DEVICE_POLICY_OFFLINE:
      return AppStrings.get('peripheral_reason_device_policy_offline')
    case PeripheralReasonCodes.EXPORT_CONNECTION_HISTORY_FAILED:
      return buildPeripheralRetryMessage('peripheral_reason_prefix_export_connection_history_failed')
    case PeripheralReasonCodes.EXPORT_POLICY_RECORDS_FAILED:
      return buildPeripheralRetryMessage('peripheral_reason_prefix_export_policy_records_failed')
    case PeripheralReasonCodes.READ_USB_STATUS_FAILED:
      return buildPeripheralRetryMessage('peripheral_reason_prefix_read_usb_status_failed')
    case PeripheralReasonCodes.READ_USB_STORAGE_POLICY_FAILED:
      return buildPeripheralRetryMessage('peripheral_reason_prefix_read_usb_storage_policy_failed')
    case PeripheralReasonCodes.SET_USB_INTERFACE_CONFLICT:
      return buildPeripheralRetryMessage('peripheral_reason_prefix_set_usb_interface_conflict')
    case PeripheralReasonCodes.SET_USB_STORAGE_POLICY_CONFLICT:
      return AppStrings.get('peripheral_reason_set_usb_storage_policy_conflict')
    default:
      return reason && reason.trim().length > 0 ? reason : MessageText.RETRY_LATER
  }
}

function buildPeripheralRetryMessage(prefixResource: string): string {
  return AppStrings.format('peripheral_reason_retry', AppStrings.get(prefixResource))
}

export class DeviceDetailStrings {
  static get TITLE(): string {
    return AppStrings.get('device_detail_title')
  }

  static get HISTORY_COUNT_SUFFIX(): string {
    return AppStrings.get('device_detail_history_count_suffix')
  }

  static get DEVICE_ID(): string {
    return AppStrings.get('device_detail_device_id')
  }

  static get RECENT_TIME(): string {
    return AppStrings.get('device_detail_recent_time')
  }

  static get CONNECTION_EVENT(): string {
    return AppStrings.get('device_detail_connection_event')
  }

  static get EVENT_SOURCE(): string {
    return AppStrings.get('device_detail_event_source')
  }

  static get POLICY_RESULT(): string {
    return AppStrings.get('device_detail_policy_result')
  }

  static get EFFECTIVE_POLICY(): string {
    return AppStrings.get('device_detail_effective_policy')
  }

  static get MATCH_TYPE(): string {
    return AppStrings.get('device_detail_match_type')
  }

  static get RESULT_STATUS(): string {
    return AppStrings.get('device_detail_result_status')
  }
}

export class DeviceTypeLabels {
  static get USB_STORAGE(): string {
    return AppStrings.get('device_type_usb_storage')
  }

  static get USB_CAMERA(): string {
    return AppStrings.get('device_type_usb_camera')
  }

  static get USB_PRINTER(): string {
    return AppStrings.get('device_type_usb_printer')
  }

  static get USB_HID(): string {
    return AppStrings.get('device_type_usb_hid')
  }

  static get USB_OTHER(): string {
    return AppStrings.get('device_type_usb_other')
  }

  static get BLUETOOTH(): string {
    return AppStrings.get('device_type_bluetooth')
  }
}

export class PeripheralSourcePresentationStrings {
  static get RUNTIME_EVENT(): string {
    return AppStrings.get('peripheral_source_runtime_event')
  }

  static get AUDIT_EVENT(): string {
    return AppStrings.get('peripheral_source_audit_event')
  }

  static get POLICY_SNAPSHOT(): string {
    return AppStrings.get('peripheral_source_policy_snapshot')
  }

  static get UNKNOWN(): string {
    return AppStrings.get('peripheral_source_unknown')
  }
}

export class PeripheralRecordActionPresentationStrings {
  static get CONNECT(): string {
    return AppStrings.get('peripheral_record_action_connect')
  }

  static get DISCONNECT(): string {
    return AppStrings.get('peripheral_record_action_disconnect')
  }

  static get DISCOVER(): string {
    return AppStrings.get('peripheral_record_action_discover')
  }

  static get POLICY_CHANGE(): string {
    return AppStrings.get('peripheral_record_action_policy_change')
  }

  static get INTERCEPT(): string {
    return AppStrings.get('peripheral_record_action_intercept')
  }

  static get UNKNOWN(): string {
    return AppStrings.get('peripheral_record_action_unknown')
  }
}

export class PeripheralRecordResultPresentationStrings {
  static get BLOCKED(): string {
    return AppStrings.get('peripheral_record_result_blocked')
  }
}
