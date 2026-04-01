import { LogUtils } from './utils/LogUtils'
import { SymbolGlyphModifier, TextModifier } from '@kit.ArkUI'
import { ActionButtonStyles, AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { FormControlUtils } from '../utils/FormControlUtils'

const TAG = 'SectionRows'
const DOMAIN = 0x0015

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
  @Prop @Watch('onSelectedIndexChange') selectedIndex: number = 0
  value: string = ''
  selectWidth: number = 140
  processing: boolean = false
  optimistic: boolean = false
  onSelect: (index: number) => void = () => {}
  onSelectAsync?: (nextIndex: number, previousIndex: number) => Promise<boolean>
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @State private displayIndex: number = 0
  @State private isAsyncPending: boolean = false

  aboutToAppear(): void {
    this.displayIndex = this.selectedIndex
  }

  private onSelectedIndexChange(): void {
    if (this.isAsyncPending) {
      return
    }
    this.displayIndex = this.selectedIndex
  }



  private getDisplayValue(): string {
    const safeIndex = this.displayIndex
    const selectedOption = this.options[safeIndex]
    if (selectedOption && typeof selectedOption.value === 'string') {
      return selectedOption.value
    }
    return this.value
  }

  private async handleSelectChange(index: number): Promise<void> {
    const nextIndex = index
    const previousIndex = this.displayIndex
    if (nextIndex === previousIndex) {
      return
    }

    if (!this.onSelectAsync) {
      this.displayIndex = nextIndex
      this.onSelect(nextIndex)
      return
    }

    this.isAsyncPending = true
    if (this.optimistic) {
      this.displayIndex = nextIndex
    }
    LogUtils.info(TAG,
      'select async start: title=%{public}s, previousIndex=%{public}d, nextIndex=%{public}d',
      this.title,
      previousIndex,
      nextIndex
    )

    let success = false
    try {
      success = await this.onSelectAsync(nextIndex, previousIndex)
    } catch (err) {
      LogUtils.error(TAG, 'select async exception: title=%{public}s, error=%{public}s', this.title, JSON.stringify(err))
    }

    this.isAsyncPending = false
    if (success) {
      LogUtils.info(TAG, 'select async success: title=%{public}s, nextIndex=%{public}d', this.title, nextIndex)
      if (!this.optimistic) {
        this.displayIndex = previousIndex
      }
      return
    }

    this.displayIndex = previousIndex
    LogUtils.warn(TAG,
      'select async rollback: title=%{public}s, rollbackIndex=%{public}d, failedIndex=%{public}d',
      this.title,
      previousIndex,
      nextIndex
    )
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

      Select(this.options)
        .selected(this.displayIndex)
        .value(this.getDisplayValue())
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
        .enabled(!(this.processing || this.isAsyncPending))
        .opacity(this.processing || this.isAsyncPending ? 0.72 : 1)
        .onSelect((index: number) => {
          void this.handleSelectChange(index)
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
  @State private isHovered: boolean = false
  @State private isPressed: boolean = false

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
