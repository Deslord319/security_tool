import { AppColors, AppStyles } from '../constants/AppConstants'
import { MetricSummaryCard } from './MetricSummaryCard'

@Component
export struct CompactSummaryCard {
  @Prop title: string = ''
  @Prop valueText: string = ''
  @Prop description: string = ''
  @Prop icon: Resource = $r('app.media.shield')
  @Prop accentStart: string = AppColors.BRAND_PRIMARY
  @Prop accentEnd: string = AppColors.GRADIENT_FIREWALL_END
  @Prop clickable: boolean = false
  @Prop hoverable: boolean = true
  @Prop disabled: boolean = false
  onPress: () => void = () => {}

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
      onPress: this.onPress
    })
  }
}
