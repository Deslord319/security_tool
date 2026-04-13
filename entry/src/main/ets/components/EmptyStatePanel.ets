import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { HoverUtils } from '../utils/HoverUtils'

@ComponentV2
export struct EmptyStatePanel {
  @Param title: string = ''
  @Param radius: number = AppStyles.RADIUS_LG
  @Param horizontalPadding: number = AppStyles.PADDING_LG
  @Param verticalPadding: number = 32
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Local isHovered: boolean = false

  build() {
    Column() {
      Text(this.title)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({
      left: this.horizontalPadding,
      right: this.horizontalPadding,
      top: this.verticalPadding,
      bottom: this.verticalPadding
    })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(this.radius)
    .clip(true)
    .border({
      width: AppStyles.DIVIDER_HEIGHT,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow(HoverUtils.getShadow(this.currentTheme, this.isHovered, true))
    .translate({ y: HoverUtils.getTranslateY(this.isHovered, 4) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(this.getUIContext(), () => {
        this.isHovered = isHover
      })
    })
  }
}
