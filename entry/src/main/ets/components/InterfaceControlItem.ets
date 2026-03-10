import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'

@Component
export struct InterfaceControlItem {
  @Prop label: string = ''
  @Prop description: string = ''
  @Prop options: string[] = []
  @Prop selectedIndex: number = 0
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onSelect: (index: number) => void = () => {}
  @State isHovered: boolean = false

  build() {
    Row() {
      Column({ space: 4 }) {
        Text(this.label)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        Text(this.description)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Select(this.options.map((opt: string) => {
        let item: SelectOption = { value: opt }
        return item
      }))
        .selected(this.selectedIndex)
        .value(this.options[this.selectedIndex] ?? '')
        .fontColor(AppColors.TEXT_PRIMARY)
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .onSelect((index: number) => {
          this.onSelect(index)
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .translate({ y: HoverUtils.getTranslateY(this.isHovered, 2) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.isHovered = isHover
      })
    })
  }
}
