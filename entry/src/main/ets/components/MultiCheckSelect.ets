import { AppColors, AppStyles } from '../constants/AppConstants'
import { FirewallDialogStrings } from '../constants/modules/FirewallStrings'
import { ThemeMode } from '../theme/ThemeColors'
import { FormControlUtils } from '../utils/FormControlUtils'

export interface MultiCheckSelectOption {
  userId: number
  label: string
}

@ComponentV2
export struct MultiCheckSelect {
  @Param options: MultiCheckSelectOption[] = []
  @Param selectedValues: number[] = []
  @Param placeholder: string = FirewallDialogStrings.USER_SCOPE_PLACEHOLDER
  @Param allLabel: string = FirewallDialogStrings.ALL_VALUE
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param disabled: boolean = false
  @Event onChange: (values: number[]) => void = () => {}
  @Local private isExpanded: boolean = false

  private getAvailableValues(): number[] {
    return this.options.map((option: MultiCheckSelectOption): number => option.userId)
  }

  private normalizeValues(values: number[], availableValues?: number[]): number[] {
    let scopedAvailableValues = availableValues ?? this.getAvailableValues()
    let availableValueSet = new Set<number>(scopedAvailableValues)
    let filtered = values.filter((value: number): boolean => availableValueSet.size === 0 || availableValueSet.has(value))
    return Array.from(new Set<number>(filtered)).sort((left: number, right: number): number => left - right)
  }

  private getNormalizedSelectedValues(): number[] {
    return this.normalizeValues(this.selectedValues)
  }

  private isAllSelected(availableValues?: number[], selectedValues?: number[]): boolean {
    let scopedAvailableValues = availableValues ?? this.getAvailableValues()
    if (scopedAvailableValues.length === 0) {
      return false
    }
    let scopedSelectedValues = selectedValues ?? this.normalizeValues(this.selectedValues, scopedAvailableValues)
    return scopedSelectedValues.length === scopedAvailableValues.length
  }

  private getSelectedLabel(value: number): string {
    return this.options.find((option: MultiCheckSelectOption): boolean => option.userId === value)?.label ?? ''
  }

  private getDisplayText(): string {
    if (this.options.length === 0) {
      return FirewallDialogStrings.USER_SCOPE_EMPTY
    }

    let availableValues = this.getAvailableValues()
    let selectedValues = this.normalizeValues(this.selectedValues, availableValues)
    if (selectedValues.length === 0) {
      return this.placeholder
    }

    if (selectedValues.length === 1) {
      let label = this.getSelectedLabel(selectedValues[0])
      return label.length > 0 ? label : this.placeholder
    }

    if (this.isAllSelected(availableValues, selectedValues)) {
      return this.allLabel
    }

    return FirewallDialogStrings.buildUserScopeSelectionSummary(selectedValues.length)
  }

  private handleChange(nextValues: number[]): void {
    this.onChange(this.normalizeValues(nextValues))
  }

  private handleToggleAll(): void {
    let availableValues = this.getAvailableValues()
    if (this.isAllSelected(availableValues)) {
      this.handleChange([])
      return
    }
    this.handleChange(availableValues)
  }

  private handleToggleValue(value: number): void {
    let currentValues = this.getNormalizedSelectedValues()
    if (currentValues.includes(value)) {
      this.handleChange(currentValues.filter((item: number): boolean => item !== value))
      return
    }
    this.handleChange([...currentValues, value])
  }

  private isOptionSelected(value: number): boolean {
    return this.getNormalizedSelectedValues().includes(value)
  }

  private getCheckboxTextColor(isChecked: boolean): ResourceColor {
    return isChecked ? Color.White : FormControlUtils.text(this.currentTheme)
  }

  private getCheckboxBackground(isChecked: boolean): ResourceColor {
    return isChecked ? AppColors.BRAND_PRIMARY : Color.Transparent
  }

  private getRowBackground(isChecked: boolean): ResourceColor {
    return isChecked
      ? AppColors.getColors(this.currentTheme).TAG_BLUE_BG
      : Color.Transparent
  }

  private getTriggerTextColor(): ResourceColor {
    return this.options.length === 0
      ? FormControlUtils.placeholder(this.currentTheme)
      : FormControlUtils.text(this.currentTheme)
  }

  build() {
    Column({ space: 6 }) {
      Row() {
        Text(this.getDisplayText())
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(this.getTriggerTextColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Text(this.isExpanded ? '⌃' : '⌄')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(FormControlUtils.selectArrow(this.currentTheme))
      }
      .width('100%')
      .height(AppStyles.INPUT_HEIGHT)
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(FormControlUtils.background(this.currentTheme))
      .borderRadius(AppStyles.RADIUS_MD)
      .border({ width: AppStyles.DIVIDER_HEIGHT, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
      .opacity(this.disabled ? 0.72 : 1)
      .onClick(() => {
        if (this.disabled || this.options.length === 0) {
          return
        }
        this.isExpanded = !this.isExpanded
      })

      if (this.isExpanded) {
        Column({ space: 2 }) {
          if (this.options.length === 0) {
            Text(FirewallDialogStrings.USER_SCOPE_EMPTY)
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontColor(FormControlUtils.placeholder(this.currentTheme))
              .width('100%')
              .padding({ left: 4, right: 4, top: 2, bottom: 2 })
          } else {
            Scroll() {
              Column({ space: 4 }) {
                Row() {
                  Row({ space: 10 }) {
                    Row() {
                      Text(this.isAllSelected() ? '✓' : '')
                        .fontSize(AppStyles.FONT_SIZE_CAPTION)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.getCheckboxTextColor(this.isAllSelected()))
                    }
                    .width(16)
                    .height(16)
                    .alignItems(VerticalAlign.Center)
                    .justifyContent(FlexAlign.Center)
                    .borderRadius(AppStyles.RADIUS_SM)
                    .border({
                      width: AppStyles.DIVIDER_HEIGHT,
                      color: this.isAllSelected() ? AppColors.BRAND_PRIMARY : FormControlUtils.border(this.currentTheme),
                      style: BorderStyle.Solid
                    })
                    .backgroundColor(this.getCheckboxBackground(this.isAllSelected()))

                    Text(this.allLabel)
                      .fontSize(AppStyles.FONT_SIZE_BODY)
                      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                  }
                  .width('100%')
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .backgroundColor(this.getRowBackground(this.isAllSelected()))
                  .borderRadius(AppStyles.RADIUS_SM)
                  .onClick(() => {
                    this.handleToggleAll()
                  })
                }

                ForEach(this.options, (option: MultiCheckSelectOption) => {
                  Row() {
                    Row({ space: 10 }) {
                      Row() {
                        Text(this.isOptionSelected(option.userId) ? '✓' : '')
                          .fontSize(AppStyles.FONT_SIZE_CAPTION)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(this.getCheckboxTextColor(this.isOptionSelected(option.userId)))
                      }
                      .width(16)
                      .height(16)
                      .alignItems(VerticalAlign.Center)
                      .justifyContent(FlexAlign.Center)
                      .borderRadius(AppStyles.RADIUS_SM)
                      .border({
                        width: AppStyles.DIVIDER_HEIGHT,
                        color: this.isOptionSelected(option.userId) ? AppColors.BRAND_PRIMARY : FormControlUtils.border(this.currentTheme),
                        style: BorderStyle.Solid
                      })
                      .backgroundColor(this.getCheckboxBackground(this.isOptionSelected(option.userId)))

                      Text(option.label)
                        .fontSize(AppStyles.FONT_SIZE_BODY)
                        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                    }
                    .width('100%')
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .backgroundColor(this.getRowBackground(this.isOptionSelected(option.userId)))
                    .borderRadius(AppStyles.RADIUS_SM)
                    .onClick(() => {
                      this.handleToggleValue(option.userId)
                    })
                  }
                }, (option: MultiCheckSelectOption): string => `${option.userId}`)
              }
              .width('100%')
            }
            .scrollBar(BarState.Auto)
            .constraintSize({ maxHeight: 240 })
          }
        }
        .width('100%')
        .padding(6)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_MD)
        .border({ width: AppStyles.DIVIDER_HEIGHT, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
      }
    }
    .width('100%')
  }
}
