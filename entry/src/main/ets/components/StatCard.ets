import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'

@Component
export struct StatCard {
  @Prop label: string = ''
  @Prop value: string = ''
  @Prop gradientStart: string = '#0A84FF'
  @Prop gradientEnd: string = '#00C6FF'
  @Prop icon: Resource = $r('app.media.shield')
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @State isHovered: boolean = false

  private setHoverState(isHovered: boolean): void {
    HoverUtils.animate(() => {
      this.isHovered = isHovered
    })
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 18,
          colors: [
            [this.isHovered ? 'rgba(255,255,255,0.08)' : 'rgba(255,255,255,0.02)', 0],
            ['rgba(255,255,255,0.00)', 1]
          ]
        })
        .opacity(this.isHovered ? 0.9 : 0.55)

      Row({ space: 16 }) {
        Column() {
          Image(this.icon)
            .width(24)
            .height(24)
            .fillColor(Color.White)
            .draggable(false)
        }
        .width(52)
        .height(52)
        .borderRadius(AppStyles.RADIUS_LG)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .scale({
          x: HoverUtils.getScale(this.isHovered, 1.06),
          y: HoverUtils.getScale(this.isHovered, 1.06)
        })
        .linearGradient({
          angle: 135,
          colors: [
            [this.gradientStart, 0],
            [this.gradientEnd, 1]
          ]
        })

        Column({ space: 4 }) {
          Text(this.value)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.label)
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(this.isHovered ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(this.isHovered ? 1 : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .padding(20)
    }
    .width('100%')
    .height(92)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow(HoverUtils.getShadow(this.currentTheme, this.isHovered))
    .translate({ y: HoverUtils.getTranslateY(this.isHovered, 4) })
    .scale({
      x: HoverUtils.getScale(this.isHovered),
      y: HoverUtils.getScale(this.isHovered)
    })
    .clip(true)
    .onHover((isHover: boolean) => {
      this.setHoverState(isHover)
    })
  }
}
