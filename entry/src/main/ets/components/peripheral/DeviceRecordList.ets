import { AppColors, AppStyles } from '../../constants/AppConstants'
import {
  getPeripheralRecordActionLabel,
  getPeripheralRecordPolicyHitLabel,
  getPeripheralTypeLabel,
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
            description: '重新连接设备后，可在这里查看最新的接入历史。',
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
                  Divider()
                    .color(AppColors.getColors(this.currentTheme).BORDER)
                    .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
                    .margin({ left: 20, right: 20 })
                }
              }
            }, (record: PeripheralConnectionRecord) => record.id)
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
    .align(Alignment.Top)
  }

  @Builder
  private header() {
    Row() {
      this.headerText('设备名称', 2.6, TextAlign.Center)
      this.headerText('设备类型', 1.5, TextAlign.Center)
      this.headerText('连接事件', 1.3, TextAlign.Center)
      this.headerText('策略', 1.2, TextAlign.Center)
      this.headerText('连接时间', 1.9, TextAlign.Center)
      this.headerText('操作', 1.1, TextAlign.End)
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 14, bottom: 14 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  private row(record: PeripheralConnectionRecord, index: number) {
    Row() {
      Column({ space: 6 }) {
        Text(record.deviceName)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(record.deviceId)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(2.6)

      this.tagCell(getPeripheralTypeLabel(record.deviceType), AppColors.TAG_PURPLE_BG, AppColors.TAG_PURPLE_TEXT, 1.5)

      Text(getPeripheralRecordActionLabel(record.action))
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.eventTagText(record))
        .layoutWeight(1.3)

      Text(this.getPolicyText(record))
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .layoutWeight(1.2)
        .textAlign(TextAlign.Center)

      Text(this.formatConnectionTime(record))
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .layoutWeight(1.9)
        .textAlign(TextAlign.Center)

      Row() {
        Text('详情')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
      }
      .height(36)
      .padding({ left: 26, right: 26 })
      .justifyContent(FlexAlign.Center)
      .borderRadius(10)
      .backgroundColor(AppColors.BRAND_PRIMARY)
      .layoutWeight(1.1)
      .onClick(() => this.onRecordClick && this.onRecordClick(record))
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 18, bottom: 18 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private headerText(label: string, weight: number, align: TextAlign = TextAlign.Start) {
    Text(label)
      .fontSize(AppStyles.FONT_SIZE_SMALL)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .layoutWeight(weight)
      .textAlign(align)
  }

  @Builder
  private tagCell(label: string, backgroundColor: ResourceColor, textColor: ResourceColor, weight: number) {
    Row() {
      Row() {
        Text(label)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(textColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .borderRadius(6)
      .backgroundColor(backgroundColor)
    }
    .layoutWeight(weight)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  private formatConnectionTime(record: PeripheralConnectionRecord): string {
    const date = new Date(record.timestamp)
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}:${String(date.getSeconds()).padStart(2, '0')}`
  }

  private getPolicyText(record: PeripheralConnectionRecord): string {
    if (record.effectivePolicyLabel && record.effectivePolicyLabel.trim().length > 0) {
      return record.effectivePolicyLabel
    }
    return getPeripheralRecordPolicyHitLabel(record.policyHit)
  }

  private eventTagText(record: PeripheralConnectionRecord): ResourceColor {
    if (record.action === 'connect') {
      return AppColors.TAG_GREEN_TEXT
    }
    if (record.action === 'disconnect') {
      return AppColors.TAG_ORANGE_TEXT
    }
    return AppColors.TAG_RED_TEXT
  }
}
