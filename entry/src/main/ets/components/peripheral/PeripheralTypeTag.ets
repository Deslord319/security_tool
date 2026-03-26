import { AppColors, AppStyles } from '../../constants/AppConstants'
import { ThemeMode } from '../../theme/ThemeColors'

@Component
export struct PeripheralTypeTag {
  @Prop label: string = ''
  @Prop weight: number = 1
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Row() {
      Row() {
        Text(this.label)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.TAG_PURPLE_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .borderRadius(6)
      .backgroundColor(AppColors.TAG_PURPLE_BG)
    }
    .layoutWeight(this.weight)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }
}
