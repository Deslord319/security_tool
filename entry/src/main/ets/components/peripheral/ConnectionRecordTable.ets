/**
 * 连接记录表格组件
 */
import { AppColors, AppStyles } from '../../constants/AppConstants'
import { PeripheralConnectionRecord, PeripheralRecordAction, PeripheralType, getPeripheralTypeLabel } from '../../models/DataModels'
import { ThemeMode } from '../../theme/ThemeColors'
import { EmptyStatePanel } from '../EmptyStatePanel'

interface ConnectionRecordTableProps {
  deviceRecords: PeripheralConnectionRecord[]
  currentTheme: ThemeMode
  onRecordClick: (record: PeripheralConnectionRecord) => void
  getEventLabel: (record: PeripheralConnectionRecord) => string
  getEventTextColor: (action: PeripheralRecordAction) => Color
  getEventBgColor: (action: PeripheralRecordAction) => Color
  getPolicyDisplay: (record: PeripheralConnectionRecord) => string
  formatTime: (record: PeripheralConnectionRecord) => string
}

@Component
export struct ConnectionRecordTable {
  @Prop deviceRecords: PeripheralConnectionRecord[] = []
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT
  onRecordClick?: (record: PeripheralConnectionRecord) => void
  getEventLabel?: (record: PeripheralConnectionRecord) => string
  getEventTextColor?: (action: PeripheralRecordAction) => Color
  getEventBgColor?: (action: PeripheralRecordAction) => Color
  getPolicyDisplay?: (record: PeripheralConnectionRecord) => string
  formatTime?: (record: PeripheralConnectionRecord) => string

  build() {
    Scroll() {
      Column({ space: 0 }) {
        if (this.deviceRecords.length === 0) {
          EmptyStatePanel({
            title: '暂无设备连接记录',
            description: '暂无实时记录，请重新插拔设备后刷新。',
            radius: AppStyles.RADIUS_LG,
            verticalPadding: 24
          })
        } else {
          Column({ space: 0 }) {
            this.tableHeader()
            Column({ space: 0 }) {
              ForEach(this.deviceRecords, (record: PeripheralConnectionRecord, index: number) => {
                Column({ space: 0 }) {
                  this.tableRow(record, index)
                  if (index < this.deviceRecords.length - 1) {
                    Divider()
                      .color(AppColors.getColors(this.currentTheme).BORDER)
                      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
                      .margin({ left: 20, right: 20 })
                  }
                }
              })
            }
            .width('100%')
          }
          .width('100%')
          .borderRadius(AppStyles.RADIUS_LG)
          .clip(true)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
          .border({
            width: 1,
            color: AppColors.getColors(this.currentTheme).BORDER
          })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_MD })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
  }

  @Builder
  private tableHeader() {
    Row({ space: 12 }) {
      Text('设备名称')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(2.1)
      Text('设备类型')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(1.2)
      Text('连接事件')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(1.1)
      Text('策略')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(1.8)
      Text('连接时间')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(1.6)
      Text('操作')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(0.9)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  private tableRow(record: PeripheralConnectionRecord, index: number) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(record.deviceName)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(record.deviceId)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(2.1)
      .alignItems(HorizontalAlign.Start)

      Row() {
        Text(getPeripheralTypeLabel(record.deviceType))
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
          .borderRadius(AppStyles.RADIUS_SM)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      }
      .layoutWeight(1.2)

      Row() {
        Text(this.getEventLabel ? this.getEventLabel(record) : record.action)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(this.getEventTextColor ? this.getEventTextColor(record.action) : AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .backgroundColor(this.getEventBgColor ? this.getEventBgColor(record.action) : AppColors.getColors(this.currentTheme).BG_PAGE)
          .borderRadius(AppStyles.RADIUS_SM)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      }
      .layoutWeight(1.1)

      Row() {
        Text(this.getPolicyDisplay ? this.getPolicyDisplay(record) : '')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1.8)

      Text(this.formatTime ? this.formatTime(record) : '')
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .layoutWeight(1.6)

      Button('详情')
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(Color.White)
        .backgroundColor(AppColors.BRAND_PRIMARY)
        .borderRadius(AppStyles.RADIUS_MD)
        .height(32)
        .layoutWeight(0.9)
        .onClick(() => {
          if (this.onRecordClick) {
            this.onRecordClick(record)
          }
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
  }
}
