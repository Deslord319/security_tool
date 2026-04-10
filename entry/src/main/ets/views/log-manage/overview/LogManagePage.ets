import { SymbolGlyphModifier, TextModifier } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { ActionText, ModuleText, ResultText, MessageText } from '../../../constants/StringCatalog'
import { LoadingStrings } from '../../../constants/modules/DialogStrings'
import {
  LogManageActionStrings,
  LogManageClearingStrings,
  LogManageDetailStrings,
  LogManageEmptyStateStrings,
  LogManageFilterStrings,
  LogManagePageStrings,
  LogManageSettingStrings,
  LogManageStatStrings
} from '../../../constants/modules/LogManageStrings'
import {
  ExportActionResult,
  LogEntry,
  LOG_EVENT_TYPE_OPTIONS,
  LOG_MAX_ENTRIES_OPTIONS,
  LOG_RETENTION_OPTIONS
} from '../../../models/DataModels'
import { LogResultPresentationStrings } from '../../../constants/modules/PresentationStrings'
import { ThemeMode } from '../../../theme/ThemeColors'
import { getScrollBarColor, SCROLL_BAR_WIDTH_DEFAULT, SCROLL_BAR_WIDTH_HOVER } from '../../../utils/ScrollBarStyleUtils'
import { ExportMessageUtils } from '../../../utils/ExportMessageUtils'
import { FormControlUtils } from '../../../utils/FormControlUtils'
import { DialogService } from '../../../utils/DialogService'
import { LogManageViewModel } from '../../../viewmodels/log-manage/overview/LogManageViewModel'
import { LogUtils } from '../../../utils/LogUtils'
import { LogEntriesPanel } from '../../../components/log-manage/entries/LogEntriesPanel'
import { LogPaginationBar } from '../../../components/log-manage/entries/LogPaginationBar'
import { SubPageHeader } from '../../../components/SubPageHeader'
import { IconTextActionButton } from '../../../components/IconTextActionButton'
import { LogStorageSettingsPanel } from '../../../components/log-manage/storage-settings/LogStorageSettingsPanel'
import { LogDetailDialog } from '../../../components/log-manage/detail/LogDetailDialog'
import { CompactSummaryCard } from '../../../components/CompactSummaryCard'

const TAG = 'LogManagePage'
const PAGE_SIZE_OPTIONS: number[] = [20, 50, 100]

@ComponentV2
export struct LogManagePage {
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param onBack: () => void = () => {}
  @Local viewModel: LogManageViewModel = new LogManageViewModel()
  @Local private settingsScrollBarWidth: number = SCROLL_BAR_WIDTH_DEFAULT
  private detailDialogController?: CustomDialogController

  private eventTypeFilterOptions: SelectOption[] = [
    { value: LogManageFilterStrings.ALL_EVENT_TYPES } as SelectOption,
    ...LOG_EVENT_TYPE_OPTIONS.map((option) => ({ value: option.label } as SelectOption))
  ]
  private resultFilterOptions: SelectOption[] = [
    { value: LogManageFilterStrings.ALL_RESULTS } as SelectOption,
    { value: ResultText.SUCCESS } as SelectOption,
    { value: LogResultPresentationStrings.BLOCKED } as SelectOption,
    { value: ResultText.FAILED } as SelectOption
  ]

  aboutToAppear() {
    void this.initializeViewModels()
  }

  aboutToDisappear() {
    this.viewModel.deactivate()
    this.viewModel.destroy()
    this.closeDetailDialog()
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
    } catch (err) {
      LogUtils.error(TAG, `initializeViewModels failed: ${JSON.stringify(err)}`)
    }
  }

  private async openStorageSettings(): Promise<void> {
    try {
      this.closeDetailDialog()
      await this.viewModel.setMode('settings')
    } catch (err) {
      LogUtils.error(TAG, `openStorageSettings failed: ${JSON.stringify(err)}`)
    }
  }

  private async backToLogList(): Promise<void> {
    await this.viewModel.setMode('list')
  }

  private openLogDetailDialog(entry: LogEntry): void {
    this.closeDetailDialogController()
    this.viewModel.openDetail(entry.id)
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
          this.viewModel.closeDetail()
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
    let result: ExportActionResult = await this.viewModel.exportLogs(context)
    if (result.success) {
      DialogService.openSuccess(this.getUIContext(), ExportMessageUtils.buildExportSuccessText(result.fileName ?? 'security_log.csv'))
      return
    }
    DialogService.openFailure(this.getUIContext(), result.reason ?? MessageText.RETRY_LATER)
  }

  private handleClearLogs(): void {
    DialogService.openConfirm(this.getUIContext(), {
      title: LogManageClearingStrings.CONFIRM_TITLE,
      message: LogManageClearingStrings.buildConfirmMessage(this.viewModel.state.summary.totalCount),
      confirmText: ActionText.CLEAR,
      cancelText: ActionText.CANCEL,
      onConfirm: async () => {
        let result = await this.viewModel.clearLogs()
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
    let result = await this.viewModel.saveStorageSettings()
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
          valueText: `${this.viewModel.state.summary.totalCount}`,
          description: LogManageStatStrings.TOTAL_DESCRIPTION,
          icon: $r('app.media.folder'),
          accentStart: AppColors.BRAND_PRIMARY,
          accentEnd: AppColors.GRADIENT_FIREWALL_END,
          preset: 'log',
          currentTheme: this.currentTheme
        })
      }
      GridCol() {
        CompactSummaryCard({
          title: LogManageStatStrings.TODAY,
          valueText: `${this.viewModel.state.summary.todayCount}`,
          description: LogManageStatStrings.TODAY_DESCRIPTION,
          icon: $r('app.media.log'),
          accentStart: AppColors.SUCCESS,
          accentEnd: AppColors.GRADIENT_LOG_END,
          preset: 'log',
          currentTheme: this.currentTheme
        })
      }
      GridCol() {
        CompactSummaryCard({
          title: LogResultPresentationStrings.BLOCKED,
          valueText: `${this.viewModel.state.summary.blockedCount}`,
          description: LogManageStatStrings.BLOCKED_DESCRIPTION,
          icon: $r('app.media.alert'),
          accentStart: AppColors.WARNING,
          accentEnd: AppColors.GRADIENT_IDENTITY_END,
          preset: 'log',
          currentTheme: this.currentTheme
        })
      }
      GridCol() {
        CompactSummaryCard({
          title: LogManageStatStrings.CURRENT_SHOWN,
          valueText: `${this.viewModel.state.summary.currentShownCount}`,
          description: LogManageStatStrings.CURRENT_SHOWN_DESCRIPTION,
          icon: $r('app.media.dashboard'),
          accentStart: AppColors.TEXT_MUTED,
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
      if (this.viewModel.state.mode === 'list') {
        IconTextActionButton({
          label: LogManageActionStrings.EXPORT_LOGS,
          icon: $r('app.media.save'),
          currentTheme: this.currentTheme,
          onTap: () => {
            void this.handleExportLogs()
          }
        })
        IconTextActionButton({
          label: LogManageActionStrings.CLEAR_LOGS,
          icon: $r('app.media.trash'),
          kind: 'danger',
          currentTheme: this.currentTheme,
          onTap: () => this.handleClearLogs()
        })
        IconTextActionButton({
          label: LogManageActionStrings.OPEN_STORAGE_SETTINGS,
          icon: $r('app.media.settings'),
          currentTheme: this.currentTheme,
          onTap: () => {
            void this.openStorageSettings()
          }
        })
      } else {
        IconTextActionButton({
          label: ActionText.SAVE_SETTINGS,
          icon: $r('app.media.save'),
          currentTheme: this.currentTheme,
          isEnabled: this.viewModel.settingsViewModel.state.dirty && !this.viewModel.settingsViewModel.state.saving,
          onTap: () => {
            void this.handleSaveStorageSettings()
          }
        })
        IconTextActionButton({
          label: LogManageActionStrings.BACK_TO_LOG_LIST,
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
      maxLocalEntries: this.viewModel.settingsViewModel.state.maxLocalEntries,
      retentionDays: this.viewModel.settingsViewModel.state.retentionDays,
      currentTheme: this.currentTheme,
      onSelectMaxEntries: (index: number) => {
        this.viewModel.settingsViewModel.setMaxLocalEntries(LOG_MAX_ENTRIES_OPTIONS[index] ?? LOG_MAX_ENTRIES_OPTIONS[0])
      },
      onSelectRetentionDays: (index: number) => {
        this.viewModel.settingsViewModel.setRetentionDays(LOG_RETENTION_OPTIONS[index] ?? LOG_RETENTION_OPTIONS[0])
      }
    })
  }

  private closeDetailDialogController(): void {
    try {
      this.detailDialogController?.close()
    } catch (_err) {
    } finally {
      this.detailDialogController = undefined
    }
  }

  private closeDetailDialog(): void {
    this.closeDetailDialogController()
    this.viewModel.closeDetail()
  }

  @Builder
  private filterToolbar() {
    Row({ space: 8 }) {
      Select(this.eventTypeFilterOptions)
        .selected(this.viewModel.state.filter.eventTypeIndex)
        .value((this.eventTypeFilterOptions[this.viewModel.state.filter.eventTypeIndex]?.value as string) ?? LogManageFilterStrings.ALL_EVENT_TYPES)
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
        .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
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
        .value((this.resultFilterOptions[this.viewModel.state.filter.resultIndex]?.value as string) ?? LogManageFilterStrings.ALL_RESULTS)
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
        .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
        .optionFont({ size: AppStyles.FONT_SIZE_BODY })
        .width(110)
        .height(36)
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .borderRadius(AppStyles.RADIUS_SM)
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .onSelect((index: number) => { void this.viewModel.setResultIndex(index) })

      TextInput({ placeholder: LogManageFilterStrings.SEARCH_PLACEHOLDER, text: this.viewModel.state.filter.keyword })
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
          title: this.viewModel.state.mode === 'settings' ? LogManagePageStrings.SETTINGS_TITLE : ModuleText.LOG_MANAGE,
          subtitle: this.viewModel.state.mode === 'settings' ? LogManagePageStrings.SETTINGS_SUBTITLE : LogManagePageStrings.SUBTITLE,
          currentTheme: this.currentTheme,
          onBack: this.onBack,
          actions: () => {
            this.headerRightActions()
          }
        })

        if (this.viewModel.state.mode === 'settings') {
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
          if (this.viewModel.state.initialized) {
            this.summaryCards()
            this.filterToolbar()
            LogEntriesPanel({
              loading: this.viewModel.state.loading,
              listState: this.viewModel.state.list,
              filterState: this.viewModel.state.filter,
              currentTheme: this.currentTheme,
              onEntryClick: (entry: LogEntry) => {
                this.openLogDetailDialog(entry)
              }
            })
            LogPaginationBar({
              loading: this.viewModel.state.loading,
              listState: this.viewModel.state.list,
              paginationState: this.viewModel.state.pagination,
              currentTheme: this.currentTheme,
              pageSizeOptions: PAGE_SIZE_OPTIONS,
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
    }
    .width('100%')
    .height('100%')
  }
}
