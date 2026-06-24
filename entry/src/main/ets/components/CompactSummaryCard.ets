import { AppColors, AppStyles } from '../constants/AppConstants'
import { AppResources } from '../constants/AppResources'
import { ThemeMode } from '../theme/ThemeColors'
import { MetricSummaryCard } from './MetricSummaryCard'

type CompactSummaryCardPreset = 'default' | 'log'

@ComponentV2
export struct CompactSummaryCard {
  @Param title: string = ''
  @Param valueText: string = ''
  @Param description: string = ''
  @Param icon: Resource = AppResources.SHIELD_ICON
  @Param accentStart: string = AppColors.BRAND_PRIMARY
  @Param accentEnd: string = AppColors.GRADIENT_FIREWALL_END
  @Param clickable: boolean = false
  @Param hoverable: boolean = true
  @Param disabled: boolean = false
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param preset: CompactSummaryCardPreset = 'default'
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

  private resolveNumberForPreset(logValue: number, defaultValue: number): number {
    return this.preset === 'log' ? logValue : defaultValue
  }

  build() {
    MetricSummaryCard({
      title: this.title,
      primaryText: this.valueText,
      secondaryText: this.description,
      icon: this.icon,
      accentStart: this.accentStart,
      accentEnd: this.accentEnd,
      cardHeight: this.resolveNumberForPreset(108, this.cardHeight),
      horizontalSpace: this.resolveNumberForPreset(16, this.horizontalSpace),
      textSpace: this.resolveNumberForPreset(6, this.textSpace),
      paddingHorizontal: this.resolveNumberForPreset(18, this.paddingHorizontal),
      paddingVertical: this.resolveNumberForPreset(18, this.paddingVertical),
      titleFontSize: this.resolveNumberForPreset(AppStyles.FONT_SIZE_BODY, this.titleFontSize),
      primaryFontSize: this.resolveNumberForPreset(24, this.primaryFontSize),
      secondaryMaxLines: this.resolveNumberForPreset(2, this.secondaryMaxLines),
      iconTileSize: this.resolveNumberForPreset(54, this.iconTileSize),
      iconTileRadius: this.resolveNumberForPreset(18, this.iconTileRadius),
      iconSize: this.resolveNumberForPreset(28, this.iconSize),
      iconHoverScale: this.resolveNumberForPreset(1.06, this.iconHoverScale),
      clickable: this.clickable,
      hoverable: this.hoverable,
      disabled: this.disabled,
      currentTheme: this.currentTheme,
      onPress: this.onPress
    })
  }
}
