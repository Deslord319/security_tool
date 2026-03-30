import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'

@Component
export struct BaseSummaryCard {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @Prop clickable: boolean = true
  @Prop disabled: boolean = false
  onPress: () => void = () => {}
  @BuilderParam content: () => void = this.defaultContent
  @State isHovered: boolean = false

  @Builder
  private defaultContent() {}

  private canInteract(): boolean {
    return this.clickable && !this.disabled
  }

  private setHoverState(isHovered: boolean): void {
    if (!this.canInteract()) {
      if (this.isHovered) {
        this.isHovered = false
      }
      return
    }
    HoverUtils.animate(() => {
      this.isHovered = isHovered
    })
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 24,
          colors: [
            [this.isHovered ? 'rgba(255,255,255,0.10)' : 'rgba(255,255,255,0.03)', 0],
            ['rgba(255,255,255,0.00)', 1]
          ]
        })

      Column() {
        this.content()
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow(HoverUtils.getShadow(this.currentTheme, this.isHovered, true))
    .translate({ y: HoverUtils.getTranslateY(this.isHovered, 4) })
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
