import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { ActionText } from '../../../constants/StringCatalog'
import { LogManagePaginationStrings } from '../../../constants/modules/LogManageStrings'
import { LogListState, LogPaginationState, LogSummaryState } from '../../../models/LogManageModels'
import { ThemeMode } from '../../../theme/ThemeColors'
import { IconTextActionButton } from '../../IconTextActionButton'
import { StyledSelect } from '../../StyledSelect'
import { StyledTextInput } from '../../StyledTextInput'

@ComponentV2
export struct LogPaginationBar {
  @Param loading: boolean = false
  @Param listState: LogListState = new LogListState()
  @Param summaryState: LogSummaryState = new LogSummaryState()
  @Param paginationState: LogPaginationState = new LogPaginationState()
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param pageSizeOptions: number[] = []
  @Event onSelectPageSize: (index: number) => void = () => {}
  @Event onChangePageInput: (value: string) => void = () => {}
  @Event onJumpPage: () => void = () => {}
  @Event onPrevPage: () => void = () => {}
  @Event onNextPage: () => void = () => {}

  private getPageSizeOptions(): SelectOption[] {
    return this.pageSizeOptions.map((size: number): SelectOption => ({ value: LogManagePaginationStrings.buildPageSizeText(size) } as SelectOption))
  }

  private getCurrentRangeText(): string {
    if (this.summaryState.filteredCount === 0 || this.listState.pagedEntries.length === 0) {
      return '0-0'
    }
    let pageSize = this.pageSizeOptions[this.paginationState.pageSizeIndex] ?? this.pageSizeOptions[0] ?? 20
    let start = (this.paginationState.currentPage - 1) * pageSize + 1
    let end = start + this.listState.pagedEntries.length - 1
    return `${start}-${end}`
  }

  build() {
    if (!this.loading && this.summaryState.filteredCount > 0) {
      Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
      Row({ space: 12 }) {
        Text(LogManagePaginationStrings.buildPageRangeText(this.getCurrentRangeText(), this.summaryState.filteredCount))
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .layoutWeight(1)

        StyledSelect({
          options: this.getPageSizeOptions(),
          selectedIndex: this.paginationState.pageSizeIndex,
          value: LogManagePaginationStrings.buildPageSizeText(this.pageSizeOptions[this.paginationState.pageSizeIndex] ?? this.pageSizeOptions[0] ?? 20),
          controlWidth: 126,
          controlHeight: 32,
          radius: AppStyles.RADIUS_SM,
          fontSize: AppStyles.FONT_SIZE_CAPTION,
          currentTheme: this.currentTheme,
          onSelect: (index: number) => this.onSelectPageSize(index)
        })

        IconTextActionButton({
          label: ActionText.PREVIOUS_PAGE,
          showIcon: false,
          isEnabled: this.paginationState.currentPage > 1,
          currentTheme: this.currentTheme,
          onTap: this.onPrevPage
        })

        Text(`${this.paginationState.currentPage}/${this.paginationState.totalPages}`)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .width(52)
          .textAlign(TextAlign.Center)

        StyledTextInput({
          text: this.paginationState.pageInputText,
          placeholder: LogManagePaginationStrings.PAGE_INPUT_PLACEHOLDER,
          inputType: InputType.Number,
          controlWidth: 62,
          controlHeight: 32,
          radius: AppStyles.RADIUS_SM,
          fontSize: AppStyles.FONT_SIZE_CAPTION,
          currentTheme: this.currentTheme,
          onChange: (value: string) => this.onChangePageInput(value),
          onSubmit: this.onJumpPage
        })

        IconTextActionButton({
          label: ActionText.JUMP,
          showIcon: false,
          isEnabled: this.paginationState.pageInputText.trim().length > 0,
          currentTheme: this.currentTheme,
          onTap: this.onJumpPage
        })

        IconTextActionButton({
          label: ActionText.NEXT_PAGE,
          showIcon: false,
          isEnabled: this.paginationState.currentPage < this.paginationState.totalPages,
          currentTheme: this.currentTheme,
          onTap: this.onNextPage
        })
      }
      .width('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: 10, bottom: 10 })
    }
  }
}
