import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { BaseCard } from './BaseCard'
import { HoverUtils } from '../utils/HoverUtils'

@ComponentV2
export struct ToolCard {
  @Param label: string = ''
  @Param icon: Resource = $r('app.media.shield')
  @Param gradientStart: string = AppColors.BRAND_PRIMARY
  @Param gradientEnd: string = AppColors.GRADIENT_FIREWALL_END
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onPress: () => void = () => {}
  @Local isHovered: boolean = false

  private setHoverState(isHovered: boolean): void {
    HoverUtils.animate(() => {
      this.isHovered = isHovered
    })
  }

  build() {
    BaseCard({
      cardHeight: 132,
      clickable: true,
      hoverable: true,
      overlayAngle: 180,
      currentTheme: this.currentTheme,
      onPress: this.onPress,
      onHoverChange: (isHovered: boolean) => {
        this.setHoverState(isHovered)
      }
    }) {
      Column({ space: 12 }) {
        Column() {
          Image(this.icon)
            .width(28)
            .height(28)
            .fillColor(Color.White)
            .draggable(false)
        }
        .width(56)
        .height(56)
        .borderRadius(28)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .scale({
          x: HoverUtils.getScale(this.isHovered, 1.06),
          y: HoverUtils.getScale(this.isHovered, 1.06)
        })
        .linearGradient({
          angle: 135,
          colors: [
            [this.gradientStart, 0],
            [this.gradientEnd, 1]
          ]
        })

        Text(this.label)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(this.isHovered ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(this.isHovered ? 1 : AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .maxLines(1)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height('100%')
      .padding({ top: 20, bottom: 20, left: 16, right: 16 })
      .alignItems(HorizontalAlign.Center)
    }
  }
}
