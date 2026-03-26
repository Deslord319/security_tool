
import { AppColors, AppStyles } from '../constants/AppConstants'
import { LogStorageService } from '../services/LogStorageService'
import { LogRuntimeCollectorService } from '../services/LogRuntimeCollectorService'
import {
  LogEntry,
  LogEventType,
  LogEventResult,
  LogFilter,
  LogStatistics,
  LogStorageConfig,
  LogAuditDiagnostics,
  LogEventTypeDiag,
  AuditSubscribeMode,
  AuditFallbackReason,
  LOG_EVENT_TYPE_OPTIONS,
  LOG_RETENTION_OPTIONS,
  LOG_MAX_ENTRIES_OPTIONS,
  DEFAULT_LOG_STORAGE_CONFIG,
  ALL_LOG_EVENT_TYPES,
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
import { HoverUtils } from '../utils/HoverUtils'
import { BackNavButton } from '../components/BackNavButton'
import { FormControlUtils } from '../utils/FormControlUtils'
import { ResultMessageBox, ResultMessageStatus } from '../components/ResultMessageBox'
import { ResultDialogHelper } from '../utils/ResultDialogHelper'

const TAG = 'LogManagePage'
const DOMAIN = 0x0012

interface LogDetailField {
  key: string
  label: string
  value: string
}

@Component
struct LogDetailTextBlock {
  title: string = ''
  value: string = ''
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @State expanded: boolean = false

  private shouldCollapse(): boolean {
    return this.value.length > 72 || this.value.indexOf('\n') >= 0
  }

  build() {
    Column({ space: 6 }) {
      Text(this.title)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

      Text(this.value)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .maxLines(this.shouldCollapse() && !this.expanded ? 2 : 12)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (this.shouldCollapse()) {
        Text(this.expanded ? '收起' : '展开')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.BRAND_PRIMARY)
          .onClick(() => {
            this.expanded = !this.expanded
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
    .borderRadius(AppStyles.RADIUS_MD)
  }
}

@Component
struct LogDetailMetricCard {
  label: string = ''
  value: string = ''
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Column({ space: 4 }) {
      Text(this.label)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)

      Text(this.value)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .layoutWeight(1)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
    .borderRadius(AppStyles.RADIUS_MD)
  }
}

@Component
struct LogDetailInfoRow {
  field: LogDetailField = { key: '', label: '', value: '' }
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @State expanded: boolean = false

  private shouldCollapse(): boolean {
    return this.field.value.length > 72 || this.field.value.indexOf('\n') >= 0
  }

  build() {
    Column({ space: 6 }) {
      Text(this.field.label)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)

      Text(this.field.value)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .maxLines(this.shouldCollapse() && !this.expanded ? 2 : 12)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (this.shouldCollapse()) {
        Text(this.expanded ? '收起' : '展开')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.BRAND_PRIMARY)
          .onClick(() => {
            this.expanded = !this.expanded
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
    .borderRadius(AppStyles.RADIUS_MD)
  }
}

@CustomDialog
struct LogDetailDialog {
  controller: CustomDialogController
  title: string = ''
  entry: LogEntry = {
    id: '',
    timestamp: 0,
    eventType: LogEventType.FILE,
    detail: '',
    result: LogEventResult.SUCCESS
  } as LogEntry
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  private hasValue(value?: string | number): boolean {
    if (value === undefined || value === null) {
      return false
    }
    return value.toString().trim().length > 0
  }

  private displayValue(value?: string | number): string {
    if (!this.hasValue(value)) {
      return ''
    }
    return value!.toString().trim()
  }

  private getResultTagTextColor(): string {
    return getLogEventResultColor(this.entry.result)
  }

  private getResultTagBgColor(): string {
    if (this.entry.result === LogEventResult.SUCCESS) {
      return AppColors.getColors(this.currentTheme).TAG_GREEN_BG
    }
    if (this.entry.result === LogEventResult.BLOCKED) {
      return AppColors.getColors(this.currentTheme).TAG_ORANGE_BG
    }
    return AppColors.getColors(this.currentTheme).TAG_RED_BG
  }

  private getMetricFields(): LogDetailField[] {
    let fields: LogDetailField[] = []
    if (this.hasValue(this.entry.processName)) {
      fields.push({ key: 'process', label: '进程', value: this.displayValue(this.entry.processName) } as LogDetailField)
    }
    if (this.hasValue(this.entry.pid)) {
      fields.push({ key: 'pid', label: 'PID', value: this.displayValue(this.entry.pid) } as LogDetailField)
    }
    if (this.hasValue(this.entry.uid)) {
      fields.push({ key: 'uid', label: 'UID', value: this.displayValue(this.entry.uid) } as LogDetailField)
    }
    return fields
  }

  private getInfoFields(): LogDetailField[] {
    let fields: LogDetailField[] = []
    if (this.hasValue(this.entry.filePath)) {
      fields.push({ key: 'file_path', label: '文件路径', value: this.displayValue(this.entry.filePath) } as LogDetailField)
    }
    if (this.hasValue(this.entry.remoteAddr)) {
      fields.push({ key: 'remote_addr', label: '远端地址', value: this.displayValue(this.entry.remoteAddr) } as LogDetailField)
    }
    return fields
  }

  build() {
    Column({ space: 0 }) {
      Row() {
        Text(this.title)
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        Blank()
        Button('关闭')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_COMPONENT)
          .borderRadius(AppStyles.RADIUS_SM)
          .height(30)
          .onClick(() => {
            this.controller.close()
          })
      }
      .width('100%')

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
        .margin({ top: 10, bottom: 10 })

      Scroll() {
        Column({ space: 12 }) {
          Row({ space: 8 }) {
            Text(formatLogTimestamp(this.entry.timestamp))
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
              .fontFamily('monospace')
              .layoutWeight(1)

            Text(getLogEventTypeLabel(this.entry.eventType))
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
              .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
              .borderRadius(AppStyles.RADIUS_SM)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })

            Text(getLogEventResultLabel(this.entry.result))
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(this.getResultTagTextColor())
              .backgroundColor(this.getResultTagBgColor())
              .borderRadius(AppStyles.RADIUS_SM)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          LogDetailTextBlock({
            title: '详情',
            value: this.entry.detail.trim().length > 0 ? this.entry.detail : '暂无详情'
          })

          if (this.getMetricFields().length > 0 || this.getInfoFields().length > 0) {
            Column({ space: 8 }) {
              Text('附加信息')
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

              if (this.getMetricFields().length > 0) {
                Row({ space: 8 }) {
                  ForEach(this.getMetricFields(), (field: LogDetailField) => {
                    LogDetailMetricCard({
                      label: field.label,
                      value: field.value
                    })
                  }, (field: LogDetailField) => field.key)
                }
                .width('100%')
              }

              if (this.getInfoFields().length > 0) {
                Column({ space: 8 }) {
                  ForEach(this.getInfoFields(), (field: LogDetailField) => {
                    LogDetailInfoRow({
                      field: field
                    })
                  }, (field: LogDetailField) => field.key)
                }
                .width('100%')
              }
            }
            .width('100%')
          }
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: 420 })
      .scrollBar(BarState.Auto)
    }
    .width(560)
    .padding(18)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
  }
}

@Component
export struct LogManagePage {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onBack: () => void = () => {}
  @State hoveredStatIndex: number = -1
  @State hoveredSettingsCardIndex: number = -1
  @State hoveredDiagType: number = -1

  @State logEntries: LogEntry[] = []
  @State pagedLogEntries: LogEntry[] = []
  @State currentPage: number = 1
  @State pageInputValue: string = '1'
  @State pageSizeIndex: number = 1
  @State statistics: LogStatistics = {
    totalCount: 0,
    todayCount: 0,
    blockedCount: 0,
    byType: new Map<LogEventType, number>()
  }
  @State diagnostics: LogAuditDiagnostics = {
    byType: new Map<LogEventType, LogEventTypeDiag>(),
    unknownEventIds: [],
    subscribeMode: 'none',
    fallbackReason: 'none',
    lastModeSwitchAt: undefined,
    lastUpdatedAt: 0
  }

  @State filterEventType: number = -1
  @State filterResult: number = -1
  @State filterKeyword: string = ''
  @State isSubscribed: boolean = false

  @State maxEntriesIndex: number = 1
  @State retentionIndex: number = 2

  @State showSettings: boolean = false
  @State isLoading: boolean = false
  @State fromAuditDiagnostics: boolean = false
  @State selectedDiagType: number = -1

  private refreshTimerId: number = -1
  private readonly REFRESH_INTERVAL_MS: number = 1500
  private readonly SETTINGS_CONTENT_MAX_WIDTH: number = 1280
  private readonly SETTINGS_FORM_CONTROL_WIDTH: number = 220
  private readonly pageSizeOptions: number[] = [20, 50, 100]
  private detailDialogController?: CustomDialogController
  private resultDialogController: CustomDialogController = new CustomDialogController({
    builder: ResultMessageBox({
      onConfirm: () => {
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: true
  })



  private eventTypeFilterOptions: SelectOption[] = [
    { value: '全部类型' } as SelectOption,
    ...LOG_EVENT_TYPE_OPTIONS.map((opt) => ({ value: opt.label } as SelectOption))
  ]
  private resultFilterOptions: SelectOption[] = [
    { value: '全部结果' } as SelectOption,
    { value: '成功' } as SelectOption,
    { value: '已阻止' } as SelectOption,
    { value: '失败' } as SelectOption
  ]

  aboutToAppear() {
    this.initServices()
    this.startRefreshTimer()
  }

  aboutToDisappear() {
    if (this.refreshTimerId >= 0) {
      clearInterval(this.refreshTimerId)
      this.refreshTimerId = -1
    }
  }

  private showResultDialog(status: ResultMessageStatus, message: string): void {
    ResultDialogHelper.prepareResultDialog(status, message)
    try {
      this.resultDialogController.close()
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to close result dialog: ${JSON.stringify(err)}`)
    }
    this.resultDialogController.open()
  }

  private startRefreshTimer(): void {
    if (this.refreshTimerId >= 0) {
      return
    }
    this.refreshTimerId = setInterval(() => {
      this.refreshAll()
    }, this.REFRESH_INTERVAL_MS)
  }

  async initServices() {
    this.isLoading = true
    try {
      let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      await LogStorageService.init(context)
      this.applyStorageConfig(LogStorageService.getConfig())

      this.refreshAll()
      hilog.info(0x0006, TAG, 'Services initialized')
    } catch (err) {
      hilog.error(0x0006, TAG, `initServices failed: ${JSON.stringify(err)}`)
    }
    this.isLoading = false
  }

  private refreshAll() {
    this.refreshData()
    this.refreshRuntimeStatus()
    this.refreshDiagnostics()
  }

  private refreshRuntimeStatus() {
    let status = LogRuntimeCollectorService.getStatus()
    this.isSubscribed = status.subscribed
  }

  private refreshDiagnostics() {
    this.diagnostics = LogRuntimeCollectorService.getDiagnostics()
  }

  refreshData() {
    let filter = this.buildFilter()
    this.logEntries = LogStorageService.queryEntries(filter)
    this.statistics = LogStorageService.getStatistics()
    this.updatePagedEntries()
  }

  private getCurrentPageSize(): number {
    if (this.pageSizeIndex < 0 || this.pageSizeIndex >= this.pageSizeOptions.length) {
      return this.pageSizeOptions[0]
    }
    return this.pageSizeOptions[this.pageSizeIndex]
  }

  private getTotalPages(): number {
    let pageSize = this.getCurrentPageSize()
    if (this.logEntries.length === 0) {
      return 1
    }
    return Math.max(1, Math.ceil(this.logEntries.length / pageSize))
  }

  private updatePagedEntries(): void {
    let totalPages = this.getTotalPages()
    if (this.currentPage < 1) {
      this.currentPage = 1
    } else if (this.currentPage > totalPages) {
      this.currentPage = totalPages
    }

    let pageSize = this.getCurrentPageSize()
    let start = (this.currentPage - 1) * pageSize
    this.pagedLogEntries = this.logEntries.slice(start, start + pageSize)
    this.syncPageInputWithCurrentPage()
  }

  private resetToFirstPageAndRefresh(): void {
    this.currentPage = 1
    this.syncPageInputWithCurrentPage()
    this.refreshData()
  }

  private exitAuditDiagnosticsView(clearTypeFilter: boolean = false): void {
    this.fromAuditDiagnostics = false
    this.selectedDiagType = -1
    if (clearTypeFilter) {
      this.filterEventType = -1
      this.filterResult = -1
      this.filterKeyword = ''
    }
  }

  private applyManualFilterChange(): void {
    if (this.fromAuditDiagnostics) {
      this.exitAuditDiagnosticsView(false)
    }
    this.resetToFirstPageAndRefresh()
  }

  private openEventsByDiagType(type: LogEventType): void {
    this.selectedDiagType = type as number
    this.fromAuditDiagnostics = true
    this.showSettings = false
    this.filterEventType = type as number
    this.filterResult = -1
    this.filterKeyword = ''
    this.resetToFirstPageAndRefresh()
  }

  private openSettingsFromList(): void {
    this.exitAuditDiagnosticsView(true)
    this.showSettings = true
    this.refreshData()
  }

  private clearAuditDiagnosticsFilter(): void {
    this.exitAuditDiagnosticsView(true)
    this.showSettings = false
    this.resetToFirstPageAndRefresh()
  }

  private goToPreviousPage(): void {
    if (this.currentPage <= 1) {
      return
    }
    this.currentPage = this.currentPage - 1
    this.updatePagedEntries()
  }

  private goToNextPage(): void {
    let totalPages = this.getTotalPages()
    if (this.currentPage >= totalPages) {
      return
    }
    this.currentPage = this.currentPage + 1
    this.updatePagedEntries()
  }

  private syncPageInputWithCurrentPage(): void {
    this.pageInputValue = `${this.currentPage}`
  }

  private sanitizePageInput(input: string): string {
    return input.replace(/[^0-9]/g, '')
  }

  private jumpToInputPage(): void {
    let cleaned = this.sanitizePageInput(this.pageInputValue)
    if (cleaned.length === 0) {
      this.syncPageInputWithCurrentPage()
      return
    }

    let targetPage = parseInt(cleaned, 10)
    if (targetPage < 1) {
      targetPage = 1
    }

    let totalPages = this.getTotalPages()
    if (targetPage > totalPages) {
      targetPage = totalPages
    }

    this.currentPage = targetPage
    this.updatePagedEntries()
  }

  private getPageSizeOptions(): SelectOption[] {
    return this.pageSizeOptions.map((size: number): SelectOption => {
      return { value: `${size} 条/页` } as SelectOption
    })
  }

  private getCurrentRangeText(): string {
    if (this.logEntries.length === 0) {
      return '0-0'
    }
    let pageSize = this.getCurrentPageSize()
    let start = (this.currentPage - 1) * pageSize + 1
    let end = Math.min(this.currentPage * pageSize, this.logEntries.length)
    return `${start}-${end}`
  }

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
    let keyword = this.filterKeyword.trim()
    if (keyword.length > 0) {
      filter.keyword = keyword
      hasFilter = true
    }

    return hasFilter ? filter : undefined
  }

  private getDiagMetricValue(type: LogEventType): string {
    return `${this.getStoredCountByType(type)}`
  }

  private getDiagMetricLabel(type: LogEventType): string {
    return '首页数量'
  }

  private getDiagCardSummaryText(type: LogEventType): string {
    let diag = this.getDiagByType(type)
    if (diag.failedEventIds.length > 0) {
      let codeText = diag.lastErrorCode !== undefined ? `，错误码 ${diag.lastErrorCode}` : ''
      return `订阅异常：eventId ${diag.failedEventIds.join(',')}${codeText}`
    }
    if (type === LogEventType.FILE) {
      let unsupported = diag.preFilterUnsupportedEventIds || []
      let preFilterFailed = diag.preFilterFailedEventIds || []
      if (unsupported.length > 0) {
        return `前置路径过滤已回退：eventId ${unsupported.join(',')}`
      }
      if (preFilterFailed.length > 0) {
        let codeText = diag.preFilterLastErrorCode !== undefined ? `，错误码 ${diag.preFilterLastErrorCode}` : ''
        return `前置路径过滤异常：eventId ${preFilterFailed.join(',')}${codeText}`
      }
      let dropped = (diag.droppedNoPathCount || 0) + (diag.droppedPrefixMismatchCount || 0)
      if (dropped > 0) {
        return `已丢弃 ${dropped} 条非用户文件事件`
      }
    }
    if (!diag.subscribed) {
      return '当前未订阅该类型'
    }
    return this.getDiagRecentTimeText(type)
  }

  async exportLogs() {
    if (this.logEntries.length === 0) {
      this.showResultDialog('failure', '没有可导出的日志')
      return
    }

    let result = await LogStorageService.exportToCsvFile(this.logEntries)
    if (result.success) {
      this.showResultDialog('success', `日志已导出，文件名：${result.fileName}`)
      return
    }

    this.showResultDialog(
      'failure',
      `日志导出失败，${ResultDialogHelper.displayReason(result.errorMessage, '请稍后重试')}`
    )
  }

  private openLogDetailTableDialog(entry: LogEntry): void {
    this.detailDialogController = new CustomDialogController({
      builder: LogDetailDialog({
        controller: this.detailDialogController as CustomDialogController,
        title: '日志详情',
        entry: entry
      }),
      autoCancel: true,
      customStyle: true,
      alignment: DialogAlignment.Center
    })
    this.detailDialogController.open()
  }

  clearLogs() {
    void this.getUIContext().showAlertDialog({
      title: '确认清空',
      message: `将清除所有 ${this.statistics.totalCount} 条日志记录，此操作不可撤销。`,
      primaryButton: {
        value: '确认清空',
        action: async () => {
          await LogStorageService.clearAll()
          this.refreshAll()
          this.showResultDialog('success', '日志已清空')
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    })
  }

  async saveStorageSettings() {
    let previousConfig = LogStorageService.getConfig()
    let config: LogStorageConfig = {
      maxLocalEntries: LOG_MAX_ENTRIES_OPTIONS[this.maxEntriesIndex],
      retentionDays: LOG_RETENTION_OPTIONS[this.retentionIndex]
    }

    if (previousConfig.maxLocalEntries === config.maxLocalEntries &&
      previousConfig.retentionDays === config.retentionDays) {
      this.showResultDialog('failure', '当前没有需要保存的更改')
      return
    }

    let success = await LogStorageService.updateConfig(config)
    if (!success) {
      this.showResultDialog('failure', '保存设置失败，请稍后重试')
      return
    }

    this.applyStorageConfig(LogStorageService.getConfig())
    this.refreshAll()
    this.showResultDialog('success', '日志存储设置已保存')
  }
  applyStorageConfig(config: LogStorageConfig): void {
    this.maxEntriesIndex = LOG_MAX_ENTRIES_OPTIONS.indexOf(config.maxLocalEntries)
    if (this.maxEntriesIndex < 0) {
      this.maxEntriesIndex = LOG_MAX_ENTRIES_OPTIONS.indexOf(DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries)
    }
    if (this.maxEntriesIndex < 0) {
      this.maxEntriesIndex = 0
    }

    this.retentionIndex = LOG_RETENTION_OPTIONS.indexOf(config.retentionDays)
    if (this.retentionIndex < 0) {
      this.retentionIndex = LOG_RETENTION_OPTIONS.indexOf(DEFAULT_LOG_STORAGE_CONFIG.retentionDays)
    }
    if (this.retentionIndex < 0) {
      this.retentionIndex = 0
    }
  }
  private getCurrentTypeDiag(): LogEventTypeDiag | undefined {
    if (this.filterEventType < 0) {
      return undefined
    }
    return this.diagnostics.byType.get(this.filterEventType as LogEventType)
  }

  private getSelectedDiagTypeLabel(): string {
    if (this.selectedDiagType < 0) {
      return ''
    }
    return getLogEventTypeLabel(this.selectedDiagType as LogEventType)
  }

  private getFilterHintMessage(): string {
    if (this.fromAuditDiagnostics && this.selectedDiagType >= 0) {
      let typeLabel = this.getSelectedDiagTypeLabel()
      let selectedType = this.selectedDiagType as LogEventType
      let diag = this.getDiagByType(selectedType)
      if (this.logEntries.length === 0) {
        if (selectedType === LogEventType.FILE) {
          let dropped = (diag.droppedNoPathCount || 0) + (diag.droppedPrefixMismatchCount || 0)
          if (dropped > 0) {
            return `当前正在查看【${typeLabel}】采集事件，首页当前可见 0 条，已过滤 ${dropped} 条系统或未知路径事件。`
          }
        }
        if (diag.seenCount > 0) {
          return `当前正在查看【${typeLabel}】采集事件，首页当前可见 0 条，本次会话命中 ${diag.seenCount} 条。`
        }
        return `当前正在查看【${typeLabel}】采集事件，该类型暂无命中事件。`
      }
      return `当前正在查看【${typeLabel}】采集事件，共 ${this.logEntries.length} 条。`
    }

    if (this.filterEventType < 0) {
      return ''
    }

    let selectedType = this.filterEventType as LogEventType
    let totalByType = this.statistics.byType.get(selectedType) || 0
    if (totalByType > 0 && this.logEntries.length === 0) {
      return '当前筛选结果为 0，可尝试清空关键词或结果筛选。'
    }

    let diag = this.getCurrentTypeDiag()
    if (!diag) {
      return ''
    }
    if (diag.failedEventIds.length > 0) {
      if (selectedType === LogEventType.ACCOUNT && diag.lastErrorCode === 401) {
        return '用户认证日志在当前设备受系统策略限制（401），并非应用权限缺失。'
      }
      let codeText = diag.lastErrorCode !== undefined ? `，错误码 ${diag.lastErrorCode}` : ''
      return `该类型订阅失败：eventId ${diag.failedEventIds.join(',')}${codeText}。${this.getTypeTriggerHint(selectedType)}`
    }
    if (selectedType === LogEventType.FILE) {
      let dropped = (diag.droppedNoPathCount || 0) + (diag.droppedPrefixMismatchCount || 0)
      if (dropped > 0) {
        return `当前文件日志仅保留用户文件操作，已过滤 ${dropped} 条系统或未知路径事件。`
      }
    }
    if (diag.subscribed && totalByType === 0) {
      return ''
    }
    if (!diag.subscribed) {
      return '该类型当前未订阅。'
    }
    return ''
  }

  private getTypeTriggerHint(type: LogEventType): string {
    switch (type) {
      case LogEventType.CRASH:
        return '提示：需等待系统上报 APP_CRASH 或 APP_FREEZE。'
      case LogEventType.FILE:
        return '提示：只记录用户公共目录或公共媒体文件操作。'
      case LogEventType.PERMISSION:
        return '提示：需触发权限授予/撤销等系统权限变更行为。'
      case LogEventType.ACCOUNT:
        return '提示：该类型在部分设备上可能受策略限制。'
      default:
        return '提示：可先触发对应系统安全操作后再刷新查看。'
    }
  }

  private getDiagByType(type: LogEventType): LogEventTypeDiag {
    let diag = this.diagnostics.byType.get(type)
    if (diag) {
      return diag
    }
    return {
      type: type,
      subscribed: false,
      failedEventIds: [],
      seenCount: 0
    }
  }

  private getStoredCountByType(type: LogEventType): number {
    return this.statistics.byType.get(type) || 0
  }

  private getDiagStatusText(type: LogEventType): string {
    let diag = this.getDiagByType(type)
    if (diag.failedEventIds.length > 0) {
      return '订阅失败'
    }
    return diag.subscribed ? '已订阅' : '未订阅'
  }

  private getDiagStatusColor(type: LogEventType): string {
    let diag = this.getDiagByType(type)
    if (diag.failedEventIds.length > 0) {
      return AppColors.getColors(this.currentTheme).TAG_RED_TEXT
    }
    return diag.subscribed ?
      AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT :
      AppColors.getColors(this.currentTheme).TAG_GRAY_TEXT
  }

  private getSubscribeModeText(mode?: AuditSubscribeMode): string {
    let current = mode || this.diagnostics.subscribeMode
    if (current === 'client') {
      return 'Client'
    }
    if (current === 'legacy') {
      return 'Legacy'
    }
    return '未订阅'
  }

  private getFallbackReasonText(reason?: AuditFallbackReason): string {
    let current = reason || this.diagnostics.fallbackReason
    if (current === 'new_api_unavailable') {
      return '新订阅 API 不可用，已自动切换到兼容模式。'
    }
    if (current === 'new_api_init_failed') {
      return '新订阅 API 初始化失败，已自动切换到兼容模式。'
    }
    return ''
  }

  private getDiagStatusBgColor(type: LogEventType): string {
    let diag = this.getDiagByType(type)
    if (diag.failedEventIds.length > 0) {
      return AppColors.getColors(this.currentTheme).TAG_RED_BG
    }
    return diag.subscribed ?
      AppColors.getColors(this.currentTheme).TAG_GREEN_BG :
      AppColors.getColors(this.currentTheme).TAG_GRAY_BG
  }

  private getDiagCountText(type: LogEventType): string {
    let diag = this.getDiagByType(type)
    if (type === LogEventType.FILE) {
      let dropped = (diag.droppedNoPathCount || 0) + (diag.droppedPrefixMismatchCount || 0)
      if (dropped > 0) {
        return `本次会话命中 ${diag.seenCount} / 过滤 ${dropped}`
      }
    }
    return `本次会话命中 ${diag.seenCount}`
  }

  private getDiagRecentTimeText(type: LogEventType): string {
    let diag = this.getDiagByType(type)
    let lastSeen = diag.lastSeenAt ? formatLogTimestamp(diag.lastSeenAt) : '-'
    return `最近 ${lastSeen}`
  }

  build() {
    Column() {
      Row() {
        Row({ space: 8 }) {
          BackNavButton({
            onBack: () => {
              this.onBack()
            }
          })

          Column({ space: 4 }) {
            Text(this.showSettings ? '日志存储设置' : '日志管理')
              .fontSize(AppStyles.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            Text(this.showSettings ? '配置日志留存与采集诊断' : '监控崩溃与关键安全日志')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Top)

        Column({ space: 8 }) {
          Row({ space: 6 }) {
            Circle({ width: 8, height: 8 })
              .fill(this.isSubscribed ? AppColors.SUCCESS : '#9E9E9E')
            Text(this.isSubscribed ? `已订阅(${this.getSubscribeModeText()})` : '订阅失败')
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          }

          Row({ space: 8 }) {
            if (!this.showSettings) {
              this.headerActionButton(
                '导出日志',
                $r('app.media.save'),
                AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT,
                AppColors.getColors(this.currentTheme).TAG_BLUE_BG,
                () => {
                  this.exportLogs()
                }
              )

              this.headerActionButton(
                '清空日志',
                $r('app.media.trash'),
                AppColors.getColors(this.currentTheme).TAG_RED_TEXT,
                AppColors.getColors(this.currentTheme).TAG_RED_BG,
                () => {
                  this.clearLogs()
                }
              )
            }

            if (!this.showSettings) {
              Button('进入存储设置')
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
                .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
                .borderRadius(AppStyles.RADIUS_SM)
                .height(32)
                .padding({ left: 12, right: 12 })
                .onClick(() => {
                  this.openSettingsFromList()
                })
            } else {
              this.headerActionButton(
                '保存设置',
                $r('app.media.save'),
                Color.White,
                AppColors.BRAND_PRIMARY,
                () => {
                  void this.saveStorageSettings()
                }
              )

              Button('返回日志列表')
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
                .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
                .borderRadius(AppStyles.RADIUS_SM)
                .height(32)
                .padding({ left: 12, right: 12 })
                .onClick(() => {
                  this.exitAuditDiagnosticsView(true)
                  this.showSettings = false
                  this.refreshData()
                })
            }
          }
        }
        .margin({ left: 12 })
        .alignItems(HorizontalAlign.End)

        if (false) {
          Row({ space: 6 }) {
            Circle({ width: 8, height: 8 })
              .fill(this.isSubscribed ? AppColors.SUCCESS : '#9E9E9E')
          Text(this.isSubscribed ? `已订阅(${this.getSubscribeModeText()})` : '订阅失败')
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        }

        Button(this.showSettings ? '返回日志列表' : '进入存储设置')
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
        this.statisticsBar()
        this.filterToolbar()
        this.filterHintView()
        this.logListView()
        this.paginationToolbar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  statisticsBar() {
    Row({ space: 12 }) {
      this.statItem(0, '总计', this.statistics.totalCount.toString(), AppColors.BRAND_PRIMARY)
      this.statItem(1, '今日', this.statistics.todayCount.toString(), AppColors.SUCCESS)
      this.statItem(2, '已阻止', this.statistics.blockedCount.toString(), AppColors.WARNING)
      this.statItem(3, '当前显示', this.pagedLogEntries.length.toString(), '#9E9E9E')
    }
    .width('100%')
    .padding({
      left: AppStyles.PADDING_LG,
      right: AppStyles.PADDING_LG,
      top: AppStyles.PADDING_MD
    })
  }

  @Builder
  statItem(index: number, label: string, value: string, color: string) {
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
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredStatIndex === index))
    .translate({ y: HoverUtils.getTranslateY(this.hoveredStatIndex === index, 4) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.hoveredStatIndex = isHover ? index : -1
      })
    })
  }

  @Builder
  filterToolbar() {
    Row({ space: 8 }) {
      Select(this.eventTypeFilterOptions)
        .selected(this.filterEventType + 1)
        .value(this.filterEventType < 0 ? '全部类型' :
          getLogEventTypeLabel(this.filterEventType as LogEventType))
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
        .optionFont({ size: AppStyles.FONT_SIZE_BODY })
        .width(120)
        .height(36)
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .borderRadius(AppStyles.RADIUS_SM)
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .onSelect((index: number) => {
          this.filterEventType = index - 1
          this.applyManualFilterChange()
        })

      Select(this.resultFilterOptions)
        .selected(this.filterResult + 1)
        .value(this.filterResult < 0 ? '全部结果' :
          getLogEventResultLabel(this.filterResult as LogEventResult))
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
        .optionFont({ size: AppStyles.FONT_SIZE_BODY })
        .width(110)
        .height(36)
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .borderRadius(AppStyles.RADIUS_SM)
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .onSelect((index: number) => {
          this.filterResult = index - 1
          this.applyManualFilterChange()
        })

      TextInput({ placeholder: '搜索日志内容...', text: this.filterKeyword })
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(FormControlUtils.text(this.currentTheme))
        .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .layoutWeight(1)
        .onChange((value: string) => {
          this.filterKeyword = value
          this.applyManualFilterChange()
        })

      Button('刷新')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .onClick(() => {
          this.refreshAll()
        })
    }
    .width('100%')
    .padding({
      left: AppStyles.PADDING_LG,
      right: AppStyles.PADDING_LG,
      top: AppStyles.PADDING_SM
    })
  }

  @Builder
  filterHintView() {
    if (this.getFilterHintMessage().length > 0) {
      Row({ space: 8 }) {
        Text(this.getFilterHintMessage())
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        if (this.fromAuditDiagnostics) {
          Button('清除筛选')
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
            .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
            .borderRadius(AppStyles.RADIUS_SM)
            .height(28)
            .padding({ left: 10, right: 10 })
            .onClick(() => {
              this.clearAuditDiagnosticsFilter()
            })

          Button('返回采集诊断')
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
            .borderRadius(AppStyles.RADIUS_SM)
            .height(28)
            .padding({ left: 10, right: 10 })
            .onClick(() => {
              this.showSettings = true
              this.exitAuditDiagnosticsView(true)
              this.refreshData()
            })
        }
      }
      .width('100%')
      .padding({
        left: AppStyles.PADDING_LG,
        right: AppStyles.PADDING_LG,
        top: 6,
        bottom: 4
      })
    }
  }

  @Builder
  logListView() {
    if (this.isLoading) {
      Column() {
        LoadingProgress().width(48).height(48)
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
        Text('安全事件与崩溃日志将实时显示在此处')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 1 }) {
        ForEach(this.pagedLogEntries, (entry: LogEntry) => {
          ListItem() {
            this.logEntryRow(entry)
          }
        }, (entry: LogEntry) => entry.id)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_SM })
      .scrollBar(BarState.Auto)
    }
  }

  @Builder
  paginationToolbar() {
    if (!this.isLoading && this.logEntries.length > 0) {
      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      Row({ space: 12 }) {
        Text(`显示 ${this.getCurrentRangeText()} / 共 ${this.logEntries.length} 条`)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .layoutWeight(1)

        Select(this.getPageSizeOptions())
          .selected(this.pageSizeIndex)
          .value(`${this.getCurrentPageSize()} 条/页`)
          .font({ size: AppStyles.FONT_SIZE_CAPTION })
          .fontColor(FormControlUtils.text(this.currentTheme))
          .selectedOptionFont({ size: AppStyles.FONT_SIZE_CAPTION })
          .optionFont({ size: AppStyles.FONT_SIZE_CAPTION })
          .width(126)
          .height(32)
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_SM)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onSelect((index: number) => {
            this.pageSizeIndex = index
            this.currentPage = 1
            this.updatePagedEntries()
          })

        Button('上一页')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(this.currentPage > 1 ? AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY : 0.4)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
          .borderRadius(AppStyles.RADIUS_SM)
          .height(32)
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            this.goToPreviousPage()
          })

        Text(`${this.currentPage}/${this.getTotalPages()}`)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .width(52)
          .textAlign(TextAlign.Center)

        TextInput({ text: this.pageInputValue, placeholder: '页码' })
          .type(InputType.Number)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .borderRadius(AppStyles.RADIUS_SM)
          .height(32)
          .width(62)
          .onChange((value: string) => {
            this.pageInputValue = this.sanitizePageInput(value)
          })

        Button('跳转')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
          .borderRadius(AppStyles.RADIUS_SM)
          .height(32)
          .padding({ left: 10, right: 10 })
          .onClick(() => {
            this.jumpToInputPage()
          })

        Button('下一页')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(this.currentPage < this.getTotalPages() ? AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY : 0.4)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
          .borderRadius(AppStyles.RADIUS_SM)
          .height(32)
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            this.goToNextPage()
          })
      }
      .width('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: 10, bottom: 10 })
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  logEntryRow(entry: LogEntry) {
    Row() {
      Text(formatLogTimestamp(entry.timestamp))
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .width(140)
        .fontFamily('monospace')

      Text(getLogEventTypeLabel(entry.eventType))
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
        .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
        .borderRadius(4)
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .width(72)
        .textAlign(TextAlign.Center)

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
    .onClick(() => {
      this.openLogDetailTableDialog(entry)
    })
  }

  @Builder
  bottomToolbar() {
    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    Row({ space: 12 }) {
      Button('导出日志').fontSize(AppStyles.FONT_SIZE_BODY).fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
        .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG).borderRadius(AppStyles.RADIUS_SM)
        .height(36).layoutWeight(1).onClick(() => { this.exportLogs() })

      Button('清空日志').fontSize(AppStyles.FONT_SIZE_BODY).fontColor(AppColors.getColors(this.currentTheme).TAG_RED_TEXT)
        .backgroundColor(AppColors.getColors(this.currentTheme).TAG_RED_BG).borderRadius(AppStyles.RADIUS_SM)
        .height(36).layoutWeight(1).onClick(() => { this.clearLogs() })
    }
    .width('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_MD })
  }

  @Builder
  headerActionButton(
    label: string,
    icon: Resource,
    textColor: ResourceColor,
    backgroundColor: ResourceColor,
    onTap: () => void
  ) {
    Button() {
      Row({ space: 6 }) {
        Image(icon)
          .width(14)
          .height(14)
          .fillColor(textColor)

        Text(label)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(textColor)
      }
      .alignItems(VerticalAlign.Center)
    }
    .type(ButtonType.Normal)
    .backgroundColor(backgroundColor)
    .borderRadius(AppStyles.RADIUS_SM)
    .height(32)
    .padding({ left: 10, right: 10 })
    .onClick(() => {
      onTap()
    })
  }

  @Builder
  storageSettingsView() {
    Column() {
      Scroll() {
        Row() {
          Column({ space: 16 }) {
            this.storageConfigCard()
            this.auditDiagnosticsCard()
          }
          .width('100%')
          .constraintSize({ maxWidth: this.SETTINGS_CONTENT_MAX_WIDTH })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_LG })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)

      if (false) {
        Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

        Column({ space: 16 }) {
        Row() {
          Blank()

          Row({ space: 12 }) {
            Button('恢复默认').fontSize(AppStyles.FONT_SIZE_BODY).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).backgroundColor(AppColors.getColors(this.currentTheme).BG_COMPONENT)
              .borderRadius(AppStyles.RADIUS_MD).height(36).width(120)
              .onClick(() => {
                this.maxEntriesIndex = LOG_MAX_ENTRIES_OPTIONS.indexOf(DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries)
                this.retentionIndex = LOG_RETENTION_OPTIONS.indexOf(DEFAULT_LOG_STORAGE_CONFIG.retentionDays)
                this.showResultDialog('success', '已恢复默认，请保存以生效')
              })

            Button('保存设置').fontSize(AppStyles.FONT_SIZE_BODY).fontColor(Color.White).backgroundColor(AppColors.BRAND_PRIMARY)
              .borderRadius(AppStyles.RADIUS_MD).height(36).width(132).onClick(() => { this.saveStorageSettings() })
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: this.SETTINGS_CONTENT_MAX_WIDTH })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_MD })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .align(Alignment.Top)
  }

  @Builder
  storageConfigCard() {
    Column({ space: 0 }) {
      Text('日志存储配置')
        .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .padding({ top: 16, bottom: 12 })

      Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      Row() {
        Text('最大存储条数')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .layoutWeight(1)

        Select(LOG_MAX_ENTRIES_OPTIONS.map((v): SelectOption => ({ value: `${v} 条` } as SelectOption)))
          .selected(this.maxEntriesIndex)
          .value(`${LOG_MAX_ENTRIES_OPTIONS[this.maxEntriesIndex]} 条`)
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .fontColor(FormControlUtils.text(this.currentTheme))
          .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
          .optionFont({ size: AppStyles.FONT_SIZE_BODY })
          .width(this.SETTINGS_FORM_CONTROL_WIDTH)
          .height(36)
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_SM)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onSelect((index: number) => { this.maxEntriesIndex = index })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)

      Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      Row() {
        Text('日志保留天数')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .layoutWeight(1)

        Select(LOG_RETENTION_OPTIONS.map((v): SelectOption => ({ value: `${v} 天` } as SelectOption)))
          .selected(this.retentionIndex)
          .value(`${LOG_RETENTION_OPTIONS[this.retentionIndex]} 天`)
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .fontColor(FormControlUtils.text(this.currentTheme))
          .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
          .optionFont({ size: AppStyles.FONT_SIZE_BODY })
          .width(this.SETTINGS_FORM_CONTROL_WIDTH)
          .height(36)
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_SM)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onSelect((index: number) => { this.retentionIndex = index })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredSettingsCardIndex === 0, true))
    .translate({ y: HoverUtils.getTranslateY(this.hoveredSettingsCardIndex === 0, 4) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.hoveredSettingsCardIndex = isHover ? 0 : -1
      })
    })
  }

  @Builder
  auditDiagnosticsCard() {
    Column({ space: 12 }) {
      Row() {
        Text('采集诊断').fontSize(AppStyles.FONT_SIZE_SUBTITLE).fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      }
      .width('100%')

      Text(`模式切换时间: ${this.diagnostics.lastModeSwitchAt !== undefined ? formatLogTimestamp(this.diagnostics.lastModeSwitchAt as number) : '-'}`)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)

      if (this.getFallbackReasonText().length > 0) {
        Row() {
          Text(this.getFallbackReasonText())
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT)
        }
        .width('100%')
        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
        .backgroundColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_BG)
        .borderRadius(AppStyles.RADIUS_SM)
      }

      if (this.diagnostics.unknownEventIds.length > 0) {
        Row() {
          Text(`未识别事件ID: ${this.diagnostics.unknownEventIds.join(',')}`)
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT)
        }
        .width('100%')
        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
        .backgroundColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_BG)
        .borderRadius(AppStyles.RADIUS_SM)
      }

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Start }) {
        ForEach(ALL_LOG_EVENT_TYPES, (type: LogEventType) => {
          Column({ space: 12 }) {
            Row() {
              Text(getLogEventTypeLabel(type))
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .layoutWeight(1)
              Text(this.getDiagStatusText(type))
                .fontSize(AppStyles.FONT_SIZE_CAPTION)
                .fontColor(this.getDiagStatusColor(type))
                .backgroundColor(this.getDiagStatusBgColor(type))
                .borderRadius(AppStyles.RADIUS_SM)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Column({ space: 4 }) {
              Text(this.getDiagMetricValue(type))
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              Text(this.getDiagMetricLabel(type))
                .fontSize(AppStyles.FONT_SIZE_CAPTION)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
            }
            .alignItems(HorizontalAlign.Start)

            Row({ space: 12 }) {
              Column({ space: 4 }) {
                Text(this.getDiagCountText(type))
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Column({ space: 4 }) {
                Text('最近命中')
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
                Text(this.getDiagRecentTimeText(type))
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.End)
            }
            .width('100%')

            Row() {
              Text(this.getDiagCardSummaryText(type))
                .fontSize(AppStyles.FONT_SIZE_CAPTION)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
          }
          .width('49%')
          .constraintSize({ minHeight: 168 })
          .padding({ left: 14, right: 14, top: 14, bottom: 14 })
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_COMPONENT)
          .borderRadius(AppStyles.RADIUS_MD)
          .border({
            width: 1,
            color: this.hoveredDiagType === (type as number) ?
              AppColors.BRAND_PRIMARY :
              AppColors.getColors(this.currentTheme).BORDER
          })
          .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredDiagType === (type as number)))
          .translate({ y: HoverUtils.getTranslateY(this.hoveredDiagType === (type as number), 4) })
          .onHover((isHover: boolean) => {
            HoverUtils.animate(() => {
              this.hoveredDiagType = isHover ? (type as number) : -1
            })
          })
          .onClick(() => {
            this.openEventsByDiagType(type)
          })
        }, (type: LogEventType) => type.toString())
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ minHeight: 360 })
    .padding(16)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .alignItems(HorizontalAlign.Start)
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredSettingsCardIndex === 1, true))
    .translate({ y: HoverUtils.getTranslateY(this.hoveredSettingsCardIndex === 1, 4) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.hoveredSettingsCardIndex = isHover ? 1 : -1
      })
    })
  }
}
