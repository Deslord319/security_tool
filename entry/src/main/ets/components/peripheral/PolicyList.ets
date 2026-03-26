import { AppColors, AppStyles } from '../../constants/AppConstants'
import { getPeripheralTypeLabel, PeripheralPolicyRecord } from '../../models/DataModels'
import { ThemeMode } from '../../theme/ThemeColors'
import { HoverUtils } from '../../utils/HoverUtils'
import { FormControlUtils } from '../../utils/FormControlUtils'
import { PeripheralTableHeaderCell } from './PeripheralTableHeaderCell'
import { PeripheralTypeTag } from './PeripheralTypeTag'

export interface PolicyOption {
  value: string
}

@Component
export struct PolicyList {
  @Prop policyRecords: PeripheralPolicyRecord[] = []
  @Prop policyListOptions: PolicyOption[] = []
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT
  @Prop hoveredPanelIndex: number = -1
  @Prop refreshVersion: number = 0
  onPolicyChange?: (index: number, policyIndex: number) => void
  getPolicyLabel?: (index: number) => string
  isUpdating?: (deviceId: string) => boolean
  onPanelHover?: (isHover: boolean) => void

  build() {
    Scroll() {
      Column({ space: 0 }) {
        Text(`${this.refreshVersion}`)
          .fontSize(0)
          .width(0)
          .height(0)
          .opacity(0)

        if (this.policyRecords.length === 0) {
          this.emptyCard()
        } else {
          this.contentCard()
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
  private contentCard() {
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
      }, (record: PeripheralPolicyRecord) => `${this.refreshVersion}-${record.deviceId}-${record.policyIndex}`)
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

  @Builder
  private emptyCard() {
    Column({ space: 10 }) {
      Text('暂无可管理的 USB 设备记录')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .textAlign(TextAlign.Center)
      Text('设备接入后会显示在这里，可直接设置允许接入或禁止访问。')
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 22, right: 22, top: 24, bottom: 24 })
    .borderRadius(AppStyles.RADIUS_LG)
    .clip(true)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER })
    .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 2, true))
    .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 2, 4) })
    .onHover((isHover: boolean) => this.onPanelHover && this.onPanelHover(isHover))
  }

  @Builder
  private tableHeader() {
    Row() {
      PeripheralTableHeaderCell({ label: '设备名称', weight: 2.6, currentTheme: this.currentTheme })
      PeripheralTableHeaderCell({ label: '设备类型', weight: 1.5, currentTheme: this.currentTheme })
      PeripheralTableHeaderCell({ label: '当前策略', weight: 1.5, currentTheme: this.currentTheme })
      PeripheralTableHeaderCell({ label: '最近连接时间', weight: 1.8, currentTheme: this.currentTheme })
      PeripheralTableHeaderCell({ label: '操作', weight: 1.4, currentTheme: this.currentTheme })
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

      PeripheralTypeTag({
        label: getPeripheralTypeLabel(record.deviceType),
        weight: 1.5,
        currentTheme: this.currentTheme
      })

      Row() {
        Text(this.getPolicyLabel ? this.getPolicyLabel(record.policyIndex) : String(record.policyIndex))
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Regular)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(1.5)
      .justifyContent(FlexAlign.Center)

      Row() {
        Text(record.lastSeenLabel)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(1.8)
      .justifyContent(FlexAlign.Center)

      Select(this.policyListOptions as SelectOption[])
        .selected(record.policyIndex)
        .value(this.getPolicyLabel ? this.getPolicyLabel(record.policyIndex) : String(record.policyIndex))
        .font({ size: AppStyles.FONT_SIZE_CAPTION, weight: FontWeight.Regular })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_CAPTION, weight: FontWeight.Regular })
        .optionFont({ size: AppStyles.FONT_SIZE_CAPTION, weight: FontWeight.Regular })
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .borderRadius(8)
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .height(32)
        .layoutWeight(1.4)
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
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .alignItems(VerticalAlign.Center)
  }
}
