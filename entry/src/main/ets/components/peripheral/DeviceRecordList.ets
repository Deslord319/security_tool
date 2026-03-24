/**
 * 设备记录列表组件
 */
import { AppColors, AppStyles } from '../../constants/AppConstants'
import { PeripheralConnectionRecord, PeripheralRecordAction, PeripheralType } from '../../models/DataModels'
import { ThemeMode } from '../../theme/ThemeColors'
import { HoverUtils } from '../../utils/HoverUtils'
import { EmptyStatePanel } from '../EmptyStatePanel'

interface DeviceRecordListProps {
  deviceRecords: PeripheralConnectionRecord[]
  currentTheme: ThemeMode
  hoveredPanelIndex: number
  onRecordClick: (record: PeripheralConnectionRecord) => void
  onPanelHover: (isHover: boolean) => void
}

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
            description: '暂无实时记录，请重新插拔设备后刷新。',
            radius: AppStyles.RADIUS_LG,
            verticalPadding: 24
          })
        } else {
          Column({ space: 0 }) {
            this.connectionTableHeader()
            Column({ space: 0 }) {
              ForEach(this.deviceRecords, (record: PeripheralConnectionRecord, index: number) => {
                Column({ space: 0 }) {
                  this.connectionRecordTableRow(record, index)
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
          .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 0, true))
          .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 0, 4) })
          .onHover((isHover: boolean) => {
            if (this.onPanelHover) {
              this.onPanelHover(isHover)
            }
          })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({
        left: AppStyles.PADDING_LG,
        right: AppStyles.PADDING_LG,
        top: AppStyles.PADDING_MD,
        bottom: AppStyles.PADDING_MD
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
  }

  @Builder
  private connectionTableHeader() {
    Row() {
      Text('时间').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY).opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(2)
      Text('设备类型').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY).opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1.5)
      Text('设备标识').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY).opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(2)
      Text('事件').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY).opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1.5)
      Text('结果').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY).opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1.5)
      Text('操作').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY).opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
    .borderRadius({ topLeft: AppStyles.RADIUS_LG, topRight: AppStyles.RADIUS_LG })
  }

  @Builder
  private connectionRecordTableRow(record: PeripheralConnectionRecord, index: number) {
    Row() {
      Text(this.formatConnectionTime(record)).fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY).opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY).layoutWeight(2)
      Text(this.getDeviceTypeLabel(record.deviceType)).fontSize(AppStyles.FONT_SIZE_CAPTION).fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT).backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG).borderRadius(4).padding({ left: 6, right: 6, top: 2, bottom: 2 }).layoutWeight(1.5)
      Text(record.deviceId).fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY).opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(2).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.getConnectionEventLabel(record.action)).fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(this.getConnectionEventColor(record.action)).backgroundColor(this.getConnectionEventBgColor(record.action)).borderRadius(4).padding({ left: 6, right: 6, top: 2, bottom: 2 }).layoutWeight(1.5)
      Text(record.result === 'success' ? '成功' : '失败').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(record.result === 'success' ? AppColors.SUCCESS : AppColors.ERROR).layoutWeight(1.5)
      Text('详情').fontSize(AppStyles.FONT_SIZE_CAPTION).fontColor(AppColors.BRAND_PRIMARY).layoutWeight(1).textAlign(TextAlign.Center).onClick(() => {
        if (this.onRecordClick) {
          this.onRecordClick(record)
        }
      })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 10, bottom: 10 })
    .backgroundColor(index % 2 === 0 ? AppColors.getColors(this.currentTheme).BG_CARD : AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  private formatConnectionTime(record: PeripheralConnectionRecord): string {
    const date = new Date(record.timestamp)
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
  }

  private getDeviceTypeLabel(type: PeripheralType): string {
    const typeMap: Record<number, string> = {
      [PeripheralType.USB_STORAGE]: 'USB 存储',
      [PeripheralType.USB_HID]: 'USB 输入',
      [PeripheralType.USB_AUDIO]: 'USB 音频',
      [PeripheralType.USB_VIDEO]: 'USB 视频',
      [PeripheralType.USB_PRINTER]: 'USB 打印机',
      [PeripheralType.USB_NETWORK]: 'USB 网卡',
      [PeripheralType.USB_OTHER]: '其他 USB',
      [PeripheralType.BLUETOOTH]: '蓝牙'
    }
    return typeMap[type] || '未知设备'
  }

  private getConnectionEventLabel(action: PeripheralRecordAction): string {
    const actionMap: Record<string, string> = {
      'connect': '连接',
      'disconnect': '断开',
      'blocked': '拦截'
    }
    return actionMap[action] || action
  }

  private getConnectionEventColor(action: PeripheralRecordAction): Color {
    switch (action) {
      case 'connect': return AppColors.SUCCESS
      case 'disconnect': return AppColors.WARNING
      case 'blocked': return AppColors.ERROR
      default: return AppColors.getColors(this.currentTheme).TEXT_PRIMARY
    }
  }

  private getConnectionEventBgColor(action: PeripheralRecordAction): Color {
    switch (action) {
      case 'connect': return AppColors.getColors(this.currentTheme).TAG_GREEN_BG
      case 'disconnect': return AppColors.getColors(this.currentTheme).TAG_ORANGE_BG
      case 'blocked': return AppColors.getColors(this.currentTheme).TAG_RED_BG
      default: return AppColors.getColors(this.currentTheme).BG_PAGE
    }
  }
}
