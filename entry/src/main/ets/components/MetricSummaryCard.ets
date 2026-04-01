import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { BaseCard } from './BaseCard'
import { HoverUtils } from '../utils/HoverUtils'

@Component
export struct MetricSummaryCard {
  @Prop title: string = ''
  @Prop primaryText: string = ''
  @Prop secondaryText: string = ''
  @Prop icon: Resource = $r('app.media.shield')
  @Prop accentStart: string = AppColors.BRAND_PRIMARY
  @Prop accentEnd: string = AppColors.GRADIENT_FIREWALL_END
  @Prop cardHeight: number = 108
  @Prop horizontalSpace: number = 16
  @Prop textSpace: number = 6
  @Prop paddingHorizontal: number = 18
  @Prop paddingVertical: number = 18
  @Prop iconTileSize: number = 60
  @Prop iconTileRadius: number = 20
  @Prop iconSize: number = 28
  @Prop iconHoverScale: number = 1.06
  @Prop titleFontSize: number = AppStyles.FONT_SIZE_BODY
  @Prop primaryFontSize: number = 24
  @Prop secondaryMaxLines: number = 3
  @Prop contentHoverable: boolean = true
  @Prop clickable: boolean = true
  @Prop hoverable: boolean = true
  @Prop disabled: boolean = false
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onPress: () => void = () => {}
  @State isHovered: boolean = false

  build() {
    BaseCard({
      cardHeight: this.cardHeight,
      clickable: this.clickable,
      hoverable: this.hoverable,
      disabled: this.disabled,
      onPress: this.onPress,
      onHoverChange: (isHovered: boolean) => {
        this.isHovered = isHovered
      }
    }) {
      Row({ space: this.horizontalSpace }) {
        Column() {
          Image(this.icon)
            .width(this.contentHoverable && this.isHovered ? this.iconSize + 1 : this.iconSize)
            .height(this.contentHoverable && this.isHovered ? this.iconSize + 1 : this.iconSize)
            .fillColor(Color.White)
            .draggable(false)
        }
        .width(this.iconTileSize)
        .height(this.iconTileSize)
        .borderRadius(this.iconTileRadius)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .scale({
          x: HoverUtils.getScale(this.contentHoverable && this.isHovered, this.iconHoverScale),
          y: HoverUtils.getScale(this.contentHoverable && this.isHovered, this.iconHoverScale)
        })
        .linearGradient({
          angle: 135,
          colors: [
            [this.accentStart, 0],
            [this.accentEnd, 1]
          ]
        })

        Column({ space: this.textSpace }) {
          Row() {
            Text(this.title)
              .fontSize(this.titleFontSize)
              .fontWeight(this.contentHoverable && this.isHovered ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(this.contentHoverable && this.isHovered ? 1 : AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

            Blank()

            if (this.clickable && !this.disabled) {
              Image($r('app.media.chevron_right'))
                .width(16)
                .height(16)
                .fillColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text(this.primaryText)
            .fontSize(this.primaryFontSize)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(this.contentHoverable && this.isHovered ? 1 : AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.secondaryText)
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(this.contentHoverable && this.isHovered ? AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY :
              AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
            .maxLines(this.secondaryMaxLines)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .padding({
        left: this.paddingHorizontal,
        right: this.paddingHorizontal,
        top: this.paddingVertical,
        bottom: this.paddingVertical
      })
      .alignItems(VerticalAlign.Center)
    }
  }
}
