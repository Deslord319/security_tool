import { AppColors, AppStyles } from '../constants/AppConstants'
import { LogManageStrings } from '../constants/modules/LogManageStrings'
import { PresentationStrings } from '../constants/modules/PresentationStrings'
import { MetricSummaryCard } from './MetricSummaryCard'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { ThemeMode } from '../theme/ThemeColors'
import { LogListViewModel } from '../viewmodels/log-manage/LogListViewModel'

@Component
export struct LogSummaryCards {
  @ObjectLink viewModel: LogListViewModel
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  @Builder
  private buildMetricCard(title: string, value: string, description: string, start: string, end: string, icon: Resource) {
    MetricSummaryCard({
      title,
      primaryText: value,
      secondaryText: description,
      accentStart: start,
      accentEnd: end,
      icon,
      cardHeight: 116,
      iconTileSize: 62,
      iconTileRadius: 20,
      iconSize: 36,
      primaryFontSize: 26,
      secondaryMaxLines: 2,
      clickable: false
    })
  }

  build() {
    GridRow({ columns: 4, gutter: 12 }) {
      GridCol() {
        this.buildMetricCard(
          LogManageStrings.statTotal,
          `${this.viewModel.state.summary.totalCount}`,
          LogManageStrings.statTotalDescription,
          AppColors.BRAND_PRIMARY,
          AppColors.GRADIENT_FIREWALL_END,
          $r('app.media.folder')
        )
      }
      GridCol() {
        this.buildMetricCard(
          LogManageStrings.statToday,
          `${this.viewModel.state.summary.todayCount}`,
          LogManageStrings.statTodayDescription,
          AppColors.SUCCESS,
          AppColors.GRADIENT_LOG_END,
          $r('app.media.log')
        )
      }
      GridCol() {
        this.buildMetricCard(
          PresentationStrings.logResultBlocked,
          `${this.viewModel.state.summary.blockedCount}`,
          LogManageStrings.statBlockedDescription,
          AppColors.WARNING,
          AppColors.GRADIENT_IDENTITY_END,
          $r('app.media.alert')
        )
      }
      GridCol() {
        this.buildMetricCard(
          LogManageStrings.statCurrentShown,
          `${this.viewModel.state.pagedEntries.length}`,
          LogManageStrings.statCurrentShownDescription,
          AppColors.TEXT_MUTED,
          AppColors.GRADIENT_TOOL_END,
          $r('app.media.dashboard')
        )
      }
    }
    .width('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD })
  }
}
