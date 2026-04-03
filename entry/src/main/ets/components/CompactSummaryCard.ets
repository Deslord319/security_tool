import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { MetricSummaryCard } from './MetricSummaryCard'

export type CompactSummaryCardPreset = 'default' | 'log'

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

  private resolveCardHeight(): number {
    return this.preset === 'log' ? 108 : this.cardHeight
  }

  private resolveHorizontalSpace(): number {
    return this.preset === 'log' ? 16 : this.horizontalSpace
  }

  private resolveTextSpace(): number {
    return this.preset === 'log' ? 6 : this.textSpace
  }

  private resolvePaddingHorizontal(): number {
    return this.preset === 'log' ? 18 : this.paddingHorizontal
  }

  private resolvePaddingVertical(): number {
    return this.preset === 'log' ? 18 : this.paddingVertical
  }

  private resolveTitleFontSize(): number {
    return this.preset === 'log' ? AppStyles.FONT_SIZE_BODY : this.titleFontSize
  }

  private resolvePrimaryFontSize(): number {
    return this.preset === 'log' ? 24 : this.primaryFontSize
  }

  private resolveSecondaryMaxLines(): number {
    return this.preset === 'log' ? 2 : this.secondaryMaxLines
  }

  private resolveIconTileSize(): number {
    return this.preset === 'log' ? 54 : this.iconTileSize
  }

  private resolveIconTileRadius(): number {
    return this.preset === 'log' ? 18 : this.iconTileRadius
  }

  private resolveIconSize(): number {
    return this.preset === 'log' ? 28 : this.iconSize
  }

  private resolveIconHoverScale(): number {
    return this.preset === 'log' ? 1.06 : this.iconHoverScale
  }

  build() {
    MetricSummaryCard({
      title: this.title,
      primaryText: this.valueText,
      secondaryText: this.description,
      icon: this.icon,
      accentStart: this.accentStart,
      accentEnd: this.accentEnd,
      cardHeight: this.resolveCardHeight(),
      horizontalSpace: this.resolveHorizontalSpace(),
      textSpace: this.resolveTextSpace(),
      paddingHorizontal: this.resolvePaddingHorizontal(),
      paddingVertical: this.resolvePaddingVertical(),
      titleFontSize: this.resolveTitleFontSize(),
      primaryFontSize: this.resolvePrimaryFontSize(),
      secondaryMaxLines: this.resolveSecondaryMaxLines(),
      iconTileSize: this.resolveIconTileSize(),
      iconTileRadius: this.resolveIconTileRadius(),
      iconSize: this.resolveIconSize(),
      iconHoverScale: this.resolveIconHoverScale(),
      clickable: this.clickable,
      hoverable: this.hoverable,
      disabled: this.disabled,
      currentTheme: this.currentTheme,
      onPress: this.onPress
    })
  }
}
