import { AppColors, AppStyles } from '../../constants/AppConstants'
import { EmptyStateStrings } from '../../constants/modules/DialogStrings'
import { PeripheralStrings } from '../../constants/modules/PeripheralStrings'
import { getPeripheralTypeLabel, PeripheralPolicyRecord } from '../../models/DataModels'
import { ThemeMode } from '../../theme/ThemeColors'
import { FormControlUtils } from '../../utils/FormControlUtils'
import { HoverUtils } from '../../utils/HoverUtils'

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
    Scroll() {
      Column({ space: 0 }) {
        if (this.policyRecords.length === 0) {
          this.emptyCard()
        } else {
          this.contentCard()
        }
      }
      .width('100%')
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

  @Builder
  private emptyCard() {
    Column({ space: 10 }) {
      Text(EmptyStateStrings.NO_DEVICES)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .textAlign(TextAlign.Center)

      Text(EmptyStateStrings.CHECK_PERMISSIONS)
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
      this.headerCell(PeripheralStrings.deviceNameLabel, 2.6)
      this.headerCell(PeripheralStrings.deviceTypeLabel, 1.5)
      this.headerCell(PeripheralStrings.currentPolicyLabel, 1.5)
      this.headerCell(PeripheralStrings.latestConnectionTimeLabel, 1.8)
      this.headerCell(PeripheralStrings.actionLabel, 1.4)
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

      this.typeTag(this.getDeviceTypeLabel(record), 1.5)

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

  @Builder
  private headerCell(label: string, weight: number, textAlign: TextAlign = TextAlign.Center) {
    Text(label)
      .fontSize(AppStyles.FONT_SIZE_SMALL)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .layoutWeight(weight)
      .textAlign(textAlign)
  }

  @Builder
  private typeTag(label: string, weight: number) {
    Row() {
      Row() {
        Text(label)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .borderRadius(6)
      .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
    }
    .layoutWeight(weight)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  private getDeviceTypeLabel(record: PeripheralPolicyRecord): string {
    return getPeripheralTypeLabel(record.deviceType)
  }
}
