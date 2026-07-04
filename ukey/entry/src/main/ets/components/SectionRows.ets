import { AppColors, AppStyles } from '../constants/AppConstants'

interface SectionRowPadding {
  left: number
  right: number
  top: number
  bottom: number
}

const SECTION_ROW_PADDING: SectionRowPadding = {
  left: 16,
  right: 16,
  top: 14,
  bottom: 14
}

@ComponentV2
export struct SectionLabel {
  @Param title: string = ''
  @Param description: string = ''

  build() {
    Column({ space: 2 }) {
      Text(this.title)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors().TEXT_PRIMARY)
        .opacity(AppColors.getColors().TEXT_PRIMARY_OPACITY)

      if (this.description.length > 0) {
        Text(this.description)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors().TEXT_PRIMARY)
          .opacity(AppColors.getColors().TEXT_TERTIARY_OPACITY)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }
}

@ComponentV2
export struct SectionToggleRow {
  @Param title: string = ''
  @Param description: string = ''
  @Param isOn: boolean = false
  @Param processing: boolean = false
  @Param enabledValue: boolean = true
  @Event onChange: (value: boolean) => void = () => {}

  build() {
    Row() {
      SectionLabel({
        title: this.title,
        description: this.description
      })

      if (this.processing) {
        LoadingProgress()
          .width(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
          .height(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
          .color(AppColors.getColors().TEXT_PRIMARY)
      } else {
        Toggle({ type: ToggleType.Switch, isOn: this.isOn })
          .selectedColor(AppColors.BRAND_PRIMARY)
          .enabled(this.enabledValue)
          .onChange((value: boolean) => {
            this.onChange(value)
          })
      }
    }
    .width('100%')
    .padding(SECTION_ROW_PADDING)
  }
}
