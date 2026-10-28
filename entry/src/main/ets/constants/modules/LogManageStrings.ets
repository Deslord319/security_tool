import { LabelText } from '../StringCatalog'
import { AppStrings } from '../AppStrings'
import { LogEventType } from '../../models/LogModels'

/**
 * 日志管理模块文案资源门面
 *
 * 文案唯一来源为 resources/{base,en_US}/element/string.json 中的 log_manage_* 资源。
 * 门面保持与旧常量一致的访问方式，内部经 AppStrings 资源管理器按当前 locale 解析，
 * 清空确认、分页范围等动态文案由占位符资源构造。
 *
 * 单元测试环境（AppStrings 未初始化）下门面返回资源名；相关断言必须经门面构造，
 * 不得断言中文或英文字面量。模块顶层常量不得在 AppStrings.init 之前读取本门面，
 * 下拉选项等集合文案统一由 presentation/log-manage/LogPresentation.ets 的惰性函数提供。
 */

export class LogManageDetailStrings {
  static get DIALOG_TITLE(): string {
    return AppStrings.get('log_manage_detail_dialog_title')
  }

  static get TIME_LABEL(): string {
    return AppStrings.get('log_manage_detail_time_label')
  }

  static get EVENT_TYPE_LABEL(): string {
    return AppStrings.get('log_manage_detail_event_type_label')
  }

  static get EVENT_NAME_LABEL(): string {
    return AppStrings.get('log_manage_detail_event_name_label')
  }
}

export class LogManageFilterStrings {

  static get ALL_TIME(): string {
    return AppStrings.get('log_manage_filter_all_time')
  }

  static get LAST_1_HOUR(): string {
    return AppStrings.get('log_manage_filter_last_1_hour')
  }

  static get LAST_12_HOURS(): string {
    return AppStrings.get('log_manage_filter_last_12_hours')
  }

  static get LAST_24_HOURS(): string {
    return AppStrings.get('log_manage_filter_last_24_hours')
  }

  static get LAST_3_DAYS(): string {
    return AppStrings.get('log_manage_filter_last_3_days')
  }

}

export class LogManageImportStrings {
  static get IMPORTING(): string {
    return AppStrings.get('log_manage_import_importing')
  }

  static get ADD_SUCCESS(): string {
    return AppStrings.get('log_manage_import_add_success')
  }

  static get USER_CANCELED(): string {
    return AppStrings.get('log_manage_import_user_canceled')
  }

  static get INVALID_ARCHIVE(): string {
    return AppStrings.get('log_manage_import_invalid_archive')
  }

  static get EXTRACT_FAILED(): string {
    return AppStrings.get('log_manage_import_extract_failed')
  }

  static get SAVE_FAILED(): string {
    return AppStrings.get('log_manage_import_save_failed')
  }
}

export class LogManageKernelImportStrings {
  static get CATEGORY_SECURITY_DENIED(): string {
    return AppStrings.get('log_manage_kernel_import_category_security_denied')
  }

  static get CATEGORY_BINDER_PERMISSION(): string {
    return AppStrings.get('log_manage_kernel_import_category_binder_permission')
  }

  static get CATEGORY_HMDEC(): string {
    return AppStrings.get('log_manage_kernel_import_category_hmdec')
  }

  static get CATEGORY_FS_DEVFS(): string {
    return AppStrings.get('log_manage_kernel_import_category_fs_devfs')
  }
}

export class LogManageSystemImportStrings {
  static get CATEGORY_SERVICE_TIMEOUT(): string {
    return AppStrings.get('log_import_category_system_service_timeout')
  }

  static get CATEGORY_WINDOW_EXCEPTION(): string {
    return AppStrings.get('log_import_category_system_window_exception')
  }

  static get CATEGORY_HISI_DIAG(): string {
    return AppStrings.get('log_import_category_system_hisi_diag')
  }

  static get CATEGORY_FSCK(): string {
    return AppStrings.get('log_import_category_system_fsck')
  }

  static get CATEGORY_RESIZE(): string {
    return AppStrings.get('log_import_category_system_resize')
  }

  static get CATEGORY_MEMINFO(): string {
    return AppStrings.get('log_import_category_system_meminfo')
  }

  static get CATEGORY_MEMVIEW(): string {
    return AppStrings.get('log_import_category_system_memview')
  }

  static get CATEGORY_MEMORY_LEAK(): string {
    return AppStrings.get('log_import_category_system_memory_leak')
  }

  static get CATEGORY_UPDATER_LOG(): string {
    return AppStrings.get('log_import_category_system_updater_log')
  }

  static get CATEGORY_UPDATER_STAGE(): string {
    return AppStrings.get('log_import_category_system_updater_stage')
  }

  static get CATEGORY_INSTALLER(): string {
    return AppStrings.get('log_import_category_system_installer')
  }

  static get CATEGORY_HSLD(): string {
    return AppStrings.get('log_import_category_system_hsld')
  }
}

export class LogManageStatStrings {
  static get TOTAL(): string {
    return AppStrings.get('log_manage_stat_total')
  }

  static get TODAY(): string {
    return AppStrings.get('log_manage_stat_today')
  }

  static get FILTERED(): string {
    return AppStrings.get('log_manage_stat_filtered')
  }

  static get CURRENT_SHOWN(): string {
    return AppStrings.get('log_manage_stat_current_shown')
  }

  static get TOTAL_DESCRIPTION(): string {
    return AppStrings.get('log_manage_stat_total_description')
  }

  static get TODAY_DESCRIPTION(): string {
    return AppStrings.get('log_manage_stat_today_description')
  }

  static get FILTERED_DESCRIPTION(): string {
    return AppStrings.get('log_manage_stat_filtered_description')
  }

  static get CURRENT_SHOWN_DESCRIPTION(): string {
    return AppStrings.get('log_manage_stat_current_shown_description')
  }
}

export class LogManageEmptyStateStrings {
  static get TITLE(): string {
    return AppStrings.get('log_manage_empty_state_title')
  }
}

export class LogManageSettingStrings {

  static get SAVE_SUCCESS(): string {
    return AppStrings.get('log_manage_setting_save_success')
  }
}

export class LogManageClearingStrings {
  static get NO_EXPORTABLE_LOGS(): string {
    return AppStrings.get('log_manage_clearing_no_exportable_logs')
  }

  static get CONFIRM_TITLE(): string {
    return AppStrings.get('log_manage_clearing_confirm_title')
  }

  static get SUCCESS(): string {
    return AppStrings.get('log_manage_clearing_success')
  }

  static buildConfirmMessage(totalCount: number): string {
    return AppStrings.format('log_manage_clearing_confirm_message', totalCount)
  }
}

export class LogManagePaginationStrings {

  static buildPageRangeText(rangeText: string, totalCount: number): string {
    return AppStrings.format('log_manage_pagination_page_range', rangeText, totalCount)
  }

  static buildPageSizeText(pageSize: number): string {
    return AppStrings.format('log_manage_pagination_page_size', pageSize)
  }
}

export class LogManageCsvStrings {
  static get EVENT_TYPE(): string {
    return AppStrings.get('log_manage_csv_event_type')
  }

  static get PROCESS_NAME(): string {
    return AppStrings.get('log_manage_csv_process_name')
  }

  static readonly PID: string = 'PID'

  static get HEADERS(): string[] {
    return [
      LabelText.TIME,
      LogManageCsvStrings.EVENT_TYPE,
      LabelText.DETAIL,
      LogManageCsvStrings.PROCESS_NAME,
      LogManageCsvStrings.PID
    ]
  }
}

export class LogEventPresentationStrings {
  static get CRASH(): string {
    return AppStrings.get('log_manage_event_type_crash')
  }

  static get FILE(): string {
    return AppStrings.get('log_manage_event_type_file')
  }

  static get ACCOUNT(): string {
    return AppStrings.get('log_manage_event_type_account')
  }

  static get PERMISSION(): string {
    return AppStrings.get('log_manage_event_type_permission')
  }

  static get POWER(): string {
    return AppStrings.get('log_manage_event_type_power')
  }

  static get SYSTEM(): string {
    return AppStrings.get('log_manage_event_type_system')
  }

  static get KERNEL(): string {
    return AppStrings.get('log_manage_event_type_kernel')
  }

  static get AUDIT(): string {
    return AppStrings.get('log_manage_event_type_audit')
  }
}

export function resolveLogEventTypeLabel(type: LogEventType): string {
  switch (type) {
    case LogEventType.CRASH:
      return LogEventPresentationStrings.CRASH
    case LogEventType.FILE:
      return LogEventPresentationStrings.FILE
    case LogEventType.ACCOUNT:
      return LogEventPresentationStrings.ACCOUNT
    case LogEventType.PERMISSION:
      return LogEventPresentationStrings.PERMISSION
    case LogEventType.POWER:
      return LogEventPresentationStrings.POWER
    case LogEventType.SYSTEM:
      return LogEventPresentationStrings.SYSTEM
    case LogEventType.KERNEL:
      return LogEventPresentationStrings.KERNEL
    case LogEventType.AUDIT:
      return LogEventPresentationStrings.AUDIT
    default:
      return LabelText.UNKNOWN
  }
}
