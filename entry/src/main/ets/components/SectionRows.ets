import { SymbolGlyphModifier, TextModifier } from '@kit.ArkUI'
import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { FormControlUtils } from '../utils/FormControlUtils'

@Component
export struct SectionToggleRow {
  title: string = ''
  description: string = ''
  isOn: boolean = false
  onChange: (value: boolean) => void = () => {}
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

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

@Component
export struct SectionSelectRow {
  title: string = ''
  description: string = ''
  options: SelectOption[] = []
  selectedIndex: number = 0
  value: string = ''
  selectWidth: number = 140
  onSelect: (index: number) => void = () => {}
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

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
        .onSelect((index: number) => {
          this.onSelect(index)
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}

@Component
export struct SectionActionRow {
  title: string = ''
  description: string = ''
  actionLabel: string = ''
  onTap: () => void = () => {}
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

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
        .fontColor(Color.White)
        .backgroundColor(AppColors.BRAND_PRIMARY)
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .padding({ left: 14, right: 14 })
        .onClick(() => {
          this.onTap()
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}

@Component
export struct SectionSelectInputRow {
  title: string = ''
  description: string = ''
  options: SelectOption[] = []
  selectedIndex: number = 0
  value: string = ''
  selectWidth: number = 140
  showInput: boolean = false
  inputText: string = ''
  inputPlaceholder: string = ''
  inputWidth: number = 112
  inputSuffix: string = ''
  onSelect: (index: number) => void = () => {}
  onInputChange: (value: string) => void = () => {}
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

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
