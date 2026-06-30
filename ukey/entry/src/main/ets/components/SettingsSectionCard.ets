import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { HoverUtils } from '../utils/HoverUtils'

@ComponentV2
export struct SectionCard {
  @Param title: string = ''
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @BuilderParam content?: () => void
  @Local hovered: boolean = false

  build() {
    Column({ space: 0 }) {
      Row() {
        Text(this.title)
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      Column({ space: 0 }) {
        if (this.content) {
          this.content()
        }
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .clip(true)
    .border({
      width: AppStyles.DIVIDER_HEIGHT,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow(HoverUtils.getShadow(this.currentTheme, this.hovered, true))
    .translate({ y: HoverUtils.getTranslateY(this.hovered, 4) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(this.getUIContext(), () => {
        this.hovered = isHover
      })
    })
  }
}
