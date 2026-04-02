import { ActionButtonStyles, AppColors, AppStyles } from '../constants/AppConstants'
import { FirewallDialogStrings } from '../constants/modules/DialogStrings'
import { LogManageStrings } from '../constants/modules/LogManageStrings'
import {
  LogEntry,
  LogEventResult,
  LogEventType,
  formatLogTimestamp,
  getLogEventResultColor,
  getLogEventResultLabel,
  getLogEventTypeLabel
} from '../models/DataModels'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { DetailDialogShell } from './DetailDialogShell'

interface LogDetailField {
  key: string
  label: string
  value: string
}

@CustomDialog
@Component
export struct LogDetailDialog {
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
    this.pushNumberField(fields, 'sourceEventId', 'Event ID', this.entry.sourceEventId)
    this.pushTextField(fields, 'rawEventName', 'Raw Event', this.entry.rawEventName)
    this.pushTextField(fields, 'rawOutcome', 'Raw Outcome', this.entry.rawOutcome)
    this.pushTextField(fields, 'rawAction', 'Raw Action', this.entry.rawAction)
    this.pushTextField(fields, 'process', LogManageStrings.processLabel, this.entry.processName)
    this.pushNumberField(fields, 'pid', 'PID', this.entry.pid)
    this.pushNumberField(fields, 'uid', 'UID', this.entry.uid)
    this.pushTextField(fields, 'filePath', LogManageStrings.filePathLabel, this.entry.filePath)
    this.pushTextField(fields, 'remoteAddr', FirewallDialogStrings.REMOTE_ADDRESS, this.entry.remoteAddr)
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
