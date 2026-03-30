import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { BaseCard } from './BaseCard'

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
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onPress: () => void = () => {}

  build() {
    BaseCard({
      cardHeight: 92,
      clickable: this.clickable,
      hoverable: this.hoverable,
      disabled: this.disabled,
      onPress: this.onPress
    }) {
      Row({ space: 12 }) {
        Column() {
          Image(this.icon)
            .width(18)
            .height(18)
            .fillColor(Color.White)
            .draggable(false)
        }
        .width(36)
        .height(36)
        .borderRadius(12)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .linearGradient({
          angle: 135,
          colors: [
            [this.accentStart, 0],
            [this.accentEnd, 1]
          ]
        })

        Column({ space: 4 }) {
          Text(this.title)
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

          Text(this.valueText)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

          if (this.description.length > 0) {
            Text(this.description)
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .alignItems(VerticalAlign.Center)
    }
  }
}
