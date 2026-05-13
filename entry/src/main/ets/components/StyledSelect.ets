import { SymbolGlyphModifier, TextModifier } from '@kit.ArkUI'
import { AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { FormControlUtils } from '../utils/FormControlUtils'

@ComponentV2
export struct StyledSelect {
  @Param options: SelectOption[] = []
  @Param selectedIndex: number = 0
  @Param value: string = ''
  @Param controlWidth: number = 0
  @Param controlHeight: number = AppStyles.INPUT_HEIGHT
  @Param radius: number = AppStyles.RADIUS_MD
  @Param fontSize: number = AppStyles.FONT_SIZE_BODY
  @Param enabledValue: boolean = true
  @Param opacityValue: number = 1
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onSelect: (index: number) => void = () => {}

  build() {
    Select(this.options)
      .selected(this.selectedIndex)
      .value(this.value)
      .font({ size: this.fontSize })
      .fontColor(FormControlUtils.text(this.currentTheme))
      .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
      .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
      .selectedOptionFont({ size: this.fontSize })
      .optionFont({ size: this.fontSize })
      .width(this.controlWidth > 0 ? this.controlWidth : '100%')
      .height(this.controlHeight)
      .backgroundColor(FormControlUtils.background(this.currentTheme))
      .borderRadius(this.radius)
      .border({
        width: AppStyles.DIVIDER_HEIGHT,
        color: FormControlUtils.border(this.currentTheme),
        style: BorderStyle.Solid
      })
      .enabled(this.enabledValue)
      .opacity(this.opacityValue)
      .onSelect((index: number) => {
        this.onSelect(index)
      })
  }
}
