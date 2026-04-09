import { SymbolGlyphModifier, TextModifier } from '@kit.ArkUI'
import { ActionButtonStyles, AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { FormControlUtils } from '../utils/FormControlUtils'

@ComponentV2
export struct SectionToggleRow {
  @Param title: string = ''
  @Param description: string = ''
  @Param isOn: boolean = false
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onChange: (value: boolean) => void = () => {}

  build() {
    Row() {
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

        if (this.description.length > 0) {
          Text(this.description)
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .selectedColor(AppColors.BRAND_PRIMARY)
        .onChange((value: boolean) => {
          this.onChange(value)
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}

@ComponentV2
export struct SectionSelectRow {
  @Param title: string = ''
  @Param description: string = ''
  @Param options: SelectOption[] = []
  @Param selectedIndex: number = 0
  @Param value: string = ''
  @Param selectWidth: number = 140
  @Param processing: boolean = false
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onSelect: (index: number) => void = () => {}

  build() {
    Row() {
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

        if (this.description.length > 0) {
          Text(this.description)
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Select(this.options)
        .selected(this.selectedIndex)
        .value(this.value)
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
        .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
        .optionFont({ size: AppStyles.FONT_SIZE_BODY })
        .width(this.selectWidth)
        .height(36)
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .borderRadius(AppStyles.RADIUS_SM)
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .enabled(!this.processing)
        .opacity(this.processing ? 0.72 : 1)
        .onSelect((index: number) => {
          this.onSelect(index)
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}

@ComponentV2
export struct SectionActionRow {
  @Param title: string = ''
  @Param description: string = ''
  @Param actionLabel: string = ''
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onTap: () => void = () => {}
  @Local private isHovered: boolean = false
  @Local private isPressed: boolean = false

  private getActionBackground(): ResourceColor {
    return ActionButtonStyles.getPrimaryBackground(this.currentTheme, this.isHovered, this.isPressed)
  }

  private getActionForeground(): ResourceColor {
    return ActionButtonStyles.getPrimaryForeground(this.currentTheme)
  }

  build() {
    Row() {
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

        if (this.description.length > 0) {
          Text(this.description)
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button(this.actionLabel)
        .type(ButtonType.Normal)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Regular)
        .fontColor(this.getActionForeground())
        .backgroundColor(this.getActionBackground())
        .borderRadius(AppStyles.RADIUS_SM)
        .height(ActionButtonStyles.CHIP_HEIGHT)
        .padding({
          left: ActionButtonStyles.CHIP_HORIZONTAL_PADDING,
          right: ActionButtonStyles.CHIP_HORIZONTAL_PADDING
        })
        .stateEffect(false)
        .onHover((isHover: boolean) => {
          this.isHovered = isHover
        })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.isPressed = true
            return
          }
          if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.isPressed = false
          }
        })
        .onClick(() => {
          this.isPressed = false
          this.onTap()
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}

@ComponentV2
export struct SectionSelectInputRow {
  @Param title: string = ''
  @Param description: string = ''
  @Param options: SelectOption[] = []
  @Param selectedIndex: number = 0
  @Param value: string = ''
  @Param selectWidth: number = 140
  @Param showInput: boolean = false
  @Param inputText: string = ''
  @Param inputPlaceholder: string = ''
  @Param inputWidth: number = 112
  @Param inputSuffix: string = ''
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onSelect: (index: number) => void = () => {}
  @Event onInputChange: (value: string) => void = () => {}

  build() {
    Row() {
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

        if (this.description.length > 0) {
          Text(this.description)
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: 8 }) {
        Select(this.options)
          .selected(this.selectedIndex)
          .value(this.value)
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .fontColor(FormControlUtils.text(this.currentTheme))
          .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
          .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
          .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
          .optionFont({ size: AppStyles.FONT_SIZE_BODY })
          .width(this.selectWidth)
          .height(36)
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_SM)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onSelect((index: number) => {
            this.onSelect(index)
          })

        if (this.showInput) {
          Row({ space: 6 }) {
            TextInput({ placeholder: this.inputPlaceholder, text: this.inputText })
              .type(InputType.Number)
              .width(this.inputWidth)
              .height(36)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(FormControlUtils.text(this.currentTheme))
              .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
              .backgroundColor(FormControlUtils.background(this.currentTheme))
              .borderRadius(AppStyles.RADIUS_SM)
              .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
              .onChange((value: string) => {
                this.onInputChange(value)
              })

            if (this.inputSuffix.length > 0) {
              Text(this.inputSuffix)
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
            }
          }
        }
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 16 })
  }
}
