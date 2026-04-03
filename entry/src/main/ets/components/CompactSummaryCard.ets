import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { MetricSummaryCard } from './MetricSummaryCard'

@ComponentV2
export struct CompactSummaryCard {
  @Param title: string = ''
  @Param valueText: string = ''
  @Param description: string = ''
  @Param icon: Resource = $r('app.media.shield')
  @Param accentStart: string = AppColors.BRAND_PRIMARY
  @Param accentEnd: string = AppColors.GRADIENT_FIREWALL_END
  @Param clickable: boolean = false
  @Param hoverable: boolean = true
  @Param disabled: boolean = false
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onPress: () => void = () => {}

  build() {
    MetricSummaryCard({
      title: this.title,
      primaryText: this.valueText,
      secondaryText: this.description,
      icon: this.icon,
      accentStart: this.accentStart,
      accentEnd: this.accentEnd,
      cardHeight: 92,
      horizontalSpace: 12,
      textSpace: 4,
      paddingHorizontal: 16,
      paddingVertical: 14,
      titleFontSize: AppStyles.FONT_SIZE_SMALL,
      primaryFontSize: AppStyles.FONT_SIZE_BODY,
      secondaryMaxLines: 1,
      iconTileSize: 36,
      iconTileRadius: 12,
      iconSize: 18,
      iconHoverScale: 1.04,
      clickable: this.clickable,
      hoverable: this.hoverable,
      disabled: this.disabled,
      currentTheme: this.currentTheme,
      onPress: this.onPress
    })
  }
}
