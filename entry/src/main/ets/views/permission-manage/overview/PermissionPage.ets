import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { AppResources } from '../../../constants/AppResources'
import { ModuleText } from '../../../constants/StringCatalog'
import {
  PermissionEmptyStrings,
  PermissionPageStrings,
  PermissionScopeStrings,
  PermissionSectionStrings,
  PermissionSummaryStrings
} from '../../../constants/modules/PermissionStrings'
import { ThemeMode } from '../../../theme/ThemeColors'
import { CompactSummaryCard } from '../../../components/CompactSummaryCard'
import { EmptyStatePanel } from '../../../components/EmptyStatePanel'
import { LoadingStatePanel } from '../../../components/LoadingStatePanel'
import { SectionCard } from '../../../components/SettingsSectionCard'
import { SubPageHeader } from '../../../components/SubPageHeader'
import { PermissionViewModel } from '../../../viewmodels/permission-manage/PermissionViewModel'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'PermissionPage'

@ComponentV2
export struct PermissionPage {
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param viewModel: PermissionViewModel = new PermissionViewModel()
  @Event onBack: () => void = () => {}

  aboutToAppear() {
    if (this.viewModel.state.initialized || this.viewModel.state.loading) {
      return
    }
    this.viewModel.loadInitialState().catch((err: Error) => {
      LogUtils.warn(TAG, `loadInitialState failed: ${JSON.stringify(err)}`)
    })
  }

  build() {
    Column() {
      SubPageHeader({
        title: ModuleText.PERMISSION_MANAGE,
        subtitle: PermissionPageStrings.SUBTITLE,
        currentTheme: this.currentTheme,
        onBack: () => this.onBack()
      })

      Scroll() {
        Column({ space: 24 }) {
          SectionCard({
            title: PermissionSectionStrings.SUMMARY,
            currentTheme: this.currentTheme,
            content: () => {
              this.summaryContent()
            }
          })

          SectionCard({
            title: PermissionSectionStrings.SCOPE,
            currentTheme: this.currentTheme,
            content: () => {
              this.scopeContent()
            }
          })

          SectionCard({
            title: PermissionSectionStrings.APPLICATIONS,
            currentTheme: this.currentTheme,
            content: () => {
              this.applicationContent()
            }
          })
        }
        .width('100%')
        .padding({
          left: AppStyles.PADDING_LG,
          right: AppStyles.PADDING_LG,
          top: AppStyles.PADDING_MD,
          bottom: AppStyles.PADDING_LG
        })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  private summaryContent() {
    if (!this.viewModel.state.initialized || this.viewModel.state.loading) {
      LoadingStatePanel({
        message: PermissionPageStrings.LOADING,
        indicatorSize: 24,
        currentTheme: this.currentTheme
      })
        .height(110)
    } else {
      Row({ space: 16 }) {
        CompactSummaryCard({
          title: PermissionSummaryStrings.ACCOUNTS_TITLE,
          valueText: `${this.viewModel.state.summary.accountCount}`,
          description: PermissionSummaryStrings.ACCOUNTS_DESC,
          icon: AppResources.IDENTITY_ICON,
          accentStart: AppColors.WARNING,
          accentEnd: AppColors.GRADIENT_IDENTITY_END,
          currentTheme: this.currentTheme
        })
          .layoutWeight(1)

        CompactSummaryCard({
          title: PermissionSummaryStrings.APPLICATIONS_TITLE,
          valueText: `${this.viewModel.state.summary.applicationCount}`,
          description: PermissionSummaryStrings.APPLICATIONS_DESC,
          icon: AppResources.PERMISSION_ICON,
          accentStart: AppColors.GRADIENT_PERMISSION_START,
          accentEnd: AppColors.GRADIENT_PERMISSION_END,
          currentTheme: this.currentTheme
        })
          .layoutWeight(1)

        CompactSummaryCard({
          title: PermissionSummaryStrings.POLICIES_TITLE,
          valueText: `${this.viewModel.state.summary.managedPolicyCount}`,
          description: PermissionSummaryStrings.POLICIES_DESC,
          icon: AppResources.CHECK_ICON,
          accentStart: AppColors.SUCCESS,
          accentEnd: AppColors.GRADIENT_LOG_END,
          currentTheme: this.currentTheme
        })
          .layoutWeight(1)
      }
      .width('100%')
      .padding(16)
    }
  }

  @Builder
  private scopeContent() {
    Column({ space: 14 }) {
      this.scopeLine(PermissionScopeStrings.READONLY_TITLE, PermissionScopeStrings.READONLY_DESC)
      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
      this.scopeLine(PermissionScopeStrings.ADMIN_TITLE, PermissionScopeStrings.ADMIN_DESC)
    }
    .width('100%')
    .padding(16)
  }

  @Builder
  private scopeLine(title: string, description: string) {
    Column({ space: 6 }) {
      Text(title)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

      Text(description)
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private applicationContent() {
    EmptyStatePanel({
      title: PermissionEmptyStrings.APPLICATIONS,
      currentTheme: this.currentTheme,
      verticalPadding: 36
    })
      .margin(16)
  }
}
