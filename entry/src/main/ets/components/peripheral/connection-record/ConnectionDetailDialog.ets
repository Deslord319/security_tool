import { DetailDialogShell } from '../../DetailDialogShell'
import { AppColors, AppStyles } from '../../../constants/AppConstants'
import {
  PeripheralConnectionRecord,
  getPeripheralRecordActionLabel,
  getPeripheralRecordSourceLabel,
  isUsbPeripheralType
} from '../../../models/DataModels'
import { ThemeMode } from '../../../theme/ThemeColors'
import {
  formatPeripheralTimestamp,
  getPeripheralConnectionPolicyLabel,
  getPeripheralConnectionResultLabel,
  getPeripheralMatchedPolicyKindLabel,
  PeripheralConnectionHistoryItem
} from '../../../viewmodels/peripheral/connection-record/PeripheralRecordPresentationMapper'
import { DeviceDetailStrings } from '../../../constants/modules/PeripheralStrings'
import { PLACEHOLDER_TEXT } from '../../../constants/StringCatalog'

@CustomDialog
export struct ConnectionDetailDialog {
  controller: CustomDialogController
  selectedRecord: PeripheralConnectionRecord | null = null
  historyItems: PeripheralConnectionHistoryItem[] = []
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
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

      Row({ space: 10 }) {
        this.metricField(DeviceDetailStrings.DEVICE_ID, this.getDetailDeviceId(record))
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
        this.metricField(DeviceDetailStrings.EFFECTIVE_POLICY, record.effectivePolicyLabel ?? PLACEHOLDER_TEXT)
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
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        Blank()
        Text(`${this.historyItems.length} ${DeviceDetailStrings.HISTORY_COUNT_SUFFIX}`)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .width('100%')

      if (this.historyItems.length === 0) {
        Text(DeviceDetailStrings.NO_HISTORY)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      } else {
        Column({ space: AppStyles.PADDING_SM }) {
          ForEach(this.historyItems, (item: PeripheralConnectionHistoryItem, index: number) => {
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
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                Text(`${item.policy} / ${item.result}`)
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
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
    return formatPeripheralTimestamp(record.timestamp)
  }

  private getDetailDeviceId(record: PeripheralConnectionRecord): string {
    return isUsbPeripheralType(record.deviceType) ? PLACEHOLDER_TEXT : record.deviceId
  }

  build() {
    DetailDialogShell({
      title: DeviceDetailStrings.TITLE,
      dialogWidth: 760,
      maxBodyHeight: 460,
      currentTheme: this.currentTheme,
      showHeader: true,
      showCloseAction: true,
      onClose: this.onClose,
      content: () => {
        this.shellContent()
      }
    })
  }
}
