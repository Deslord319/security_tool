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
  @Local private isAsyncPending: boolean = false
  @Local private rollbackIndex: number = 0

  aboutToAppear(): void {
    this.rollbackIndex = this.selectedIndex
  }

  private getEffectiveSelectedIndex(): number {
    return this.selectedIndex
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
    let success = false
    try {
      this.isAsyncPending = true
      await this.waitForPendingRendered()
      success = await this.onSelectAsync(nextIndex)
    } catch (err) {
      const errorText = err instanceof Error ? err.message : String(err)
      LogUtils.error(TAG, `async select exception: label=${this.label}, error=${errorText}`)
    } finally {
      this.isAsyncPending = false
    }
    if (success) {
      this.rollbackIndex = this.selectedIndex
      return
    }
    LogUtils.warn(TAG, `async select rollback: label=${this.label}, rollbackIndex=${this.rollbackIndex}, failedIndex=${nextIndex}`)
  }

  private async waitForPendingRendered(): Promise<void> {
    await new Promise<void>((resolve: () => void): void => {
      setTimeout((): void => {
        resolve()
      }, 0)
    })
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
