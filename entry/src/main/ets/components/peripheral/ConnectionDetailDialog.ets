import { AppColors, AppStyles } from '../../constants/AppConstants'
import {
  getLogEventResultLabel,
  getPeripheralRecordActionLabel,
  getPeripheralRecordPolicyHitLabel,
  getPeripheralRecordSourceLabel,
  PeripheralConnectionRecord
} from '../../models/DataModels'
import { ThemeMode } from '../../theme/ThemeColors'
import { ConnectionDetailMetricField } from './ConnectionDetailMetricField'

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
        .backgroundColor('#66000000')
        .onClick(() => this.onClose && this.onClose())

      Column({ space: 12 }) {
        Row() {
          Text('设备详情')
            .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          Blank()
          Button('关闭')
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
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
          Text('当前没有可展示的连接记录。')
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
        ConnectionDetailMetricField({ label: '设备标识', value: record.deviceId, currentTheme: this.currentTheme })
        ConnectionDetailMetricField({ label: '最近时间', value: this.formatConnectionTime(record), currentTheme: this.currentTheme })
      }
      .width('100%')

      Row({ space: 10 }) {
        ConnectionDetailMetricField({ label: '连接事件', value: getPeripheralRecordActionLabel(record.action), currentTheme: this.currentTheme })
        ConnectionDetailMetricField({ label: '事件来源', value: getPeripheralRecordSourceLabel(record.source), currentTheme: this.currentTheme })
      }
      .width('100%')

      Row({ space: 10 }) {
        ConnectionDetailMetricField({ label: '策略结论', value: getPeripheralRecordPolicyHitLabel(record.policyHit), currentTheme: this.currentTheme })
        ConnectionDetailMetricField({ label: '执行策略', value: record.effectivePolicyLabel ?? '--', currentTheme: this.currentTheme })
      }
      .width('100%')

      Row({ space: 10 }) {
        ConnectionDetailMetricField({ label: '命中类型', value: record.matchedPolicyKind ?? 'unknown', currentTheme: this.currentTheme })
        ConnectionDetailMetricField({ label: '结果状态', value: getLogEventResultLabel(record.result), currentTheme: this.currentTheme })
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
    .borderRadius(AppStyles.RADIUS_LG)
  }

  @Builder
  private historyCard() {
    Column({ space: 8 }) {
      Row() {
        Text('历史连接记录')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(`${this.historyItems.length} 条`)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .width('100%')

      if (this.historyItems.length === 0) {
        Text('暂无历史连接记录')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      } else {
        Column({ space: 8 }) {
          ForEach(this.historyItems, (item: ConnectionHistoryItem, index: number) => {
            Row({ space: 10 }) {
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
                Text(`${item.policy} · ${item.result}`)
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
