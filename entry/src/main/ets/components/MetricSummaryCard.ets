import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { BaseCard } from './BaseCard'

@Component
export struct MetricSummaryCard {
  @Prop title: string = ''
  @Prop primaryText: string = ''
  @Prop secondaryText: string = ''
  @Prop icon: Resource = $r('app.media.shield')
  @Prop accentStart: string = AppColors.BRAND_PRIMARY
  @Prop accentEnd: string = AppColors.GRADIENT_FIREWALL_END
  @Prop clickable: boolean = true
  @Prop hoverable: boolean = true
  @Prop disabled: boolean = false
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onPress: () => void = () => {}

  build() {
    BaseCard({
      cardHeight: 144,
      clickable: this.clickable,
      hoverable: this.hoverable,
      disabled: this.disabled,
      onPress: this.onPress
    }) {
      Row({ space: 16 }) {
        Column() {
          Image(this.icon)
            .width(30)
            .height(30)
            .fillColor(Color.White)
            .draggable(false)
        }
        .width(60)
        .height(60)
        .borderRadius(20)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .linearGradient({
          angle: 135,
          colors: [
            [this.accentStart, 0],
            [this.accentEnd, 1]
          ]
        })

        Column({ space: 6 }) {
          Row() {
            Text(this.title)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

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
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.secondaryText)
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 18 })
      .alignItems(VerticalAlign.Center)
    }
  }
}
