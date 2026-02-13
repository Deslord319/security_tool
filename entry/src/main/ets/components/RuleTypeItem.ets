import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

@Component
export struct RuleTypeItem {
  @Prop label: string = ''
  @Prop description: string = ''
  @Prop count: number = 0
  @Prop iconColor: string = '#0A84FF'
  @Prop iconText: string = ''
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onPress: () => void = () => {}

  build() {
    Row() {
      // 左侧图标
      Column() {
        Text(this.iconText)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.iconColor)
      }
      .width(40)
      .height(40)
      .borderRadius(AppStyles.RADIUS_MD)
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // 文字内容
      Column({ space: 2 }) {
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
      .margin({ left: 12 })

      // 数量徽章
      if (this.count > 0) {
        Text(`${this.count}`)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.BRAND_PRIMARY)
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
          .borderRadius(10)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      }

      // 箭头
      Text('>')
        .fontSize(16)
        .fontColor(this.currentTheme === ThemeMode.DARK ? '#555555' : '#C7C7CC')
        .margin({ left: 8 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .onClick(() => {
      this.onPress()
    })
  }
}
