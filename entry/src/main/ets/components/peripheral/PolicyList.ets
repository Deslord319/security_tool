import { AppColors, AppStyles } from '../../constants/AppConstants'
import { getPeripheralTypeLabel, PeripheralPolicyRecord } from '../../models/DataModels'
import { ThemeMode } from '../../theme/ThemeColors'
import { HoverUtils } from '../../utils/HoverUtils'
import { FormControlUtils } from '../../utils/FormControlUtils'

export interface PolicyOption {
  value: string
}

@Component
export struct PolicyList {
  @Prop policyRecords: PeripheralPolicyRecord[] = []
  @Prop policyListOptions: PolicyOption[] = []
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT
  @Prop hoveredPanelIndex: number = -1
  onPolicyChange?: (index: number, policyIndex: number) => void
  getPolicyLabel?: (index: number) => string
  isUpdating?: (deviceId: string) => boolean
  onPanelHover?: (isHover: boolean) => void

  build() {
    Column({ space: 0 }) {
      if (this.policyRecords.length === 0) {
        Column({ space: 10 }) {
          Text('暂无可管理的 USB 设备记录')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          Text('设备接入后会显示在这里，可直接设置允许接入或禁止访问。')
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 22, right: 22, top: 24, bottom: 24 })
        .borderRadius(AppStyles.RADIUS_LG)
        .clip(true)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 2, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 2, 4) })
        .onHover((isHover: boolean) => this.onPanelHover && this.onPanelHover(isHover))
      } else {
        Column({ space: 0 }) {
          this.tableHeader()
          ForEach(this.policyRecords, (record: PeripheralPolicyRecord, index: number) => {
            Column({ space: 0 }) {
              this.tableRow(record, index)
              if (index < this.policyRecords.length - 1) {
                Divider()
                  .color(AppColors.getColors(this.currentTheme).BORDER)
                  .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
                  .margin({ left: 20, right: 20 })
              }
            }
          }, (record: PeripheralPolicyRecord) => `${record.deviceId}-${record.policyIndex}`)
        }
        .width('100%')
        .borderRadius(AppStyles.RADIUS_LG)
        .clip(true)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 2, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 2, 4) })
        .onHover((isHover: boolean) => this.onPanelHover && this.onPanelHover(isHover))
      }
    }
    .width('100%')
  }

  @Builder
  private tableHeader() {
    Row() {
      this.headerText('设备名称', 2.6, TextAlign.Center)
      this.headerText('设备类型', 1.5, TextAlign.Center)
      this.headerText('当前策略', 1.5, TextAlign.Center)
      this.headerText('最近连接时间', 1.8, TextAlign.Center)
      this.headerText('操作', 1.6, TextAlign.End)
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 14, bottom: 14 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  private tableRow(record: PeripheralPolicyRecord, index: number) {
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

      this.typeTag(record)

      Text(this.getPolicyLabel ? this.getPolicyLabel(record.policyIndex) : String(record.policyIndex))
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .layoutWeight(1.5)
        .textAlign(TextAlign.Center)

      Text(record.lastSeenLabel)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .layoutWeight(1.8)
        .textAlign(TextAlign.Center)

      Select(this.policyListOptions as SelectOption[])
        .selected(record.policyIndex)
        .value(this.getPolicyLabel ? this.getPolicyLabel(record.policyIndex) : String(record.policyIndex))
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
        .optionFont({ size: AppStyles.FONT_SIZE_BODY })
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .borderRadius(10)
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .height(36)
        .layoutWeight(1.6)
        .enabled(!(this.isUpdating ? this.isUpdating(record.deviceId) : false))
        .opacity((this.isUpdating ? this.isUpdating(record.deviceId) : false) ? 0.6 : 1)
        .onSelect((selectIndex: number) => {
          if (this.onPolicyChange) {
            this.onPolicyChange(index, selectIndex)
          }
        })
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 18, bottom: 18 })
    .backgroundColor(index % 2 === 0 ? AppColors.getColors(this.currentTheme).BG_CARD : AppColors.getColors(this.currentTheme).BG_PAGE)
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
  private typeTag(record: PeripheralPolicyRecord) {
    Row() {
      Row() {
        Text(getPeripheralTypeLabel(record.deviceType))
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.TAG_PURPLE_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .borderRadius(6)
      .backgroundColor(AppColors.TAG_PURPLE_BG)
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .layoutWeight(1.5)
  }
}
