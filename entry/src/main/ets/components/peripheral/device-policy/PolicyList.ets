import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { EmptyStateStrings } from '../../../constants/modules/DialogStrings'
import { PeripheralPageStrings } from '../../../constants/modules/PeripheralStrings'
import { FirewallDialogStrings } from '../../../constants/modules/FirewallStrings'
import {
  PeripheralPolicyRecord,
  PeripheralType,
  isUsbPeripheralType
} from '../../../models/PeripheralModels'
import { getPeripheralTypeLabel } from '../../../viewmodels/peripheral/connection-record/PeripheralRecordPresentationMapper'
import { ThemeMode } from '../../../theme/ThemeColors'
import { HoverUtils } from '../../../utils/HoverUtils'
import { getScrollBarColor, SCROLL_BAR_WIDTH_DEFAULT, SCROLL_BAR_WIDTH_HOVER } from '../../../utils/ScrollBarStyleUtils'
import { PeripheralDeviceIdentityCell, PeripheralHeaderCell, PeripheralTypeTag } from '../common/PeripheralTableCells'
import { StyledSelect } from '../../StyledSelect'
import { AsyncSelectRow } from '../../AsyncSelectRow'

@ComponentV2
export struct PolicyList {
  @Param policyRecords: PeripheralPolicyRecord[] = []
  @Param policyListOptions: SelectOption[] = []
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param hoveredPanelIndex: number = -1
  @Event onPolicyChange?: (index: number, policyIndex: number) => void = undefined
  @Param isUpdating?: (deviceId: string) => boolean = undefined
  @Param usbDefaultPolicyIndex: number = 0
  @Param usbGloballyDisabled: boolean = false
  @Event onDefaultPolicyChange?: (policyIndex: number) => Promise<boolean> = undefined
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
      this.defaultPolicyRow()
      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
      this.tableHeader()
      ForEach(this.policyRecords, (record: PeripheralPolicyRecord, index: number) => {
        Column({ space: 0 }) {
          this.tableRow(record, index)
          if (index < this.policyRecords.length - 1) {
            Divider()
              .color(AppColors.getColors(this.currentTheme).BORDER)
              .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
              .margin({
                left: AppStyles.TABLE_DIVIDER_MARGIN,
                right: AppStyles.TABLE_DIVIDER_MARGIN
              })
          }
        }
      }, (record: PeripheralPolicyRecord) =>
        `${record.deviceId}-${record.policyIndex}-${record.present === false ? 'offline' : 'online'}-` +
        `${record.editable === false ? 'locked' : 'editable'}`)
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
    Column() {
      this.defaultPolicyRow()
      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
      Text(EmptyStateStrings.NO_DEVICES)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({
      left: AppStyles.TABLE_HORIZONTAL_PADDING,
      right: AppStyles.TABLE_HORIZONTAL_PADDING,
      top: AppStyles.PADDING_LG,
      bottom: AppStyles.PADDING_LG
    })
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
    .padding({
      left: AppStyles.TABLE_HORIZONTAL_PADDING,
      right: AppStyles.TABLE_HORIZONTAL_PADDING,
      top: AppStyles.TABLE_HEADER_VERTICAL_PADDING,
      bottom: AppStyles.TABLE_HEADER_VERTICAL_PADDING
    })
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

      StyledSelect({
        options: this.policyListOptions,
        selectedIndex: record.policyIndex,
        value: this.getPolicyLabel(record.policyIndex),
        controlHeight: 32,
        radius: 8,
        fontSize: AppStyles.FONT_SIZE_CAPTION,
        enabledValue: this.isPolicyEditable(record),
        opacityValue: this.isPolicyEditable(record) ? 1 : 0.6,
        currentTheme: this.currentTheme,
        onSelect: (selectIndex: number) => {
          if (this.onPolicyChange && this.isPolicyEditable(record)) {
            this.onPolicyChange(index, selectIndex)
          }
        }
      })
        .hitTestBehavior(this.isPolicyEditable(record) ? HitTestMode.Default : HitTestMode.None)
        .layoutWeight(1.4)
    }
    .width('100%')
    .padding({
      left: AppStyles.TABLE_HORIZONTAL_PADDING,
      right: AppStyles.TABLE_HORIZONTAL_PADDING,
      top: AppStyles.TABLE_ROW_VERTICAL_PADDING,
      bottom: AppStyles.TABLE_ROW_VERTICAL_PADDING
    })
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

  @Builder
  private defaultPolicyRow() {
    AsyncSelectRow({
      label: PeripheralPageStrings.USB_DEFAULT_POLICY_TITLE,
      description: PeripheralPageStrings.USB_DEFAULT_POLICY_DESCRIPTION,
      options: this.policyListOptions.map((item: SelectOption) => `${item.value}`),
      selectedIndex: this.usbDefaultPolicyIndex,
      enabledValue: !this.usbGloballyDisabled,
      currentTheme: this.currentTheme,
      onSelectAsync: async (index: number): Promise<boolean> => {
        return this.onDefaultPolicyChange ? await this.onDefaultPolicyChange(index) : false
      }
    })
  }

  private isPolicyEditable(record: PeripheralPolicyRecord): boolean {
    const updating = this.isUpdating ? this.isUpdating(record.deviceId) : false
    return !this.usbGloballyDisabled && !updating && record.editable !== false
  }
}
