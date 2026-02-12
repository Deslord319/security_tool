import { AppColors, AppStyles } from '../constants/AppConstants'

@CustomDialog
export struct AddBlacklistDialog {
  controller: CustomDialogController
  onConfirm: (baseClass: number, subClass: number, protocol: number, description: string) => void = () => {}

  @State baseClassText: string = ''
  @State subClassText: string = ''
  @State protocolText: string = ''
  @State description: string = ''

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
        Text('添加 USB 设备类型黑名单')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .opacity(AppColors.TEXT_PRIMARY_OPACITY)
          .layoutWeight(1)
        Text('\u00D7')
          .fontSize(20)
          .fontColor(AppColors.TEXT_PRIMARY)
          .opacity(AppColors.TEXT_TERTIARY_OPACITY)
          .onClick(() => {
            this.controller.close()
          })
      }
      .width('100%')

      Column({ space: 6 }) {
        Text('Base Class')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .opacity(AppColors.TEXT_SECONDARY_OPACITY)
        TextInput({ placeholder: '例: 0x08' })
          .height(40)
          .backgroundColor(AppColors.BG_PAGE)
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: AppColors.BORDER, style: BorderStyle.Solid })
          .onChange((value: string) => { this.baseClassText = value })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text('Sub Class')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .opacity(AppColors.TEXT_SECONDARY_OPACITY)
        TextInput({ placeholder: '例: 0x06' })
          .height(40)
          .backgroundColor(AppColors.BG_PAGE)
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: AppColors.BORDER, style: BorderStyle.Solid })
          .onChange((value: string) => { this.subClassText = value })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text('Protocol')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .opacity(AppColors.TEXT_SECONDARY_OPACITY)
        TextInput({ placeholder: '例: 0x50' })
          .height(40)
          .backgroundColor(AppColors.BG_PAGE)
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: AppColors.BORDER, style: BorderStyle.Solid })
          .onChange((value: string) => { this.protocolText = value })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text('描述')
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .opacity(AppColors.TEXT_SECONDARY_OPACITY)
        TextInput({ placeholder: '例: USB 大容量存储设备' })
          .height(40)
          .backgroundColor(AppColors.BG_PAGE)
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: AppColors.BORDER, style: BorderStyle.Solid })
          .onChange((value: string) => { this.description = value })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 16 }) {
        Button('取消')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.TEXT_PRIMARY)
          .opacity(AppColors.TEXT_SECONDARY_OPACITY)
          .backgroundColor(Color.White)
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: AppColors.BORDER, style: BorderStyle.Solid })
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
            let bc = this.parseHex(this.baseClassText)
            let sc = this.parseHex(this.subClassText)
            let pr = this.parseHex(this.protocolText)
            if (!isNaN(bc) && !isNaN(sc) && !isNaN(pr)) {
              this.onConfirm(bc, sc, pr, this.description)
              this.controller.close()
            }
          })
      }
      .width('100%')
    }
    .padding(32)
    .constraintSize({ maxWidth: 600 })
    .width('90%')
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppStyles.RADIUS_XL)
  }
}
