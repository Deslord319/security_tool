import { common } from '@kit.AbilityKit'
import { AppColors, AppStyles } from '../constants/AppConstants'
import { CommonStrings } from '../constants/CommonStrings'
import { ResultStrings } from '../constants/modules/DialogStrings'
import { LogManageStrings } from '../constants/modules/LogManageStrings'
import {
  ExportActionResult,
  LogEntry,
  LOG_EVENT_TYPE_OPTIONS,
} from '../models/DataModels'
import { PresentationStrings } from '../constants/modules/PresentationStrings'
import { IconTextActionButton } from '../components/IconTextActionButton'
import { SubPageHeader } from '../components/SubPageHeader'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { ExportMessageUtils } from '../utils/ExportMessageUtils'
import { FormControlUtils } from '../utils/FormControlUtils'
import { DialogService } from '../utils/DialogService'
import { LogManageViewModel } from '../viewmodels/log-manage/LogManageViewModel'
import { LogStorageSettingsPanel } from '../components/LogStorageSettingsPanel'
import { LogDetailDialog } from '../components/LogDetailDialog'
import { LogUtils } from '../utils/LogUtils'
import { LogSummaryCards } from '../components/LogSummaryCards'
import { LogEntriesPanel } from '../components/LogEntriesPanel'
import { LogPaginationBar } from '../components/LogPaginationBar'

const TAG = 'LogManagePage'

@Component
export struct LogManagePage {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onBack: () => void = () => {}
  @State viewModel: LogManageViewModel = new LogManageViewModel()
  private detailDialogController?: CustomDialogController

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
    } catch (err) {
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
    this.closeLogDetailDialogController()
    this.viewModel.closeDetail()
  }

  private closeLogDetailDialogController(): void {
    try {
      this.detailDialogController?.close()
    } catch (_err) {
    } finally {
      this.detailDialogController = undefined
    }
  }

  private openLogDetailDialog(entry: LogEntry): void {
    this.closeLogDetailDialogController()
    this.viewModel.openDetail(entry.id)
    let selectedEntry = this.viewModel.getCurrentDetailEntry()
    if (!selectedEntry) {
      return
    }
    try {
      this.detailDialogController = new CustomDialogController({
        builder: LogDetailDialog({
          controller: this.detailDialogController,
          title: LogManageStrings.detailDialogTitle,
          entry: selectedEntry,
          onClose: () => {
            this.dismissLogDetailDialog()
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
    } catch (err) {
      LogUtils.warn(TAG, `openLogDetailDialog failed: ${JSON.stringify(err)}`)
      this.dismissLogDetailDialog()
    }
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
      message: LogManageStrings.buildClearConfirmMessage(this.viewModel.state.summary.totalCount),
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
    let index = this.viewModel.state.filter.eventTypeIndex
    return index <= 0 ? LogManageStrings.allEventTypes : this.eventTypeFilterOptions[index].value as string
  }

  private getSelectedResultLabel(): string {
    let index = this.viewModel.state.filter.resultIndex
    return index <= 0 ? LogManageStrings.allResults : this.resultFilterOptions[index].value as string
  }

  @Builder
  private headerRightActions() {
    Row({ space: 8 }) {
      if (this.viewModel.state.mode === 'list') {
        IconTextActionButton({
          label: LogManageStrings.exportLogsButton,
          icon: $r('app.media.save'),
          kind: 'primary',
          onTap: () => { void this.handleExportLogs() }
        })
        IconTextActionButton({
          label: LogManageStrings.clearLogsButton,
          icon: $r('app.media.trash'),
          kind: 'danger',
          onTap: () => this.handleClearLogs()
        })
        IconTextActionButton({
          label: LogManageStrings.openStorageSettingsButton,
          icon: $r('app.media.settings'),
          kind: 'primary',
          onTap: () => { void this.openStorageSettings() }
        })
      } else {
        IconTextActionButton({
          label: CommonStrings.actionSaveSettings,
          icon: $r('app.media.save'),
          kind: 'primary',
          onTap: () => { void this.handleSaveStorageSettings() }
        })
        IconTextActionButton({
          label: LogManageStrings.backToLogListButton,
          icon: $r('app.media.log'),
          kind: 'primary',
          onTap: () => { void this.backToLogList() }
        })
      }
    }
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
        .onSelect((index: number) => { void this.viewModel.setEventTypeIndex(index) })

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
        .onSelect((index: number) => { void this.viewModel.setResultIndex(index) })

      TextInput({ placeholder: LogManageStrings.searchPlaceholder, text: this.viewModel.state.filter.keyword })
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
    Column() {
      SubPageHeader({
        title: this.viewModel.state.mode === 'settings' ? LogManageStrings.settingsTitle : LogManageStrings.pageTitle,
        subtitle: this.viewModel.state.mode === 'settings' ? LogManageStrings.settingsSubtitle : LogManageStrings.pageSubtitle,
        currentTheme: this.currentTheme,
        onBack: () => this.onBack(),
        actions: () => {
          this.headerRightActions()
        }
      })

      if (this.viewModel.state.mode === 'settings') {
        Scroll() {
          Column({ space: 24 }) {
            LogStorageSettingsPanel({
              viewModel: this.viewModel.settingsViewModel
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
        LogSummaryCards({
          viewModel: this.viewModel
        })
        this.filterToolbar()
        LogEntriesPanel({
          viewModel: this.viewModel,
          onEntryClick: (entry: LogEntry) => {
            this.openLogDetailDialog(entry)
          }
        })
        LogPaginationBar({
          viewModel: this.viewModel
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }
}
