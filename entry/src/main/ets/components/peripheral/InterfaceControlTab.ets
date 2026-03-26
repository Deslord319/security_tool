import { SymbolGlyphModifier, TextModifier } from '@kit.ArkUI'
import { AppColors, AppStyles } from '../../constants/AppConstants'
import { PeripheralService } from '../../services/PeripheralService'
import { ThemeMode } from '../../theme/ThemeColors'
import { HoverUtils } from '../../utils/HoverUtils'
import { FormControlUtils } from '../../utils/FormControlUtils'

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
          this.toggleItem(
            'USB 接口',
            '启用或禁用 USB 接口。禁用后，USB 接口相关外设将无法接入。',
            PeripheralService.FEATURE_USB,
            this.usbDisabled
          )
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
          this.toggleItem('打印机', '启用或禁用打印机接口。', PeripheralService.FEATURE_PRINTER, this.printerDisabled)
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
    this.controlRow(
      label,
      description,
      ['启用', '禁用'],
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
    this.controlRow(
      'USB 存储设备',
      '设置 USB 存储设备的访问权限，可选只读、读写或禁止访问。',
      ['只读', '读写', '禁止访问'],
      this.usbStoragePolicyIndex,
      this.interfaceControlProcessingKey === this.usbStorageControlKey,
      (index: number) => this.onUsbStoragePolicyChange && this.onUsbStoragePolicyChange(index)
    )
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
      Text(`${this.interfaceControlSyncToken}`)
        .fontSize(0)
        .width(0)
        .height(0)
        .opacity(0)

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

      Select(options.map((opt: string) => {
        let item: SelectOption = { value: opt }
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
        .opacity(isProcessing ? 0.6 : 1)
        .onSelect((index: number) => onSelect(index))
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .opacity(isProcessing ? 0.8 : 1)
  }
}
