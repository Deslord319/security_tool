import { common } from '@kit.AbilityKit'
import { AppColors, AppStyles } from '../constants/AppConstants'
import { CommonStrings } from '../constants/CommonStrings'
import { LoadingStrings, ResultStrings } from '../constants/modules/DialogStrings'
import { LogManageStrings } from '../constants/modules/LogManageStrings'
import {
  ExportActionResult,
  LogEntry,
  LOG_EVENT_TYPE_OPTIONS,
  LOG_MAX_ENTRIES_OPTIONS,
  LOG_RETENTION_OPTIONS
} from '../models/DataModels'
import { LogManageState, LogStorageSettingsState } from '../models/LogManageModels'
import { PresentationStrings } from '../constants/modules/PresentationStrings'
import { ThemeMode } from '../theme/ThemeColors'
import { ExportMessageUtils } from '../utils/ExportMessageUtils'
import { FormControlUtils } from '../utils/FormControlUtils'
import { DialogService } from '../utils/DialogService'
import { LogManageViewModel } from '../viewmodels/log-manage/LogManageViewModel'
import { LogUtils } from '../utils/LogUtils'
import { LogSummaryCards } from '../components/LogSummaryCards'
import { LogEntriesPanel } from '../components/LogEntriesPanel'
import { LogPaginationBar } from '../components/LogPaginationBar'
import { SubPageHeader } from '../components/SubPageHeader'
import { IconTextActionButton } from '../components/IconTextActionButton'
import { LogStorageSettingsPanel } from '../components/LogStorageSettingsPanel'
import { DetailDialogOverlay } from '../components/DetailDialogShell'
import { LogDetailDialog } from '../components/LogDetailDialog'

const TAG = 'LogManagePage'

@ComponentV2
export struct LogManagePage {
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param onBack: () => void = () => {}
  private viewModel: LogManageViewModel = new LogManageViewModel()
  @Local state: LogManageState = this.viewModel.state
  @Local settingsState: LogStorageSettingsState = this.viewModel.settingsViewModel.state
  @Local listReady: boolean = false

  private eventTypeFilterOptions: SelectOption[] = [
    { value: LogManageStrings.allEventTypes } as SelectOption,
    ...LOG_EVENT_TYPE_OPTIONS.map((option) => ({ value: option.label } as SelectOption))
  ]
  private resultFilterOptions: SelectOption[] = [
    { value: LogManageStrings.allResults } as SelectOption,
    { value: ResultStrings.SUCCESS } as SelectOption,
    { value: PresentationStrings.logResultBlocked } as SelectOption,
    { value: ResultStrings.FAILED } as SelectOption
  ]

  aboutToAppear() {
    this.listReady = false
    void this.initializeViewModels()
  }

  aboutToDisappear() {
    this.viewModel.deactivate()
    this.viewModel.destroy()
    this.dismissLogDetailDialog()
  }

  private async initializeViewModels(): Promise<void> {
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext
      let initResult = await this.viewModel.initialize(context)
      if (!initResult.success) {
        LogUtils.warn(TAG, `initializeViewModels list init failed: ${initResult.code}`)
      }
      this.viewModel.activate()
      await this.viewModel.refreshAll()
      this.listReady = true
    } catch (err) {
      this.listReady = true
      LogUtils.error(TAG, `initializeViewModels failed: ${JSON.stringify(err)}`)
    }
  }

  private async openStorageSettings(): Promise<void> {
    try {
      this.dismissLogDetailDialog()
      await this.viewModel.setMode('settings')
    } catch (err) {
      LogUtils.error(TAG, `openStorageSettings failed: ${JSON.stringify(err)}`)
    }
  }

  private async backToLogList(): Promise<void> {
    await this.viewModel.setMode('list')
  }

  private dismissLogDetailDialog(): void {
    this.viewModel.closeDetail()
  }

  private openLogDetailDialog(entry: LogEntry): void {
    this.viewModel.openDetail(entry.id)
  }

  private getCurrentDetailEntry(): LogEntry | null {
    return this.viewModel.getCurrentDetailEntry()
  }

  private hasCurrentDetailEntry(): boolean {
    return this.getCurrentDetailEntry() !== null
  }

  private async handleExportLogs(): Promise<void> {
    let context = this.getUIContext().getHostContext() as common.UIAbilityContext
    let result: ExportActionResult = await this.viewModel.exportLogs(context)
    if (result.success) {
      DialogService.openSuccess(this.getUIContext(), ExportMessageUtils.buildExportSuccessText(result.fileName ?? 'security_log.csv'))
      return
    }
    DialogService.openFailure(this.getUIContext(), result.reason ?? CommonStrings.messageRetryLater)
  }

  private handleClearLogs(): void {
    DialogService.openConfirm(this.getUIContext(), {
      title: LogManageStrings.clearConfirmTitle,
      message: LogManageStrings.buildClearConfirmMessage(this.state.summary.totalCount),
      confirmText: CommonStrings.actionClear,
      cancelText: CommonStrings.actionCancel,
      onConfirm: async () => {
        let result = await this.viewModel.clearLogs()
        this.dismissLogDetailDialog()
        if (result.success) {
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
      DialogService.openFailure(this.getUIContext(), result.code === 'no_changes' ? CommonStrings.messageNoChanges : LogManageStrings.saveSettingsFailed)
      return
    }
    DialogService.openSuccess(this.getUIContext(), LogManageStrings.saveSettingsSuccess)
  }

  private getSelectedEventTypeLabel(): string {
    let index = this.state.filter.eventTypeIndex
    return index <= 0 ? LogManageStrings.allEventTypes : this.eventTypeFilterOptions[index].value as string
  }

  private getSelectedResultLabel(): string {
    let index = this.state.filter.resultIndex
    return index <= 0 ? LogManageStrings.allResults : this.resultFilterOptions[index].value as string
  }

  @Builder
  private headerRightActions() {
    Row({ space: 8 }) {
      if (this.state.mode === 'list') {
        IconTextActionButton({
          label: LogManageStrings.exportLogsButton,
          icon: $r('app.media.save'),
          currentTheme: this.currentTheme,
          onTap: () => {
            void this.handleExportLogs()
          }
        })
        IconTextActionButton({
          label: LogManageStrings.clearLogsButton,
          icon: $r('app.media.trash'),
          kind: 'danger',
          currentTheme: this.currentTheme,
          onTap: () => this.handleClearLogs()
        })
        IconTextActionButton({
          label: LogManageStrings.openStorageSettingsButton,
          icon: $r('app.media.settings'),
          currentTheme: this.currentTheme,
          onTap: () => {
            void this.openStorageSettings()
          }
        })
      } else {
        IconTextActionButton({
          label: CommonStrings.actionSaveSettings,
          icon: $r('app.media.save'),
          currentTheme: this.currentTheme,
          isEnabled: this.settingsState.dirty && !this.settingsState.saving,
          onTap: () => {
            void this.handleSaveStorageSettings()
          }
        })
        IconTextActionButton({
          label: LogManageStrings.backToLogListButton,
          icon: $r('app.media.log'),
          currentTheme: this.currentTheme,
          onTap: () => {
            void this.backToLogList()
          }
        })
      }
    }
  }

  @Builder
  private settingsPanel() {
    LogStorageSettingsPanel({
      maxLocalEntries: this.settingsState.maxLocalEntries,
      retentionDays: this.settingsState.retentionDays,
      currentTheme: this.currentTheme,
      onSelectMaxEntries: (index: number) => {
        this.viewModel.settingsViewModel.setMaxLocalEntries(LOG_MAX_ENTRIES_OPTIONS[index] ?? LOG_MAX_ENTRIES_OPTIONS[0])
      },
      onSelectRetentionDays: (index: number) => {
        this.viewModel.settingsViewModel.setRetentionDays(LOG_RETENTION_OPTIONS[index] ?? LOG_RETENTION_OPTIONS[0])
      }
    })
  }

  @Builder
  private detailOverlay() {
    if (this.state.detail.visible && this.hasCurrentDetailEntry()) {
      DetailDialogOverlay({
        onDismiss: () => this.dismissLogDetailDialog(),
        content: () => {
          if (this.getCurrentDetailEntry()) {
            LogDetailDialog({
              title: LogManageStrings.detailDialogTitle,
              entry: this.getCurrentDetailEntry() as LogEntry,
              currentTheme: this.currentTheme,
              onClose: () => this.dismissLogDetailDialog()
            })
          }
        }
      })
    }
  }

  @Builder
  private filterToolbar() {
    Row({ space: 8 }) {
      Select(this.eventTypeFilterOptions)
        .selected(this.state.filter.eventTypeIndex)
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
        .onSelect((index: number) => { void this.viewModel.setEventTypeIndex(index) })

      Select(this.resultFilterOptions)
        .selected(this.state.filter.resultIndex)
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
        .onSelect((index: number) => { void this.viewModel.setResultIndex(index) })

      TextInput({ placeholder: LogManageStrings.searchPlaceholder, text: this.state.filter.keyword })
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(FormControlUtils.text(this.currentTheme))
        .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .layoutWeight(1)
        .onChange((value: string) => { void this.viewModel.setKeyword(value) })
    }
    .width('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_SM })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        SubPageHeader({
          title: this.state.mode === 'settings' ? LogManageStrings.settingsTitle : LogManageStrings.pageTitle,
          subtitle: this.state.mode === 'settings' ? LogManageStrings.settingsSubtitle : LogManageStrings.pageSubtitle,
          currentTheme: this.currentTheme,
          onBack: this.onBack,
          actions: () => {
            this.headerRightActions()
          }
        })

        if (this.state.mode === 'settings') {
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
          .align(Alignment.Top)
        } else {
          if (this.listReady) {
            LogSummaryCards({
              summary: this.state.summary,
              currentTheme: this.currentTheme
            })
            this.filterToolbar()
            LogEntriesPanel({
              loading: this.state.loading,
              listState: this.state.list,
              filterState: this.state.filter,
              currentTheme: this.currentTheme,
              onEntryClick: (entry: LogEntry) => {
                this.openLogDetailDialog(entry)
              }
            })
            LogPaginationBar({
              loading: this.state.loading,
              listState: this.state.list,
              paginationState: this.state.pagination,
              currentTheme: this.currentTheme,
              pageSizeOptions: this.viewModel.getPageSizeOptions(),
              currentPageSize: this.viewModel.getCurrentPageSize(),
              onSelectPageSize: (index: number) => this.viewModel.setPageSizeIndex(index),
              onChangePageInput: (value: string) => this.viewModel.setPageInputText(value),
              onJumpPage: () => this.viewModel.jumpToInputPage(),
              onPrevPage: () => this.viewModel.goToPreviousPage(),
              onNextPage: () => this.viewModel.goToNextPage()
            })
          } else {
            Column({ space: 12 }) {
              LoadingProgress()
                .width(42)
                .height(42)
              Text(LoadingStrings.LOADING)
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            }
            .layoutWeight(1)
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)

      this.detailOverlay()
    }
    .width('100%')
    .height('100%')
  }
}
