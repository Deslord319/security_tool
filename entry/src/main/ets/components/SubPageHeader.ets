import { AppColors, AppStyles, InteractiveItemStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'

@Component
export struct SubPageHeader {
  title: string = ''
  subtitle: string = ''
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT
  onBack: () => void = () => {}
  @BuilderParam actions?: () => void
  @State private hovered: boolean = false
  @State private pressed: boolean = false

  private getIconColor(): string {
    return AppColors.getColors(this.currentTheme).TEXT_PRIMARY
  }

  private getButtonBackground(): string {
    return InteractiveItemStyles.getBackButtonBackground(this.currentTheme, this.hovered, this.pressed)
  }

  build() {
    Row() {
      Row({ space: 8 }) {
        Row() {
          Image($r('app.media.arrow_left'))
            .width(InteractiveItemStyles.ICON_SIZE)
            .height(InteractiveItemStyles.ICON_SIZE)
            .fillColor(this.getIconColor())
            .draggable(false)
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .width(InteractiveItemStyles.ITEM_HEIGHT)
        .height(InteractiveItemStyles.ITEM_HEIGHT)
        .borderRadius(InteractiveItemStyles.ITEM_RADIUS)
        .backgroundColor(this.getButtonBackground())
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
