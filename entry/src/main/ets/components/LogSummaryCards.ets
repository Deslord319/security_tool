import { AppColors, AppStyles } from '../constants/AppConstants'
import { LogManageStrings } from '../constants/modules/LogManageStrings'
import { LogSummaryState } from '../models/LogManageModels'
import { PresentationStrings } from '../constants/modules/PresentationStrings'
import { ThemeMode } from '../theme/ThemeColors'

@ComponentV2
export struct LogSummaryCards {
  @Param summary: LogSummaryState = new LogSummaryState()
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT

  @Builder
  private metricCard(title: string, value: string, description: string, start: string, end: string, icon: Resource) {
    Row({ space: 16 }) {
      Column() {
        Image(icon)
          .width(36)
          .height(36)
          .fillColor(Color.White)
          .draggable(false)
      }
      .width(62)
      .height(62)
      .borderRadius(20)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .linearGradient({
        angle: 135,
        colors: [
          [start, 0],
          [end, 1]
        ]
      })

      Column({ space: 6 }) {
        Text(title)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

        Text(value)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .maxLines(1)

        Text(description)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(116)
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER,
      style: BorderStyle.Solid
    })
  }

  build() {
    GridRow({ columns: 4, gutter: 12 }) {
      GridCol() {
        this.metricCard(
          LogManageStrings.statTotal,
          `${this.summary.totalCount}`,
          LogManageStrings.statTotalDescription,
          AppColors.BRAND_PRIMARY,
          AppColors.GRADIENT_FIREWALL_END,
          $r('app.media.folder')
        )
      }
      GridCol() {
        this.metricCard(
          LogManageStrings.statToday,
          `${this.summary.todayCount}`,
          LogManageStrings.statTodayDescription,
          AppColors.SUCCESS,
          AppColors.GRADIENT_LOG_END,
          $r('app.media.log')
        )
      }
      GridCol() {
        this.metricCard(
          PresentationStrings.logResultBlocked,
          `${this.summary.blockedCount}`,
          LogManageStrings.statBlockedDescription,
          AppColors.WARNING,
          AppColors.GRADIENT_IDENTITY_END,
          $r('app.media.alert')
        )
      }
      GridCol() {
        this.metricCard(
          LogManageStrings.statCurrentShown,
          `${this.summary.currentShownCount}`,
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
