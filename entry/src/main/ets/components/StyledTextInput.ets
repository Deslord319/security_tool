import { AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { FormControlUtils } from '../utils/FormControlUtils'

@ComponentV2
export struct StyledTextInput {
  @Param text: string = ''
  @Param placeholder: string = ''
  @Param inputType: InputType = InputType.Normal
  @Param controlWidth: number = 0
  @Param controlHeight: number = AppStyles.INPUT_HEIGHT
  @Param radius: number = AppStyles.RADIUS_MD
  @Param fontSize: number = AppStyles.FONT_SIZE_BODY
  @Param enabledValue: boolean = true
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onChange: (value: string) => void = () => {}
  @Event onSubmit: () => void = () => {}

  build() {
    TextInput({ text: this.text, placeholder: this.placeholder })
      .type(this.inputType)
      .width(this.controlWidth > 0 ? this.controlWidth : '100%')
      .height(this.controlHeight)
      .fontSize(this.fontSize)
      .fontColor(FormControlUtils.text(this.currentTheme))
      .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
      .backgroundColor(FormControlUtils.background(this.currentTheme))
      .borderRadius(this.radius)
      .border({
        width: AppStyles.DIVIDER_HEIGHT,
        color: FormControlUtils.border(this.currentTheme),
        style: BorderStyle.Solid
      })
      .enabled(this.enabledValue)
      .onChange((value: string) => {
        this.onChange(value)
      })
      .onSubmit(() => {
        this.onSubmit()
      })
  }
}
