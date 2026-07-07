import { ActionButtonStyles, AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { StyledSelect } from './StyledSelect'
import { StyledTextInput } from './StyledTextInput'

const SECTION_LABEL_SPACE: number = 2
const SECTION_CONTROL_HEIGHT: number = 36
const SECTION_CONTROL_DISABLED_OPACITY: number = 0.72
const SECTION_ACTION_DISABLED_OPACITY: number = 0.56
const SECTION_SELECT_INPUT_GAP: number = 8
const SECTION_INPUT_SUFFIX_GAP: number = 6
const SECTION_INPUT_WIDTH_DEFAULT: number = 112

@ComponentV2
export struct SectionLabel {
  @Param title: string = ''
  @Param description: string = ''
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Column({ space: SECTION_LABEL_SPACE }) {
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
  }
}

@ComponentV2
export struct SectionToggleRow {
  @Param title: string = ''
  @Param description: string = ''
  @Param isOn: boolean = false
  @Param processing: boolean = false
  @Param enabledValue: boolean = true
  @Param opacityValue: number = 1
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onChange: (value: boolean) => void = () => {}

  build() {
    Row() {
      SectionLabel({
        title: this.title,
        description: this.description,
        currentTheme: this.currentTheme
      })

      if (this.processing) {
        LoadingProgress()
          .width(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
          .height(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
          .color(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      } else {
        Toggle({ type: ToggleType.Switch, isOn: this.isOn })
          .selectedColor(AppColors.BRAND_PRIMARY)
          .enabled(this.enabledValue)
          .opacity(this.opacityValue)
          .onChange((value: boolean) => {
            this.onChange(value)
          })
      }
    }
    .width('100%')
    .padding({
      left: AppStyles.CONTROL_ROW_HORIZONTAL_PADDING,
      right: AppStyles.CONTROL_ROW_HORIZONTAL_PADDING,
      top: AppStyles.CONTROL_ROW_VERTICAL_PADDING,
      bottom: AppStyles.CONTROL_ROW_VERTICAL_PADDING
    })
  }
}

@ComponentV2
export struct SectionSelectRow {
  @Param title: string = ''
  @Param description: string = ''
  @Param options: SelectOption[] = []
  @Param selectedIndex: number = 0
  @Param value: string = ''
  @Param selectWidth: number = AppStyles.SELECT_WIDTH_DEFAULT
  @Param processing: boolean = false
  @Param enabledValue: boolean = true
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onSelect: (index: number) => void = () => {}

  build() {
    Row() {
      SectionLabel({
        title: this.title,
        description: this.description,
        currentTheme: this.currentTheme
      })

      Row({ space: AppStyles.CONTROL_ROW_ACTION_GAP }) {
        if (this.processing) {
          LoadingProgress()
            .width(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
            .height(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
            .color(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        }

        StyledSelect({
          options: this.options,
          selectedIndex: this.selectedIndex,
          value: this.value,
          controlWidth: this.selectWidth,
          controlHeight: SECTION_CONTROL_HEIGHT,
          radius: AppStyles.RADIUS_SM,
          enabledValue: !this.processing && this.enabledValue,
          opacityValue: this.processing || !this.enabledValue ? SECTION_CONTROL_DISABLED_OPACITY : 1,
          currentTheme: this.currentTheme,
          onSelect: (index: number) => {
            this.onSelect(index)
          }
        })
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({
      left: AppStyles.CONTROL_ROW_HORIZONTAL_PADDING,
      right: AppStyles.CONTROL_ROW_HORIZONTAL_PADDING,
      top: AppStyles.CONTROL_ROW_VERTICAL_PADDING,
      bottom: AppStyles.CONTROL_ROW_VERTICAL_PADDING
    })
  }
}

@ComponentV2
export struct SectionActionRow {
  @Param title: string = ''
  @Param description: string = ''
  @Param actionLabel: string = ''
  @Param isEnabled: boolean = true
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
      SectionLabel({
        title: this.title,
        description: this.description,
        currentTheme: this.currentTheme
      })

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
        .enabled(this.isEnabled)
        .opacity(this.isEnabled ? 1 : SECTION_ACTION_DISABLED_OPACITY)
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
    .padding({
      left: AppStyles.CONTROL_ROW_HORIZONTAL_PADDING,
      right: AppStyles.CONTROL_ROW_HORIZONTAL_PADDING,
      top: AppStyles.CONTROL_ROW_VERTICAL_PADDING,
      bottom: AppStyles.CONTROL_ROW_VERTICAL_PADDING
    })
  }
}

@ComponentV2
export struct SectionSelectInputRow {
  @Param title: string = ''
  @Param description: string = ''
  @Param options: SelectOption[] = []
  @Param selectedIndex: number = 0
  @Param value: string = ''
  @Param selectWidth: number = AppStyles.SELECT_WIDTH_DEFAULT
  @Param showInput: boolean = false
  @Param inputText: string = ''
  @Param inputPlaceholder: string = ''
  @Param inputWidth: number = SECTION_INPUT_WIDTH_DEFAULT
  @Param inputSuffix: string = ''
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onSelect: (index: number) => void = () => {}
  @Event onInputChange: (value: string) => void = () => {}

  build() {
    Row() {
      SectionLabel({
        title: this.title,
        description: this.description,
        currentTheme: this.currentTheme
      })

      Row({ space: SECTION_SELECT_INPUT_GAP }) {
        StyledSelect({
          options: this.options,
          selectedIndex: this.selectedIndex,
          value: this.value,
          controlWidth: this.selectWidth,
          controlHeight: SECTION_CONTROL_HEIGHT,
          radius: AppStyles.RADIUS_SM,
          enabledValue: true,
          opacityValue: 1,
          currentTheme: this.currentTheme,
          onSelect: (index: number) => {
            this.onSelect(index)
          }
        })

        if (this.showInput) {
          Row({ space: SECTION_INPUT_SUFFIX_GAP }) {
            StyledTextInput({
              text: this.inputText,
              placeholder: this.inputPlaceholder,
              inputType: InputType.Number,
              controlWidth: this.inputWidth,
              controlHeight: SECTION_CONTROL_HEIGHT,
              radius: AppStyles.RADIUS_SM,
              currentTheme: this.currentTheme,
              onChange: (value: string) => {
                this.onInputChange(value)
              }
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
    .padding({
      left: AppStyles.CONTROL_ROW_HORIZONTAL_PADDING,
      right: AppStyles.CONTROL_ROW_HORIZONTAL_PADDING,
      top: AppStyles.CONTROL_ROW_VERTICAL_PADDING,
      bottom: AppStyles.CONTROL_ROW_VERTICAL_PADDING
    })
  }
}
