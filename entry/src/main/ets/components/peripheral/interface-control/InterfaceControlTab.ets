import { SymbolGlyphModifier, TextModifier } from '@kit.ArkUI'
import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { DeviceTypeLabels, PeripheralInterfaceStrings, PeripheralOptionStrings } from '../../../constants/modules/PeripheralStrings'
import { PeripheralService } from '../../../services/peripheral/interface-control/PeripheralService'
import { ThemeMode } from '../../../theme/ThemeColors'
import { HoverUtils } from '../../../utils/HoverUtils'
import { FormControlUtils } from '../../../utils/FormControlUtils'
import { getScrollBarColor, SCROLL_BAR_WIDTH_DEFAULT, SCROLL_BAR_WIDTH_HOVER } from '../../../utils/ScrollBarStyleUtils'
import { AsyncSelectRow } from '../../AsyncSelectRow'
import { SectionLabel } from '../../SectionRows'

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
  @Event onUsbInterfaceToggleAsync?: (disallow: boolean) => Promise<boolean>
  @Event onUsbStoragePolicyChange?: (index: number) => Promise<boolean>
  @Event onPanelHover?: (isHover: boolean) => void
  @Local private scrollBarWidth: number = SCROLL_BAR_WIDTH_DEFAULT

  build() {
    Scroll() {
      Column({ space: 0 }) {
        Column() {
          this.usbInterfaceItem()
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.storageItem()
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralInterfaceStrings.BLUETOOTH_TITLE, PeripheralInterfaceStrings.BLUETOOTH_DESCRIPTION, PeripheralService.FEATURE_BLUETOOTH, this.btDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralInterfaceStrings.WIFI_TITLE, PeripheralInterfaceStrings.WIFI_DESCRIPTION, PeripheralService.FEATURE_WIFI, this.wifiDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralInterfaceStrings.HDC_TITLE, PeripheralInterfaceStrings.HDC_DESCRIPTION, PeripheralService.FEATURE_HDC, this.hdcDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralInterfaceStrings.NETWORK_SHARING_TITLE, PeripheralInterfaceStrings.NETWORK_SHARING_DESCRIPTION, PeripheralService.FEATURE_NETWORK, this.networkDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralInterfaceStrings.PRINTER_TITLE, PeripheralInterfaceStrings.PRINTER_DESCRIPTION, PeripheralService.FEATURE_PRINTER, this.printerDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralInterfaceStrings.MICROPHONE_TITLE, PeripheralInterfaceStrings.MICROPHONE_DESCRIPTION, PeripheralService.FEATURE_MICROPHONE, this.microphoneDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralInterfaceStrings.CAMERA_TITLE, PeripheralInterfaceStrings.CAMERA_DESCRIPTION, PeripheralService.FEATURE_CAMERA, this.cameraDisabled)
        }
        .borderRadius(AppStyles.RADIUS_LG)
        .clip(true)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .border({ width: AppStyles.DIVIDER_HEIGHT, color: AppColors.getColors(this.currentTheme).BORDER })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 0, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 0, 4) })
        .onHover((isHover: boolean) => this.onPanelHover && this.onPanelHover(isHover))
      }
      .width('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_XS })
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
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
  private usbInterfaceItem() {
    AsyncSelectRow({
      label: PeripheralInterfaceStrings.USB_INTERFACE_TITLE,
      description: PeripheralInterfaceStrings.USB_INTERFACE_DESCRIPTION,
      options: PeripheralOptionStrings.INTERFACE_TOGGLE_OPTIONS,
      selectedIndex: this.usbDisabled ? 1 : 0,
      processing: this.interfaceControlProcessingKey === PeripheralService.FEATURE_USB,
      currentTheme: this.currentTheme,
      optimistic: true,
      onSelectAsync: async (nextIndex: number): Promise<boolean> => {
        if (!this.onUsbInterfaceToggleAsync) {
          return false
        }
        return await this.onUsbInterfaceToggleAsync(nextIndex === 1)
      }
    })
  }

  @Builder
  private toggleItem(label: string, description: string, feature: string, disabled: boolean) {
    this.controlRow(
      label,
      description,
      PeripheralOptionStrings.INTERFACE_TOGGLE_OPTIONS,
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
    AsyncSelectRow({
      label: DeviceTypeLabels.USB_STORAGE,
      description: PeripheralInterfaceStrings.USB_STORAGE_DESCRIPTION,
      options: PeripheralOptionStrings.USB_STORAGE_OPTIONS,
      selectedIndex: this.usbStoragePolicyIndex,
      processing: this.interfaceControlProcessingKey === this.usbStorageControlKey,
      currentTheme: this.currentTheme,
      optimistic: true,
      onSelectAsync: async (nextIndex: number): Promise<boolean> => {
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
    onSelect?: (index: number) => void
  ) {
    Row() {
      SectionLabel({
        title: label,
        description: description,
        currentTheme: this.currentTheme
      })

      Row({ space: 10 }) {
        if (isProcessing) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        }

        Select(options.map((value: string): SelectOption => ({ value: value } as SelectOption)))
          .selected(selectedIndex)
          .value(options[selectedIndex] ?? '')
          .fontColor(FormControlUtils.text(this.currentTheme))
          .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
          .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: AppStyles.DIVIDER_HEIGHT, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .enabled(!isProcessing)
          .opacity(isProcessing ? 0.72 : 1)
          .onSelect((index: number) => {
            if (onSelect) {
              onSelect(index)
            }
          })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .opacity(isProcessing ? 0.8 : 1)
  }
}
