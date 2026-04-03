import { DetailDialogShell } from '../DetailDialogShell'
import { AppColors, AppStyles } from '../../constants/AppConstants'
import {
  PeripheralConnectionRecord,
  getPeripheralRecordActionLabel,
  getPeripheralRecordSourceLabel
} from '../../models/DataModels'
import { ThemeMode } from '../../theme/ThemeColors'
import {
  getPeripheralConnectionPolicyLabel,
  getPeripheralConnectionResultLabel,
  getPeripheralMatchedPolicyKindLabel
} from '../../viewmodels/PeripheralRecordPresentationMapper'
import { DeviceDetailStrings } from '../../constants/modules/DialogStrings'

export interface ConnectionHistoryItem {
  time: string
  policy: string
  result: string
}

@CustomDialog
export struct ConnectionDetailDialog {
  controller: CustomDialogController
  selectedRecord: PeripheralConnectionRecord | null = null
  historyItems: ConnectionHistoryItem[] = []
  currentTheme: ThemeMode = ThemeMode.LIGHT
  onClose: () => void = () => {}

  @Builder
  private shellContent() {
    if (this.selectedRecord) {
      Column({ space: 12 }) {
        this.metricCard(this.selectedRecord)
        this.historyCard()
      }
      .width('100%')
    } else {
      Text(DeviceDetailStrings.NO_RECORDS)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
    }
  }

  @Builder
  private metricCard(record: PeripheralConnectionRecord) {
    Column({ space: 10 }) {
      Text(DeviceDetailStrings.KEY_INFO)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)

      Row({ space: 10 }) {
        this.metricField(DeviceDetailStrings.DEVICE_ID, record.deviceId)
        this.metricField(DeviceDetailStrings.RECENT_TIME, this.formatConnectionTime(record))
      }
      .width('100%')

      Row({ space: 10 }) {
        this.metricField(DeviceDetailStrings.CONNECTION_EVENT, getPeripheralRecordActionLabel(record.action))
        this.metricField(DeviceDetailStrings.EVENT_SOURCE, getPeripheralRecordSourceLabel(record.source))
      }
      .width('100%')

      Row({ space: 10 }) {
        this.metricField(DeviceDetailStrings.POLICY_RESULT, getPeripheralConnectionPolicyLabel(record))
        this.metricField(DeviceDetailStrings.EFFECTIVE_POLICY, record.effectivePolicyLabel ?? '--')
      }
      .width('100%')

      Row({ space: 10 }) {
        this.metricField(DeviceDetailStrings.MATCH_TYPE, getPeripheralMatchedPolicyKindLabel(record.matchedPolicyKind))
        this.metricField(DeviceDetailStrings.RESULT_STATUS, getPeripheralConnectionResultLabel(record))
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
    .borderRadius(AppStyles.RADIUS_LG)
  }

  @Builder
  private metricField(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      Text(value)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private historyCard() {
    Column({ space: AppStyles.PADDING_SM }) {
      Row() {
        Text(DeviceDetailStrings.HISTORY_TITLE)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(`${this.historyItems.length} ${DeviceDetailStrings.HISTORY_COUNT_SUFFIX}`)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .width('100%')

      if (this.historyItems.length === 0) {
        Text(DeviceDetailStrings.NO_HISTORY)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      } else {
        Column({ space: AppStyles.PADDING_SM }) {
          ForEach(this.historyItems, (item: ConnectionHistoryItem, index: number) => {
            Row({ space: AppStyles.PADDING_SM }) {
              Text(`${index + 1}`)
                .fontSize(AppStyles.FONT_SIZE_CAPTION)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.BRAND_PRIMARY)
                .width(24)
                .textAlign(TextAlign.Center)
              Column({ space: 4 }) {
                Text(item.time)
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontWeight(FontWeight.Medium)
                Text(`${item.policy} / ${item.result}`)
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(10)
            .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
            .borderRadius(AppStyles.RADIUS_MD)
          })
        }
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
    .borderRadius(AppStyles.RADIUS_LG)
  }

  private formatConnectionTime(record: PeripheralConnectionRecord): string {
    const date = new Date(record.timestamp)
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
  }

  build() {
    DetailDialogShell({
      title: DeviceDetailStrings.TITLE,
      dialogWidth: 760,
      maxBodyHeight: 460,
      currentTheme: this.currentTheme,
      showHeader: false,
      showCloseAction: false,
      onClose: this.onClose,
      content: () => {
        this.shellContent()
      }
    })
  }
}
