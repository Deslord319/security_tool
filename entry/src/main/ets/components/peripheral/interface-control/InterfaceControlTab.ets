import { AppColors, AppStyles } from '../../../constants/AppConstants'
import {
  DeviceTypeLabels,
  PeripheralInterfaceStrings,
  PeripheralInterfaceToggleOptionIndexes,
  PeripheralOptionStrings
} from '../../../constants/modules/PeripheralStrings'
import { PeripheralInterfaceFeature, PeripheralInterfaceFeatures } from '../../../models/PeripheralModels'
import { ThemeMode } from '../../../theme/ThemeColors'
import { HoverUtils } from '../../../utils/HoverUtils'
import { getScrollBarColor, SCROLL_BAR_WIDTH_DEFAULT, SCROLL_BAR_WIDTH_HOVER } from '../../../utils/ScrollBarStyleUtils'
import { AsyncSelectRow } from '../../AsyncSelectRow'

@ComponentV2
export struct InterfaceControlTab {
  @Param usbDisabled: boolean = false
  @Param btDisabled: boolean = false
  @Param wifiDisabled: boolean = false
  @Param ethernetDisabled: boolean = false
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
  @Event onInterfaceToggle?: (feature: PeripheralInterfaceFeature, disallow: boolean) => Promise<boolean>
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
          this.toggleItem(PeripheralInterfaceStrings.BLUETOOTH_TITLE, PeripheralInterfaceStrings.BLUETOOTH_DESCRIPTION, PeripheralInterfaceFeatures.BLUETOOTH, this.btDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralInterfaceStrings.WIFI_TITLE, PeripheralInterfaceStrings.WIFI_DESCRIPTION, PeripheralInterfaceFeatures.WIFI, this.wifiDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralInterfaceStrings.ETHERNET_TITLE, PeripheralInterfaceStrings.ETHERNET_DESCRIPTION, PeripheralInterfaceFeatures.ETHERNET, this.ethernetDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralInterfaceStrings.HDC_TITLE, PeripheralInterfaceStrings.HDC_DESCRIPTION, PeripheralInterfaceFeatures.HDC, this.hdcDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralInterfaceStrings.NETWORK_SHARING_TITLE, PeripheralInterfaceStrings.NETWORK_SHARING_DESCRIPTION, PeripheralInterfaceFeatures.NETWORK, this.networkDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralInterfaceStrings.PRINTER_TITLE, PeripheralInterfaceStrings.PRINTER_DESCRIPTION, PeripheralInterfaceFeatures.PRINTER, this.printerDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralInterfaceStrings.MICROPHONE_TITLE, PeripheralInterfaceStrings.MICROPHONE_DESCRIPTION, PeripheralInterfaceFeatures.MICROPHONE, this.microphoneDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem(PeripheralInterfaceStrings.CAMERA_TITLE, PeripheralInterfaceStrings.CAMERA_DESCRIPTION, PeripheralInterfaceFeatures.CAMERA, this.cameraDisabled)
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
      selectedIndex: this.usbDisabled ?
        PeripheralInterfaceToggleOptionIndexes.DISABLED :
        PeripheralInterfaceToggleOptionIndexes.ENABLED,
      processing: this.interfaceControlProcessingKey === PeripheralInterfaceFeatures.USB,
      currentTheme: this.currentTheme,
      onSelectAsync: async (nextIndex: number): Promise<boolean> => {
        if (!this.onUsbInterfaceToggleAsync) {
          return false
        }
        return await this.onUsbInterfaceToggleAsync(nextIndex === PeripheralInterfaceToggleOptionIndexes.DISABLED)
      }
    })
  }

  @Builder
  private toggleItem(label: string, description: string, feature: PeripheralInterfaceFeature, disabled: boolean) {
    AsyncSelectRow({
      label: label,
      description: description,
      options: PeripheralOptionStrings.INTERFACE_TOGGLE_OPTIONS,
      selectedIndex: disabled ?
        PeripheralInterfaceToggleOptionIndexes.DISABLED :
        PeripheralInterfaceToggleOptionIndexes.ENABLED,
      processing: this.interfaceControlProcessingKey === feature,
      currentTheme: this.currentTheme,
      onSelectAsync: async (index: number): Promise<boolean> => {
        if (!this.onInterfaceToggle) {
          return false
        }
        return await this.onInterfaceToggle(feature, index === PeripheralInterfaceToggleOptionIndexes.DISABLED)
      }
    })
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
      onSelectAsync: async (nextIndex: number): Promise<boolean> => {
        if (!this.onUsbStoragePolicyChange) {
          return false
        }
        return await this.onUsbStoragePolicyChange(nextIndex)
      }
    })
  }
}
