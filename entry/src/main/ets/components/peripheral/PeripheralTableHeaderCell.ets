import { AppColors, AppStyles } from '../../constants/AppConstants'
import { ThemeMode } from '../../theme/ThemeColors'

@Component
export struct PeripheralTableHeaderCell {
  @Prop label: string = ''
  @Prop weight: number = 1
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT
  @Prop textAlign: TextAlign = TextAlign.Center

  build() {
    Text(this.label)
      .fontSize(AppStyles.FONT_SIZE_SMALL)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .layoutWeight(this.weight)
      .textAlign(this.textAlign)
  }
}
