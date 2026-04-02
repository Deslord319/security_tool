import { ActionButtonStyles, AppColors, AppStyles } from '../constants/AppConstants'
import { EmptyStateStrings, LoadingStrings } from '../constants/modules/DialogStrings'
import { LogManageStrings } from '../constants/modules/LogManageStrings'
import {
  formatLogTimestamp,
  getLogEventResultColor,
  getLogEventResultLabel,
  getLogEventTypeLabel,
  LogEntry
} from '../models/DataModels'
import { EmptyStatePanel } from './EmptyStatePanel'
import { LogListViewModel } from '../viewmodels/log-manage/LogListViewModel'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { ThemeMode } from '../theme/ThemeColors'

@Component
export struct LogEntriesPanel {
  @ObjectLink viewModel: LogListViewModel
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onEntryClick: (entry: LogEntry) => void = () => {}

  private getEmptyStateTitle(): string {
    return this.viewModel.hasActiveFilters() ? EmptyStateStrings.NO_RESULTS : LogManageStrings.emptyTitle
  }

  private getEmptyStateDescription(): string {
    if (this.viewModel.state.hintMessage.length > 0) {
      return this.viewModel.state.hintMessage
    }
    return this.viewModel.hasActiveFilters() ? LogManageStrings.emptyDescription : EmptyStateStrings.CHECK_PERMISSIONS
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
      this.onEntryClick(entry)
    })
  }

  build() {
    if (this.viewModel.state.loading) {
      Column() {
        LoadingProgress().width(48).height(48)
        Text(LoadingStrings.LOADING).fontSize(AppStyles.FONT_SIZE_BODY).margin({ top: 8 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.viewModel.state.entries.length === 0) {
      Scroll() {
        Column() {
          EmptyStatePanel({
            title: this.getEmptyStateTitle(),
            description: this.getEmptyStateDescription(),
            radius: AppStyles.RADIUS_LG,
            verticalPadding: 36
          })
        }
        .width('100%')
        .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_MD })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
    } else {
      Scroll() {
        Column({ space: 0 }) {
          List({ space: 1 }) {
            ForEach(this.viewModel.state.pagedEntries, (entry: LogEntry) => {
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
}
