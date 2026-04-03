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
  @Param cardHeight: number = 92
  @Param horizontalSpace: number = 12
  @Param textSpace: number = 4
  @Param paddingHorizontal: number = 16
  @Param paddingVertical: number = 14
  @Param titleFontSize: number = AppStyles.FONT_SIZE_SMALL
  @Param primaryFontSize: number = AppStyles.FONT_SIZE_BODY
  @Param secondaryMaxLines: number = 1
  @Param iconTileSize: number = 36
  @Param iconTileRadius: number = 12
  @Param iconSize: number = 18
  @Param iconHoverScale: number = 1.04
  @Event onPress: () => void = () => {}

  build() {
    MetricSummaryCard({
      title: this.title,
      primaryText: this.valueText,
      secondaryText: this.description,
      icon: this.icon,
      accentStart: this.accentStart,
      accentEnd: this.accentEnd,
      cardHeight: this.cardHeight,
      horizontalSpace: this.horizontalSpace,
      textSpace: this.textSpace,
      paddingHorizontal: this.paddingHorizontal,
      paddingVertical: this.paddingVertical,
      titleFontSize: this.titleFontSize,
      primaryFontSize: this.primaryFontSize,
      secondaryMaxLines: this.secondaryMaxLines,
      iconTileSize: this.iconTileSize,
      iconTileRadius: this.iconTileRadius,
      iconSize: this.iconSize,
      iconHoverScale: this.iconHoverScale,
      clickable: this.clickable,
      hoverable: this.hoverable,
      disabled: this.disabled,
      currentTheme: this.currentTheme,
      onPress: this.onPress
    })
  }
}
