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
            [this.isHovered ? 'rgba(255,255,255,0.16)' : 'rgba(255,255,255,0.02)', 0],
            [this.isHovered ? 'rgba(255,255,255,0.00)' : 'rgba(255,255,255,0.00)', 1]
          ]
        })
        .opacity(this.isHovered ? 1 : 0.65)

      Row({ space: 16 }) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Column() {
            Image(this.icon)
              .width(24)
              .height(24)
              .fillColor(Color.White)
          }
          .width(52)
          .height(52)
          .borderRadius(AppStyles.RADIUS_LG)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .linearGradient({
            angle: 135,
            colors: [
              [this.gradientStart, 0],
              [this.gradientEnd, 1]
            ]
          })
          .scale({ x: this.isHovered ? 1.08 : 1, y: this.isHovered ? 1.08 : 1 })
          .shadow(HoverUtils.getShadow(this.currentTheme, this.isHovered))

          Column()
            .width(22)
            .height(52)
            .linearGradient({
              angle: 180,
              colors: [
                ['rgba(255,255,255,0)', 0],
                ['rgba(255,255,255,0.36)', 0.55],
                ['rgba(255,255,255,0)', 1]
              ]
            })
            .rotate({ angle: 18 })
            .translate({ x: this.isHovered ? 34 : -32 })
            .opacity(this.isHovered ? 1 : 0)
        }

        Column({ space: 4 }) {
          Text(this.value)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .translate({ y: this.isHovered ? -1 : 0 })

          Text(this.label)
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(this.isHovered ? 0.72 : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
            .maxLines(1)
            .translate({ y: this.isHovered ? -1 : 0 })
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
      color: this.isHovered ? this.gradientStart : AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow(HoverUtils.getShadow(this.currentTheme, this.isHovered, true))
    .translate({ y: HoverUtils.getTranslateY(this.isHovered) })
    .scale({
      x: HoverUtils.getScale(this.isHovered, 1.015),
      y: HoverUtils.getScale(this.isHovered, 1.015)
    })
    .clip(true)
    .onHover((isHover: boolean) => {
      this.setHoverState(isHover)
    })
  }
}
