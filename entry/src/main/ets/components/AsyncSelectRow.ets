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
    if (this.successAwaitingParent) {
      if (this.selectedIndex === this.successDisplayIndex) {
        this.successAwaitingParent = false
        this.rollbackIndex = this.selectedIndex
        return this.selectedIndex
      }
      if (this.selectedIndex === this.rollbackIndex) {
        return this.successDisplayIndex
      }
      this.successAwaitingParent = false
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
          controlWidth: AppStyles.SELECT_WIDTH_DEFAULT,
          enabledValue: !this.isBusy(),
          opacityValue: this.isBusy() ? 0.72 : 1,
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
