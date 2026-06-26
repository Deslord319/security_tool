import { AppColors, AppStyles } from '../constants/AppConstants'
import { SectionLabel } from './SectionRows'
import { ThemeMode } from '../theme/ThemeColors'
import { LogUtils } from '../utils/LogUtils'
import { StyledSelect } from './StyledSelect'

const TAG = 'AsyncSelectRow'

@ComponentV2
export struct AsyncSelectRow {
  @Param label: string = ''
  @Param description: string = ''
  @Param options: string[] = []
  @Param selectedIndex: number = 0
  @Param selectWidth: number = AppStyles.SELECT_WIDTH_DEFAULT
  @Param processing: boolean = false
  @Param enabledValue: boolean = true
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onSelectAsync: (nextIndex: number) => Promise<boolean> = async () => false
  @Local private displayIndex: number = 0
  @Local private isAsyncPending: boolean = false
  @Local private rollbackIndex: number = 0

  aboutToAppear(): void {
    this.displayIndex = this.selectedIndex
    this.rollbackIndex = this.selectedIndex
  }

  private getEffectiveSelectedIndex(): number {
    if (!this.isAsyncPending && this.displayIndex !== this.selectedIndex) {
      this.displayIndex = this.selectedIndex
    }
    return this.displayIndex
  }

  private getDisplayValue(): string {
    const effectiveIndex = this.getEffectiveSelectedIndex()
    return this.options[effectiveIndex] ?? ''
  }

  private isBusy(): boolean {
    return this.processing || this.isAsyncPending
  }

  private canSelect(): boolean {
    return !this.isBusy() && this.enabledValue
  }

  private async handleSelectChange(nextIndex: number): Promise<void> {
    const previousIndex = this.getEffectiveSelectedIndex()
    if (nextIndex === previousIndex || !this.canSelect()) {
      return
    }

    this.rollbackIndex = previousIndex
    this.displayIndex = previousIndex
    let success = false
    try {
      this.isAsyncPending = true
      success = await this.onSelectAsync(nextIndex)
    } catch (err) {
      const errorText = err instanceof Error ? err.message : String(err)
      LogUtils.error(TAG, `async select exception: label=${this.label}, error=${errorText}`)
    } finally {
      this.isAsyncPending = false
    }
    if (success) {
      this.displayIndex = this.selectedIndex
      this.rollbackIndex = this.selectedIndex
      return
    }
    this.displayIndex = this.rollbackIndex
    LogUtils.warn(TAG, `async select rollback: label=${this.label}, rollbackIndex=${this.rollbackIndex}, failedIndex=${nextIndex}`)
  }

  build() {
    Row() {
      SectionLabel({
        title: this.label,
        description: this.description,
        currentTheme: this.currentTheme
      })

      Row({ space: AppStyles.CONTROL_ROW_ACTION_GAP }) {
        if (this.isBusy()) {
          LoadingProgress()
            .width(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
            .height(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
            .color(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        }

        StyledSelect({
          options: this.options.map((value: string): SelectOption => ({ value: value } as SelectOption)),
          selectedIndex: this.getEffectiveSelectedIndex(),
          value: this.getDisplayValue(),
          controlWidth: this.selectWidth,
          enabledValue: this.canSelect(),
          opacityValue: this.canSelect() ? 1 : 0.72,
          currentTheme: this.currentTheme,
          onSelect: (index: number) => {
            this.handleSelectChange(index)
          }
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
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .opacity(this.isBusy() ? 0.8 : 1)
  }
}
