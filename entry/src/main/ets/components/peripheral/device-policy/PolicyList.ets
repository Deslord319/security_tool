import { SymbolGlyphModifier, TextModifier } from '@kit.ArkUI'
import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { MessageText } from '../../../constants/StringCatalog'
import { EmptyStateStrings } from '../../../constants/modules/DialogStrings'
import { PeripheralPageStrings } from '../../../constants/modules/PeripheralStrings'
import { FirewallDialogStrings } from '../../../constants/modules/FirewallStrings'
import { getPeripheralTypeLabel, PeripheralPolicyRecord, PeripheralType, isUsbPeripheralType } from '../../../models/DataModels'
import { ThemeMode } from '../../../theme/ThemeColors'
import { FormControlUtils } from '../../../utils/FormControlUtils'
import { HoverUtils } from '../../../utils/HoverUtils'
import { getScrollBarColor, SCROLL_BAR_WIDTH_DEFAULT, SCROLL_BAR_WIDTH_HOVER } from '../../../utils/ScrollBarStyleUtils'
import { PeripheralDeviceIdentityCell, PeripheralHeaderCell, PeripheralTypeTag } from '../common/PeripheralTableCells'

@ComponentV2
export struct PolicyList {
  @Param policyRecords: PeripheralPolicyRecord[] = []
  @Param policyListOptions: SelectOption[] = []
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param hoveredPanelIndex: number = -1
  @Event onPolicyChange?: (index: number, policyIndex: number) => void = undefined
  @Param isUpdating?: (deviceId: string) => boolean = undefined
  @Event onPanelHover?: (isHover: boolean) => void = undefined
  @Local private scrollBarWidth: number = SCROLL_BAR_WIDTH_DEFAULT

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
        top: AppStyles.PADDING_SM,
        bottom: AppStyles.PADDING_MD
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .scrollBarColor(getScrollBarColor(this.currentTheme))
    .scrollBarWidth(this.scrollBarWidth)
    .onHover((isHover: boolean) => {
      this.scrollBarWidth = isHover ? SCROLL_BAR_WIDTH_HOVER : SCROLL_BAR_WIDTH_DEFAULT
    })
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
    .border({ width: AppStyles.DIVIDER_HEIGHT, color: AppColors.getColors(this.currentTheme).BORDER })
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

      Text(MessageText.CHECK_PERMISSIONS)
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
    .border({ width: AppStyles.DIVIDER_HEIGHT, color: AppColors.getColors(this.currentTheme).BORDER })
    .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 2, true))
    .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 2, 4) })
    .onHover((isHover: boolean) => this.onPanelHover && this.onPanelHover(isHover))
  }

  @Builder
  private tableHeader() {
    Row() {
      PeripheralHeaderCell({ label: PeripheralPageStrings.DEVICE_NAME_LABEL, weight: 2.6, currentTheme: this.currentTheme })
      PeripheralHeaderCell({ label: PeripheralPageStrings.DEVICE_TYPE_LABEL, weight: 1.5, currentTheme: this.currentTheme })
      PeripheralHeaderCell({ label: FirewallDialogStrings.CURRENT_STATUS, weight: 1.5, currentTheme: this.currentTheme })
      PeripheralHeaderCell({ label: PeripheralPageStrings.LATEST_CONNECTION_TIME_LABEL, weight: 1.8, currentTheme: this.currentTheme })
      PeripheralHeaderCell({ label: PeripheralPageStrings.ACTION_LABEL, weight: 1.4, currentTheme: this.currentTheme })
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 14, bottom: 14 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  private tableRow(record: PeripheralPolicyRecord, index: number) {
    Row() {
      PeripheralDeviceIdentityCell({
        deviceName: record.deviceName,
        deviceId: this.getDisplayDeviceId(record.deviceType, record.deviceId),
        currentTheme: this.currentTheme,
        weight: 2.6
      })

      PeripheralTypeTag({ label: this.getDeviceTypeLabel(record), weight: 1.5, currentTheme: this.currentTheme })

      Row() {
        Text(this.getPolicyLabel(record.policyIndex))
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

      Select(this.policyListOptions)
        .selected(record.policyIndex)
        .value(this.getPolicyLabel(record.policyIndex))
        .font({ size: AppStyles.FONT_SIZE_CAPTION, weight: FontWeight.Regular })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
        .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_CAPTION, weight: FontWeight.Regular })
        .optionFont({ size: AppStyles.FONT_SIZE_CAPTION, weight: FontWeight.Regular })
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .borderRadius(8)
        .border({ width: AppStyles.DIVIDER_HEIGHT, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
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

  private getDeviceTypeLabel(record: PeripheralPolicyRecord): string {
    return getPeripheralTypeLabel(record.deviceType)
  }

  private getPolicyLabel(policyIndex: number): string {
    const option = this.policyListOptions[policyIndex]
    return option ? `${option.value}` : String(policyIndex)
  }

  private getDisplayDeviceId(deviceType: PeripheralType, deviceId: string): string {
    return isUsbPeripheralType(deviceType) ? '' : deviceId
  }
}
