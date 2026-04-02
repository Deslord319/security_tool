import { AppColors, AppStyles } from '../constants/AppConstants'
import { LogManageStrings } from '../constants/modules/LogManageStrings'
import { IconTextActionButton } from './IconTextActionButton'
import { FormControlUtils } from '../utils/FormControlUtils'
import { LogManageViewModel } from '../viewmodels/log-manage/LogManageViewModel'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

@Component
export struct LogPaginationBar {
  @ObjectLink viewModel: LogManageViewModel
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  private getPageSizeOptions(): SelectOption[] {
    return this.viewModel.getPageSizeOptions().map((size: number): SelectOption => ({ value: LogManageStrings.buildPageSizeText(size) } as SelectOption))
  }

  private getSelectedPageSizeIndex(): number {
    return this.viewModel.state.pagination.pageSizeIndex
  }

  private getCurrentRangeText(): string {
    if (this.viewModel.state.list.allEntries.length === 0 || this.viewModel.state.list.pagedEntries.length === 0) {
      return '0-0'
    }
    let start = (this.viewModel.state.pagination.currentPage - 1) * this.viewModel.getCurrentPageSize() + 1
    let end = start + this.viewModel.state.list.pagedEntries.length - 1
    return `${start}-${end}`
  }

  build() {
    if (!this.viewModel.state.loading && this.viewModel.state.list.allEntries.length > 0) {
      Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
      Row({ space: 12 }) {
        Text(LogManageStrings.buildPageRangeText(this.getCurrentRangeText(), this.viewModel.state.list.allEntries.length))
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .layoutWeight(1)

        Select(this.getPageSizeOptions())
          .selected(this.getSelectedPageSizeIndex())
          .value(LogManageStrings.buildPageSizeText(this.viewModel.getCurrentPageSize()))
          .font({ size: AppStyles.FONT_SIZE_CAPTION })
          .fontColor(FormControlUtils.text(this.currentTheme))
          .selectedOptionFont({ size: AppStyles.FONT_SIZE_CAPTION })
          .optionFont({ size: AppStyles.FONT_SIZE_CAPTION })
          .width(126)
          .height(32)
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .borderRadius(AppStyles.RADIUS_SM)
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .onSelect((index: number) => {
            this.viewModel.setPageSizeIndex(index)
          })

        IconTextActionButton({
          label: LogManageStrings.previousPageButton,
          showIcon: false,
          kind: 'primary',
          isEnabled: this.viewModel.state.pagination.currentPage > 1,
          onTap: () => this.viewModel.goToPreviousPage()
        })

        Text(`${this.viewModel.state.pagination.currentPage}/${this.viewModel.state.pagination.totalPages}`)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .width(52)
          .textAlign(TextAlign.Center)

        TextInput({ text: this.viewModel.state.pagination.pageInputText, placeholder: LogManageStrings.pageInputPlaceholder })
          .type(InputType.Number)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(FormControlUtils.text(this.currentTheme))
          .backgroundColor(FormControlUtils.background(this.currentTheme))
          .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
          .borderRadius(AppStyles.RADIUS_SM)
          .height(32)
          .width(62)
          .onChange((value: string) => this.viewModel.setPageInputText(value))
          .onSubmit(() => this.viewModel.jumpToInputPage())

        IconTextActionButton({
          label: LogManageStrings.jumpButton,
          showIcon: false,
          kind: 'primary',
          isEnabled: this.viewModel.state.pagination.pageInputText.trim().length > 0,
          onTap: () => this.viewModel.jumpToInputPage()
        })

        IconTextActionButton({
          label: LogManageStrings.nextPageButton,
          showIcon: false,
          kind: 'primary',
          isEnabled: this.viewModel.state.pagination.currentPage < this.viewModel.state.pagination.totalPages,
          onTap: () => this.viewModel.goToNextPage()
        })
      }
      .width('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: 10, bottom: 10 })
    }
  }
}
