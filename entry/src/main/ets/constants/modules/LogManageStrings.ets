import { CommonStrings } from '../CommonStrings'
import { DialogButtonStrings } from './DialogStrings'
import { PresentationStrings } from './PresentationStrings'

export class LogManageStrings {
  static readonly pageTitle: string = '日志管理'
  static readonly settingsTitle: string = '日志存储配置'
  static readonly pageSubtitle: string = '监控崩溃与关键安全日志'
  static readonly settingsSubtitle: string = '配置日志留存设置'

  static readonly detailTitle: string = '详情'
  static readonly detailDialogTitle: string = '日志详情'
  static readonly detailEmpty: string = '暂无详情'
  static readonly additionalInfo: string = '附加信息'
  static readonly processLabel: string = '进程'
  static readonly filePathLabel: string = '文件路径'
  static readonly subscribeFailed: string = '订阅失败'
  static readonly subscribed: string = '已订阅'
  static readonly notSubscribed: string = '未订阅'

  static readonly allEventTypes: string = '全部类型'
  static readonly allResults: string = '全部结果'
  static readonly exportLogsButton: string = '导出日志'
  static readonly clearLogsButton: string = '清空日志'
  static readonly openStorageSettingsButton: string = '存储设置'
  static readonly backToLogListButton: string = '返回日志列表'

  static readonly statTotal: string = '总计'
  static readonly statToday: string = '今日'
  static readonly statCurrentShown: string = '当前显示'
  static readonly statTotalDescription: string = '全部日志数量'
  static readonly statTodayDescription: string = '今日新增日志'
  static readonly statBlockedDescription: string = '阻止结果事件'
  static readonly statCurrentShownDescription: string = '当前页显示数量'

  static readonly searchPlaceholder: string = '搜索日志内容...'
  static readonly emptyTitle: string = '暂无日志记录'
  static readonly emptyDescription: string = '可以稍后刷新，或检查采集与筛选配置。'
  static readonly fileFilterHint: string = '提示：文件日志仅记录当前前台用户目录中的文件操作。'
  static readonly fileFilterEmptyHint: string = '当前文件日志为空，仅会记录当前前台用户目录中的文件操作。'

  static readonly pageInputPlaceholder: string = '页码'
  static readonly previousPageButton: string = '上一页'
  static readonly nextPageButton: string = '下一页'
  static readonly jumpButton: string = '跳转'

  static readonly maxEntriesLabel: string = '最大存储条数'
  static readonly maxEntriesDescription: string = '选择本地最多保留的日志数量，达到上限后会按时间清理旧日志。'
  static readonly retentionDaysLabel: string = '日志保留天数'
  static readonly retentionDaysDescription: string = '选择日志在本地保留的时间，到期后会自动清理历史日志。'

  static readonly noExportableLogs: string = '当前没有可导出的日志'
  static readonly clearConfirmTitle: string = '确认清空'
  static readonly clearSuccess: string = '日志已清空'
  static readonly saveSettingsFailed: string = '保存设置失败'
  static readonly saveSettingsSuccess: string = '设置已保存'

  static buildSubscribedText(modeText: string): string {
    return `已订阅（${modeText}）`
  }

  static buildPageRangeText(rangeText: string, totalCount: number): string {
    return `${rangeText} / 共 ${totalCount} 条`
  }

  static buildPageSizeText(pageSize: number): string {
    return `${pageSize} 条/页`
  }

  static buildExportFailedText(reasonText: string): string {
    return `导出失败：${reasonText}`
  }

  static buildClearConfirmMessage(totalCount: number): string {
    return `确认清空当前全部 ${totalCount} 条日志吗？该操作不可恢复。`
  }
  static readonly auditEventFallbackDetail: string = '安全审计事件'
  static readonly csvHeaderTime: string = '时间'
  static readonly csvHeaderEventType: string = '事件类型'
  static readonly csvHeaderDetail: string = '详情'
  static readonly csvHeaderProcessName: string = '进程名'
  static readonly csvHeaderPid: string = 'PID'
  static readonly csvHeaderResult: string = '结果'

  static buildCsvHeader(): string {
    return [
      LogManageStrings.csvHeaderTime,
      LogManageStrings.csvHeaderEventType,
      LogManageStrings.csvHeaderDetail,
      LogManageStrings.csvHeaderProcessName,
      LogManageStrings.csvHeaderPid,
      LogManageStrings.csvHeaderResult
    ].join(',')
  }
}
