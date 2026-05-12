import { LabelText, ResultText } from '../StringCatalog'
import { LogEventResult, LogEventType } from '../../models/LogModels'

export class LogManagePageStrings {
  static readonly SETTINGS_TITLE: string = '日志存储配置'
  static readonly SUBTITLE: string = '监控和审计系统安全事件日志'
  static readonly SETTINGS_SUBTITLE: string = '配置日志留存、自动导出与审计诊断'
}

export class LogManageDetailStrings {
  static readonly DIALOG_TITLE: string = '日志详情'
  static readonly SUMMARY: string = '摘要'
  static readonly TIME_LABEL: string = '时间'
  static readonly EVENT_TYPE_LABEL: string = '事件类型'
  static readonly RESULT_LABEL: string = '结果'
  static readonly STRUCTURED_DETAILS: string = '结构化详情'
  static readonly EMPTY: string = '暂无详情'
  static readonly PROCESS_LABEL: string = '进程'
}

export class LogManageFilterStrings {
  static readonly ALL_EVENT_TYPES: string = '全部类型'
  static readonly ALL_RESULTS: string = '全部结果'
  static readonly ALL_TIME: string = '全部时间'
  static readonly LAST_1_HOUR: string = '最近1小时'
  static readonly LAST_12_HOURS: string = '最近12小时'
  static readonly LAST_24_HOURS: string = '最近24小时'
  static readonly LAST_3_DAYS: string = '最近3天'
  static readonly SEARCH_PLACEHOLDER: string = '搜索日志内容...'
}

export class LogManageActionStrings {
  static readonly IMPORT_LOGS: string = '添加日志'
  static readonly EXPORT_LOGS: string = '导出日志'
  static readonly CLEAR_LOGS: string = '清空日志'
  static readonly OPEN_STORAGE_SETTINGS: string = '存储设置'
  static readonly BACK_TO_LOG_LIST: string = '日志列表'
}

export class LogManageImportStrings {
  static readonly USER_CANCELED: string = '已取消导入'
  static readonly INVALID_ARCHIVE: string = '请选择 zip 格式日志包'
  static readonly EXTRACT_FAILED: string = '日志包解压失败'
  static readonly SAVE_FAILED: string = '日志入库失败'

  static buildSuccessMessage(inserted: number, skipped: number, expired: number, dropped: number, failed: number): string {
    return `导入完成：新增 ${inserted} 条，重复跳过 ${skipped} 条，过期跳过 ${expired} 条，丢弃 ${dropped} 条，失败 ${failed} 条。`
  }
}

export class LogManageImportDetailStrings {
  static readonly RULE_ID: string = '规则ID'
  static readonly CATEGORY: string = '类别'
  static readonly SOURCE_FILE: string = '来源文件'
  static readonly LINE_NUMBER: string = '原始行号'
}

export class LogManageKernelImportStrings {
  static readonly CATEGORY_SECURITY_DENIED: string = '安全访问控制拒绝'
  static readonly CATEGORY_BINDER_PERMISSION: string = 'Binder/IPC 权限失败'
  static readonly CATEGORY_HMDEC: string = 'DEC 规则设置'
  static readonly CATEGORY_FS_DEVFS: string = 'DEC 设备文件事件'
}

export class LogManageStatStrings {
  static readonly TOTAL: string = '总计'
  static readonly TODAY: string = '今日'
  static readonly CURRENT_SHOWN: string = '当前显示'
  static readonly TOTAL_DESCRIPTION: string = '全部日志数量'
  static readonly TODAY_DESCRIPTION: string = '今日新增日志'
  static readonly BLOCKED_DESCRIPTION: string = '阻止结果事件'
  static readonly CURRENT_SHOWN_DESCRIPTION: string = '当前页显示数量'
}

export class LogManageEmptyStateStrings {
  static readonly TITLE: string = '暂无日志记录'
}

export class LogManageSettingStrings {
  static readonly MAX_ENTRIES_LABEL: string = '最大存储条数'
  static readonly MAX_ENTRIES_DESCRIPTION: string = '选择本地最多保留的日志数量，达到上限后会按时间清理旧日志。'
  static readonly RETENTION_DAYS_LABEL: string = '日志保留天数'
  static readonly RETENTION_DAYS_DESCRIPTION: string = '选择日志在本地保留的时间，到期后会自动清理历史日志。'
  static readonly SAVE_SUCCESS: string = '设置已保存'
}

export class LogManageClearingStrings {
  static readonly NO_EXPORTABLE_LOGS: string = '当前没有可导出的日志'
  static readonly CONFIRM_TITLE: string = '确认清空'
  static readonly SUCCESS: string = '日志已清空'

  static buildConfirmMessage(totalCount: number): string {
    return `确认清空当前全部 ${totalCount} 条日志吗？该操作不可恢复。`
  }
}

export class LogManagePaginationStrings {
  static readonly PAGE_INPUT_PLACEHOLDER: string = '页码'

  static buildPageRangeText(rangeText: string, totalCount: number): string {
    return `${rangeText} / 共 ${totalCount} 条`
  }

  static buildPageSizeText(pageSize: number): string {
    return `${pageSize} 条/页`
  }
}

export class LogManageCsvStrings {
  static readonly EVENT_TYPE: string = '事件类型'
  static readonly PROCESS_NAME: string = '进程名'
  static readonly PID: string = 'PID'
  static readonly RESULT: string = '结果'

  static get HEADERS(): string[] {
    return [
      LabelText.TIME,
      LogManageCsvStrings.EVENT_TYPE,
      LabelText.DETAIL,
      LogManageCsvStrings.PROCESS_NAME,
      LogManageCsvStrings.PID,
      LogManageCsvStrings.RESULT
    ]
  }

  static buildHeader(): string {
    return LogManageCsvStrings.HEADERS.join(',')
  }
}

export class LogManageAuditStrings {
  static readonly FALLBACK_DETAIL: string = '安全审计事件'
}

export class LogEventPresentationStrings {
  static readonly CRASH: string = '崩溃日志'
  static readonly FILE: string = '文件操作日志'
  static readonly ACCOUNT: string = '用户认证日志'
  static readonly PERMISSION: string = '权限变更日志'
  static readonly POWER: string = '开关机日志'
  static readonly SYSTEM: string = '系统日志'
  static readonly KERNEL: string = '内核日志'
}

export class LogDeviceLifecycleStrings {
  static readonly BOOT: string = '设备启动'
  static readonly SHUTDOWN_REQUESTED: string = '设备关闭'
}

export class LogResultPresentationStrings {
  static readonly BLOCKED: string = '已阻止'
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
    default:
      return LabelText.UNKNOWN
  }
}

export function resolveLogEventResultLabel(result: LogEventResult): string {
  switch (result) {
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
