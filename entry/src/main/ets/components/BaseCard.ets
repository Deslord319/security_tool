import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { HoverUtils } from '../utils/HoverUtils'

@ComponentV2
export struct BaseCard {
  @Param cardHeight: number = 132
  @Param useAutoHeight: boolean = false
  @Param clickable: boolean = false
  @Param hoverable: boolean = true
  @Param disabled: boolean = false
  @Param overlayAngle: number = 24
  @Param hoverLift: number = 4
  @Param hoverScale: number = 1.01
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @BuilderParam content: () => void
  @Event onPress: () => void = () => {}
  @Event onHoverChange: (isHovered: boolean) => void = () => {}
  @Local isHovered: boolean = false

  private canInteract(): boolean {
    return this.clickable && !this.disabled
  }

  private canHover(): boolean {
    return this.hoverable && !this.disabled
  }

  private setHoverState(isHovered: boolean): void {
    if (!this.canHover()) {
      if (this.isHovered) {
        this.isHovered = false
        this.onHoverChange(false)
      }
      return
    }
    HoverUtils.animate(this.getUIContext(), () => {
      this.isHovered = isHovered
    })
    this.onHoverChange(isHovered)
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height(this.useAutoHeight ? 'auto' : '100%')
        .linearGradient({
          angle: this.overlayAngle,
          colors: [
            [this.isHovered ? 'rgba(255,255,255,0.10)' : 'rgba(255,255,255,0.03)', 0],
            ['rgba(255,255,255,0.00)', 1]
          ]
        })

      this.content()
    }
    .width('100%')
    .height(this.useAutoHeight ? 'auto' : this.cardHeight)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow(HoverUtils.getShadow(this.currentTheme, this.isHovered, true))
    .translate({ y: HoverUtils.getTranslateY(this.isHovered, this.hoverLift) })
    .scale({
      x: HoverUtils.getScale(this.isHovered, this.hoverScale),
      y: HoverUtils.getScale(this.isHovered, this.hoverScale)
    })
    .opacity(this.disabled ? 0.6 : 1)
    .clip(true)
    .onHover((isHover: boolean) => {
      this.setHoverState(isHover)
    })
    .onClick(() => {
      if (this.canInteract()) {
        this.onPress()
      }
    })
  }
}
