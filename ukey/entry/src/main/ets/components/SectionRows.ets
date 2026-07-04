import { ActionButtonStyles, AppColors, AppStyles } from '../constants/AppConstants'

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

@ComponentV2
export struct SectionActionRow {
  @Param title: string = ''
  @Param description: string = ''
  @Param actionLabel: string = ''
  @Param isEnabled: boolean = true
  @Event onTap: () => void = () => {}
  @Local private isHovered: boolean = false
  @Local private isPressed: boolean = false

  build() {
    Row() {
      SectionLabel({
        title: this.title,
        description: this.description
      })

      Button(this.actionLabel)
        .type(ButtonType.Normal)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Regular)
        .fontColor(ActionButtonStyles.getPrimaryForeground())
        .backgroundColor(ActionButtonStyles.getPrimaryBackground(this.isHovered, this.isPressed))
        .borderRadius(AppStyles.RADIUS_SM)
        .height(ActionButtonStyles.CHIP_HEIGHT)
        .padding({
          left: ActionButtonStyles.CHIP_HORIZONTAL_PADDING,
          right: ActionButtonStyles.CHIP_HORIZONTAL_PADDING
        })
        .stateEffect(false)
        .enabled(this.isEnabled)
        .opacity(this.isEnabled ? 1 : 0.56)
        .onHover((isHover: boolean) => {
          if (!this.isEnabled) {
            return
          }
          this.isHovered = isHover
        })
        .onTouch((event: TouchEvent) => {
          if (!this.isEnabled) {
            return
          }
          if (event.type === TouchType.Down) {
            this.isPressed = true
            return
          }
          if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.isPressed = false
          }
        })
        .onClick(() => {
          if (!this.isEnabled) {
            return
          }
          this.isPressed = false
          this.onTap()
        })
    }
    .width('100%')
    .padding(SECTION_ROW_PADDING)
  }
}
