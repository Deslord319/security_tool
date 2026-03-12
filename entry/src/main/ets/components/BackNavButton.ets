import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

@Component
export struct BackNavButton {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @State hovered: boolean = false
  onBack: () => void = () => {}

  build() {
    Button() {
      Image($r('app.media.arrow_left'))
        .width(18)
        .height(18)
        .fillColor(AppColors.BRAND_PRIMARY)
    }
    .type(ButtonType.Normal)
    .width(32)
    .height(32)
    .borderRadius(AppStyles.RADIUS_MD)
    .backgroundColor(this.hovered ? AppColors.getColors(this.currentTheme).BG_COMPONENT : Color.Transparent)
    .onHover((isHover: boolean) => {
      this.hovered = isHover
    })
    .onClick(() => {
      this.onBack()
    })
  }
}
