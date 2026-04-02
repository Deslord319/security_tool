import { AppColors, AppStyles } from '../constants/AppConstants'
import { LogManageStrings } from '../constants/modules/LogManageStrings'
import { IconTextActionButton } from './IconTextActionButton'
import { FormControlUtils } from '../utils/FormControlUtils'
import { LogListViewModel } from '../viewmodels/log-manage/LogListViewModel'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

@Component
export struct LogPaginationBar {
  @ObjectLink viewModel: LogListViewModel
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  private getPageSizeOptions(): SelectOption[] {
    return this.viewModel.getPageSizeOptions().map((size: number): SelectOption => ({ value: LogManageStrings.buildPageSizeText(size) } as SelectOption))
  }

  private getSelectedPageSizeIndex(): number {
    let options = this.viewModel.getPageSizeOptions()
    let index = options.indexOf(this.viewModel.state.pagination.pageSize)
    return index >= 0 ? index : 0
  }

  build() {
    if (!this.viewModel.state.loading && this.viewModel.state.entries.length > 0) {
      Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
      Row({ space: 12 }) {
        Text(LogManageStrings.buildPageRangeText(this.viewModel.getCurrentRangeText(), this.viewModel.state.entries.length))
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .layoutWeight(1)

        Select(this.getPageSizeOptions())
          .selected(this.getSelectedPageSizeIndex())
          .value(LogManageStrings.buildPageSizeText(this.viewModel.state.pagination.pageSize))
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
            let size = this.viewModel.getPageSizeOptions()[index] ?? this.viewModel.getPageSizeOptions()[0]
            this.viewModel.setPageSize(size)
          })

        IconTextActionButton({
          label: LogManageStrings.previousPageButton,
          showIcon: false,
          kind: 'primary',
          isEnabled: this.viewModel.state.pagination.currentPage > 1,
          onTap: () => this.viewModel.goPrev()
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
          .onSubmit(() => this.viewModel.jumpToPage())

        IconTextActionButton({
          label: LogManageStrings.jumpButton,
          showIcon: false,
          kind: 'primary',
          isEnabled: this.viewModel.state.pagination.pageInputText.trim().length > 0,
          onTap: () => this.viewModel.jumpToPage()
        })

        IconTextActionButton({
          label: LogManageStrings.nextPageButton,
          showIcon: false,
          kind: 'primary',
          isEnabled: this.viewModel.state.pagination.currentPage < this.viewModel.state.pagination.totalPages,
          onTap: () => this.viewModel.goNext()
        })
      }
      .width('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: 10, bottom: 10 })
    }
  }
}
