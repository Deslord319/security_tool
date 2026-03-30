import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'

@Component
export struct BaseCard {
  @Prop cardHeight: number = 132
  @Prop clickable: boolean = false
  @Prop hoverable: boolean = true
  @Prop disabled: boolean = false
  @Prop overlayAngle: number = 24
  @Prop hoverLift: number = 4
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @BuilderParam content: () => void
  onPress: () => void = () => {}
  onHoverChange: (isHovered: boolean) => void = () => {}
  @State isHovered: boolean = false

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
    HoverUtils.animate(() => {
      this.isHovered = isHovered
    })
    this.onHoverChange(isHovered)
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
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
    .height(this.cardHeight)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow(HoverUtils.getShadow(this.currentTheme, this.isHovered, true))
    .translate({ y: HoverUtils.getTranslateY(this.isHovered, this.hoverLift) })
    .scale({
      x: HoverUtils.getScale(this.isHovered),
      y: HoverUtils.getScale(this.isHovered)
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
