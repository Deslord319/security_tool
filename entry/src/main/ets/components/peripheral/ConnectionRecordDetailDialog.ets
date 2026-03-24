/**
 * 连接记录详情对话框组件
 */
import { AppColors, AppStyles } from '../../constants/AppConstants'
import { PeripheralConnectionRecord, PeripheralRecordAction, getPeripheralRecordSourceLabel } from '../../models/DataModels'
import { ThemeMode } from '../../theme/ThemeColors'
import { HoverUtils } from '../../utils/HoverUtils'
import { ConnectionDetailMetricField } from './ConnectionDetailMetricField'

interface ConnectionRecordDetailDialogProps {
  selectedRecord: PeripheralConnectionRecord | null
  currentTheme: ThemeMode
  connectionDetailHostWidth: number
  onClose: () => void
  getConnectionEventLabel: (record: PeripheralConnectionRecord) => string
  getConnectionPolicyDisplay: (record: PeripheralConnectionRecord) => string
  getExecutedUsbPolicyDisplay: (record: PeripheralConnectionRecord) => string
  getConnectionPolicyHitLabel: (record: PeripheralConnectionRecord) => string
  getConnectionResultLabel: (record: PeripheralConnectionRecord) => string
  formatConnectionTime: (record: PeripheralConnectionRecord) => string
  normalizeConnectionDetailValue: (value?: string) => string
  getConnectionHistoryItems: (record: PeripheralConnectionRecord | null) => Array<{ time: string; policy: string; result: string }>
}

@Component
export struct ConnectionRecordDetailDialog {
  @Prop selectedRecord: PeripheralConnectionRecord | null = null
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT
  @Prop connectionDetailHostWidth: number = 0
  onClose?: () => void
  getConnectionEventLabel?: (record: PeripheralConnectionRecord) => string
  getConnectionPolicyDisplay?: (record: PeripheralConnectionRecord) => string
  getExecutedUsbPolicyDisplay?: (record: PeripheralConnectionRecord) => string
  getConnectionPolicyHitLabel?: (record: PeripheralConnectionRecord) => string
  getConnectionResultLabel?: (record: PeripheralConnectionRecord) => string
  formatConnectionTime?: (record: PeripheralConnectionRecord) => string
  normalizeConnectionDetailValue?: (value?: string) => string
  getConnectionHistoryItems?: (record: PeripheralConnectionRecord | null) => Array<{ time: string; policy: string; result: string }>

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#66000000')
      .onClick(() => {
        if (this.onClose) {
          this.onClose()
        }
      })

      Column({ space: 8 }) {
        Row() {
          Text('设备详情')
            .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          Blank()
          Button('关闭')
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
            .borderRadius(AppStyles.RADIUS_MD)
            .height(32)
            .onClick(() => {
              if (this.onClose) {
                this.onClose()
              }
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (!this.selectedRecord) {
          Column({ space: 8 }) {
            Text('当前没有可展示的连接记录。')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          }
          .width('100%')
        } else {
          this.detailContent(this.selectedRecord)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: this.getConnectionDetailDialogMaxWidth(), maxHeight: this.getConnectionDetailDialogMaxHeight() })
      .padding(16)
      .margin({ left: 16, right: 16, top: 16, bottom: 16 })
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
      .borderRadius(AppStyles.RADIUS_XL)
      .shadow(HoverUtils.getShadow(this.currentTheme, true, true))
      .onClick(() => {
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private detailContent(record: PeripheralConnectionRecord) {
    Scroll() {
      Column({ space: 8 }) {
        this.keyInfoSection(record)
        this.historySection(record)
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ maxHeight: this.getConnectionDetailDialogContentMaxHeight() })
    .scrollBar(BarState.Auto)
  }

  @Builder
  private keyInfoSection(record: PeripheralConnectionRecord) {
    Column({ space: 8 }) {
      Text('关键信息')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

      Column({ space: 8 }) {
        Row({ space: 12 }) {
          ConnectionDetailMetricField({
            label: '设备标识',
            value: this.normalizeConnectionDetailValue ? this.normalizeConnectionDetailValue(record.deviceId) : record.deviceId,
            currentTheme: this.currentTheme
          })
          ConnectionDetailMetricField({
            label: '最近时间',
            value: this.formatConnectionTime ? this.formatConnectionTime(record) : '',
            currentTheme: this.currentTheme
          })
        }
        .width('100%')

        Row({ space: 12 }) {
          ConnectionDetailMetricField({
            label: '连接事件',
            value: this.getConnectionEventLabel ? this.getConnectionEventLabel(record) : '',
            currentTheme: this.currentTheme
          })
          ConnectionDetailMetricField({
            label: '事件来源',
            value: getPeripheralRecordSourceLabel(record.source),
            currentTheme: this.currentTheme
          })
        }
        .width('100%')

        Row({ space: 12 }) {
          ConnectionDetailMetricField({
            label: '策略结论',
            value: this.getConnectionPolicyDisplay ? this.getConnectionPolicyDisplay(record) : '',
            currentTheme: this.currentTheme
          })
          ConnectionDetailMetricField({
            label: '实际执行策略',
            value: this.getExecutedUsbPolicyDisplay ? this.getExecutedUsbPolicyDisplay(record) : '',
            currentTheme: this.currentTheme
          })
        }
        .width('100%')

        Row({ space: 12 }) {
          ConnectionDetailMetricField({
            label: '命中类型',
            value: this.getConnectionPolicyHitLabel ? this.getConnectionPolicyHitLabel(record) : '',
            currentTheme: this.currentTheme
          })
          ConnectionDetailMetricField({
            label: '结果状态',
            value: this.getConnectionResultLabel ? this.getConnectionResultLabel(record) : '',
            currentTheme: this.currentTheme
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding(12)
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
      .borderRadius(AppStyles.RADIUS_LG)
    }
    .width('100%')
  }

  @Builder
  private historySection(record: PeripheralConnectionRecord) {
    Column({ space: 8 }) {
      Row() {
        Text('历史连接记录')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        Blank()
        Text(`${this.getConnectionHistoryItems ? this.getConnectionHistoryItems(record).length : 0} 条`)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .width('100%')

      if (!(this.getConnectionHistoryItems ? this.getConnectionHistoryItems(record).length : 0)) {
        Text('暂无历史连接记录')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      } else {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.getConnectionHistoryItems ? this.getConnectionHistoryItems(record) : [], (item: { time: string; policy: string; result: string }, index: number) => {
              Row({ space: 12 }) {
                Stack({ alignContent: Alignment.Center }) {
                  Text(`${index + 1}`)
                    .fontSize(AppStyles.FONT_SIZE_CAPTION)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.BRAND_PRIMARY)
                }
                .width(28)
                .height(28)
                .borderRadius(14)
                .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)

                Column({ space: 4 }) {
                  Text(item.time)
                    .fontSize(AppStyles.FONT_SIZE_SMALL)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  Text(`${item.policy} · ${item.result}`)
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
              .padding(10)
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              .borderRadius(AppStyles.RADIUS_MD)
            })
          }
          .width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: this.getConnectionDetailHistoryMaxHeight() })
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
    .borderRadius(AppStyles.RADIUS_LG)
  }

  private getConnectionDetailDialogMaxWidth(): number {
    const nextWidth = this.connectionDetailHostWidth
    if (nextWidth > 800) {
      return 800
    }
    if (nextWidth > 600) {
      return 600
    }
    return Math.max(400, nextWidth - 32)
  }

  private getConnectionDetailDialogMaxHeight(): number {
    return 600
  }

  private getConnectionDetailDialogContentMaxHeight(): number {
    return this.getConnectionDetailDialogMaxHeight() - 150
  }

  private getConnectionDetailHistoryMaxHeight(): number {
    return 300
  }
}
