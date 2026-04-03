import { SymbolGlyphModifier, TextModifier } from '@kit.ArkUI'
import { SectionSelectRow } from '../SectionRows'
import { AppColors, AppStyles } from '../../constants/AppConstants'
import { DeviceTypeLabels } from '../../constants/modules/DialogStrings'
import { PeripheralStrings } from '../../constants/modules/PeripheralStrings'
import { PeripheralService } from '../../services/PeripheralService'
import { ThemeMode } from '../../theme/ThemeColors'
import { HoverUtils } from '../../utils/HoverUtils'
import { FormControlUtils } from '../../utils/FormControlUtils'

@ComponentV2
export struct InterfaceControlTab {
  @Param usbDisabled: boolean = false
  @Param btDisabled: boolean = false
  @Param wifiDisabled: boolean = false
  @Param hdcDisabled: boolean = false
  @Param networkDisabled: boolean = false
  @Param printerDisabled: boolean = false
  @Param microphoneDisabled: boolean = false
  @Param cameraDisabled: boolean = false
  @Param usbStoragePolicyIndex: number = 0
  @Param interfaceControlProcessingKey: string = ''
  @Param usbStorageControlKey: string = ''
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param hoveredPanelIndex: number = -1
  @Event onInterfaceToggle?: (feature: string, disallow: boolean) => void
  @Event onUsbStoragePolicyChange?: (index: number) => Promise<boolean>
  @Event onPanelHover?: (isHover: boolean) => void

  build() {
    Scroll() {
      Column({ space: 0 }) {
        Column() {
          this.toggleItem(
            PeripheralStrings.usbInterfaceTitle,
            PeripheralStrings.usbInterfaceDescription,
            PeripheralService.FEATURE_USB,
            this.usbDisabled
          )
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.storageItem()
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralStrings.bluetoothTitle, PeripheralStrings.bluetoothDescription, PeripheralService.FEATURE_BLUETOOTH, this.btDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralStrings.wifiTitle, PeripheralStrings.wifiDescription, PeripheralService.FEATURE_WIFI, this.wifiDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralStrings.hdcTitle, PeripheralStrings.hdcDescription, PeripheralService.FEATURE_HDC, this.hdcDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralStrings.networkSharingTitle, PeripheralStrings.networkSharingDescription, PeripheralService.FEATURE_NETWORK, this.networkDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralStrings.printerTitle, PeripheralStrings.printerDescription, PeripheralService.FEATURE_PRINTER, this.printerDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralStrings.microphoneTitle, PeripheralStrings.microphoneDescription, PeripheralService.FEATURE_MICROPHONE, this.microphoneDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralStrings.cameraTitle, PeripheralStrings.cameraDescription, PeripheralService.FEATURE_CAMERA, this.cameraDisabled)
        }
        .borderRadius(AppStyles.RADIUS_LG)
        .clip(true)
        .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 0, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 0, 4) })
        .onHover((isHover: boolean) => this.onPanelHover && this.onPanelHover(isHover))
      }
      .width('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
  }

  @Builder
  private toggleItem(label: string, description: string, feature: string, disabled: boolean) {
    this.controlRow(
      label,
      description,
      PeripheralStrings.interfaceToggleOptions,
      disabled ? 1 : 0,
      this.interfaceControlProcessingKey === feature,
      (index: number) => {
        if (this.onInterfaceToggle) {
          this.onInterfaceToggle(feature, index === 1)
        }
      }
    )
  }

  @Builder
  private storageItem() {
    SectionSelectRow({
      title: DeviceTypeLabels.USB_STORAGE,
      description: PeripheralStrings.usbStorageDescription,
      options: PeripheralStrings.usbStorageOptions.map((value: string): SelectOption => ({ value: value } as SelectOption)),
      selectedIndex: this.usbStoragePolicyIndex,
      value: PeripheralStrings.usbStorageOptions[this.usbStoragePolicyIndex] ?? '',
      selectWidth: 150,
      processing: this.interfaceControlProcessingKey === this.usbStorageControlKey,
      optimistic: true,
      currentTheme: this.currentTheme,
      onSelectAsync: async (nextIndex: number, _previousIndex: number): Promise<boolean> => {
        if (!this.onUsbStoragePolicyChange) {
          return false
        }
        return await this.onUsbStoragePolicyChange(nextIndex)
      }
    })
  }

  @Builder
  private controlRow(
    label: string,
    description: string,
    options: string[],
    selectedIndex: number,
    isProcessing: boolean,
    onSelect: (index: number) => void
  ) {
    Row() {
      Column({ space: 4 }) {
        Text(label)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        Text(description)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: 10 }) {
        if (isProcessing) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        }

        Select(options.map((value: string) => {
          const item: SelectOption = { value: value }
          return item
        }))
          .selected(selectedIndex)
          .value(options[selectedIndex] ?? '')
          .fontColor(FormControlUtils.text(this.currentTheme))
          .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
          .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .enabled(!isProcessing)
          .opacity(isProcessing ? 0.72 : 1)
          .onSelect((index: number) => onSelect(index))
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .opacity(isProcessing ? 0.8 : 1)
  }
}
