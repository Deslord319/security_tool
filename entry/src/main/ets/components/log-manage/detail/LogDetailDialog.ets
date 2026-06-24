import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { LogManageDetailStrings } from '../../../constants/modules/LogManageStrings'
import {
  LogDetailTableRow,
  LogEntry,
  LogEventType
} from '../../../models/LogModels'
import {
  formatLogTimestamp,
  getLogEventTypeLabel
} from '../../../viewmodels/log-manage/presentation/LogPresentationMapper'
import { ThemeMode } from '../../../theme/ThemeColors'
import { DetailDialogShell } from '../../DetailDialogShell'
import { LogDetailTable } from './LogDetailTable'

@CustomDialog
export struct LogDetailDialog {
  controller: CustomDialogController
  title: string = ''
  currentTheme: ThemeMode = ThemeMode.LIGHT
  entry: LogEntry = {
    id: '',
    timestamp: 0,
    eventType: LogEventType.FILE,
    detail: ''
  } as LogEntry
  onClose: () => void = () => {}

  private getDetailRows(): LogDetailTableRow[] {
    return this.entry.detailRows ?? []
  }

  @Builder
  private summaryMetric(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)

      Text(value)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private dialogContent() {
    Column({ space: 12 }) {
      Column({ space: 8 }) {
        Text(LogManageDetailStrings.SUMMARY)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

        Row({ space: 10 }) {
          this.summaryMetric(
            LogManageDetailStrings.TIME_LABEL,
            formatLogTimestamp(this.entry.timestamp)
          )
          this.summaryMetric(
            LogManageDetailStrings.EVENT_TYPE_LABEL,
            getLogEventTypeLabel(this.entry.eventType)
          )
        }
        .width('100%')
      }
      .width('100%')
      .padding(AppStyles.PADDING_12)
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
      .borderRadius(AppStyles.RADIUS_MD)

      Column({ space: 8 }) {
        Text(LogManageDetailStrings.STRUCTURED_DETAILS)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

        LogDetailTable({
          rows: this.getDetailRows(),
          currentTheme: this.currentTheme
        })
      }
      .width('100%')
      .padding(AppStyles.PADDING_12)
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
      .borderRadius(AppStyles.RADIUS_MD)
    }
    .width('100%')
  }

  build() {
    DetailDialogShell({
      title: this.title,
      dialogWidth: AppStyles.DIALOG_WIDTH_DEFAULT,
      maxBodyHeight: AppStyles.DIALOG_BODY_MAX_HEIGHT_DEFAULT,
      currentTheme: this.currentTheme,
      showHeader: true,
      showCloseAction: true,
      onClose: this.onClose,
      content: () => {
        this.dialogContent()
      }
    })
  }
}
