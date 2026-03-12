
import { AppColors, AppStyles } from '../constants/AppConstants'
import { LogAuditService } from '../services/LogAuditService'
import { LogStorageService } from '../services/LogStorageService'
import { LogRuntimeCollectorService } from '../services/LogRuntimeCollectorService'
import {
  LogEntry,
  LogEventType,
  LogEventResult,
  LogFilter,
  LogStatistics,
  LogStorageConfig,
  LogExportFormat,
  LogExportResult,
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

const TAG = 'LogManagePage'

interface DetailDialogField {
  key: string
  label: string
  value: string
}

@Component
struct DetailTableRow {
  label: string = ''
  value: string = '-'
  labelWidth: number = 112
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @State expanded: boolean = false

  private shouldCollapse(): boolean {
    return this.value.length > 60 || this.value.indexOf('\n') >= 0
  }

  build() {
    Row({ space: 12 }) {
      Text(this.label)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .width(this.labelWidth)

      Column({ space: 6 }) {
        Text(this.value)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
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
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 10, bottom: 10 })
  }
}

@CustomDialog
struct DetailTableDialog {
  controller: CustomDialogController
  title: string = ''
  fields: DetailDialogField[] = []
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  private readonly labelWidth: number = 112

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
        Column({ space: 0 }) {
          ForEach(this.fields, (field: DetailDialogField, index: number) => {
            DetailTableRow({
              label: field.label,
              value: field.value,
              labelWidth: this.labelWidth
            })
            if (index < this.fields.length - 1) {
              Divider()
                .color(AppColors.getColors(this.currentTheme).BORDER)
                .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
            }
          }, (field: DetailDialogField) => field.key)
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: 420 })
      .scrollBar(BarState.Auto)
    }
    .width(580)
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

@CustomDialog
struct ExportFormatDialog {
  controller: CustomDialogController
  onSelect: (format: LogExportFormat) => void = () => {}
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  private handleSelect(format: LogExportFormat): void {
    this.controller.close()
    this.onSelect(format)
  }

  build() {
    Column({ space: 12 }) {
      Text('选择导出格式')
        .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .width('100%')
        .textAlign(TextAlign.Start)

      Row({ space: 10 }) {
        Button('JSON')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
          .borderRadius(AppStyles.RADIUS_SM)
          .layoutWeight(1)
          .height(36)
          .onClick(() => {
            this.handleSelect(LogExportFormat.JSON)
          })

        Button('CSV')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT)
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_GREEN_BG)
          .borderRadius(AppStyles.RADIUS_SM)
          .layoutWeight(1)
          .height(36)
          .onClick(() => {
            this.handleSelect(LogExportFormat.CSV)
          })

        Button('TXT')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
          .borderRadius(AppStyles.RADIUS_SM)
          .layoutWeight(1)
          .height(36)
          .onClick(() => {
            this.handleSelect(LogExportFormat.TXT)
          })
      }
      .width('100%')

      Button('取消')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_COMPONENT)
        .borderRadius(AppStyles.RADIUS_SM)
        .height(34)
        .width('100%')
        .onClick(() => {
          this.controller.close()
        })
    }
    .width(360)
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
  @State autoExportEnabled: boolean = false

  @State showSettings: boolean = false
  @State isLoading: boolean = false

  private refreshTimerId: number = -1
  private readonly REFRESH_INTERVAL_MS: number = 1500
  private readonly SETTINGS_CONTENT_MAX_WIDTH: number = 1280
  private readonly SETTINGS_FORM_CONTROL_WIDTH: number = 220
  private readonly pageSizeOptions: number[] = [20, 50, 100]
  private detailDialogController?: CustomDialogController

  private exportFormatDialogController: CustomDialogController = new CustomDialogController({
    builder: ExportFormatDialog({
      onSelect: (format: LogExportFormat) => {
        void this.exportLogs(format)
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  private resolveStatIndex(label: string): number {
    if (label === '总计') {
      return 0
    }
    if (label === '今日') {
      return 1
    }
    if (label === '已阻止') {
      return 2
    }
    return 3
  }

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
      let context = getContext(this) as common.UIAbilityContext
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
    this.diagnostics = LogAuditService.getDiagnostics()
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

  private showExportFormatDialog(): void {
    this.exportFormatDialogController.open()
  }

  async exportLogs(format: LogExportFormat) {
    if (this.logEntries.length === 0) {
      promptAction.showToast({ message: '没有可导出的日志' })
      return
    }

    let result = await LogStorageService.exportToFile(this.logEntries, format, 'manual')
    if (result.success) {
      this.showExportSuccessDetailDialog(result)
      return
    }
    this.showExportFailureDialog(result)
  }
  showExportSuccessDialog(result: LogExportResult) {
    let fileName = result.fileName || '未知'
    let directory = result.directory || '未知'
    let fullPath = result.fullPath || '未知'
    let size = this.formatBytes(result.sizeBytes)
    let exportedAt = formatLogTimestamp(result.timestamp)
    let hint = result.errorMessage ? `\n备注: ${result.errorMessage}` : ''

    AlertDialog.show({
      title: '导出详情',
      message:
        `导出完成（${result.count} 条）\n` +
        `导出格式: ${result.format.toUpperCase()}\n` +
        `导出条数: ${result.count}\n` +
        `文件名: ${fileName}\n` +
        `保存位置: ${directory}\n` +
        `完整路径: ${fullPath}\n` +
        `文件大小: ${size}\n` +
        `导出时间: ${exportedAt}${hint}`,
      primaryButton: { value: '我知道了', action: () => {} }
    })
  }

  showExportFailureDialog(result: LogExportResult) {
    let directory = result.directory || '-'
    let fileName = result.fileName || '未知'
    let codeText = result.errorCode !== undefined ? '错误码: ' + result.errorCode + '\n' : ''
    let reasonText = result.errorMessage || '未知错误'

    AlertDialog.show({
      title: '导出失败',
      message:
        codeText +
        '目标文件: ' + fileName + '\n' +
        '目标目录: ' + directory + '\n' +
        '失败原因: ' + reasonText + '\n' +
        '建议: 重试导出，系统会在需要时自动请求 DOWNLOAD 目录授权。',
      primaryButton: { value: '关闭', action: () => {} }
    })
  }

  private displayField(value: string | number | undefined): string {
    if (value === undefined || value === null) {
      return '-'
    }
    let text = value.toString().trim()
    if (text.length === 0) {
      return '-'
    }
    return text
  }

  private toDetailField(key: string, label: string, value: string | number | undefined): DetailDialogField {
    return {
      key: key,
      label: label,
      value: this.displayField(value)
    } as DetailDialogField
  }

  private openDetailTableDialog(title: string, fields: DetailDialogField[]): void {
    this.detailDialogController = new CustomDialogController({
      builder: DetailTableDialog({
        title: title,
        fields: fields
      }),
      autoCancel: true,
      customStyle: true,
      alignment: DialogAlignment.Center
    })
    this.detailDialogController.open()
  }

  private showExportSuccessDetailDialog(result: LogExportResult): void {
    let fields: DetailDialogField[] = [
      this.toDetailField('summary', '导出结果', `导出完成（${result.count} 条）`),
      this.toDetailField('format', '导出格式', result.format.toUpperCase()),
      this.toDetailField('count', '导出条数', result.count.toString()),
      this.toDetailField('file_name', '文件名', result.fileName),
      this.toDetailField('directory', '保存位置', result.directory),
      this.toDetailField('full_path', '完整路径', result.fullPath),
      this.toDetailField('size', '文件大小', this.formatBytes(result.sizeBytes)),
      this.toDetailField('exported_at', '导出时间', formatLogTimestamp(result.timestamp))
    ]
    if (result.errorMessage && result.errorMessage.trim().length > 0) {
      fields.push(this.toDetailField('remark', '备注', result.errorMessage))
    }
    this.openDetailTableDialog('导出详情', fields)
  }

  private openLogDetailTableDialog(entry: LogEntry): void {
    let fields: DetailDialogField[] = [
      this.toDetailField('timestamp', '时间', formatLogTimestamp(entry.timestamp)),
      this.toDetailField('event_type', '类型', getLogEventTypeLabel(entry.eventType)),
      this.toDetailField('result', '结果', getLogEventResultLabel(entry.result)),
      this.toDetailField('detail', '详情', entry.detail),
      this.toDetailField('process', '进程', entry.processName),
      this.toDetailField('pid', 'PID', entry.pid),
      this.toDetailField('uid', 'UID', entry.uid),
      this.toDetailField('file_path', '文件路径', entry.filePath),
      this.toDetailField('remote_addr', '远端地址', entry.remoteAddr),
      this.toDetailField('source_event_id', '源事件 ID', entry.sourceEventId),
      this.toDetailField('source_sub_type', '源子类型', entry.sourceSubType),
      this.toDetailField('raw_event_name', '原始事件名', entry.rawEventName),
      this.toDetailField('raw_outcome', '原始结果', entry.rawOutcome)
    ]
    this.openDetailTableDialog('日志详情', fields)
  }

  private showLogDetailDialog(entry: LogEntry): void {
    AlertDialog.show({
      title: '日志详情',
      message:
        `时间: ${formatLogTimestamp(entry.timestamp)}\n` +
        `类型: ${getLogEventTypeLabel(entry.eventType)}\n` +
        `结果: ${getLogEventResultLabel(entry.result)}\n` +
        `详情: ${this.displayField(entry.detail)}\n` +
        `进程: ${this.displayField(entry.processName)}\n` +
        `PID: ${this.displayField(entry.pid)}\n` +
        `UID: ${this.displayField(entry.uid)}\n` +
        `文件路径: ${this.displayField(entry.filePath)}\n` +
        `远端地址: ${this.displayField(entry.remoteAddr)}\n` +
        `源事件 ID: ${this.displayField(entry.sourceEventId)}\n` +
        `源子类型: ${this.displayField(entry.sourceSubType)}\n` +
        `原始事件名: ${this.displayField(entry.rawEventName)}\n` +
        `原始结果: ${this.displayField(entry.rawOutcome)}`,
      primaryButton: { value: '关闭', action: () => {} }
    })
  }

  formatBytes(sizeBytes: number | undefined): string {
    if (sizeBytes === undefined || sizeBytes < 0) {
      return '未知'
    }
    if (sizeBytes < 1024) {
      return `${sizeBytes} B`
    }
    if (sizeBytes < 1024 * 1024) {
      return `${(sizeBytes / 1024).toFixed(2)} KB`
    }
    return `${(sizeBytes / (1024 * 1024)).toFixed(2)} MB`
  }

  clearLogs() {
    AlertDialog.show({
      title: '确认清空',
      message: `将清除所有 ${this.statistics.totalCount} 条日志记录，此操作不可撤销。`,
      primaryButton: {
        value: '确认清空',
        action: async () => {
          await LogStorageService.clearAll()
          this.refreshAll()
          promptAction.showToast({ message: '日志已清空' })
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    })
  }

  async saveStorageSettings() {
    let previousConfig = LogStorageService.getConfig()
    let config: LogStorageConfig = {
      maxLocalEntries: LOG_MAX_ENTRIES_OPTIONS[this.maxEntriesIndex],
      retentionDays: LOG_RETENTION_OPTIONS[this.retentionIndex],
      autoExportEnabled: this.autoExportEnabled,
      exportTargetType: 'download',
      exportTargetValue: previousConfig.exportTargetValue || '',
      exportAuthMode: 'download_mode',
      exportPath: ''
    }

    let success = await LogStorageService.updateConfig(config)
    if (!success) {
      promptAction.showToast({ message: '保存失败' })
      return
    }

    this.applyStorageConfig(LogStorageService.getConfig())
    this.refreshAll()
    promptAction.showToast({ message: '存储设置已保存' })
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

    this.autoExportEnabled = config.autoExportEnabled
  }
  private getCurrentTypeDiag(): LogEventTypeDiag | undefined {
    if (this.filterEventType < 0) {
      return undefined
    }
    return this.diagnostics.byType.get(this.filterEventType as LogEventType)
  }

  private getFilterHintMessage(): string {
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
        return '账户审计在当前设备受系统策略限制（401），并非应用权限缺失。'
      }
      let codeText = diag.lastErrorCode !== undefined ? `，错误码 ${diag.lastErrorCode}` : ''
      return `该类型订阅失败：eventId ${diag.failedEventIds.join(',')}${codeText}。${this.getTypeTriggerHint(selectedType)}`
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
      case LogEventType.NETWORK_CONN:
        return '提示：只有系统上报的连接审计事件会出现，普通网页访问未必触发。'
      case LogEventType.NETWORK_TRAFFIC:
        return '提示：该类型通常需要系统侧开启流量审计上报。'
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
    return `命中 ${diag.seenCount}`
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
            Text(this.showSettings ? '配置日志留存、自动导出与审计诊断' : '监控和审计系统安全事件日志')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Top)

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
        this.bottomToolbar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  statisticsBar() {
    Row({ space: 12 }) {
      this.statItem('总计', this.statistics.totalCount.toString(), AppColors.BRAND_PRIMARY)
      this.statItem('今日', this.statistics.todayCount.toString(), AppColors.SUCCESS)
      this.statItem('已阻止', this.statistics.blockedCount.toString(), AppColors.WARNING)
      this.statItem('当前显示', this.pagedLogEntries.length.toString(), '#9E9E9E')
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
    .border({
      width: 1,
      color: this.hoveredStatIndex === this.resolveStatIndex(label) ? color : AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredStatIndex === this.resolveStatIndex(label)))
    .translate({ y: HoverUtils.getTranslateY(this.hoveredStatIndex === this.resolveStatIndex(label), 4) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.hoveredStatIndex = isHover ? this.resolveStatIndex(label) : -1
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
          this.resetToFirstPageAndRefresh()
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
          this.resetToFirstPageAndRefresh()
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
          this.resetToFirstPageAndRefresh()
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
      Row() {
        Text(this.getFilterHintMessage())
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
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
        .height(36).layoutWeight(1).onClick(() => { this.showExportFormatDialog() })

      Button('清空日志').fontSize(AppStyles.FONT_SIZE_BODY).fontColor(AppColors.getColors(this.currentTheme).TAG_RED_TEXT)
        .backgroundColor(AppColors.getColors(this.currentTheme).TAG_RED_BG).borderRadius(AppStyles.RADIUS_SM)
        .height(36).layoutWeight(1).onClick(() => { this.clearLogs() })
    }
    .width('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_MD })
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
                this.autoExportEnabled = DEFAULT_LOG_STORAGE_CONFIG.autoExportEnabled
                promptAction.showToast({ message: '已恢复默认，请保存以生效' })
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
    .width('100%')
    .layoutWeight(1)
    .align(Alignment.Top)
  }

  @Builder
  storageConfigCard() {
    Column({ space: 0 }) {
      Text('日志存储配置').fontSize(AppStyles.FONT_SIZE_SUBTITLE).fontWeight(FontWeight.Medium)
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

      Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      Row() {
        Text('自动导出')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.autoExportEnabled })
          .selectedColor(AppColors.BRAND_PRIMARY)
          .onChange((value: boolean) => { this.autoExportEnabled = value })
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
      color: this.hoveredSettingsCardIndex === 0 ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).BORDER
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
        Text('审计诊断').fontSize(AppStyles.FONT_SIZE_SUBTITLE).fontWeight(FontWeight.Medium)
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

      Column({ space: 8 }) {
        ForEach(ALL_LOG_EVENT_TYPES, (type: LogEventType) => {
          Column({ space: 8 }) {
            Row() {
              Text(getLogEventTypeLabel(type))
                .fontSize(AppStyles.FONT_SIZE_BODY)
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

            Row() {
              Text(this.getDiagCountText(type))
                .fontSize(AppStyles.FONT_SIZE_CAPTION)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                .layoutWeight(1)
              Text(this.getDiagRecentTimeText(type))
                .fontSize(AppStyles.FONT_SIZE_CAPTION)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                .layoutWeight(1)
                .textAlign(TextAlign.End)
            }
            .width('100%')

          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_COMPONENT)
          .borderRadius(AppStyles.RADIUS_MD)
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
      color: this.hoveredSettingsCardIndex === 1 ? AppColors.WARNING : AppColors.getColors(this.currentTheme).BORDER
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


