import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'

@Component
export struct ToolCard {
  @Prop label: string = ''
  @Prop icon: Resource = $r('app.media.shield')
  @Prop gradientStart: string = '#0A84FF'
  @Prop gradientEnd: string = '#00C6FF'
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onPress: () => void = () => {}
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
          angle: 180,
          colors: [
            [this.isHovered ? 'rgba(255,255,255,0.12)' : 'rgba(255,255,255,0.02)', 0],
            ['rgba(255,255,255,0)', 1]
          ]
        })

      Column({ space: 12 }) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Column() {
            Image(this.icon)
              .width(28)
              .height(28)
              .fillColor(Color.White)
          }
          .width(56)
          .height(56)
          .borderRadius(28)
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
            .width(20)
            .height(56)
            .linearGradient({
              angle: 180,
              colors: [
                ['rgba(255,255,255,0)', 0],
                ['rgba(255,255,255,0.34)', 0.55],
                ['rgba(255,255,255,0)', 1]
              ]
            })
            .rotate({ angle: 16 })
            .translate({ x: this.isHovered ? 36 : -30 })
            .opacity(this.isHovered ? 1 : 0)
        }

        Text(this.label)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .maxLines(1)
          .translate({ y: this.isHovered ? -1 : 0 })
      }
      .width('100%')
      .height('100%')
      .padding({ top: 20, bottom: 20, left: 16, right: 16 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height(132)
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
    .onClick(() => {
      this.onPress()
    })
  }
}
