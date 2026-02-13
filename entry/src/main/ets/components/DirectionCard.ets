import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

@Component
export struct DirectionCard {
  @Prop label: string = ''
  @Prop count: number = 0
  @Prop gradientStart: string = '#0A84FF'
  @Prop gradientEnd: string = '#00C6FF'
  @Prop iconText: string = ''
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Row({ space: 16 }) {
      // 渐变图标
      Column() {
        Text(this.iconText)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(48)
      .height(48)
      .borderRadius(AppStyles.RADIUS_LG)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .linearGradient({
        angle: 135,
        colors: [
          [this.gradientStart, 0],
          [this.gradientEnd, 1]
        ]
      })

      // 文字
      Column({ space: 4 }) {
        Text(this.label)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        Text(`${this.count} 条规则`)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .shadow({
      radius: 4,
      color: this.currentTheme === ThemeMode.DARK ? 'rgba(0,0,0,0.3)' : 'rgba(0,0,0,0.06)',
      offsetX: 0,
      offsetY: 2
    })
  }
}
