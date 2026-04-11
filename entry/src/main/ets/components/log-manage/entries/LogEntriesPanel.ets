import { ActionButtonStyles, AppColors, AppStyles } from '../../../constants/AppConstants'
import { EmptyStateStrings, LoadingStrings } from '../../../constants/modules/DialogStrings'
import { LogManageDetailStrings, LogManageEmptyStateStrings } from '../../../constants/modules/LogManageStrings'
import {
  formatLogTimestamp,
  getLogEventResultColor,
  getLogEventResultLabel,
  getLogEventTypeLabel,
  LogEntry
} from '../../../models/DataModels'
import { LogFilterState, LogListState } from '../../../models/LogManageModels'
import { ThemeMode } from '../../../theme/ThemeColors'
import { getScrollBarColor, SCROLL_BAR_WIDTH_DEFAULT, SCROLL_BAR_WIDTH_HOVER } from '../../../utils/ScrollBarStyleUtils'
import { EmptyStatePanel } from '../../EmptyStatePanel'

@ComponentV2
export struct LogEntriesPanel {
  @Param loading: boolean = false
  @Param listState: LogListState = new LogListState()
  @Param filterState: LogFilterState = new LogFilterState()
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onEntryClick: (entry: LogEntry) => void = () => {}
  @Local private scrollBarWidth: number = SCROLL_BAR_WIDTH_DEFAULT

  private getEmptyStateTitle(): string {
    return (this.filterState.eventTypeIndex > 0 ||
      this.filterState.resultIndex > 0 ||
      this.filterState.keyword.trim().length > 0) ?
      EmptyStateStrings.NO_RESULTS :
      LogManageEmptyStateStrings.TITLE
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
          Text(`${LogManageDetailStrings.PROCESS_LABEL}: ${entry.processName}${entry.pid !== undefined ? ` (PID: ${entry.pid})` : ''}`)
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

  @Builder
  private emptyState() {
    EmptyStatePanel({
      title: this.getEmptyStateTitle(),
      currentTheme: this.currentTheme
    })
  }

  build() {
    if (this.loading) {
      Column() {
        LoadingProgress().width(48).height(48)
        Text(LoadingStrings.LOADING).fontSize(AppStyles.FONT_SIZE_BODY).margin({ top: 8 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.listState.pagedEntries.length === 0) {
      Scroll() {
        Column() {
          this.emptyState()
        }
        .width('100%')
        .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_MD })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .scrollBarColor(getScrollBarColor(this.currentTheme))
      .scrollBarWidth(this.scrollBarWidth)
      .onHover((isHover: boolean) => {
        this.scrollBarWidth = isHover ? SCROLL_BAR_WIDTH_HOVER : SCROLL_BAR_WIDTH_DEFAULT
      })
      .align(Alignment.Top)
    } else {
      Scroll() {
        Column({ space: 0 }) {
          List({ space: 1 }) {
            ForEach(this.listState.pagedEntries, (entry: LogEntry) => {
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
      .scrollBarColor(getScrollBarColor(this.currentTheme))
      .scrollBarWidth(this.scrollBarWidth)
      .onHover((isHover: boolean) => {
        this.scrollBarWidth = isHover ? SCROLL_BAR_WIDTH_HOVER : SCROLL_BAR_WIDTH_DEFAULT
      })
      .align(Alignment.Top)
    }
  }
}
