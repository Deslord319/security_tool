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
import { PresentationStrings } from '../constants/modules/PresentationStrings'
import { ThemeMode } from '../theme/ThemeColors'
import { ExportMessageUtils } from '../utils/ExportMessageUtils'
import { FormControlUtils } from '../utils/FormControlUtils'
import { DialogService } from '../utils/DialogService'
import { LogManageViewModel } from '../viewmodels/log-manage/LogManageViewModel'
import { LogUtils } from '../utils/LogUtils'
import { LogEntriesPanel } from '../components/LogEntriesPanel'
import { LogPaginationBar } from '../components/LogPaginationBar'
import { SubPageHeader } from '../components/SubPageHeader'
import { IconTextActionButton } from '../components/IconTextActionButton'
import { LogStorageSettingsPanel } from '../components/LogStorageSettingsPanel'
import { LogDetailDialog } from '../components/LogDetailDialog'

const TAG = 'LogManagePage'
const PAGE_SIZE_OPTIONS: number[] = [20, 50, 100]

@ComponentV2
export struct LogManagePage {
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param onBack: () => void = () => {}
  @Local viewModel: LogManageViewModel = new LogManageViewModel()
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
          title: LogManageStrings.detailDialogTitle,
          entry: entry,
          currentTheme: this.currentTheme,
          onClose: () => this.closeDetailDialog()
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
        this.closeDetailDialog()
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

  @Builder
  private summaryCards() {
    GridRow({ columns: 4, gutter: 12 }) {
      GridCol() {
        Row({ space: 16 }) {
          Column() {
            Image($r('app.media.folder'))
              .width(36)
              .height(36)
              .fillColor(Color.White)
              .draggable(false)
          }
          .width(62)
          .height(62)
          .borderRadius(20)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .linearGradient({
            angle: 135,
            colors: [
              [AppColors.BRAND_PRIMARY, 0],
              [AppColors.GRADIENT_FIREWALL_END, 1]
            ]
          })

          Column({ space: 6 }) {
            Text(LogManageStrings.statTotal)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

            Text(`${this.viewModel.state.summary.totalCount}`)
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .maxLines(1)

            Text(LogManageStrings.statTotalDescription)
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height(116)
        .padding({ left: 18, right: 18, top: 18, bottom: 18 })
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_LG)
        .border({
          width: 1,
          color: AppColors.getColors(this.currentTheme).BORDER,
          style: BorderStyle.Solid
        })
      }
      GridCol() {
        Row({ space: 16 }) {
          Column() {
            Image($r('app.media.log'))
              .width(36)
              .height(36)
              .fillColor(Color.White)
              .draggable(false)
          }
          .width(62)
          .height(62)
          .borderRadius(20)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .linearGradient({
            angle: 135,
            colors: [
              [AppColors.SUCCESS, 0],
              [AppColors.GRADIENT_LOG_END, 1]
            ]
          })

          Column({ space: 6 }) {
            Text(LogManageStrings.statToday)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

            Text(`${this.viewModel.state.summary.todayCount}`)
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .maxLines(1)

            Text(LogManageStrings.statTodayDescription)
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height(116)
        .padding({ left: 18, right: 18, top: 18, bottom: 18 })
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_LG)
        .border({
          width: 1,
          color: AppColors.getColors(this.currentTheme).BORDER,
          style: BorderStyle.Solid
        })
      }
      GridCol() {
        Row({ space: 16 }) {
          Column() {
            Image($r('app.media.alert'))
              .width(36)
              .height(36)
              .fillColor(Color.White)
              .draggable(false)
          }
          .width(62)
          .height(62)
          .borderRadius(20)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .linearGradient({
            angle: 135,
            colors: [
              [AppColors.WARNING, 0],
              [AppColors.GRADIENT_IDENTITY_END, 1]
            ]
          })

          Column({ space: 6 }) {
            Text(PresentationStrings.logResultBlocked)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

            Text(`${this.viewModel.state.summary.blockedCount}`)
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .maxLines(1)

            Text(LogManageStrings.statBlockedDescription)
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height(116)
        .padding({ left: 18, right: 18, top: 18, bottom: 18 })
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_LG)
        .border({
          width: 1,
          color: AppColors.getColors(this.currentTheme).BORDER,
          style: BorderStyle.Solid
        })
      }
      GridCol() {
        Row({ space: 16 }) {
          Column() {
            Image($r('app.media.dashboard'))
              .width(36)
              .height(36)
              .fillColor(Color.White)
              .draggable(false)
          }
          .width(62)
          .height(62)
          .borderRadius(20)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .linearGradient({
            angle: 135,
            colors: [
              [AppColors.TEXT_MUTED, 0],
              [AppColors.GRADIENT_TOOL_END, 1]
            ]
          })

          Column({ space: 6 }) {
            Text(LogManageStrings.statCurrentShown)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

            Text(`${this.viewModel.state.summary.currentShownCount}`)
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .maxLines(1)

            Text(LogManageStrings.statCurrentShownDescription)
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height(116)
        .padding({ left: 18, right: 18, top: 18, bottom: 18 })
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_LG)
        .border({
          width: 1,
          color: AppColors.getColors(this.currentTheme).BORDER,
          style: BorderStyle.Solid
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
          isEnabled: this.viewModel.settingsViewModel.state.dirty && !this.viewModel.settingsViewModel.state.saving,
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
        .value((this.eventTypeFilterOptions[this.viewModel.state.filter.eventTypeIndex]?.value as string) ?? LogManageStrings.allEventTypes)
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
        .value((this.resultFilterOptions[this.viewModel.state.filter.resultIndex]?.value as string) ?? LogManageStrings.allResults)
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
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        SubPageHeader({
          title: this.viewModel.state.mode === 'settings' ? LogManageStrings.settingsTitle : LogManageStrings.pageTitle,
          subtitle: this.viewModel.state.mode === 'settings' ? LogManageStrings.settingsSubtitle : LogManageStrings.pageSubtitle,
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
