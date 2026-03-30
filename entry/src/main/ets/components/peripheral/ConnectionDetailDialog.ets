import { AppColors, AppStyles } from '../../constants/AppConstants'
import {
  getPeripheralRecordActionLabel,
  getPeripheralRecordSourceLabel,
  PeripheralConnectionRecord
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

@Component
export struct ConnectionDetailDialog {
  @Prop selectedRecord: PeripheralConnectionRecord | null = null
  @Prop historyItems: ConnectionHistoryItem[] = []
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT
  onClose?: () => void

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(AppColors.OVERLAY_BACKGROUND)
        .onClick(() => this.onClose && this.onClose())

      Column({ space: 12 }) {
        Row() {
          Text(DeviceDetailStrings.TITLE)
            .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          Blank()
          Button(DeviceDetailStrings.CLOSE_BUTTON)
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(this.currentTheme === ThemeMode.DARK ? Color.White : Color.Black)
            .height(32)
            .borderRadius(AppStyles.RADIUS_MD)
            .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
            .onClick(() => this.onClose && this.onClose())
        }
        .width('100%')

        if (this.selectedRecord) {
          Scroll() {
            Column({ space: 12 }) {
              this.metricCard(this.selectedRecord)
              this.historyCard()
            }
            .width('100%')
          }
          .width('100%')
          .constraintSize({ maxHeight: 460 })
          .scrollBar(BarState.Auto)
        } else {
          Text(DeviceDetailStrings.NO_RECORDS)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: 760, maxHeight: 580 })
      .padding(18)
      .margin(16)
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
      .borderRadius(AppStyles.RADIUS_XL)
      .onClick(() => {})
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private metricCard(record: PeripheralConnectionRecord) {
    Column({ space: 10 }) {
      Text('关键信息')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)

      Row({ space: 10 }) {
        this.metricField('设备标识', record.deviceId)
        this.metricField('最近时间', this.formatConnectionTime(record))
      }
      .width('100%')

      Row({ space: 10 }) {
        this.metricField('连接事件', getPeripheralRecordActionLabel(record.action))
        this.metricField('事件来源', getPeripheralRecordSourceLabel(record.source))
      }
      .width('100%')

      Row({ space: 10 }) {
        this.metricField('策略结论', getPeripheralConnectionPolicyLabel(record))
        this.metricField('执行策略', record.effectivePolicyLabel ?? '--')
      }
      .width('100%')

      Row({ space: 10 }) {
        this.metricField('命中类型', getPeripheralMatchedPolicyKindLabel(record.matchedPolicyKind))
        this.metricField('结果状态', getPeripheralConnectionResultLabel(record))
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
}
