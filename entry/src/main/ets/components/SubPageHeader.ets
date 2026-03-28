import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'

@Component
export struct SubPageHeader {
  title: string = ''
  subtitle: string = ''
  currentTheme: ThemeMode = ThemeMode.LIGHT
  onBack: () => void = () => {}
  @BuilderParam actions?: () => void
  @State private hovered: boolean = false

  private getIconColor(): string {
    return AppColors.getColors(this.currentTheme).TEXT_PRIMARY
  }

  private getButtonBackground(): string {
    return Color.Transparent.toString()
  }

  private getButtonHoverBackground(): string {
    return Color.Transparent.toString()
  }

  build() {
    Row() {
      Row({ space: 8 }) {
        Button() {
          Image($r('app.media.arrow_left'))
            .width(22)
            .height(22)
            .fillColor(this.getIconColor())
            .draggable(false)
        }
        .type(ButtonType.Normal)
        .width(36)
        .height(36)
        .borderRadius(AppStyles.RADIUS_MD)
        .backgroundColor(this.hovered ? this.getButtonHoverBackground() : this.getButtonBackground())
        .onHover((isHover: boolean) => {
          this.hovered = isHover
        })
        .onClick(() => {
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
