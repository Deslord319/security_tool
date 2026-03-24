/**
 * 接口管控 Tab 组件
 */
import { AppColors, AppStyles } from '../../constants/AppConstants'
import { PeripheralService } from '../../services/PeripheralService'
import { ThemeMode } from '../../theme/ThemeColors'
import { HoverUtils } from '../../utils/HoverUtils'
import { InterfaceControlItem } from '../InterfaceControlItem'

interface InterfaceControlTabProps {
  usbDisabled: boolean
  btDisabled: boolean
  wifiDisabled: boolean
  hdcDisabled: boolean
  networkDisabled: boolean
  printerDisabled: boolean
  microphoneDisabled: boolean
  cameraDisabled: boolean
  usbStoragePolicyIndex: number
  interfaceControlProcessingKey: string
  usbStorageControlKey: string
  interfaceControlSyncToken: number
  currentTheme: ThemeMode
  hoveredPanelIndex: number
  onInterfaceToggle: (feature: string, disallow: boolean) => void
  onUsbStoragePolicyChange: (index: number) => void
  onPanelHover: (isHover: boolean) => void
}

@Component
export struct InterfaceControlTab {
  @Prop usbDisabled: boolean = false
  @Prop btDisabled: boolean = false
  @Prop wifiDisabled: boolean = false
  @Prop hdcDisabled: boolean = false
  @Prop networkDisabled: boolean = false
  @Prop printerDisabled: boolean = false
  @Prop microphoneDisabled: boolean = false
  @Prop cameraDisabled: boolean = false
  @Prop usbStoragePolicyIndex: number = 0
  @Prop interfaceControlProcessingKey: string = ''
  @Prop usbStorageControlKey: string = ''
  @Prop interfaceControlSyncToken: number = 0
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT
  @Prop hoveredPanelIndex: number = -1
  onInterfaceToggle?: (feature: string, disallow: boolean) => void
  onUsbStoragePolicyChange?: (index: number) => void
  onPanelHover?: (isHover: boolean) => void

  build() {
    Scroll() {
      Column({ space: 0 }) {
        Column() {
          this.interfaceControlItem(
            'USB 接口',
            '启用或禁用 USB 接口。禁用后，USB 接口相关外设将无法接入。',
            ['启用', '禁用'],
            this.usbDisabled ? 1 : 0,
            this.isInterfaceControlProcessing(this.getInterfaceControlKey(PeripheralService.FEATURE_USB)),
            () => {
              if (this.onInterfaceToggle) {
                this.onInterfaceToggle(PeripheralService.FEATURE_USB, true)
              }
            },
            () => {
              if (this.onInterfaceToggle) {
                this.onInterfaceToggle(PeripheralService.FEATURE_USB, false)
              }
            }
          )

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          this.interfaceControlItem(
            'USB 存储设备',
            '设置 USB 存储设备的访问权限，可选只读、读写或禁止访问。',
            ['只读', '读写', '禁止访问'],
            this.usbStoragePolicyIndex,
            this.isInterfaceControlProcessing(this.usbStorageControlKey),
            (index: number) => {
              if (this.onUsbStoragePolicyChange) {
                this.onUsbStoragePolicyChange(index)
              }
            }
          )

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          this.interfaceControlItem(
            '蓝牙',
            '启用或禁用蓝牙接口。',
            ['启用', '禁用'],
            this.btDisabled ? 1 : 0,
            this.isInterfaceControlProcessing(this.getInterfaceControlKey(PeripheralService.FEATURE_BLUETOOTH)),
            () => {
              if (this.onInterfaceToggle) {
                this.onInterfaceToggle(PeripheralService.FEATURE_BLUETOOTH, true)
              }
            },
            () => {
              if (this.onInterfaceToggle) {
                this.onInterfaceToggle(PeripheralService.FEATURE_BLUETOOTH, false)
              }
            }
          )

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          this.interfaceControlItem(
            'Wi-Fi',
            '启用或禁用 Wi-Fi 接口。',
            ['启用', '禁用'],
            this.wifiDisabled ? 1 : 0,
            this.isInterfaceControlProcessing(this.getInterfaceControlKey(PeripheralService.FEATURE_WIFI)),
            () => {
              if (this.onInterfaceToggle) {
                this.onInterfaceToggle(PeripheralService.FEATURE_WIFI, true)
              }
            },
            () => {
              if (this.onInterfaceToggle) {
                this.onInterfaceToggle(PeripheralService.FEATURE_WIFI, false)
              }
            }
          )

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          this.interfaceControlItem(
            'HDC 调试',
            '启用或禁用 HDC 调试接口。',
            ['启用', '禁用'],
            this.hdcDisabled ? 1 : 0,
            this.isInterfaceControlProcessing(this.getInterfaceControlKey(PeripheralService.FEATURE_HDC)),
            () => {
              if (this.onInterfaceToggle) {
                this.onInterfaceToggle(PeripheralService.FEATURE_HDC, true)
              }
            },
            () => {
              if (this.onInterfaceToggle) {
                this.onInterfaceToggle(PeripheralService.FEATURE_HDC, false)
              }
            }
          )

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          this.interfaceControlItem(
            '网络共享',
            '启用或禁用网络共享接口。',
            ['启用', '禁用'],
            this.networkDisabled ? 1 : 0,
            this.isInterfaceControlProcessing(this.getInterfaceControlKey(PeripheralService.FEATURE_NETWORK)),
            () => {
              if (this.onInterfaceToggle) {
                this.onInterfaceToggle(PeripheralService.FEATURE_NETWORK, true)
              }
            },
            () => {
              if (this.onInterfaceToggle) {
                this.onInterfaceToggle(PeripheralService.FEATURE_NETWORK, false)
              }
            }
          )

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          this.interfaceControlItem(
            '打印机',
            '启用或禁用打印机接口。',
            ['启用', '禁用'],
            this.printerDisabled ? 1 : 0,
            this.isInterfaceControlProcessing(this.getInterfaceControlKey(PeripheralService.FEATURE_PRINTER)),
            () => {
              if (this.onInterfaceToggle) {
                this.onInterfaceToggle(PeripheralService.FEATURE_PRINTER, true)
              }
            },
            () => {
              if (this.onInterfaceToggle) {
                this.onInterfaceToggle(PeripheralService.FEATURE_PRINTER, false)
              }
            }
          )

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          this.interfaceControlItem(
            '麦克风',
            '启用或禁用麦克风接口。',
            ['启用', '禁用'],
            this.microphoneDisabled ? 1 : 0,
            this.isInterfaceControlProcessing(this.getInterfaceControlKey(PeripheralService.FEATURE_MICROPHONE)),
            () => {
              if (this.onInterfaceToggle) {
                this.onInterfaceToggle(PeripheralService.FEATURE_MICROPHONE, true)
              }
            },
            () => {
              if (this.onInterfaceToggle) {
                this.onInterfaceToggle(PeripheralService.FEATURE_MICROPHONE, false)
              }
            }
          )

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          this.interfaceControlItem(
            '摄像头',
            '启用或禁用摄像头接口。',
            ['启用', '禁用'],
            this.cameraDisabled ? 1 : 0,
            this.isInterfaceControlProcessing(this.getInterfaceControlKey(PeripheralService.FEATURE_CAMERA)),
            () => {
              if (this.onInterfaceToggle) {
                this.onInterfaceToggle(PeripheralService.FEATURE_CAMERA, true)
              }
            },
            () => {
              if (this.onInterfaceToggle) {
                this.onInterfaceToggle(PeripheralService.FEATURE_CAMERA, false)
              }
            }
          )
        }
        .borderRadius(AppStyles.RADIUS_LG)
        .clip(true)
        .border({
          width: 1,
          color: AppColors.getColors(this.currentTheme).BORDER
        })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 1, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 1, 4) })
        .onHover((isHover: boolean) => {
          if (this.onPanelHover) {
            this.onPanelHover(isHover)
          }
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
  }

  @Builder
  private interfaceControlItem(
    label: string,
    description: string,
    options: string[],
    selectedIndex: number,
    isProcessing: boolean,
    onSelect: (index: number) => void
  ) {
    InterfaceControlItem({
      label: label,
      description: description,
      options: options,
      selectedIndex: selectedIndex,
      isProcessing: isProcessing,
      syncToken: 0,
      onSelect: onSelect
    })
  }

  @Builder
  private interfaceControlItemWithToggle(
    label: string,
    description: string,
    options: string[],
    selectedIndex: number,
    isProcessing: boolean,
    onEnable: () => void,
    onDisable: () => void
  ) {
    InterfaceControlItem({
      label: label,
      description: description,
      options: options,
      selectedIndex: selectedIndex,
      isProcessing: isProcessing,
      syncToken: 0,
      onSelect: (index: number) => {
        if (index === 1) {
          onDisable()
        } else {
          onEnable()
        }
      }
    })
  }

  private getInterfaceControlKey(feature: string): string {
    return feature
  }

  private isInterfaceControlProcessing(controlKey: string): boolean {
    return this.interfaceControlProcessingKey === controlKey
  }
}
