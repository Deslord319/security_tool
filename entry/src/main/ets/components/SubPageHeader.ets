import { AppColors, AppStyles, InteractiveItemStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { InteractiveMenuRow } from './ThemeMenuPopup'

@Component
export struct SubPageHeader {
  title: string = ''
  subtitle: string = ''
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT
  onBack: () => void = () => {}
  @BuilderParam actions?: () => void
  @State private hovered: boolean = false
  @State private pressed: boolean = false

  build() {
    Row() {
      Row({ space: 8 }) {
        InteractiveMenuRow({
          icon: $r('app.media.arrow_left'),
          itemId: 'sub-page-back',
          currentTheme: this.currentTheme,
          showLabel: false,
          fixedWidth: InteractiveItemStyles.ITEM_HEIGHT,
          itemBackground: InteractiveItemStyles.getBackButtonBackground(this.currentTheme, this.hovered, this.pressed),
          iconTileBackground: Color.Transparent,
          iconColor: AppColors.getColors(this.currentTheme).TEXT_PRIMARY,
          onHoverChange: (isHover: boolean) => {
            this.hovered = isHover
          },
          onPressedChange: (isPressed: boolean) => {
            this.pressed = isPressed
          },
          onTap: () => {
            this.pressed = false
            this.onBack()
          }
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
