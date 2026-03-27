import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

@Component
export struct BackNavButton {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @State hovered: boolean = false
  onBack: () => void = () => {}

  private getIconColor(): string {
    return AppColors.getColors(this.currentTheme).TEXT_PRIMARY
  }

  private getButtonBackground(): string {
    /*return this.currentTheme === ThemeMode.DARK ? 'rgba(255,255,255,0.08)' : 'rgba(10,132,255,0.08)'*/
    return Color.Transparent.toString();
  }

  private getButtonHoverBackground(): string {
/*    return this.currentTheme === ThemeMode.DARK ? 'rgba(255,255,255,0.14)' : 'rgba(10,132,255,0.14)';*/
    return Color.Transparent.toString()
  }

  build() {
    Button() {
      Image($r('app.media.arrow_left'))
        .width(22)
        .height(22)
        .fillColor(this.getIconColor())
        .draggable(false)
    }
    .type(ButtonType.Normal)
    .width(36)
    .height(36)
    .borderRadius(AppStyles.RADIUS_MD)
    .backgroundColor(this.hovered ? this.getButtonHoverBackground() : this.getButtonBackground())
    .onHover((isHover: boolean) => {
      this.hovered = isHover
    })
    .onClick(() => {
      this.onBack()
    })
  }
}
