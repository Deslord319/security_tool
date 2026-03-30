
import { ActionButtonStyles, AppColors, AppStyles } from '../constants/AppConstants'
import { CommonStrings } from '../constants/CommonStrings'
import { LogManageStrings } from '../constants/modules/LogManageStrings'
import { LogStorageService } from '../services/LogStorageService'
import {
  LogEntry,
  LogEventType,
  LogEventResult,
  LogFilter,
  LogStatistics,
  LOG_RETENTION_OPTIONS,
  LOG_MAX_ENTRIES_OPTIONS,
  LOG_EVENT_TYPE_OPTIONS,
  getLogEventTypeLabel,
  getLogEventResultLabel,
  getLogEventResultColor,
  formatLogTimestamp
} from '../models/DataModels'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { common } from '@kit.AbilityKit'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'
import { ExportMessageUtils } from '../utils/ExportMessageUtils'
import { SubPageHeader } from '../components/SubPageHeader'
import { SectionCard } from '../components/SettingsSectionCard'
import { SectionSelectRow } from '../components/SectionRows'
import { FormControlUtils } from '../utils/FormControlUtils'
import { LogStorageSettingsViewModel } from '../viewmodels/LogStorageSettingsViewModel'
import { IconTextActionButton } from '../components/IconTextActionButton'
import { DialogService } from '../utils/DialogService'

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
        Text(this.expanded ? LogManageStrings.collapse : LogManageStrings.expand)
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
        Text(this.expanded ? LogManageStrings.collapse : LogManageStrings.expand)
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

  private getResultTagBgColor(): ResourceColor {
    if (this.entry.result === LogEventResult.SUCCESS) {
      return AppColors.getColors(this.currentTheme).TAG_GREEN_BG
    }
    if (this.entry.result === LogEventResult.BLOCKED) {
      return AppColors.getColors(this.currentTheme).TAG_ORANGE_BG
    }
    return ActionButtonStyles.getDangerBackground(this.currentTheme, false)
  }

  private getMetricFields(): LogDetailField[] {
    let fields: LogDetailField[] = []
    if (this.hasValue(this.entry.processName)) {
      fields.push({ key: 'process', label: LogManageStrings.processLabel, value: this.displayValue(this.entry.processName) } as LogDetailField)
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
      fields.push({ key: 'file_path', label: LogManageStrings.filePathLabel, value: this.displayValue(this.entry.filePath) } as LogDetailField)
    }
    if (this.hasValue(this.entry.remoteAddr)) {
      fields.push({ key: 'remote_addr', label: LogManageStrings.remoteAddressLabel, value: this.displayValue(this.entry.remoteAddr) } as LogDetailField)
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
        Button(LogManageStrings.close)
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
              .fontColor(ActionButtonStyles.getPrimaryForeground(this.currentTheme))
              .backgroundColor(ActionButtonStyles.getPrimaryBackground(this.currentTheme, false))
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
            title: LogManageStrings.detailTitle,
            value: this.entry.detail.trim().length > 0 ? this.entry.detail : LogManageStrings.detailEmpty
          })

          if (this.getMetricFields().length > 0 || this.getInfoFields().length > 0) {
            Column({ space: 8 }) {
              Text(LogManageStrings.additionalInfo)
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
  private static readonly STORAGE_MAX_ENTRY_OPTIONS: SelectOption[] =
    LOG_MAX_ENTRIES_OPTIONS.map((value: number): SelectOption => ({ value: `${value}` } as SelectOption))
  private static readonly STORAGE_RETENTION_OPTIONS: SelectOption[] =
    LOG_RETENTION_OPTIONS.map((value: number): SelectOption => ({ value: `${value}` } as SelectOption))
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onBack: () => void = () => {}
  @State hoveredStatIndex: number = -1
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

  @State filterEventType: number = -1
  @State filterResult: number = -1
  @State filterKeyword: string = ''

  @State showSettings: boolean = false
  @State isLoading: boolean = false
  @State storageSettingsViewModel: LogStorageSettingsViewModel = new LogStorageSettingsViewModel()

  private refreshTimerId: number = -1
  private readonly REFRESH_INTERVAL_MS: number = 1500
  private readonly SETTINGS_FORM_CONTROL_WIDTH: number = 140
  private readonly pageSizeOptions: number[] = [20, 50, 100]
  private detailDialogController?: CustomDialogController
  private eventTypeFilterOptions: SelectOption[] = [
    { value: LogManageStrings.allEventTypes } as SelectOption,
    ...LOG_EVENT_TYPE_OPTIONS.map((opt) => ({ value: opt.label } as SelectOption))
  ]
  private resultFilterOptions: SelectOption[] = [
    { value: LogManageStrings.allResults } as SelectOption,
    { value: LogManageStrings.successOption } as SelectOption,
    { value: LogManageStrings.statBlocked } as SelectOption,
    { value: LogManageStrings.failedOption } as SelectOption
  ]

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, `aboutToAppear: showSettings=${this.showSettings}, filterEventType=${this.filterEventType}`)
    this.initServices()
    this.startRefreshTimer()
  }

  aboutToDisappear() {
    hilog.info(DOMAIN, TAG, `aboutToDisappear: showSettings=${this.showSettings}, filterEventType=${this.filterEventType}`)
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
      let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      await LogStorageService.init(context)
      this.storageSettingsViewModel.initialize(LogStorageService.getConfig())

      this.refreshAll()
      hilog.info(0x0006, TAG, 'Services initialized')
    } catch (err) {
      hilog.error(0x0006, TAG, `initServices failed: ${JSON.stringify(err)}`)
    }
    this.isLoading = false
  }

  private refreshAll() {
    this.refreshData()
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

  private applyManualFilterChange(): void {
    this.resetToFirstPageAndRefresh()
  }

  private openSettingsFromList(): void {
    this.storageSettingsViewModel.initialize(LogStorageService.getConfig())
    this.showSettings = true
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

  private getFilterHintMessage(): string {
    if (this.filterEventType < 0) {
      return ''
    }

    let selectedType = this.filterEventType as LogEventType
    if (selectedType === LogEventType.FILE) {
      return this.logEntries.length > 0 ? LogManageStrings.fileFilterHint : LogManageStrings.fileFilterEmptyHint
    }
    let totalByType = this.statistics.byType.get(selectedType) || 0
    if (totalByType > 0 && this.logEntries.length === 0) {
      return LogManageStrings.emptyDescription
    }
    return ''
  }

  async exportLogs() {
    if (this.logEntries.length === 0) {
      DialogService.openFailure(this.getUIContext(), LogManageStrings.noExportableLogs)
      return
    }

    let result = await LogStorageService.exportToCsvFile({
      csvContent: LogStorageService.buildCsvContent(this.logEntries)
    })
    if (result.success) {
        DialogService.openSuccess(
        this.getUIContext(),
        ExportMessageUtils.buildExportSuccessText(result.fileName ?? 'security_log.csv')
      )
      return
    }

    DialogService.openFailure(
      this.getUIContext(),
      LogManageStrings.buildExportFailedText(DialogService.displayReason(result.errorMessage, CommonStrings.messageRetryLater))
    )
  }

  private openLogDetailTableDialog(entry: LogEntry): void {
    this.detailDialogController = new CustomDialogController({
      builder: LogDetailDialog({
        controller: this.detailDialogController as CustomDialogController,
        title: LogManageStrings.detailDialogTitle,
        entry: entry
      }),
      autoCancel: true,
      customStyle: true,
      alignment: DialogAlignment.Center
    })
    this.detailDialogController.open()
  }

  clearLogs() {
    DialogService.openConfirm(this.getUIContext(), {
      title: LogManageStrings.clearConfirmTitle,
      message: LogManageStrings.buildClearConfirmMessage(this.statistics.totalCount),
      confirmText: LogManageStrings.clearConfirmAction,
      cancelText: CommonStrings.actionCancel,
      onConfirm: async () => {
        await LogStorageService.clearAll()
        this.refreshAll()
        DialogService.openSuccess(this.getUIContext(), LogManageStrings.clearSuccess)
      }
    })
  }

  async saveStorageSettings() {
    let result = await this.storageSettingsViewModel.save()
    if (!result.success) {
      DialogService.openFailure(this.getUIContext(), result.message)
      return
    }

    this.refreshAll()
    DialogService.openSuccess(this.getUIContext(), result.message)
  }
  build() {
    Column() {
      SubPageHeader({
        title: this.showSettings ? LogManageStrings.settingsTitle : LogManageStrings.pageTitle,
        subtitle: this.showSettings ? LogManageStrings.settingsSubtitle : LogManageStrings.pageSubtitle,
        currentTheme: this.currentTheme,
        onBack: () => this.onBack(),
        actions: () => {
          this.headerActions()
        }
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
      this.statItem(0, LogManageStrings.statTotal, this.statistics.totalCount.toString(), AppColors.BRAND_PRIMARY)
      this.statItem(1, LogManageStrings.statToday, this.statistics.todayCount.toString(), AppColors.SUCCESS)
      this.statItem(2, LogManageStrings.statBlocked, this.statistics.blockedCount.toString(), AppColors.WARNING)
      this.statItem(3, LogManageStrings.statCurrentShown, this.pagedLogEntries.length.toString(), AppColors.TEXT_MUTED)
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
        .value(this.filterEventType < 0 ? LogManageStrings.allEventTypes :
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
        .value(this.filterResult < 0 ? LogManageStrings.allResults :
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

      TextInput({ placeholder: LogManageStrings.searchPlaceholder, text: this.filterKeyword })
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

      Button(LogManageStrings.refreshButton)
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
        Text(LogManageStrings.loading)
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
        Text(LogManageStrings.emptyTitle)
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        Text(LogManageStrings.emptyDescription)
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
        Text(LogManageStrings.buildPageRangeText(this.getCurrentRangeText(), this.logEntries.length))
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .layoutWeight(1)

        Select(this.getPageSizeOptions())
          .selected(this.pageSizeIndex)
          .value(LogManageStrings.buildPageSizeText(this.getCurrentPageSize()))
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

        Button(LogManageStrings.previousPageButton)
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

        TextInput({ text: this.pageInputValue, placeholder: LogManageStrings.pageInputPlaceholder })
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

        Button(LogManageStrings.jumpButton)
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

        Button(LogManageStrings.nextPageButton)
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
        .fontColor(ActionButtonStyles.getPrimaryForeground(this.currentTheme))
        .backgroundColor(ActionButtonStyles.getPrimaryBackground(this.currentTheme, false))
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
          Text(`${LogManageStrings.processLabel}: ${entry.processName}${entry.pid !== undefined ? ` (PID: ${entry.pid})` : ''}`)
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
      IconTextActionButton({
        label: LogManageStrings.exportLogsButton,
        icon: $r('app.media.save'),
        kind: 'primary',
        onTap: () => { this.exportLogs() }
      })

      IconTextActionButton({
        label: LogManageStrings.clearLogsButton,
        icon: $r('app.media.trash'),
        kind: 'danger',
        onTap: () => { this.clearLogs() }
      })
    }
    .width('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_MD })
  }

  @Builder
  private headerActions() {
    Column() {
      Row({ space: 8 }) {
        if (!this.showSettings) {
          IconTextActionButton({
            label: LogManageStrings.exportLogsButton,
            icon: $r('app.media.save'),
            kind: 'primary',
            onTap: () => {
              this.exportLogs()
            }
          })

          IconTextActionButton({
            label: LogManageStrings.clearLogsButton,
            icon: $r('app.media.trash'),
            kind: 'danger',
            onTap: () => {
              this.clearLogs()
            }
          })
        }

        if (!this.showSettings) {
          IconTextActionButton({
            label: LogManageStrings.openStorageSettingsButton,
            icon: $r('app.media.settings'),
            kind: 'primary',
            onTap: () => {
              this.openSettingsFromList()
            }
          })
        } else {
          IconTextActionButton({
            label: CommonStrings.actionSaveSettings,
            icon: $r('app.media.save'),
            kind: 'primary',
            onTap: () => {
              this.saveStorageSettings()
            }
          })

          IconTextActionButton({
            label: LogManageStrings.backToLogListButton,
            icon: $r('app.media.log'),
            kind: 'primary',
            onTap: () => {
              this.showSettings = false
              this.refreshData()
            }
          })
        }
      }
    }
    .margin({ left: 12 })
    .alignItems(HorizontalAlign.End)
  }

  @Builder
  storageSettingsView() {
    Column() {
      Scroll() {
        Column({ space: 24 }) {
          this.storageConfigCard()
        }
        .width('100%')
        .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_LG })
        .justifyContent(FlexAlign.Start)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)

    }
    .width('100%')
    .layoutWeight(1)
    .align(Alignment.Top)
  }

  @Builder
  storageConfigCard() {
    SectionCard({
      title: LogManageStrings.settingsTitle,
      content: () => {
        this.storageConfigRows()
      }
    })
  }

  @Builder
  storageConfigRows() {
    SectionSelectRow({
      title: LogManageStrings.maxEntriesLabel,
      description: LogManageStrings.maxEntriesDescription,
      options: LogManagePage.STORAGE_MAX_ENTRY_OPTIONS,
      selectedIndex: this.storageSettingsViewModel.state.maxEntriesIndex,
      value: `${LOG_MAX_ENTRIES_OPTIONS[this.storageSettingsViewModel.state.maxEntriesIndex]}`,
      selectWidth: this.SETTINGS_FORM_CONTROL_WIDTH,
      onSelect: (index: number) => {
        this.storageSettingsViewModel.setMaxEntriesIndex(index)
      }
    })

    Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionSelectRow({
      title: LogManageStrings.retentionDaysLabel,
      description: LogManageStrings.retentionDaysDescription,
      options: LogManagePage.STORAGE_RETENTION_OPTIONS,
      selectedIndex: this.storageSettingsViewModel.state.retentionIndex,
      value: `${LOG_RETENTION_OPTIONS[this.storageSettingsViewModel.state.retentionIndex]}`,
      selectWidth: this.SETTINGS_FORM_CONTROL_WIDTH,
      onSelect: (index: number) => {
        this.storageSettingsViewModel.setRetentionIndex(index)
      }
    })
  }
}
