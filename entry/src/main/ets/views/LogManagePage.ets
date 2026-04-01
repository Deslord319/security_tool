import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { ActionButtonStyles, AppColors, AppStyles } from '../constants/AppConstants'
import { CommonStrings } from '../constants/CommonStrings'
import { LogManageStrings } from '../constants/modules/LogManageStrings'
import {
  ExportActionResult,
  LogEntry,
  LogEventResult,
  LogEventType,
  LOG_EVENT_TYPE_OPTIONS,
  LOG_MAX_ENTRIES_OPTIONS,
  LOG_RETENTION_OPTIONS,
  formatLogTimestamp,
  getLogEventResultColor,
  getLogEventResultLabel,
  getLogEventTypeLabel
} from '../models/DataModels'
import { EmptyStatePanel } from '../components/EmptyStatePanel'
import { IconTextActionButton } from '../components/IconTextActionButton'
import { MetricSummaryCard } from '../components/MetricSummaryCard'
import { SectionCard } from '../components/SettingsSectionCard'
import { SectionSelectRow } from '../components/SectionRows'
import { SubPageHeader } from '../components/SubPageHeader'
import { DetailDialogShell } from '../components/DetailDialogShell'
import { EmptyStateStrings } from '../constants/modules/DialogStrings'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { ExportMessageUtils } from '../utils/ExportMessageUtils'
import { FormControlUtils } from '../utils/FormControlUtils'
import { DialogService } from '../utils/DialogService'
import { LogManageViewModel } from '../viewmodels/LogManageViewModel'

const TAG = 'LogManagePage'
const DOMAIN = 0x0012

function getPageLogEventTypeLabel(type: LogEventType): string {
  switch (type) {
    case LogEventType.CRASH:
      return '崩溃日志'
    case LogEventType.FILE:
      return '文件操作'
    case LogEventType.ACCOUNT:
      return '用户认证'
    case LogEventType.PERMISSION:
      return '权限变更'
    default:
      return '未知'
  }
}

function getPageLogEventResultLabel(result: LogEventResult): string {
  switch (result) {
    case LogEventResult.SUCCESS:
      return '成功'
    case LogEventResult.BLOCKED:
      return '已阻止'
    case LogEventResult.FAILED:
      return '失败'
    default:
      return '未知'
  }
}

interface LogDetailField {
  key: string
  label: string
  value: string
}

@CustomDialog
struct LogDetailDialogPanel {
  controller: CustomDialogController
  title: string = ''
  entry: LogEntry = {
    id: '',
    timestamp: 0,
    eventType: LogEventType.FILE,
    detail: '',
    result: LogEventResult.SUCCESS
  } as LogEntry
  onClose: () => void = () => {}
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  private pushTextField(fields: LogDetailField[], key: string, label: string, value?: string): void {
    if (!value) {
      return
    }
    let normalized = value.trim()
    if (normalized.length === 0) {
      return
    }
    fields.push({ key, label, value: normalized } as LogDetailField)
  }

  private pushNumberField(fields: LogDetailField[], key: string, label: string, value?: number): void {
    if (value === undefined) {
      return
    }
    fields.push({ key, label, value: `${value}` } as LogDetailField)
  }

  private getFields(): LogDetailField[] {
    let fields: LogDetailField[] = []
    this.pushTextField(fields, 'process', LogManageStrings.processLabel, this.entry.processName)
    this.pushNumberField(fields, 'pid', 'PID', this.entry.pid)
    this.pushNumberField(fields, 'uid', 'UID', this.entry.uid)
    this.pushTextField(fields, 'filePath', LogManageStrings.filePathLabel, this.entry.filePath)
    this.pushTextField(fields, 'remoteAddr', LogManageStrings.remoteAddressLabel, this.entry.remoteAddr)
    return fields
  }

  private getResultBackground(): ResourceColor {
    if (this.entry.result === LogEventResult.SUCCESS) {
      return AppColors.getColors(this.currentTheme).TAG_GREEN_BG
    }
    if (this.entry.result === LogEventResult.BLOCKED) {
      return AppColors.getColors(this.currentTheme).TAG_ORANGE_BG
    }
    return ActionButtonStyles.getDangerBackground(this.currentTheme, false)
  }

  @Builder
  private dialogContent() {
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
          .fontColor(getLogEventResultColor(this.entry.result))
          .backgroundColor(this.getResultBackground())
          .borderRadius(AppStyles.RADIUS_SM)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      }
      .width('100%')

      Column({ space: 6 }) {
        Text(LogManageStrings.detailTitle)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

        Text(this.entry.detail.trim().length > 0 ? this.entry.detail : LogManageStrings.detailEmpty)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .width('100%')
      }
      .width('100%')
      .padding(12)
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
      .borderRadius(AppStyles.RADIUS_MD)

      if (this.getFields().length > 0) {
        Column({ space: 8 }) {
          Text(LogManageStrings.additionalInfo)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

          ForEach(this.getFields(), (field: LogDetailField) => {
            Row() {
              Text(field.label)
                .fontSize(AppStyles.FONT_SIZE_CAPTION)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
                .width(84)

              Text(field.value)
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .layoutWeight(1)
            }
            .width('100%')
            .padding(12)
            .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
            .borderRadius(AppStyles.RADIUS_MD)
          }, (field: LogDetailField) => field.key)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  build() {
    DetailDialogShell({
      title: this.title,
      dialogWidth: 560,
      maxBodyHeight: 420,
      onClose: this.onClose,
      content: () => {
        this.dialogContent()
      }
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
  @State viewModel: LogManageViewModel = new LogManageViewModel()

  private detailDialogController?: CustomDialogController
  private initialized: boolean = false
  private readonly settingsFormControlWidth: number = 140
  private eventTypeFilterOptions: SelectOption[] = [
    { value: LogManageStrings.allEventTypes } as SelectOption,
    ...LOG_EVENT_TYPE_OPTIONS.map((option) => ({ value: option.label } as SelectOption))
  ]
  private resultFilterOptions: SelectOption[] = [
    { value: LogManageStrings.allResults } as SelectOption,
    { value: LogManageStrings.successOption } as SelectOption,
    { value: LogManageStrings.statBlocked } as SelectOption,
    { value: LogManageStrings.failedOption } as SelectOption
  ]

  aboutToAppear() {
    void this.initializeViewModel()
  }

  aboutToDisappear() {
    this.viewModel.deactivate()
    this.viewModel.destroy()
    this.dismissLogDetailDialog()
    this.initialized = false
  }

  private async initializeViewModel(): Promise<void> {
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext
      if (!this.initialized) {
        await this.viewModel.initialize(context)
        this.initialized = true
      } else {
        this.viewModel.refreshAll()
      }
      this.viewModel.activate()
    } catch (err) {
      hilog.error(DOMAIN, TAG, `initializeViewModel failed: ${JSON.stringify(err)}`)
    }
  }

  private dismissLogDetailDialog(): void {
    try {
      this.detailDialogController?.close()
    } catch (_err) {
    } finally {
      this.detailDialogController = undefined
    }
  }

  private openLogDetailDialog(entry: LogEntry): void {
    if (this.detailDialogController) {
      return
    }
    this.detailDialogController = new CustomDialogController({
      builder: LogDetailDialogPanel({
        controller: this.detailDialogController,
        title: LogManageStrings.detailDialogTitle,
        entry,
        onClose: () => {
          this.dismissLogDetailDialog()
          this.viewModel.closeDetail()
        }
      }),
      alignment: DialogAlignment.Center,
      autoCancel: true,
      customStyle: true,
      isModal: true,
      maskColor: AppColors.OVERLAY_BACKGROUND,
      cancel: () => {
        this.detailDialogController = undefined
        this.viewModel.closeDetail()
      }
    })
    this.detailDialogController.open()
  }

  private async handleExportLogs(): Promise<void> {
    let result: ExportActionResult = await this.viewModel.exportLogs()
    if (result.success) {
      DialogService.openSuccess(this.getUIContext(), ExportMessageUtils.buildExportSuccessText(result.fileName ?? 'security_log.csv'))
      return
    }
    DialogService.openFailure(this.getUIContext(), result.reason ?? CommonStrings.messageRetryLater)
  }

  private handleClearLogs(): void {
    DialogService.openConfirm(this.getUIContext(), {
      title: LogManageStrings.clearConfirmTitle,
      message: LogManageStrings.buildClearConfirmMessage(this.viewModel.state.summary.totalCount),
      confirmText: LogManageStrings.clearConfirmAction,
      cancelText: CommonStrings.actionCancel,
      onConfirm: async () => {
        let success = await this.viewModel.clearLogs()
        this.dismissLogDetailDialog()
        if (success) {
          DialogService.openSuccess(this.getUIContext(), LogManageStrings.clearSuccess)
          return
        }
        DialogService.openFailure(this.getUIContext(), CommonStrings.messageRetryLater)
      }
    })
  }

  private async handleSaveStorageSettings(): Promise<void> {
    let result = await this.viewModel.saveStorageSettings()
    if (!result.success) {
      DialogService.openFailure(this.getUIContext(), result.message)
      return
    }
    DialogService.openSuccess(this.getUIContext(), result.message)
  }

  private getSelectedEventTypeLabel(): string {
    let index = this.viewModel.state.filter.eventTypeIndex
    return index <= 0 ? LogManageStrings.allEventTypes : this.eventTypeFilterOptions[index].value as string
  }

  private getSelectedResultLabel(): string {
    let index = this.viewModel.state.filter.resultIndex
    return index <= 0 ? LogManageStrings.allResults : this.resultFilterOptions[index].value as string
  }

  private getPageSizeOptions(): SelectOption[] {
    return [20, 50, 100].map((size: number): SelectOption => ({ value: LogManageStrings.buildPageSizeText(size) } as SelectOption))
  }

  @Builder
  private buildMetricCard(title: string, value: string, description: string, start: string, end: string, icon: Resource) {
    MetricSummaryCard({
      title,
      primaryText: value,
      secondaryText: description,
      accentStart: start,
      accentEnd: end,
      icon,
      cardHeight: 116,
      iconTileSize: 62,
      iconTileRadius: 20,
      iconSize: 36,
      primaryFontSize: 26,
      secondaryMaxLines: 2,
      clickable: false
    })
  }

  @Builder
  private statisticsBar() {
    GridRow({ columns: 4, gutter: 12 }) {
      GridCol() {
        this.buildMetricCard(LogManageStrings.statTotal, `${this.viewModel.state.summary.totalCount}`, LogManageStrings.statTotalDescription,
          AppColors.BRAND_PRIMARY, AppColors.GRADIENT_FIREWALL_END, $r('app.media.folder'))
      }
      GridCol() {
        this.buildMetricCard(LogManageStrings.statToday, `${this.viewModel.state.summary.todayCount}`, LogManageStrings.statTodayDescription,
          AppColors.SUCCESS, AppColors.GRADIENT_LOG_END, $r('app.media.log'))
      }
      GridCol() {
        this.buildMetricCard(LogManageStrings.statBlocked, `${this.viewModel.state.summary.blockedCount}`, LogManageStrings.statBlockedDescription,
          AppColors.WARNING, AppColors.GRADIENT_IDENTITY_END, $r('app.media.alert'))
      }
      GridCol() {
        this.buildMetricCard(LogManageStrings.statCurrentShown, `${this.viewModel.state.list.pagedEntries.length}`, LogManageStrings.statCurrentShownDescription,
          AppColors.TEXT_MUTED, AppColors.GRADIENT_TOOL_END, $r('app.media.dashboard'))
      }
    }
    .width('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD })
  }

  @Builder
  private filterToolbar() {
    Row({ space: 8 }) {
      Select(this.eventTypeFilterOptions)
        .selected(this.viewModel.state.filter.eventTypeIndex)
        .value(this.getSelectedEventTypeLabel())
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
        .optionFont({ size: AppStyles.FONT_SIZE_BODY })
        .width(120)
        .height(36)
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .borderRadius(AppStyles.RADIUS_SM)
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .onSelect((index: number) => this.viewModel.setEventTypeIndex(index))

      Select(this.resultFilterOptions)
        .selected(this.viewModel.state.filter.resultIndex)
        .value(this.getSelectedResultLabel())
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
        .optionFont({ size: AppStyles.FONT_SIZE_BODY })
        .width(110)
        .height(36)
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .borderRadius(AppStyles.RADIUS_SM)
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .onSelect((index: number) => this.viewModel.setResultIndex(index))

      TextInput({ placeholder: LogManageStrings.searchPlaceholder, text: this.viewModel.state.filter.keyword })
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(FormControlUtils.text(this.currentTheme))
        .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .layoutWeight(1)
        .onChange((value: string) => this.viewModel.setKeyword(value))

      Button(LogManageStrings.refreshButton)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .onClick(() => this.viewModel.refreshAll())
    }
    .width('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_SM })
  }

  @Builder
  private filterHintView() {
    if (this.viewModel.state.filter.hintMessage.length > 0) {
      Row() {
        Text(this.viewModel.state.filter.hintMessage)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: 6, bottom: 4 })
    }
  }

  @Builder
  private logEntryRow(entry: LogEntry) {
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
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
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
    .onClick(() => {
      this.viewModel.openDetail(entry.id)
      this.openLogDetailDialog(entry)
    })
  }

  @Builder
  private logListView() {
    if (this.viewModel.state.loading) {
      Column() {
        LoadingProgress().width(48).height(48)
        Text(LogManageStrings.loading).fontSize(AppStyles.FONT_SIZE_BODY).margin({ top: 8 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.viewModel.state.list.allEntries.length === 0) {
      Scroll() {
        EmptyStatePanel({
          title: EmptyStateStrings.NO_RECORDS,
          description: EmptyStateStrings.CHECK_PERMISSIONS,
          radius: AppStyles.RADIUS_LG,
          verticalPadding: 24
        })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
    } else {
      Scroll() {
        Column({ space: 0 }) {
          List({ space: 1 }) {
            ForEach(this.viewModel.state.list.pagedEntries, (entry: LogEntry) => {
              ListItem() {
                this.logEntryRow(entry)
              }
            }, (entry: LogEntry) => entry.id)
          }
          .width('100%')
          .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_SM, bottom: AppStyles.PADDING_SM })
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
    }
  }

  @Builder
  private paginationToolbar() {
    if (!this.viewModel.state.loading && this.viewModel.state.list.allEntries.length > 0) {
      Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
      Row({ space: 12 }) {
        Text(LogManageStrings.buildPageRangeText(this.viewModel.getCurrentRangeText(), this.viewModel.state.list.allEntries.length))
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .layoutWeight(1)

        Select(this.getPageSizeOptions())
          .selected(this.viewModel.state.pagination.pageSizeIndex)
          .value(LogManageStrings.buildPageSizeText(this.viewModel.getCurrentPageSize()))
          .font({ size: AppStyles.FONT_SIZE_CAPTION })
          .fontColor(FormControlUtils.text(this.currentTheme))
          .selectedOptionFont({ size: AppStyles.FONT_SIZE_CAPTION })
          .optionFont({ size: AppStyles.FONT_SIZE_CAPTION })
          .width(126)
          .height(32)
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_SM)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onSelect((index: number) => this.viewModel.setPageSizeIndex(index))

        IconTextActionButton({
          label: LogManageStrings.previousPageButton,
          showIcon: false,
          kind: 'primary',
          isEnabled: this.viewModel.state.pagination.currentPage > 1,
          onTap: () => this.viewModel.goToPreviousPage()
        })

        Text(`${this.viewModel.state.pagination.currentPage}/${this.viewModel.state.pagination.totalPages}`)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .width(52)
          .textAlign(TextAlign.Center)

        TextInput({ text: this.viewModel.state.pagination.pageInputText, placeholder: LogManageStrings.pageInputPlaceholder })
          .type(InputType.Number)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .borderRadius(AppStyles.RADIUS_SM)
          .height(32)
          .width(62)
          .onChange((value: string) => this.viewModel.setPageInputText(value))

        IconTextActionButton({
          label: LogManageStrings.jumpButton,
          showIcon: false,
          kind: 'primary',
          isEnabled: this.viewModel.state.pagination.pageInputText.trim().length > 0,
          onTap: () => this.viewModel.jumpToInputPage()
        })

        IconTextActionButton({
          label: LogManageStrings.nextPageButton,
          showIcon: false,
          kind: 'primary',
          isEnabled: this.viewModel.state.pagination.currentPage < this.viewModel.state.pagination.totalPages,
          onTap: () => this.viewModel.goToNextPage()
        })
      }
      .width('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: 10, bottom: 10 })
    }
  }

  @Builder
  private headerActions() {
    Row({ space: 8 }) {
      if (this.viewModel.state.mode !== 'settings') {
        IconTextActionButton({ label: LogManageStrings.exportLogsButton, icon: $r('app.media.save'), kind: 'primary', onTap: () => { void this.handleExportLogs() } })
        IconTextActionButton({ label: LogManageStrings.clearLogsButton, icon: $r('app.media.trash'), kind: 'danger', onTap: () => this.handleClearLogs() })
        IconTextActionButton({
          label: LogManageStrings.openStorageSettingsButton,
          icon: $r('app.media.settings'),
          kind: 'primary',
          onTap: () => {
            this.viewModel.setMode('settings')
            this.dismissLogDetailDialog()
          }
        })
      } else {
        IconTextActionButton({ label: CommonStrings.actionSaveSettings, icon: $r('app.media.save'), kind: 'primary', onTap: () => { void this.handleSaveStorageSettings() } })
        IconTextActionButton({ label: LogManageStrings.backToLogListButton, icon: $r('app.media.log'), kind: 'primary', onTap: () => this.viewModel.setMode('list') })
      }
    }
    .margin({ left: 12 })
  }

  @Builder
  private storageSettingsContent() {
    SectionSelectRow({
      title: LogManageStrings.maxEntriesLabel,
      description: LogManageStrings.maxEntriesDescription,
      options: LogManagePage.STORAGE_MAX_ENTRY_OPTIONS,
      selectedIndex: this.viewModel.state.settings.maxEntriesIndex,
      value: `${LOG_MAX_ENTRIES_OPTIONS[this.viewModel.state.settings.maxEntriesIndex]}`,
      selectWidth: this.settingsFormControlWidth,
      onSelect: (index: number) => this.viewModel.setStorageMaxEntriesIndex(index)
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionSelectRow({
      title: LogManageStrings.retentionDaysLabel,
      description: LogManageStrings.retentionDaysDescription,
      options: LogManagePage.STORAGE_RETENTION_OPTIONS,
      selectedIndex: this.viewModel.state.settings.retentionIndex,
      value: `${LOG_RETENTION_OPTIONS[this.viewModel.state.settings.retentionIndex]}`,
      selectWidth: this.settingsFormControlWidth,
      onSelect: (index: number) => this.viewModel.setStorageRetentionIndex(index)
    })
  }

  build() {
    Column() {
      SubPageHeader({
        title: this.viewModel.state.mode === 'settings' ? LogManageStrings.settingsTitle : LogManageStrings.pageTitle,
        subtitle: this.viewModel.state.mode === 'settings' ? LogManageStrings.settingsSubtitle : LogManageStrings.pageSubtitle,
        currentTheme: this.currentTheme,
        onBack: () => this.onBack(),
        actions: () => {
          this.headerActions()
        }
      })

      if (this.viewModel.state.mode === 'settings') {
        Scroll() {
          Column({ space: 24 }) {
            SectionCard({
              title: LogManageStrings.settingsTitle,
              content: () => {
                this.storageSettingsContent()
              }
            })
          }
          .width('100%')
          .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_LG })
          .justifyContent(FlexAlign.Start)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
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
}
