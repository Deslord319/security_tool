import { AppColors, AppStyles } from '../constants/AppConstants'
import { LogAuditService } from '../services/LogAuditService'
import { LogStorageService } from '../services/LogStorageService'
import {
  LogEntry,
  LogEventType,
  LogEventResult,
  LogFilter,
  LogStatistics,
  LogStorageConfig,
  LogSubscriptionConfig,
  LogExportFormat,
  LogEventTypeOption,
  LOG_EVENT_TYPE_OPTIONS,
  LOG_RETENTION_OPTIONS,
  LOG_MAX_ENTRIES_OPTIONS,
  DEFAULT_LOG_STORAGE_CONFIG,
  getLogEventTypeLabel,
  getLogEventResultLabel,
  getLogEventResultColor,
  formatLogTimestamp
} from '../models/DataModels'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

const TAG = 'LogManagePage'

@Component
export struct LogManagePage {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  // ========== 日志数据 ==========
  @State logEntries: LogEntry[] = []
  @State statistics: LogStatistics = {
    totalCount: 0,
    todayCount: 0,
    blockedCount: 0,
    byType: new Map<LogEventType, number>()
  }

  // ========== 过滤状态 ==========
  @State filterEventType: number = -1  // -1 表示全部
  @State filterResult: number = -1     // -1 表示全部
  @State filterKeyword: string = ''
  @State isSubscribed: boolean = false

  // ========== 存储配置 ==========
  @State maxEntriesIndex: number = 2   // 默认 10000
  @State retentionIndex: number = 2    // 默认 30 天
  @State autoExportEnabled: boolean = false

  // ========== UI 状态 ==========
  @State showSettings: boolean = false
  @State isLoading: boolean = false

  // 高频审计事件缓冲与节流
  private pendingEntries: LogEntry[] = []
  private flushTimerId: number = -1
  private refreshTimerId: number = -1
  private isFlushingEntries: boolean = false
  private readonly BATCH_FLUSH_INTERVAL_MS: number = 500
  private readonly REFRESH_INTERVAL_MS: number = 300
  private readonly MAX_PENDING_ENTRIES: number = 1200
  private readonly INTERNAL_LOG_PATH_KEYWORDS: string[] = [
    'preferences/log_settings',
    'preferences/theme_preferences',
    'files/hiappevent/',
    'databases/appevent.db'
  ]

  // 事件类型过滤选项
  private eventTypeFilterOptions: SelectOption[] = [{ value: '全部类型' } as SelectOption]
  private resultFilterOptions: SelectOption[] = [
    { value: '全部结果' } as SelectOption,
    { value: '成功' } as SelectOption,
    { value: '已阻止' } as SelectOption,
    { value: '失败' } as SelectOption
  ]

  aboutToAppear() {
    // 构造事件类型选项
    for (let opt of LOG_EVENT_TYPE_OPTIONS) {
      this.eventTypeFilterOptions.push({ value: opt.label } as SelectOption)
    }

    this.initServices()
  }

  aboutToDisappear() {
    // 取消审计订阅
    LogAuditService.unsubscribe()
    if (this.flushTimerId >= 0) {
      clearTimeout(this.flushTimerId)
      this.flushTimerId = -1
    }
    if (this.refreshTimerId >= 0) {
      clearTimeout(this.refreshTimerId)
      this.refreshTimerId = -1
    }
    this.pendingEntries = []
  }

  async initServices() {
    this.isLoading = true
    try {
      let context = getContext(this) as common.UIAbilityContext
      await LogStorageService.init(context)

      // 加载存储配置到 UI
      let config = LogStorageService.getConfig()
      this.maxEntriesIndex = LOG_MAX_ENTRIES_OPTIONS.indexOf(config.maxLocalEntries)
      if (this.maxEntriesIndex < 0) {
        this.maxEntriesIndex = 2
      }
      this.retentionIndex = LOG_RETENTION_OPTIONS.indexOf(config.retentionDays)
      if (this.retentionIndex < 0) {
        this.retentionIndex = 2
      }
      this.autoExportEnabled = config.autoExportEnabled

      // 加载日志并刷新统计
      this.refreshData()

      // 订阅审计事件
      await this.startSubscription()

      hilog.info(0x0006, TAG, 'Services initialized')
    } catch (err) {
      hilog.error(0x0006, TAG, `initServices failed: ${JSON.stringify(err)}`)
    }
    this.isLoading = false
  }

  // 启动审计事件订阅
  async startSubscription() {
    let subscribeConfig: LogSubscriptionConfig = await LogStorageService.loadSubscriptionConfig()
    let eventTypes = subscribeConfig.subscribeAll ? undefined : subscribeConfig.subscribedTypes

    let success = LogAuditService.subscribe((entry: LogEntry) => {
      this.handleIncomingEntry(entry)
    }, eventTypes)
    this.isSubscribed = success
    let failedEventIds = LogAuditService.getLastSubscribeFailedEventIds()
    if (success && failedEventIds.length > 0) {
      hilog.warn(0x0006, TAG, `Partial subscribe success, failed eventIds: ${failedEventIds.join(',')}`)
      promptAction.showToast({
        message: `已订阅 ${eventTypes ? eventTypes.length : LOG_EVENT_TYPE_OPTIONS.length} 类，部分事件不支持`
      })
      return
    }

    if (!success) {
      let code = LogAuditService.getLastSubscribeErrorCode()
      if (code === 201) {
        promptAction.showToast({ message: '审计订阅失败：权限不足（201）' })
      } else if (code === 401) {
        promptAction.showToast({ message: '审计订阅失败：订阅参数异常（401）' })
      } else if (code !== undefined) {
        promptAction.showToast({ message: `审计订阅失败：错误码 ${code}` })
      } else {
        promptAction.showToast({ message: '审计订阅失败，请检查系统日志' })
      }
    }
  }

  // 处理审计回调（过滤内部事件 + 批量落盘）
  handleIncomingEntry(entry: LogEntry) {
    if (this.shouldIgnoreInternalEntry(entry)) {
      return
    }

    this.pendingEntries.push(entry)
    if (this.pendingEntries.length > this.MAX_PENDING_ENTRIES) {
      let dropped = this.pendingEntries.length - this.MAX_PENDING_ENTRIES
      this.pendingEntries.splice(0, dropped)
      hilog.warn(0x0006, TAG, `Dropped ${dropped} queued log entries due to burst traffic`)
    }

    this.scheduleFlushPendingEntries()
  }

  // 过滤本应用内部持久化产生的 FILE 审计，避免写日志触发自激循环
  shouldIgnoreInternalEntry(entry: LogEntry): boolean {
    if (entry.eventType !== LogEventType.FILE) {
      return false
    }

    let process = (entry.processName || '').toLowerCase()
    let content = `${entry.filePath || ''} ${entry.detail || ''}`.toLowerCase()
    let fromSelfProcess = process.includes('com.example.securitytool')

    for (let keyword of this.INTERNAL_LOG_PATH_KEYWORDS) {
      if (content.includes(keyword)) {
        return true
      }
    }

    return fromSelfProcess && content.includes('com.example.securitytool')
  }

  // 安排批量落盘
  scheduleFlushPendingEntries() {
    if (this.flushTimerId >= 0) {
      return
    }

    this.flushTimerId = setTimeout(() => {
      this.flushTimerId = -1
      this.flushPendingEntries()
    }, this.BATCH_FLUSH_INTERVAL_MS)
  }

  // 执行批量落盘，降低主线程与 I/O 压力
  async flushPendingEntries() {
    if (this.isFlushingEntries || this.pendingEntries.length === 0) {
      return
    }

    this.isFlushingEntries = true
    let batch = this.pendingEntries.slice(0, this.pendingEntries.length)
    this.pendingEntries = []

    let saved = await LogStorageService.addEntries(batch)
    if (saved) {
      this.scheduleRefreshData()
    }

    this.isFlushingEntries = false
    if (this.pendingEntries.length > 0) {
      this.scheduleFlushPendingEntries()
    }
  }

  // 节流刷新列表，避免每条事件重绘
  scheduleRefreshData() {
    if (this.refreshTimerId >= 0) {
      return
    }

    this.refreshTimerId = setTimeout(() => {
      this.refreshTimerId = -1
      this.refreshData()
    }, this.REFRESH_INTERVAL_MS)
  }

  // 刷新数据
  refreshData() {
    let filter = this.buildFilter()
    this.logEntries = LogStorageService.queryEntries(filter)
    this.statistics = LogStorageService.getStatistics()
  }

  // 构建过滤条件
  buildFilter(): LogFilter | undefined {
    let hasFilter = false
    let filter: LogFilter = {}

    if (this.filterEventType >= 0) {
      filter.eventTypes = [this.filterEventType as LogEventType]
      hasFilter = true
    }

    if (this.filterResult >= 0) {
      filter.results = [this.filterResult as LogEventResult]
      hasFilter = true
    }

    if (this.filterKeyword.length > 0) {
      filter.keyword = this.filterKeyword
      hasFilter = true
    }

    return hasFilter ? filter : undefined
  }

  // 导出日志
  exportLogs(format: LogExportFormat) {
    let entries = this.logEntries
    if (entries.length === 0) {
      promptAction.showToast({ message: '没有可导出的日志' })
      return
    }

    let content = LogStorageService.exportToString(entries, format)
    hilog.info(0x0006, TAG, `Export ${format}: ${content.length} chars, ${entries.length} entries`)
    promptAction.showToast({ message: `已导出 ${entries.length} 条日志（${format.toUpperCase()}）` })
  }

  // 清空日志
  clearLogs() {
    AlertDialog.show({
      title: '确认清空',
      message: `将清除所有 ${this.statistics.totalCount} 条日志记录，此操作不可撤销。`,
      primaryButton: {
        value: '确认清空',
        action: async () => {
          await LogStorageService.clearAll()
          this.refreshData()
          promptAction.showToast({ message: '日志已清空' })
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    })
  }

  // 保存存储设置
  async saveStorageSettings() {
    let config: LogStorageConfig = {
      maxLocalEntries: LOG_MAX_ENTRIES_OPTIONS[this.maxEntriesIndex],
      retentionDays: LOG_RETENTION_OPTIONS[this.retentionIndex],
      autoExportEnabled: this.autoExportEnabled
    }
    let success = await LogStorageService.updateConfig(config)
    if (success) {
      promptAction.showToast({ message: '存储设置已保存' })
    } else {
      promptAction.showToast({ message: '保存失败' })
    }
  }

  build() {
    Column() {
      // 页面头部
      Row() {
        Column({ space: 4 }) {
          Text('日志管理')
            .fontSize(AppStyles.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          Text('监控和审计系统安全事件日志')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 订阅状态指示
        Row({ space: 6 }) {
          Circle({ width: 8, height: 8 })
            .fill(this.isSubscribed ? AppColors.SUCCESS : '#9E9E9E')
          Text(this.isSubscribed ? '已订阅' : '订阅失败')
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        }

        Button(this.showSettings ? '返回日志' : '存储设置')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
          .borderRadius(AppStyles.RADIUS_SM)
          .height(32)
          .padding({ left: 12, right: 12 })
          .margin({ left: 12 })
          .onClick(() => {
            this.showSettings = !this.showSettings
          })
      }
      .width('100%')
      .padding({
        left: AppStyles.PADDING_LG,
        right: AppStyles.PADDING_LG,
        top: AppStyles.PADDING_LG
      })

      if (this.showSettings) {
        this.storageSettingsView()
      } else {
        // 统计卡片
        this.statisticsBar()

        // 过滤工具栏
        this.filterToolbar()

        // 日志列表
        this.logListView()

        // 底部操作栏
        this.bottomToolbar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  // ==================== 统计卡片行 ====================
  @Builder
  statisticsBar() {
    Row({ space: 12 }) {
      this.statItem('总计', this.statistics.totalCount.toString(), AppColors.BRAND_PRIMARY)
      this.statItem('今日', this.statistics.todayCount.toString(), AppColors.SUCCESS)
      this.statItem('已阻止', this.statistics.blockedCount.toString(), AppColors.WARNING)
      this.statItem('当前显示', this.logEntries.length.toString(), '#9E9E9E')
    }
    .width('100%')
    .padding({
      left: AppStyles.PADDING_LG,
      right: AppStyles.PADDING_LG,
      top: AppStyles.PADDING_MD
    })
  }

  @Builder
  statItem(label: string, value: string, color: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
    }
    .layoutWeight(1)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_MD)
    .alignItems(HorizontalAlign.Center)
  }

  // ==================== 过滤工具栏 ====================
  @Builder
  filterToolbar() {
    Row({ space: 8 }) {
      // 事件类型筛选
      Select(this.eventTypeFilterOptions)
        .selected(this.filterEventType + 1) // +1 因为 "全部类型" 在第 0 项
        .value(this.filterEventType < 0 ? '全部类型' :
          getLogEventTypeLabel(this.filterEventType as LogEventType))
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
        .optionFont({ size: AppStyles.FONT_SIZE_BODY })
        .width(120)
        .onSelect((index: number) => {
          this.filterEventType = index - 1 // 0 = 全部，1+ = 对应枚举值
          this.refreshData()
        })

      // 结果筛选
      Select(this.resultFilterOptions)
        .selected(this.filterResult + 1)
        .value(this.filterResult < 0 ? '全部结果' :
          getLogEventResultLabel(this.filterResult as LogEventResult))
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
        .optionFont({ size: AppStyles.FONT_SIZE_BODY })
        .width(110)
        .onSelect((index: number) => {
          this.filterResult = index - 1
          this.refreshData()
        })

      // 关键字搜索
      TextInput({ placeholder: '搜索日志内容...', text: this.filterKeyword })
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .layoutWeight(1)
        .onChange((value: string) => {
          this.filterKeyword = value
          this.refreshData()
        })

      // 刷新按钮
      Button('刷新')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .onClick(() => {
          this.refreshData()
        })
    }
    .width('100%')
    .padding({
      left: AppStyles.PADDING_LG,
      right: AppStyles.PADDING_LG,
      top: AppStyles.PADDING_SM
    })
  }

  // ==================== 日志列表 ====================
  @Builder
  logListView() {
    if (this.isLoading) {
      Column() {
        LoadingProgress()
          .width(48)
          .height(48)
        Text('加载中...')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .margin({ top: 8 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.logEntries.length === 0) {
      Column({ space: 8 }) {
        Text('暂无日志记录')
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        Text('系统安全审计事件将实时显示在此处')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 1 }) {
        ForEach(this.logEntries, (entry: LogEntry) => {
          ListItem() {
            this.logEntryRow(entry)
          }
        }, (entry: LogEntry) => entry.id)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({
        left: AppStyles.PADDING_LG,
        right: AppStyles.PADDING_LG,
        top: AppStyles.PADDING_SM
      })
      .scrollBar(BarState.Auto)
    }
  }

  @Builder
  logEntryRow(entry: LogEntry) {
    Row() {
      // 时间
      Text(formatLogTimestamp(entry.timestamp))
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .width(140)
        .fontFamily('monospace')

      // 事件类型标签
      Text(getLogEventTypeLabel(entry.eventType))
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
        .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
        .borderRadius(4)
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .width(72)
        .textAlign(TextAlign.Center)

      // 详情
      Column({ space: 2 }) {
        Text(entry.detail)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (entry.processName) {
          Text(`进程: ${entry.processName}${entry.pid !== undefined ? ` (PID: ${entry.pid})` : ''}`)
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            .maxLines(1)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 8 })

      // 结果标签
      Text(getLogEventResultLabel(entry.result))
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(getLogEventResultColor(entry.result))
        .fontWeight(FontWeight.Medium)
        .width(50)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_SM)
    .alignItems(VerticalAlign.Center)
  }

  // ==================== 底部操作栏 ====================
  @Builder
  bottomToolbar() {
    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    Row({ space: 12 }) {
      // 导出按钮组
      Button('导出 JSON')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
        .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .layoutWeight(1)
        .onClick(() => {
          this.exportLogs(LogExportFormat.JSON)
        })

      Button('导出 CSV')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT)
        .backgroundColor(AppColors.getColors(this.currentTheme).TAG_GREEN_BG)
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .layoutWeight(1)
        .onClick(() => {
          this.exportLogs(LogExportFormat.CSV)
        })

      Button('导出 TXT')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
        .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .layoutWeight(1)
        .onClick(() => {
          this.exportLogs(LogExportFormat.TXT)
        })

      Button('清空日志')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TAG_RED_TEXT)
        .backgroundColor(AppColors.getColors(this.currentTheme).TAG_RED_BG)
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .layoutWeight(1)
        .onClick(() => {
          this.clearLogs()
        })
    }
    .width('100%')
    .padding({
      left: AppStyles.PADDING_LG,
      right: AppStyles.PADDING_LG,
      top: AppStyles.PADDING_MD,
      bottom: AppStyles.PADDING_MD
    })
  }

  // ==================== 存储设置视图 ====================
  @Builder
  storageSettingsView() {
    Scroll() {
      Column({ space: 24 }) {
        // 存储配置区
        Column({ space: 0 }) {
          Row() {
            Text('日志存储配置')
              .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            Blank()
            Text('Preferences')
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TAG_TEAL_TEXT)
              .backgroundColor(AppColors.getColors(this.currentTheme).TAG_TEAL_BG)
              .borderRadius(4)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 12 })

          Divider()
            .color(AppColors.getColors(this.currentTheme).BORDER)
            .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          // 最大存储条数
          Row() {
            Column({ space: 2 }) {
              Text('最大存储条数')
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
              Text('超出后自动删除最早的记录')
                .fontSize(AppStyles.FONT_SIZE_CAPTION)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Select(LOG_MAX_ENTRIES_OPTIONS.map((v): SelectOption =>
              ({ value: v.toLocaleString() + ' 条' } as SelectOption)))
              .selected(this.maxEntriesIndex)
              .value(LOG_MAX_ENTRIES_OPTIONS[this.maxEntriesIndex].toLocaleString() + ' 条')
              .font({ size: AppStyles.FONT_SIZE_BODY })
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
              .optionFont({ size: AppStyles.FONT_SIZE_BODY })
              .width(120)
              .onSelect((index: number) => {
                this.maxEntriesIndex = index
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })

          Divider()
            .color(AppColors.getColors(this.currentTheme).BORDER)
            .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          // 保留天数
          Row() {
            Column({ space: 2 }) {
              Text('日志保留天数')
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
              Text('超过保留期的日志自动清除')
                .fontSize(AppStyles.FONT_SIZE_CAPTION)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Select(LOG_RETENTION_OPTIONS.map((v): SelectOption =>
              ({ value: v + ' 天' } as SelectOption)))
              .selected(this.retentionIndex)
              .value(LOG_RETENTION_OPTIONS[this.retentionIndex] + ' 天')
              .font({ size: AppStyles.FONT_SIZE_BODY })
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
              .optionFont({ size: AppStyles.FONT_SIZE_BODY })
              .width(100)
              .onSelect((index: number) => {
                this.retentionIndex = index
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })

          Divider()
            .color(AppColors.getColors(this.currentTheme).BORDER)
            .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          // 自动导出
          Row() {
            Column({ space: 2 }) {
              Text('自动导出')
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
              Text('日志达到上限时自动导出到本地')
                .fontSize(AppStyles.FONT_SIZE_CAPTION)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: this.autoExportEnabled })
              .selectedColor(AppColors.BRAND_PRIMARY)
              .onChange((value: boolean) => {
                this.autoExportEnabled = value
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })

          Divider()
            .color(AppColors.getColors(this.currentTheme).BORDER)
            .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          // 当前存储信息
          Row() {
            Text(`当前已存储 ${this.statistics.totalCount} 条日志`)
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
        }
        .width('100%')
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_LG)
        .clip(true)

        // 权限信息区
        Column({ space: 0 }) {
          Row() {
            Text('权限信息')
              .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            Blank()
            Text('SecurityAudit')
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
              .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
              .borderRadius(4)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 12 })

          Divider()
            .color(AppColors.getColors(this.currentTheme).BORDER)
            .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          Row() {
            Column({ space: 4 }) {
              Text('ohos.permission.QUERY_AUDIT_EVENT')
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
                .fontFamily('monospace')
              Text('必需权限：用于订阅和查询系统安全审计事件')
                .fontSize(AppStyles.FONT_SIZE_CAPTION)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text(this.isSubscribed ? '已订阅' : '订阅失败')
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(this.isSubscribed ?
                AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT :
                AppColors.getColors(this.currentTheme).TAG_RED_TEXT)
              .backgroundColor(this.isSubscribed ?
                AppColors.getColors(this.currentTheme).TAG_GREEN_BG :
                AppColors.getColors(this.currentTheme).TAG_RED_BG)
              .borderRadius(4)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        }
        .width('100%')
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_LG)
        .clip(true)
      }
      .width('100%')
      .padding({
        left: AppStyles.PADDING_LG,
        right: AppStyles.PADDING_LG,
        top: AppStyles.PADDING_MD,
        bottom: AppStyles.PADDING_LG
      })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)

    // 底部保存按钮
    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    Row({ space: 12 }) {
      Button('恢复默认')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_COMPONENT)
        .borderRadius(AppStyles.RADIUS_MD)
        .height(36)
        .layoutWeight(1)
        .onClick(() => {
          this.maxEntriesIndex = LOG_MAX_ENTRIES_OPTIONS.indexOf(
            DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries)
          this.retentionIndex = LOG_RETENTION_OPTIONS.indexOf(
            DEFAULT_LOG_STORAGE_CONFIG.retentionDays)
          this.autoExportEnabled = DEFAULT_LOG_STORAGE_CONFIG.autoExportEnabled
          promptAction.showToast({ message: '已恢复默认，请保存以生效' })
        })

      Button('保存设置')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(Color.White)
        .backgroundColor(AppColors.BRAND_PRIMARY)
        .borderRadius(AppStyles.RADIUS_MD)
        .height(36)
        .layoutWeight(1)
        .onClick(() => {
          this.saveStorageSettings()
        })
    }
    .width('100%')
    .padding({
      left: AppStyles.PADDING_LG,
      right: AppStyles.PADDING_LG,
      top: AppStyles.PADDING_MD,
      bottom: AppStyles.PADDING_MD
    })
  }
}
