import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { LogEntry, LogEventType } from '../../../models/LogModels'
import { buildLogDetailViewData } from '../../../presentation/log-manage/LogEntryPresentationMapper'
import { LogDetailViewData } from '../../../presentation/log-manage/LogEntryPresentationModels'
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
    eventKey: 'file.unknown',
    detail: ''
  }
  onClose: () => void = () => {}

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
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private dialogContent(viewData: LogDetailViewData) {
    Column({ space: 14 }) {
      Column({ space: 10 }) {
        Text(viewData.title)
          .fontSize(AppStyles.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        Row({ space: 12 }) {
          this.summaryMetric('发生时间', viewData.timestamp)
          this.summaryMetric('日志类型', viewData.typeLabel)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(AppStyles.PADDING_12)
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
      .borderRadius(AppStyles.RADIUS_MD)

      LogDetailTable({ sections: viewData.sections, currentTheme: this.currentTheme })
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
        this.dialogContent(buildLogDetailViewData(this.entry))
      }
    })
  }
}
