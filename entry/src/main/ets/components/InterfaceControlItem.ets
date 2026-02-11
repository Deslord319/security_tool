import { AppColors, AppStyles } from '../constants/AppConstants'

@Component
export struct InterfaceControlItem {
  @Prop label: string = ''
  @Prop description: string = ''
  @Prop options: string[] = []
  @Prop selectedIndex: number = 0
  onSelect: (index: number) => void = () => {}

  build() {
    Row() {
      Column({ space: 4 }) {
        Text(this.label)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .opacity(AppColors.TEXT_PRIMARY_OPACITY)
        Text(this.description)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.TEXT_PRIMARY)
          .opacity(AppColors.TEXT_TERTIARY_OPACITY)
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
    .backgroundColor(AppColors.BG_CARD)
  }
}
