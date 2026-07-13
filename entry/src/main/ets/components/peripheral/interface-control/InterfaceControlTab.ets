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
struct InterfaceToggleRow {
  @Param label: string = ''
  @Param description: string = ''
  @Param feature: PeripheralInterfaceFeature = PeripheralInterfaceFeatures.BLUETOOTH
  @Param disabled: boolean = false
  @Param processing: boolean = false
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onToggle: (feature: PeripheralInterfaceFeature, disallow: boolean) => Promise<boolean> = async () => false

  build() {
    AsyncSelectRow({
      label: this.label,
      description: this.description,
      options: PeripheralOptionStrings.INTERFACE_TOGGLE_OPTIONS,
      selectedIndex: this.disabled ?
        PeripheralInterfaceToggleOptionIndexes.DISABLED :
        PeripheralInterfaceToggleOptionIndexes.ENABLED,
      processing: this.processing,
      currentTheme: this.currentTheme,
      onSelectAsync: async (index: number): Promise<boolean> => {
        return await this.onToggle(
          this.feature,
          index === PeripheralInterfaceToggleOptionIndexes.DISABLED
        )
      }
    })
  }
}

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
          InterfaceToggleRow({
            label: PeripheralInterfaceStrings.BLUETOOTH_TITLE,
            description: PeripheralInterfaceStrings.BLUETOOTH_DESCRIPTION,
            feature: PeripheralInterfaceFeatures.BLUETOOTH,
            disabled: this.btDisabled,
            processing: this.interfaceControlProcessingKey === PeripheralInterfaceFeatures.BLUETOOTH,
            currentTheme: this.currentTheme,
            onToggle: async (feature: PeripheralInterfaceFeature, disallow: boolean): Promise<boolean> =>
              await this.toggleInterface(feature, disallow)
          })
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          InterfaceToggleRow({
            label: PeripheralInterfaceStrings.WIFI_TITLE,
            description: PeripheralInterfaceStrings.WIFI_DESCRIPTION,
            feature: PeripheralInterfaceFeatures.WIFI,
            disabled: this.wifiDisabled,
            processing: this.interfaceControlProcessingKey === PeripheralInterfaceFeatures.WIFI,
            currentTheme: this.currentTheme,
            onToggle: async (feature: PeripheralInterfaceFeature, disallow: boolean): Promise<boolean> =>
              await this.toggleInterface(feature, disallow)
          })
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          InterfaceToggleRow({
            label: PeripheralInterfaceStrings.ETHERNET_TITLE,
            description: PeripheralInterfaceStrings.ETHERNET_DESCRIPTION,
            feature: PeripheralInterfaceFeatures.ETHERNET,
            disabled: this.ethernetDisabled,
            processing: this.interfaceControlProcessingKey === PeripheralInterfaceFeatures.ETHERNET,
            currentTheme: this.currentTheme,
            onToggle: async (feature: PeripheralInterfaceFeature, disallow: boolean): Promise<boolean> =>
              await this.toggleInterface(feature, disallow)
          })
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          InterfaceToggleRow({
            label: PeripheralInterfaceStrings.HDC_TITLE,
            description: PeripheralInterfaceStrings.HDC_DESCRIPTION,
            feature: PeripheralInterfaceFeatures.HDC,
            disabled: this.hdcDisabled,
            processing: this.interfaceControlProcessingKey === PeripheralInterfaceFeatures.HDC,
            currentTheme: this.currentTheme,
            onToggle: async (feature: PeripheralInterfaceFeature, disallow: boolean): Promise<boolean> =>
              await this.toggleInterface(feature, disallow)
          })
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          InterfaceToggleRow({
            label: PeripheralInterfaceStrings.NETWORK_SHARING_TITLE,
            description: PeripheralInterfaceStrings.NETWORK_SHARING_DESCRIPTION,
            feature: PeripheralInterfaceFeatures.NETWORK,
            disabled: this.networkDisabled,
            processing: this.interfaceControlProcessingKey === PeripheralInterfaceFeatures.NETWORK,
            currentTheme: this.currentTheme,
            onToggle: async (feature: PeripheralInterfaceFeature, disallow: boolean): Promise<boolean> =>
              await this.toggleInterface(feature, disallow)
          })
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          InterfaceToggleRow({
            label: PeripheralInterfaceStrings.PRINTER_TITLE,
            description: PeripheralInterfaceStrings.PRINTER_DESCRIPTION,
            feature: PeripheralInterfaceFeatures.PRINTER,
            disabled: this.printerDisabled,
            processing: this.interfaceControlProcessingKey === PeripheralInterfaceFeatures.PRINTER,
            currentTheme: this.currentTheme,
            onToggle: async (feature: PeripheralInterfaceFeature, disallow: boolean): Promise<boolean> =>
              await this.toggleInterface(feature, disallow)
          })
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          InterfaceToggleRow({
            label: PeripheralInterfaceStrings.MICROPHONE_TITLE,
            description: PeripheralInterfaceStrings.MICROPHONE_DESCRIPTION,
            feature: PeripheralInterfaceFeatures.MICROPHONE,
            disabled: this.microphoneDisabled,
            processing: this.interfaceControlProcessingKey === PeripheralInterfaceFeatures.MICROPHONE,
            currentTheme: this.currentTheme,
            onToggle: async (feature: PeripheralInterfaceFeature, disallow: boolean): Promise<boolean> =>
              await this.toggleInterface(feature, disallow)
          })
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          InterfaceToggleRow({
            label: PeripheralInterfaceStrings.CAMERA_TITLE,
            description: PeripheralInterfaceStrings.CAMERA_DESCRIPTION,
            feature: PeripheralInterfaceFeatures.CAMERA,
            disabled: this.cameraDisabled,
            processing: this.interfaceControlProcessingKey === PeripheralInterfaceFeatures.CAMERA,
            currentTheme: this.currentTheme,
            onToggle: async (feature: PeripheralInterfaceFeature, disallow: boolean): Promise<boolean> =>
              await this.toggleInterface(feature, disallow)
          })
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
  private async toggleInterface(feature: PeripheralInterfaceFeature, disallow: boolean): Promise<boolean> {
    if (!this.onInterfaceToggle) {
      return false
    }
    return await this.onInterfaceToggle(feature, disallow)
  }
}
