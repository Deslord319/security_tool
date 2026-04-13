import { SymbolGlyphModifier, TextModifier } from '@kit.ArkUI'
import { AppColors, AppStyles } from '../constants/AppConstants'
import { SectionLabel } from './SectionRows'
import { ThemeMode } from '../theme/ThemeColors'
import { FormControlUtils } from '../utils/FormControlUtils'
import { LogUtils } from '../utils/LogUtils'

const TAG = 'AsyncSelectRow'

@ComponentV2
export struct AsyncSelectRow {
  @Param label: string = ''
  @Param description: string = ''
  @Param options: string[] = []
  @Param selectedIndex: number = 0
  @Param processing: boolean = false
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param optimistic: boolean = true
  @Event onSelectAsync: (nextIndex: number) => Promise<boolean> = async () => false
  @Local private displayIndex: number = 0
  @Local private isAsyncPending: boolean = false
  @Local private successAwaitingParent: boolean = false
  @Local private successDisplayIndex: number = 0
  @Local private rollbackIndex: number = 0

  aboutToAppear(): void {
    this.displayIndex = this.selectedIndex
    this.successDisplayIndex = this.selectedIndex
    this.rollbackIndex = this.selectedIndex
  }

  private getEffectiveSelectedIndex(): number {
    if (this.isAsyncPending) {
      return this.displayIndex
    }
    if (this.successAwaitingParent && this.selectedIndex === this.rollbackIndex) {
      return this.successDisplayIndex
    }
    return this.selectedIndex
  }

  private getDisplayValue(): string {
    const effectiveIndex = this.getEffectiveSelectedIndex()
    return this.options[effectiveIndex] ?? ''
  }

  private isBusy(): boolean {
    return this.processing || this.isAsyncPending
  }

  private async handleSelectChange(nextIndex: number): Promise<void> {
    const previousIndex = this.getEffectiveSelectedIndex()
    if (nextIndex === previousIndex) {
      return
    }

    this.rollbackIndex = previousIndex
    this.successAwaitingParent = false
    this.isAsyncPending = true
    if (this.optimistic) {
      this.displayIndex = nextIndex
    }

    let success = false
    try {
      success = await this.onSelectAsync(nextIndex)
    } catch (err) {
      const errorText = err instanceof Error ? err.message : String(err)
      LogUtils.error(TAG, `async select exception: label=${this.label}, error=${errorText}`)
    } finally {
      this.isAsyncPending = false
      if (success) {
        this.successDisplayIndex = nextIndex
        this.successAwaitingParent = true
        if (!this.optimistic) {
          this.displayIndex = previousIndex
        }
        return
      }
      this.displayIndex = previousIndex
      this.successDisplayIndex = previousIndex
      this.successAwaitingParent = false
      LogUtils.warn(TAG, `async select rollback: label=${this.label}, rollbackIndex=${previousIndex}, failedIndex=${nextIndex}`)
    }
  }

  build() {
    Row() {
      SectionLabel({
        title: this.label,
        description: this.description,
        currentTheme: this.currentTheme
      })

      Row({ space: 10 }) {
        if (this.isBusy()) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        }

        Select(this.options.map((value: string): SelectOption => ({ value: value } as SelectOption)))
          .selected(this.getEffectiveSelectedIndex())
          .value(this.getDisplayValue())
          .fontColor(FormControlUtils.text(this.currentTheme))
          .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
          .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
          .font({ size: AppStyles.FONT_SIZE_BODY })
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: AppStyles.DIVIDER_HEIGHT, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .enabled(!this.isBusy())
          .opacity(this.isBusy() ? 0.72 : 1)
          .onSelect((index: number) => {
            void this.handleSelectChange(index)
          })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .opacity(this.isBusy() ? 0.8 : 1)
  }
}
