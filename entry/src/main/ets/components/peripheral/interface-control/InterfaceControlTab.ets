import { SymbolGlyphModifier, TextModifier } from '@kit.ArkUI'
import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { DeviceTypeLabels } from '../../../constants/modules/DialogStrings'
import { PeripheralStrings } from '../../../constants/modules/PeripheralStrings'
import { PeripheralService } from '../../../services/peripheral/interface-control/PeripheralService'
import { ThemeMode } from '../../../theme/ThemeColors'
import { HoverUtils } from '../../../utils/HoverUtils'
import { FormControlUtils } from '../../../utils/FormControlUtils'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'InterfaceControlTab'

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
    InterfaceControlAsyncSelectRow({
      label: DeviceTypeLabels.USB_STORAGE,
      description: PeripheralStrings.usbStorageDescription,
      options: PeripheralStrings.usbStorageOptions,
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

  @Builder
  private controlRow(
    label: string,
    description: string,
    options: string[],
    selectedIndex: number,
    isProcessing: boolean,
    onSelect?: (index: number) => void,
    onSelectAsync?: (index: number) => Promise<boolean>
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
          .onSelect((index: number) => {
            if (onSelectAsync) {
              void onSelectAsync(index)
              return
            }
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

@ComponentV2
struct InterfaceControlAsyncSelectRow {
  @Param label: string = ''
  @Param description: string = ''
  @Param options: string[] = []
  @Param selectedIndex: number = 0
  @Param processing: boolean = false
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param onSelectAsync: ((nextIndex: number) => Promise<boolean>) | undefined = undefined
  @Local private displayIndex: number = 0
  @Local private isAsyncPending: boolean = false
  @Local private successAwaitingParent: boolean = false
  @Local private successDisplayIndex: number = 0
  @Local private rollbackIndex: number = 0

  aboutToAppear(): void {
    this.displayIndex = this.selectedIndex
    this.successDisplayIndex = this.selectedIndex
    this.rollbackIndex = this.selectedIndex
  }

  private getEffectiveSelectedIndex(): number {
    if (this.isAsyncPending) {
      return this.displayIndex
    }
    if (this.successAwaitingParent && this.selectedIndex === this.rollbackIndex) {
      return this.successDisplayIndex
    }
    return this.selectedIndex
  }

  private getDisplayValue(): string {
    const effectiveIndex = this.getEffectiveSelectedIndex()
    return this.options[effectiveIndex] ?? ''
  }

  private async handleSelectChange(nextIndex: number): Promise<void> {
    const previousIndex = this.getEffectiveSelectedIndex()
    if (nextIndex === previousIndex || !this.onSelectAsync) {
      return
    }

    this.rollbackIndex = previousIndex
    this.displayIndex = nextIndex
    this.successAwaitingParent = false
    this.isAsyncPending = true
    LogUtils.info(TAG, `usb storage async start: previousIndex=${previousIndex}, nextIndex=${nextIndex}`)

    let success = false
    try {
      success = await this.onSelectAsync(nextIndex)
    } catch (err) {
      LogUtils.error(TAG, `usb storage async exception: ${JSON.stringify(err)}`)
    } finally {
      this.isAsyncPending = false
      if (success) {
        this.successDisplayIndex = nextIndex
        this.successAwaitingParent = true
        LogUtils.info(TAG, `usb storage async success: nextIndex=${nextIndex}`)
        return
      }
      this.displayIndex = previousIndex
      this.successDisplayIndex = previousIndex
      this.successAwaitingParent = false
      LogUtils.warn(TAG, `usb storage async rollback: rollbackIndex=${previousIndex}, failedIndex=${nextIndex}`)
    }
  }

  build() {
    Row() {
      Column({ space: 4 }) {
        Text(this.label)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        Text(this.description)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: 10 }) {
        if (this.processing || this.isAsyncPending) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        }

        Select(this.options.map((value: string) => {
          const item: SelectOption = { value: value }
          return item
        }))
          .selected(this.getEffectiveSelectedIndex())
          .value(this.getDisplayValue())
          .fontColor(FormControlUtils.text(this.currentTheme))
          .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
          .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .enabled(!(this.processing || this.isAsyncPending))
          .opacity(this.processing || this.isAsyncPending ? 0.72 : 1)
          .onSelect((index: number) => {
            void this.handleSelectChange(index)
          })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .opacity(this.processing || this.isAsyncPending ? 0.8 : 1)
  }
}
