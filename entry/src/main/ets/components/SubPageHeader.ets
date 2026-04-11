import { AppColors, AppStyles, InteractiveItemStyles } from '../constants/AppConstants'
import { AppResources } from '../constants/AppResources'
import { ThemeMode } from '../theme/ThemeColors'

@ComponentV2
export struct SubPageHeader {
  @Param title: string = ''
  @Param subtitle: string = ''
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onBack: () => void = () => {}
  @BuilderParam actions?: () => void
  @Local private hovered: boolean = false
  @Local private pressed: boolean = false

  build() {
    Row() {
      Row({ space: 8 }) {
        Button() {
          Image(AppResources.ARROW_LEFT_ICON)
            .width(18)
            .height(18)
            .fillColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .draggable(false)
        }
        .type(ButtonType.Normal)
        .width(InteractiveItemStyles.ITEM_HEIGHT)
        .height(InteractiveItemStyles.ITEM_HEIGHT)
        .borderRadius(AppStyles.RADIUS_MD)
        .backgroundColor(InteractiveItemStyles.getBackButtonBackground(this.currentTheme, this.hovered, this.pressed))
        .stateEffect(false)
        .onHover((isHover: boolean) => {
          this.hovered = isHover
        })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.pressed = true
            return
          }
          if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.pressed = false
          }
        })
        .onClick(() => {
          this.pressed = false
          this.onBack()
        })

        Column({ space: 4 }) {
          Text(this.title)
            .fontSize(AppStyles.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

          Text(this.subtitle)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Top)

      if (this.actions) {
        this.actions()
      }
    }
    .width('100%')
    .padding({
      left: AppStyles.PADDING_LG,
      right: AppStyles.PADDING_LG,
      top: AppStyles.PADDING_LG
    })
    .alignItems(VerticalAlign.Top)
  }
}
