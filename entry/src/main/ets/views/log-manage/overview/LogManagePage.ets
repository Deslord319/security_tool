import { common } from '@kit.AbilityKit'
import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { AppResources } from '../../../constants/AppResources'
import { ActionText, ModuleText, ResultText, MessageText } from '../../../constants/StringCatalog'
import { LoadingStrings } from '../../../constants/modules/DialogStrings'
import {
  LogManageActionStrings,
  LogManageClearingStrings,
  LogManageDetailStrings,
  LogManageFilterStrings,
  LogManageImportStrings,
  LogManagePageStrings,
  LogManageSettingStrings,
  LogManageStatStrings
} from '../../../constants/modules/LogManageStrings'
import { ExportActionResult } from '../../../models/CommonModels'
import {
  LogEntry,
  LOG_MAX_ENTRIES_OPTIONS,
  LOG_RETENTION_OPTIONS
} from '../../../models/LogModels'
import { LOG_PAGE_SIZE_OPTIONS } from '../../../models/LogManageModels'
import {
  LOG_EVENT_TYPE_OPTIONS,
  LOG_TIME_RANGE_OPTIONS
} from '../../../presentation/log-manage/LogPresentationMapper'
import { ThemeMode } from '../../../theme/ThemeColors'
import { getScrollBarColor, SCROLL_BAR_WIDTH_DEFAULT, SCROLL_BAR_WIDTH_HOVER } from '../../../utils/ScrollBarStyleUtils'
import { ExportMessageUtils } from '../../../utils/ExportMessageUtils'
import { DialogService } from '../../../utils/DialogService'
import { LogManageViewModel } from '../../../viewmodels/log-manage/overview/LogManageViewModel'
import { ImportLogsResult, LogImportSelectionResult } from '../../../models/LogImportModels'
import { LogUtils } from '../../../utils/LogUtils'
import { LogEntriesPanel } from '../../../components/log-manage/entries/LogEntriesPanel'
import { LogPaginationBar } from '../../../components/log-manage/entries/LogPaginationBar'
import { SubPageHeader } from '../../../components/SubPageHeader'
import { IconTextActionButton } from '../../../components/IconTextActionButton'
import { LogStorageSettingsPanel } from '../../../components/log-manage/storage-settings/LogStorageSettingsPanel'
import { LogDetailDialog } from '../../../components/log-manage/detail/LogDetailDialog'
import { CompactSummaryCard } from '../../../components/CompactSummaryCard'
import { LoadingStatePanel } from '../../../components/LoadingStatePanel'
import { StyledSelect } from '../../../components/StyledSelect'
import { StyledTextInput } from '../../../components/StyledTextInput'

const TAG = 'LogManagePage'

@ComponentV2
export struct LogManagePage {
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param onBack: () => void = () => {}
  @Param viewModel: LogManageViewModel | null = null
  @Local ownedViewModel: LogManageViewModel = new LogManageViewModel()
  @Local private settingsScrollBarWidth: number = SCROLL_BAR_WIDTH_DEFAULT
  @Local private isImportProcessing: boolean = false
  private detailDialogController?: CustomDialogController

  private eventTypeFilterOptions: SelectOption[] = [
    { value: LogManageFilterStrings.ALL_EVENT_TYPES } as SelectOption,
    ...LOG_EVENT_TYPE_OPTIONS.map((option) => ({ value: option.label } as SelectOption))
  ]
  private timeRangeFilterOptions: SelectOption[] = LOG_TIME_RANGE_OPTIONS.map((option) => ({ value: option.label } as SelectOption))

  aboutToAppear() {
    this.initializeViewModels()
  }

  aboutToDisappear() {
    this.getActiveViewModel().deactivate()
    if (!this.viewModel) {
      this.ownedViewModel.destroy()
    }
    this.closeDetailDialog()
  }

  private async initializeViewModels(): Promise<void> {
    try {
      let viewModel = this.getActiveViewModel()
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext
      if (!viewModel.state.initialized) {
        let initResult = await viewModel.initialize(context)
        if (!initResult.success) {
          LogUtils.error(TAG, `initializeViewModels list init failed: ${initResult.code}`)
          return
        }
      }
      viewModel.activate()
      await viewModel.refreshAll()
    } catch (err) {
      LogUtils.error(TAG, `initializeViewModels failed: ${JSON.stringify(err)}`)
    }
  }

  private getActiveViewModel(): LogManageViewModel {
    return this.viewModel ?? this.ownedViewModel
  }

  private async openStorageSettings(): Promise<void> {
    try {
      this.closeDetailDialog()
      await this.getActiveViewModel().setMode('settings')
    } catch (err) {
      LogUtils.error(TAG, `openStorageSettings failed: ${JSON.stringify(err)}`)
    }
  }

  private async backToLogList(): Promise<void> {
    await this.getActiveViewModel().setMode('list')
  }

  private openLogDetailDialog(entry: LogEntry): void {
    let viewModel = this.getActiveViewModel()
    this.detailDialogController = DialogService.closeController(this.detailDialogController)
    viewModel.openDetail(entry.id)
    try {
      this.detailDialogController = new CustomDialogController({
        builder: LogDetailDialog({
          controller: this.detailDialogController,
          title: LogManageDetailStrings.DIALOG_TITLE,
          entry: entry,
          currentTheme: this.currentTheme,
          onClose: () => this.closeDetailDialog()
        }),
        alignment: DialogAlignment.Center,
        autoCancel: false,
        customStyle: true,
        isModal: true,
        maskColor: AppColors.OVERLAY_BACKGROUND,
        cancel: () => {
          this.detailDialogController = undefined
          viewModel.closeDetail()
        }
      })
      this.detailDialogController.open()
    } catch (err) {
      LogUtils.warn(TAG, `openLogDetailDialog failed: ${JSON.stringify(err)}`)
      this.closeDetailDialog()
    }
  }

  private async handleExportLogs(): Promise<void> {
    let context = this.getUIContext().getHostContext() as common.UIAbilityContext
    let result: ExportActionResult = await this.getActiveViewModel().exportLogs(context)
    if (result.success) {
      DialogService.openSuccess(this.getUIContext(), ExportMessageUtils.buildExportSuccessText(result.fileName ?? 'security_log.csv'))
      return
    }
    DialogService.openFailure(this.getUIContext(), result.reason ?? MessageText.RETRY_LATER)
  }

  private async handleImportLogs(): Promise<void> {
    if (this.isImportProcessing) {
      return
    }
    let context = this.getUIContext().getHostContext() as common.UIAbilityContext
    let viewModel = this.getActiveViewModel()
    let selection: LogImportSelectionResult = await viewModel.pickImportTargets(context)
    if (!selection.success) {
      DialogService.openFailure(this.getUIContext(), this.mapImportFailureText(selection.code))
      return
    }
    this.isImportProcessing = true
    let result: ImportLogsResult = {
      success: false,
      code: 'extract_failed',
      extractedFileCount: 0,
      scannedFileCount: 0,
      parsedEntryCount: 0,
      insertedEntryCount: 0,
      skippedDuplicateCount: 0,
      skippedExpiredCount: 0,
      droppedEntryCount: 0,
      failedEntryCount: 0
    }
    try {
      await this.waitImportOverlayReady()
      result = await viewModel.importSelectedLogs(selection.archivePath, selection.targetDirectory)
    } finally {
      this.isImportProcessing = false
    }
    if (result.success) {
      DialogService.openSuccess(this.getUIContext(), LogManageImportStrings.ADD_SUCCESS)
      return
    }
    DialogService.openFailure(this.getUIContext(), this.mapImportFailureText(result.code))
  }

  private mapImportFailureText(code: string): string {
    if (code === 'user_canceled') {
      return LogManageImportStrings.USER_CANCELED
    }
    if (code === 'invalid_archive') {
      return LogManageImportStrings.INVALID_ARCHIVE
    }
    if (code === 'extract_failed') {
      return LogManageImportStrings.EXTRACT_FAILED
    }
    if (code === 'save_failed') {
      return LogManageImportStrings.SAVE_FAILED
    }
    return MessageText.RETRY_LATER
  }

  private async waitImportOverlayReady(): Promise<void> {
    await new Promise<void>((resolve: () => void) => {
      setTimeout(() => resolve(), 180)
    })
  }

  private handleClearLogs(): void {
    let viewModel = this.getActiveViewModel()
    DialogService.openConfirm(this.getUIContext(), {
      title: LogManageClearingStrings.CONFIRM_TITLE,
      message: LogManageClearingStrings.buildConfirmMessage(viewModel.state.summary.totalCount),
      confirmText: ActionText.CLEAR,
      cancelText: ActionText.CANCEL,
      onConfirm: async () => {
        let result = await viewModel.clearLogs()
        this.closeDetailDialog()
        if (result.success) {
          DialogService.openSuccess(this.getUIContext(), LogManageClearingStrings.SUCCESS)
          return
        }
        DialogService.openFailure(this.getUIContext(), MessageText.RETRY_LATER)
      }
    })
  }

  private async handleSaveStorageSettings(): Promise<void> {
    let result = await this.getActiveViewModel().saveStorageSettings()
    if (!result.success) {
      DialogService.openFailure(this.getUIContext(), result.code === 'no_changes' ? MessageText.NO_CHANGES : ResultText.SAVE_FAILED)
      return
    }
    DialogService.openSuccess(this.getUIContext(), LogManageSettingStrings.SAVE_SUCCESS)
  }

  @Builder
  private summaryCards() {
    GridRow({ columns: 4, gutter: 12 }) {
      GridCol() {
        CompactSummaryCard({
          title: LogManageStatStrings.TOTAL,
          valueText: `${this.getActiveViewModel().state.summary.totalCount}`,
          description: LogManageStatStrings.TOTAL_DESCRIPTION,
          icon: AppResources.FOLDER_ICON,
          accentStart: AppColors.BRAND_PRIMARY,
          accentEnd: AppColors.GRADIENT_FIREWALL_END,
          preset: 'log',
          currentTheme: this.currentTheme
        })
      }
      GridCol() {
        CompactSummaryCard({
          title: LogManageStatStrings.TODAY,
          valueText: `${this.getActiveViewModel().state.summary.todayCount}`,
          description: LogManageStatStrings.TODAY_DESCRIPTION,
          icon: AppResources.LOG_ICON,
          accentStart: AppColors.SUCCESS,
          accentEnd: AppColors.GRADIENT_LOG_END,
          preset: 'log',
          currentTheme: this.currentTheme
        })
      }
      GridCol() {
        CompactSummaryCard({
          title: LogManageStatStrings.FILTERED,
          valueText: `${this.getActiveViewModel().state.summary.filteredCount}`,
          description: LogManageStatStrings.FILTERED_DESCRIPTION,
          icon: AppResources.ALERT_ICON,
          accentStart: AppColors.WARNING,
          accentEnd: AppColors.GRADIENT_IDENTITY_END,
          preset: 'log',
          currentTheme: this.currentTheme
        })
      }
      GridCol() {
        CompactSummaryCard({
          title: LogManageStatStrings.CURRENT_SHOWN,
          valueText: `${this.getActiveViewModel().state.summary.currentShownCount}`,
          description: LogManageStatStrings.CURRENT_SHOWN_DESCRIPTION,
          icon: AppResources.DASHBOARD_ICON,
          accentStart: AppColors.GRADIENT_TOOL_START,
          accentEnd: AppColors.GRADIENT_TOOL_END,
          preset: 'log',
          currentTheme: this.currentTheme
        })
      }
    }
    .width('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD })
  }

  @Builder
  private headerRightActions() {
    Row({ space: 8 }) {
      if (this.getActiveViewModel().state.mode === 'list') {
        IconTextActionButton({
          label: LogManageActionStrings.EXPORT_LOGS,
          icon: AppResources.SAVE_ICON,
          currentTheme: this.currentTheme,
          onTap: () => {
            this.handleExportLogs()
          }
        })
        IconTextActionButton({
          label: LogManageActionStrings.IMPORT_LOGS,
          icon: AppResources.LOG_ICON,
          currentTheme: this.currentTheme,
          isEnabled: !this.isImportProcessing,
          onTap: () => {
            this.handleImportLogs()
          }
        })
        IconTextActionButton({
          label: LogManageActionStrings.CLEAR_LOGS,
          icon: AppResources.TRASH_ICON,
          kind: 'danger',
          currentTheme: this.currentTheme,
          onTap: () => this.handleClearLogs()
        })
        IconTextActionButton({
          label: LogManageActionStrings.OPEN_STORAGE_SETTINGS,
          icon: AppResources.SETTINGS_ICON,
          currentTheme: this.currentTheme,
          onTap: () => {
            this.openStorageSettings()
          }
        })
      } else {
        IconTextActionButton({
          label: ActionText.SAVE_SETTINGS,
          icon: AppResources.SAVE_ICON,
          currentTheme: this.currentTheme,
          isEnabled: this.getActiveViewModel().settingsViewModel.state.dirty &&
            !this.getActiveViewModel().settingsViewModel.state.saving,
          onTap: () => {
            this.handleSaveStorageSettings()
          }
        })
        IconTextActionButton({
          label: LogManageActionStrings.BACK_TO_LOG_LIST,
          icon: AppResources.LOG_ICON,
          currentTheme: this.currentTheme,
          onTap: () => {
            this.backToLogList()
          }
        })
      }
    }
  }

  @Builder
  private settingsPanel() {
    LogStorageSettingsPanel({
      maxLocalEntries: this.getActiveViewModel().settingsViewModel.state.maxLocalEntries,
      retentionDays: this.getActiveViewModel().settingsViewModel.state.retentionDays,
      currentTheme: this.currentTheme,
      onSelectMaxEntries: (index: number) => {
        this.getActiveViewModel().settingsViewModel.setMaxLocalEntries(LOG_MAX_ENTRIES_OPTIONS[index] ??
          LOG_MAX_ENTRIES_OPTIONS[0])
      },
      onSelectRetentionDays: (index: number) => {
        this.getActiveViewModel().settingsViewModel.setRetentionDays(LOG_RETENTION_OPTIONS[index] ??
          LOG_RETENTION_OPTIONS[0])
      }
    })
  }

  @Builder
  private importLoadingOverlay() {
    Column() {
      Column({ space: 14 }) {
        LoadingProgress()
          .width(AppStyles.MODAL_LOADING_INDICATOR_SIZE)
          .height(AppStyles.MODAL_LOADING_INDICATOR_SIZE)

        Text(LogManageImportStrings.IMPORTING)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .textAlign(TextAlign.Center)
      }
      .width(AppStyles.LOADING_DIALOG_WIDTH)
      .padding({
        left: AppStyles.LOADING_DIALOG_PADDING_HORIZONTAL,
        right: AppStyles.LOADING_DIALOG_PADDING_HORIZONTAL,
        top: AppStyles.LOADING_DIALOG_PADDING_VERTICAL,
        bottom: AppStyles.LOADING_DIALOG_PADDING_VERTICAL
      })
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
      .borderRadius(AppStyles.RADIUS_LG)
      .shadow({
        radius: AppStyles.LOADING_DIALOG_SHADOW_RADIUS,
        color: this.currentTheme === ThemeMode.DARK ? AppColors.MODAL_SHADOW_DARK : AppColors.MODAL_SHADOW_LIGHT,
        offsetX: 0,
        offsetY: AppStyles.LOADING_DIALOG_SHADOW_OFFSET_Y
      })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppColors.OVERLAY_BACKGROUND)
    .zIndex(10)
  }

  private closeDetailDialog(): void {
    this.detailDialogController = DialogService.closeController(this.detailDialogController)
    this.getActiveViewModel().closeDetail()
  }

  @Builder
  private filterToolbar() {
    Row({ space: 8 }) {
      StyledSelect({
        options: this.eventTypeFilterOptions,
        selectedIndex: this.getActiveViewModel().state.filter.eventTypeIndex,
        value: (this.eventTypeFilterOptions[this.getActiveViewModel().state.filter.eventTypeIndex]?.value as string) ??
          LogManageFilterStrings.ALL_EVENT_TYPES,
        controlWidth: 120,
        controlHeight: 36,
        radius: AppStyles.RADIUS_SM,
        currentTheme: this.currentTheme,
        onSelect: (index: number) => { void this.getActiveViewModel().setEventTypeIndex(index) }
      })

      StyledSelect({
        options: this.timeRangeFilterOptions,
        selectedIndex: this.getActiveViewModel().state.filter.timeRangeIndex,
        value: (this.timeRangeFilterOptions[this.getActiveViewModel().state.filter.timeRangeIndex]?.value as string) ??
          LogManageFilterStrings.ALL_TIME,
        controlWidth: 128,
        controlHeight: 36,
        radius: AppStyles.RADIUS_SM,
        currentTheme: this.currentTheme,
        onSelect: (index: number) => { void this.getActiveViewModel().setTimeRangeIndex(index) }
      })

      StyledTextInput({
        placeholder: LogManageFilterStrings.SEARCH_PLACEHOLDER,
        text: this.getActiveViewModel().state.filter.keyword,
        controlHeight: 36,
        radius: AppStyles.RADIUS_SM,
        currentTheme: this.currentTheme,
        onChange: (value: string) => { void this.getActiveViewModel().setKeyword(value) }
      })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_SM })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        SubPageHeader({
          title: this.getActiveViewModel().state.mode === 'settings' ? LogManagePageStrings.SETTINGS_TITLE : ModuleText.LOG_MANAGE,
          subtitle: this.getActiveViewModel().state.mode === 'settings' ?
            LogManagePageStrings.SETTINGS_SUBTITLE : LogManagePageStrings.SUBTITLE,
          currentTheme: this.currentTheme,
          onBack: this.onBack,
          actions: () => {
            this.headerRightActions()
          }
        })

        if (this.getActiveViewModel().state.mode === 'settings') {
          Scroll() {
            Column({ space: 24 }) {
              this.settingsPanel()
            }
            .width('100%')
            .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_LG })
            .justifyContent(FlexAlign.Start)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          .scrollBarColor(getScrollBarColor(this.currentTheme))
          .scrollBarWidth(this.settingsScrollBarWidth)
          .onHover((isHover: boolean) => {
            this.settingsScrollBarWidth = isHover ? SCROLL_BAR_WIDTH_HOVER : SCROLL_BAR_WIDTH_DEFAULT
          })
          .align(Alignment.Top)
        } else {
          if (this.getActiveViewModel().state.initialized) {
            this.summaryCards()
            this.filterToolbar()
            LogEntriesPanel({
              loading: this.getActiveViewModel().state.loading,
              listState: this.getActiveViewModel().state.list,
              filterState: this.getActiveViewModel().state.filter,
              currentTheme: this.currentTheme,
              onEntryClick: (entry: LogEntry) => {
                this.openLogDetailDialog(entry)
              }
            })
            LogPaginationBar({
              loading: this.getActiveViewModel().state.loading,
              listState: this.getActiveViewModel().state.list,
              summaryState: this.getActiveViewModel().state.summary,
              paginationState: this.getActiveViewModel().state.pagination,
              currentTheme: this.currentTheme,
              pageSizeOptions: LOG_PAGE_SIZE_OPTIONS,
              onSelectPageSize: (index: number) => { void this.getActiveViewModel().setPageSizeIndex(index) },
              onChangePageInput: (value: string) => this.getActiveViewModel().setPageInputText(value),
              onJumpPage: () => { void this.getActiveViewModel().jumpToInputPage() },
              onPrevPage: () => { void this.getActiveViewModel().goToPreviousPage() },
              onNextPage: () => { void this.getActiveViewModel().goToNextPage() }
            })
          } else {
            LoadingStatePanel({
              message: LoadingStrings.LOADING,
              indicatorSize: AppStyles.LOADING_INDICATOR_SIZE,
              spacing: 12,
              currentTheme: this.currentTheme
            })
              .layoutWeight(1)
          }
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)

      if (this.isImportProcessing) {
        this.importLoadingOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }
}
