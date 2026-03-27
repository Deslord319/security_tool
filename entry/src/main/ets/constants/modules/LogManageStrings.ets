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
  static readonly filePathLabel: string = '文件路径'
  static readonly remoteAddressLabel: string = '远端地址'

  static readonly subscribeFailed: string = '订阅失败'
  static readonly subscribed: string = '已订阅'
  static readonly notSubscribed: string = '未订阅'
  static readonly notSubscribedForType: string = '当前类型未订阅'

  static readonly allEventTypes: string = '全部类型'
  static readonly allResults: string = '全部结果'
  static readonly successOption: string = '成功'
  static readonly failedOption: string = '失败'

  static readonly exportLogsButton: string = '导出日志'
  static readonly clearLogsButton: string = '清空日志'
  static readonly openStorageSettingsButton: string = '存储设置'
  static readonly backToLogListButton: string = '返回日志列表'
  static readonly refreshButton: string = '刷新'
  static readonly clearFilterButton: string = '清除筛选'
  static readonly backToDiagnosticsButton: string = '返回诊断视图'

  static readonly statTotal: string = '总计'
  static readonly statToday: string = '今日'
  static readonly statBlocked: string = '已阻止'
  static readonly statCurrentShown: string = '当前显示'
  static readonly homeMetricLabel: string = '累计命中'
  static readonly recentHitLabel: string = '最近命中'

  static readonly searchPlaceholder: string = '搜索日志内容...'
  static readonly loading: string = '加载中...'
  static readonly emptyTitle: string = '暂无日志记录'
  static readonly emptyDescription: string = '可以稍后刷新，或检查采集与筛选配置。'
  static readonly emptyFilteredResult: string = '当前筛选条件下没有匹配结果'
  static readonly accountLogRestricted: string = '账户类事件仅在系统支持时可采集'

  static readonly pageInputPlaceholder: string = '页码'
  static readonly previousPageButton: string = '上一页'
  static readonly nextPageButton: string = '下一页'
  static readonly jumpButton: string = '跳转'

  static readonly maxEntriesLabel: string = '最大存储条数'
  static readonly retentionDaysLabel: string = '日志保留天数'
  static readonly diagnosticsTitle: string = '采集诊断'

  static readonly noExportableLogs: string = '当前没有可导出的日志'
  static readonly clearConfirmTitle: string = '确认清空'
  static readonly clearConfirmAction: string = CommonStrings.actionClear
  static readonly clearSuccess: string = '日志已清空'
  static readonly saveSettingsFailed: string = '保存设置失败'
  static readonly saveSettingsSuccess: string = '设置已保存'

  static readonly triggerHint: string = '请触发对应安全事件后再查看诊断结果'
  static readonly crashTriggerHint: string = '请触发一次应用崩溃或异常退出以生成崩溃日志'
  static readonly fileTriggerHint: string = '请执行一次文件访问操作以触发文件审计事件'
  static readonly permissionTriggerHint: string = '请触发一次权限申请或拒绝行为以生成权限事件'
  static readonly accountTriggerHint: string = '请进行一次账户登录、切换或访问行为以生成账户事件'
  static readonly newApiUnavailableFallback: string = '当前设备不支持新版审计接口，已回退到兼容模式'
  static readonly newApiInitFailedFallback: string = '新版审计接口初始化失败，已回退到兼容模式'

  static buildSubscribedText(modeText: string): string {
    return `已订阅（${modeText}）`
  }

  static buildPageRangeText(rangeText: string, totalCount: number): string {
    return `${rangeText} / 共 ${totalCount} 条`
  }

  static buildPageSizeText(pageSize: number): string {
    return `${pageSize} 条/页`
  }

  static buildExportSuccessText(fileName: string): string {
    return `导出成功：${fileName}`
  }

  static buildExportFailedText(reasonText: string): string {
    return `导出失败：${reasonText}`
  }

  static buildClearConfirmMessage(totalCount: number): string {
    return `确认清空当前全部 ${totalCount} 条日志吗？该操作不可恢复。`
  }

  static buildSubscriptionErrorText(eventIds: string, codeText: string): string {
    return `订阅事件 ${eventIds} 失败${codeText}`
  }

  static buildTypeFailedText(eventIds: string, codeText: string, triggerHint: string): string {
    return `当前类型订阅失败，事件 ID：${eventIds}${codeText}。${triggerHint}`
  }

  static buildSessionHitText(seenCount: number): string {
    return `本次会话命中 ${seenCount} 次`
  }

  static buildSessionHitWithDropText(seenCount: number, droppedCount: number): string {
    return `本次会话命中 ${seenCount} 次，过滤 ${droppedCount} 次`
  }

  static buildFilteredFileEventText(droppedCount: number): string {
    return `文件事件中过滤了 ${droppedCount} 条非用户目录记录`
  }

  static buildPreFilterRollbackText(eventIds: string): string {
    return `事件 ${eventIds} 不支持前置路径过滤，已回退到兼容订阅模式`
  }

  static buildPreFilterFailedText(eventIds: string, codeText: string): string {
    return `事件 ${eventIds} 的前置路径过滤设置失败${codeText}`
  }

  static buildDroppedNonUserFileText(droppedCount: number): string {
    return `已丢弃 ${droppedCount} 条非用户目录的文件事件`
  }

  static buildViewingWithHitsText(typeLabel: string, seenCount: number): string {
    return `当前查看 ${typeLabel}，本次会话命中 ${seenCount} 次`
  }

  static buildViewingWithoutHitsText(typeLabel: string): string {
    return `当前查看 ${typeLabel}，尚未命中事件`
  }

  static buildViewingFilteredText(typeLabel: string, droppedCount: number): string {
    return `当前查看 ${typeLabel}，已过滤 ${droppedCount} 条无效记录`
  }

  static buildViewingTotalText(typeLabel: string, totalCount: number): string {
    return `当前查看 ${typeLabel}，共展示 ${totalCount} 条记录`
  }

  static buildNotSubscribedSentence(): string {
    return '当前未建立有效订阅，请检查采集配置'
  }

  static buildRecentSeenText(lastSeen: string): string {
    return `最近：${lastSeen}`
  }

  static buildModeSwitchTimeText(timeText: string): string {
    return `模式切换时间：${timeText}`
  }

  static buildUnknownEventIdsText(eventIds: string): string {
    return `未识别事件 ID：${eventIds}`
  }
}
