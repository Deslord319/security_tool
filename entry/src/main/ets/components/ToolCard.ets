import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

@Component
export struct ToolCard {
  @Prop label: string = ''
  @Prop iconText: string = ''
  @Prop gradientStart: string = '#0A84FF'
  @Prop gradientEnd: string = '#00C6FF'
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onPress: () => void = () => {}

  build() {
    Column({ space: 12 }) {
      // 圆形渐变图标
      Column() {
        Text(this.iconText)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(52)
      .height(52)
      .borderRadius(26)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .linearGradient({
        angle: 135,
        colors: [
          [this.gradientStart, 0],
          [this.gradientEnd, 1]
        ]
      })

      Text(this.label)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .maxLines(1)
    }
    .width('100%')
    .padding({ top: 20, bottom: 20, left: 16, right: 16 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .alignItems(HorizontalAlign.Center)
    .shadow({
      radius: 4,
      color: this.currentTheme === ThemeMode.DARK ? 'rgba(0,0,0,0.3)' : 'rgba(0,0,0,0.06)',
      offsetX: 0,
      offsetY: 2
    })
    .onClick(() => {
      this.onPress()
    })
  }
}
