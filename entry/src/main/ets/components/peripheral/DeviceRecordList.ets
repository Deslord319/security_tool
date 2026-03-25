import { AppColors, AppStyles } from '../../constants/AppConstants'
import {
  getLogEventResultLabel,
  getPeripheralRecordActionLabel,
  getPeripheralTypeLabel,
  LogEventResult,
  PeripheralConnectionRecord
} from '../../models/DataModels'
import { ThemeMode } from '../../theme/ThemeColors'
import { HoverUtils } from '../../utils/HoverUtils'
import { EmptyStatePanel } from '../EmptyStatePanel'

@Component
export struct DeviceRecordList {
  @Prop deviceRecords: PeripheralConnectionRecord[] = []
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT
  @Prop hoveredPanelIndex: number = -1
  onRecordClick?: (record: PeripheralConnectionRecord) => void
  onPanelHover?: (isHover: boolean) => void

  build() {
    Scroll() {
      Column({ space: 0 }) {
        if (this.deviceRecords.length === 0) {
          EmptyStatePanel({
            title: '暂无设备连接记录',
            description: '重新插拔设备后，可在这里查看最新连接历史。',
            radius: AppStyles.RADIUS_LG,
            verticalPadding: 24
          })
        } else {
          Column({ space: 0 }) {
            this.header()
            ForEach(this.deviceRecords, (record: PeripheralConnectionRecord, index: number) => {
              Column({ space: 0 }) {
                this.row(record, index)
                if (index < this.deviceRecords.length - 1) {
                  Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY).margin({ left: 20, right: 20 })
                }
              }
            })
          }
          .width('100%')
          .borderRadius(AppStyles.RADIUS_LG)
          .clip(true)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
          .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER })
          .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 1, true))
          .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 1, 4) })
          .onHover((isHover: boolean) => this.onPanelHover && this.onPanelHover(isHover))
        }
      }
      .width('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_MD })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
  }

  @Builder
  private header() {
    Row() {
      Text('时间').fontSize(AppStyles.FONT_SIZE_SMALL).layoutWeight(2)
      Text('设备类型').fontSize(AppStyles.FONT_SIZE_SMALL).layoutWeight(1.5)
      Text('设备标识').fontSize(AppStyles.FONT_SIZE_SMALL).layoutWeight(2)
      Text('事件').fontSize(AppStyles.FONT_SIZE_SMALL).layoutWeight(1.5)
      Text('结果').fontSize(AppStyles.FONT_SIZE_SMALL).layoutWeight(1.5)
      Text('操作').fontSize(AppStyles.FONT_SIZE_SMALL).layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  private row(record: PeripheralConnectionRecord, index: number) {
    Row() {
      Text(this.formatConnectionTime(record)).fontSize(AppStyles.FONT_SIZE_SMALL).layoutWeight(2)
      Text(getPeripheralTypeLabel(record.deviceType)).fontSize(AppStyles.FONT_SIZE_CAPTION).layoutWeight(1.5)
      Text(record.deviceId).fontSize(AppStyles.FONT_SIZE_SMALL).layoutWeight(2).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(getPeripheralRecordActionLabel(record.action)).fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(this.eventColor(record)).layoutWeight(1.5)
      Text(getLogEventResultLabel(record.result)).fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(this.resultColor(record.result)).layoutWeight(1.5)
      Text('详情').fontSize(AppStyles.FONT_SIZE_CAPTION).fontColor(AppColors.BRAND_PRIMARY).layoutWeight(1).textAlign(TextAlign.Center).onClick(() => this.onRecordClick && this.onRecordClick(record))
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 10, bottom: 10 })
    .backgroundColor(index % 2 === 0 ? AppColors.getColors(this.currentTheme).BG_CARD : AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  private formatConnectionTime(record: PeripheralConnectionRecord): string {
    const date = new Date(record.timestamp)
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
  }

  private eventColor(record: PeripheralConnectionRecord): ResourceColor {
    if (record.result === LogEventResult.BLOCKED || record.action === 'intercept') {
      return AppColors.DANGER
    }
    if (record.action === 'disconnect') {
      return AppColors.WARNING
    }
    return AppColors.SUCCESS
  }

  private resultColor(result: LogEventResult): ResourceColor {
    if (result === LogEventResult.SUCCESS) {
      return AppColors.SUCCESS
    }
    if (result === LogEventResult.BLOCKED) {
      return AppColors.WARNING
    }
    if (result === LogEventResult.FAILED) {
      return AppColors.DANGER
    }
    return AppColors.getColors(this.currentTheme).TEXT_PRIMARY
  }
}
