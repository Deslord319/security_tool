import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'

@Component
export struct DirectionCard {
  @Prop label: string = ''
  @Prop count: number = 0
  @Prop gradientStart: string = '#0A84FF'
  @Prop gradientEnd: string = '#00C6FF'
  @Prop iconText: string = ''
  @Prop icon: Resource | undefined = undefined
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @State isHovered: boolean = false

  private getCountLabel(): string {
    return `${this.count} 条`
  }

  build() {
    Row({ space: 12 }) {
      Column() {
        if (this.icon !== undefined) {
          Image(this.icon)
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
        } else {
          Text(this.iconText)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
      }
      .width(36)
      .height(36)
      .borderRadius(10)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .linearGradient({
        angle: 135,
        colors: [
          [this.gradientStart, 0],
          [this.gradientEnd, 1]
        ]
      })
      .scale({ x: this.isHovered ? 1.06 : 1, y: this.isHovered ? 1.06 : 1 })
      .shadow(HoverUtils.getShadow(this.currentTheme, this.isHovered))

      Column({ space: 2 }) {
        Text(this.label)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

        Text(this.getCountLabel())
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(10)
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow(HoverUtils.getShadow(this.currentTheme, this.isHovered, true))
    .translate({ y: HoverUtils.getTranslateY(this.isHovered, 4) })
    .scale({ x: HoverUtils.getScale(this.isHovered), y: HoverUtils.getScale(this.isHovered) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.isHovered = isHover
      })
    })
  }
}
