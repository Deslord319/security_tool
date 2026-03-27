import { CommonStrings } from '../CommonStrings'

export class LogManageStrings {
  static readonly pageTitle: string = CommonStrings.moduleLogManage
  static readonly settingsTitle: string = '日志存储配置'
  static readonly pageSubtitle: string = '监控崩溃与关键安全日志'
  static readonly settingsSubtitle: string = '配置日志留存与采集诊断'

  static readonly expand: string = '展开'
  static readonly collapse: string = '收起'
  static readonly close: string = '关闭'

  static readonly detailTitle: string = '详情'
  static readonly detailDialogTitle: string = '日志详情'
  static readonly detailEmpty: string = '暂无详情'
  static readonly additionalInfo: string = '附加信息'
  static readonly processLabel: string = '进程'
  static readonly processPrefix: string = '进程'
  static readonly filePathLabel: string = '文件路径'
  static readonly remoteAddressLabel: string = '远端地址'

  static readonly subscribeFailed: string = '订阅失败'
  static readonly subscribed: string = '已订阅'
  static readonly notSubscribed: string = '未订阅'
  static readonly notSubscribedForType: string = '当前未订阅该类型'
  static readonly allEventTypes: string = '全部类型'
  static readonly allResults: string = '全部结果'
  static readonly successOption: string = '成功'
  static readonly blockedOption: string = '已阻止'
  static readonly failedOption: string = '失败'

  static readonly exportLogsButton: string = '导出日志'
  static readonly clearLogsButton: string = '清空日志'
  static readonly openStorageSettingsButton: string = '进入存储设置'
  static readonly saveSettingsButton: string = CommonStrings.actionSaveSettings
  static readonly backToLogListButton: string = '返回日志列表'
  static readonly refreshButton: string = '刷新'
  static readonly clearFilterButton: string = '清除筛选'
  static readonly backToDiagnosticsButton: string = '返回采集诊断'

  static readonly statTotal: string = '总计'
  static readonly statToday: string = '今日'
  static readonly statBlocked: string = '已阻止'
  static readonly statCurrentShown: string = '当前显示'
  static readonly homeMetricLabel: string = '首页数量'
  static readonly recentHitLabel: string = '最近命中'

  static readonly searchPlaceholder: string = '搜索日志内容...'
  static readonly loading: string = '加载中...'
  static readonly emptyTitle: string = '暂无日志记录'
  static readonly emptyDescription: string = '安全事件与崩溃日志将实时显示在此处'

  static readonly pageInputPlaceholder: string = '页码'
  static readonly previousPageButton: string = '上一页'
  static readonly nextPageButton: string = '下一页'
  static readonly jumpButton: string = '跳转'

  static readonly storageConfigTitle: string = '日志存储配置'
  static readonly maxEntriesLabel: string = '最大存储条数'
  static readonly retentionDaysLabel: string = '日志保留天数'
  static readonly diagnosticsTitle: string = '采集诊断'

  static readonly noExportableLogs: string = '没有可导出的日志'
  static readonly exportFailedPrefix: string = '日志导出失败'
  static readonly exportSuccessPrefix: string = '日志已导出，文件名：'
  static readonly clearConfirmTitle: string = '确认清空'
  static readonly clearConfirmAction: string = '确认清空'
  static readonly clearSuccess: string = '日志已清空'
  static readonly saveSettingsFailed: string = '保存设置失败，请稍后重试'
  static readonly saveSettingsSuccess: string = '日志存储设置已保存'
  static readonly emptyFilteredResult: string = '当前筛选结果为 0，可尝试清空关键词或结果筛选。'
  static readonly accountLogRestricted: string = '用户认证日志在当前设备受系统策略限制（401），并非应用权限缺失。'
  static readonly triggerHint: string = '提示：可先触发对应系统安全操作后再刷新查看。'
  static readonly crashTriggerHint: string = '提示：需等待系统上报 APP_CRASH 或 APP_FREEZE。'
  static readonly fileTriggerHint: string = '提示：只记录用户公共目录或公共媒体文件操作。'
  static readonly permissionTriggerHint: string = '提示：需触发权限授予/撤销等系统权限变更行为。'
  static readonly accountTriggerHint: string = '提示：该类型在部分设备上可能受策略限制。'
  static readonly newApiUnavailableFallback: string = '新订阅 API 不可用，已自动切换到兼容模式。'
  static readonly newApiInitFailedFallback: string = '新订阅 API 初始化失败，已自动切换到兼容模式。'

  static buildSubscribedText(modeText: string): string {
    return `${LogManageStrings.subscribed}(${modeText})`
  }

  static buildPageRangeText(rangeText: string, totalCount: number): string {
    return `显示 ${rangeText} / 共 ${totalCount} 条`
  }

  static buildPageSizeText(pageSize: number): string {
    return `${pageSize} 条/页`
  }

  static buildExportSuccessText(fileName: string): string {
    return `${LogManageStrings.exportSuccessPrefix}${fileName}`
  }

  static buildExportFailedText(reasonText: string): string {
    return `${LogManageStrings.exportFailedPrefix}，${reasonText}`
  }

  static buildClearConfirmMessage(totalCount: number): string {
    return `将清除所有 ${totalCount} 条日志记录，此操作不可撤销。`
  }

  static buildSubscriptionErrorText(eventIds: string, codeText: string): string {
    return `订阅异常：eventId ${eventIds}${codeText}`
  }

  static buildTypeFailedText(eventIds: string, codeText: string, triggerHint: string): string {
    return `该类型订阅失败：eventId ${eventIds}${codeText}。${triggerHint}`
  }

  static buildSessionHitText(seenCount: number): string {
    return `本次会话命中 ${seenCount}`
  }

  static buildSessionHitWithDropText(seenCount: number, droppedCount: number): string {
    return `本次会话命中 ${seenCount} / 过滤 ${droppedCount}`
  }

  static buildFilteredFileEventText(droppedCount: number): string {
    return `当前文件日志仅保留用户文件操作，已过滤 ${droppedCount} 条系统或未知路径事件。`
  }

  static buildPreFilterRollbackText(eventIds: string): string {
    return `前置路径过滤已回退：eventId ${eventIds}`
  }

  static buildPreFilterFailedText(eventIds: string, codeText: string): string {
    return `前置路径过滤异常：eventId ${eventIds}${codeText}`
  }

  static buildDroppedNonUserFileText(droppedCount: number): string {
    return `已丢弃 ${droppedCount} 条非用户文件事件`
  }

  static buildViewingWithHitsText(typeLabel: string, seenCount: number): string {
    return `当前正在查看【${typeLabel}】采集事件，首页当前可见 0 条，本次会话命中 ${seenCount} 条。`
  }

  static buildViewingWithoutHitsText(typeLabel: string): string {
    return `当前正在查看【${typeLabel}】采集事件，该类型暂无命中事件。`
  }

  static buildViewingFilteredText(typeLabel: string, droppedCount: number): string {
    return `当前正在查看【${typeLabel}】采集事件，首页当前可见 0 条，已过滤 ${droppedCount} 条系统或未知路径事件。`
  }

  static buildViewingTotalText(typeLabel: string, totalCount: number): string {
    return `当前正在查看【${typeLabel}】采集事件，共 ${totalCount} 条。`
  }

  static buildNotSubscribedSentence(): string {
    return `${LogManageStrings.notSubscribedForType}。`
  }

  static buildRecentSeenText(lastSeen: string): string {
    return `最近：${lastSeen}`
  }
}
