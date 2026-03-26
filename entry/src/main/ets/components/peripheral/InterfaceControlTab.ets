import { AppColors, AppStyles } from '../../constants/AppConstants'
import { PeripheralService } from '../../services/PeripheralService'
import { ThemeMode } from '../../theme/ThemeColors'
import { HoverUtils } from '../../utils/HoverUtils'
import { InterfaceControlItem } from '../InterfaceControlItem'

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
          this.toggleItem('USB 接口', '启用或禁用 USB 接口。', PeripheralService.FEATURE_USB, this.usbDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.storageItem()
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem('蓝牙', '启用或禁用蓝牙接口。', PeripheralService.FEATURE_BLUETOOTH, this.btDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem('Wi-Fi', '启用或禁用 Wi-Fi 接口。', PeripheralService.FEATURE_WIFI, this.wifiDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem('HDC 调试', '启用或禁用 HDC 调试接口。', PeripheralService.FEATURE_HDC, this.hdcDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem('网络共享', '启用或禁用网络共享接口。', PeripheralService.FEATURE_NETWORK, this.networkDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem('打印机', '启用或禁用打印设备接口。', PeripheralService.FEATURE_PRINTER, this.printerDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem('麦克风', '启用或禁用麦克风接口。', PeripheralService.FEATURE_MICROPHONE, this.microphoneDisabled)
          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
          this.toggleItem('摄像头', '启用或禁用摄像头接口。', PeripheralService.FEATURE_CAMERA, this.cameraDisabled)
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
    InterfaceControlItem({
      label: label,
      description: description,
      options: ['启用', '禁用'],
      selectedIndex: disabled ? 1 : 0,
      isProcessing: this.interfaceControlProcessingKey === feature,
      syncToken: this.interfaceControlSyncToken,
      onSelect: (index: number) => {
        if (this.onInterfaceToggle) {
          this.onInterfaceToggle(feature, index === 1)
        }
      }
    })
  }

  @Builder
  private storageItem() {
    InterfaceControlItem({
      label: 'USB 存储设备',
      description: '设置 USB 存储设备访问权限，可选择只读、读写或禁止访问。',
      options: ['只读', '读写', '禁止访问'],
      selectedIndex: this.usbStoragePolicyIndex,
      isProcessing: this.interfaceControlProcessingKey === this.usbStorageControlKey,
      syncToken: this.interfaceControlSyncToken,
      onSelect: (index: number) => this.onUsbStoragePolicyChange && this.onUsbStoragePolicyChange(index)
    })
  }
}
