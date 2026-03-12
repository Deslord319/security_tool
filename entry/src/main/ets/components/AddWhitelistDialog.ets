import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { FormControlUtils } from '../utils/FormControlUtils'

@CustomDialog
export struct AddWhitelistDialog {
  controller: CustomDialogController
  @State mode: string = 'usb' // 'usb' | 'bluetooth'
  onConfirmUsb: (vendorId: number, productId: number, remark: string) => void = () => {}
  onConfirmBluetooth: (mac: string, remark: string) => void = () => {}

  // USB 模式字段
  @State vendorIdText: string = ''
  @State productIdText: string = ''

  // 蓝牙模式字段
  @State macAddress: string = ''

  // 公共字段
  @State remark: string = ''
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  parseHex(text: string): number {
    let trimmed = text.trim()
    if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
      return parseInt(trimmed.substring(2), 16)
    }
    return parseInt(trimmed, 16)
  }

  build() {
    Column({ space: 16 }) {
      // 标题 + 关闭按钮
      Row() {
        Text(this.mode === 'usb' ? '添加 USB 设备白名单' : '添加蓝牙设备白名单')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .layoutWeight(1)
        Text('\u00D7')
          .fontSize(20)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .onClick(() => {
            this.controller.close()
          })
      }
      .width('100%')

      if (this.mode === 'usb') {
        Column({ space: 6 }) {
          Text('Vendor ID')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          TextInput({ placeholder: '例: 0x2B7E' })
          .height(40)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onChange((value: string) => { this.vendorIdText = value })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 6 }) {
          Text('Product ID')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          TextInput({ placeholder: '例: 0xB5A2' })
          .height(40)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onChange((value: string) => { this.productIdText = value })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      } else {
        Column({ space: 6 }) {
          Text('MAC 地址')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          TextInput({ placeholder: '例: AA:BB:CC:DD:EE:01' })
          .height(40)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onChange((value: string) => { this.macAddress = value })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      Column({ space: 6 }) {
        Text('备注')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        TextInput({ placeholder: '设备备注信息' })
        .height(40)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onChange((value: string) => { this.remark = value })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 16 }) {
        Button('取消')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER, style: BorderStyle.Solid })
          .layoutWeight(1)
          .height(40)
          .onClick(() => {
            this.controller.close()
          })
        Button('添加')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(Color.White)
          .backgroundColor(AppColors.BRAND_PRIMARY)
          .borderRadius(AppStyles.RADIUS_MD)
          .layoutWeight(1)
          .height(40)
          .onClick(() => {
            if (this.mode === 'usb') {
              let vid = this.parseHex(this.vendorIdText)
              let pid = this.parseHex(this.productIdText)
              if (!isNaN(vid) && !isNaN(pid)) {
                this.onConfirmUsb(vid, pid, this.remark)
                this.controller.close()
              }
            } else {
              if (this.macAddress.trim().length > 0) {
                this.onConfirmBluetooth(this.macAddress.trim(), this.remark)
                this.controller.close()
              }
            }
          })
      }
      .width('100%')
    }
    .padding(32)
    .constraintSize({ maxWidth: 600 })
    .width('90%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_XL)
  }
}
