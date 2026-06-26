import { ActionButtonStyles, AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { StyledSelect } from './StyledSelect'
import { StyledTextInput } from './StyledTextInput'

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
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
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
  }
}

interface SectionSelectParams {
  options: SelectOption[]
  selectedIndex: number
  value: string
  selectWidth: number
  currentTheme: ThemeMode
  enabled: boolean
  opacity: number
  onSelect: (index: number) => void
}

@Builder
function SectionSelectBuilder(params: SectionSelectParams) {
  StyledSelect({
    options: params.options,
    selectedIndex: params.selectedIndex,
    value: params.value,
    controlWidth: params.selectWidth,
    controlHeight: 36,
    radius: AppStyles.RADIUS_SM,
    enabledValue: params.enabled,
    opacityValue: params.opacity,
    currentTheme: params.currentTheme,
    onSelect: (index: number) => {
      params.onSelect(index)
    }
  })
}

@ComponentV2
export struct SectionToggleRow {
  @Param title: string = ''
  @Param description: string = ''
  @Param isOn: boolean = false
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

      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .selectedColor(AppColors.BRAND_PRIMARY)
        .enabled(this.enabledValue)
        .opacity(this.opacityValue)
        .onChange((value: boolean) => {
          this.onChange(value)
        })
    }
    .width('100%')
    .padding(SECTION_ROW_PADDING)
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

      SectionSelectBuilder({
        options: this.options,
        selectedIndex: this.selectedIndex,
        value: this.value,
        selectWidth: this.selectWidth,
        currentTheme: this.currentTheme,
        enabled: !this.processing && this.enabledValue,
        opacity: this.processing || !this.enabledValue ? 0.72 : 1,
        onSelect: this.onSelect
      } as SectionSelectParams)
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
      SectionLabel({
        title: this.title,
        description: this.description,
        currentTheme: this.currentTheme
      })

      Row({ space: 8 }) {
        SectionSelectBuilder({
          options: this.options,
          selectedIndex: this.selectedIndex,
          value: this.value,
          selectWidth: this.selectWidth,
          currentTheme: this.currentTheme,
          enabled: true,
          opacity: 1,
          onSelect: this.onSelect
        } as SectionSelectParams)

        if (this.showInput) {
          Row({ space: 6 }) {
            StyledTextInput({
              text: this.inputText,
              placeholder: this.inputPlaceholder,
              inputType: InputType.Number,
              controlWidth: this.inputWidth,
              controlHeight: 36,
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
    .padding(SECTION_ROW_PADDING)
  }
}
