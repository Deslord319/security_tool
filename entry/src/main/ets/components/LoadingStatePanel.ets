import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'

@ComponentV2
export struct LoadingStatePanel {
  @Param message: string = ''
  @Param indicatorSize: number = AppStyles.LOADING_INDICATOR_SIZE
  @Param spacing: number = 10
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Column({ space: this.spacing }) {
      LoadingProgress()
        .width(this.indicatorSize)
        .height(this.indicatorSize)

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
