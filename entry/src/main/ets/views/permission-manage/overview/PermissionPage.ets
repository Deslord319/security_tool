import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { AppResources } from '../../../constants/AppResources'
import { ModuleText } from '../../../constants/StringCatalog'
import {
  PermissionEmptyStrings,
  PermissionAccountStrings,
  PermissionApplicationStrings,
  PermissionPageStrings,
  PermissionSearchStrings,
  PermissionScopeStrings,
  PermissionSectionStrings,
  PermissionSummaryStrings
} from '../../../constants/modules/PermissionStrings'
import { ThemeMode } from '../../../theme/ThemeColors'
import { CompactSummaryCard } from '../../../components/CompactSummaryCard'
import { EmptyStatePanel } from '../../../components/EmptyStatePanel'
import { LoadingStatePanel } from '../../../components/LoadingStatePanel'
import { SectionSelectRow } from '../../../components/SectionRows'
import { SectionCard } from '../../../components/SettingsSectionCard'
import { StyledTextInput } from '../../../components/StyledTextInput'
import { SubPageHeader } from '../../../components/SubPageHeader'
import { ManagedApplicationInfo, PermissionManagedAccount, PermissionPolicyState } from '../../../models/PermissionModels'
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

  private getAccountOptions(): SelectOption[] {
    return this.viewModel.state.accounts.map((account: PermissionManagedAccount): SelectOption => ({
      value: account.displayName
    } as SelectOption))
  }

  private getSelectedAccountIndex(): number {
    let index = this.viewModel.state.accounts.findIndex((account: PermissionManagedAccount): boolean =>
      account.accountId === this.viewModel.state.selectedAccountId
    )
    return index >= 0 ? index : 0
  }

  private getSelectedAccountLabel(): string {
    let account = this.viewModel.state.accounts[this.getSelectedAccountIndex()]
    return account?.displayName ?? PermissionAccountStrings.NO_ACCOUNTS
  }

  private switchAccountByIndex(index: number): void {
    let account = this.viewModel.state.accounts[index]
    if (!account) {
      return
    }
    this.viewModel.switchAccount(account.accountId).catch((err: Error) => {
      LogUtils.warn(TAG, `switchAccount failed: ${JSON.stringify(err)}`)
    })
  }

  private getSelectedApplication(): ManagedApplicationInfo | undefined {
    return this.viewModel.state.filteredApplications.find((app: ManagedApplicationInfo): boolean =>
      app.key === this.viewModel.state.selectedAppKey
    )
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
            title: PermissionSectionStrings.ACCOUNT_SCOPE,
            currentTheme: this.currentTheme,
            content: () => {
              this.accountContent()
            }
          })

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
  private accountContent() {
    if (!this.viewModel.state.initialized || this.viewModel.state.loading) {
      LoadingStatePanel({
        message: PermissionPageStrings.LOADING,
        indicatorSize: 24,
        currentTheme: this.currentTheme
      })
        .height(88)
    } else {
      SectionSelectRow({
        title: PermissionAccountStrings.SELECT_TITLE,
        description: PermissionAccountStrings.SELECT_DESC,
        options: this.getAccountOptions(),
        selectedIndex: this.getSelectedAccountIndex(),
        value: this.getSelectedAccountLabel(),
        selectWidth: 220,
        processing: this.viewModel.state.accounts.length === 0,
        currentTheme: this.currentTheme,
        onSelect: (index: number) => {
          this.switchAccountByIndex(index)
        }
      })
    }
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
          valueText: `${this.viewModel.state.accounts.length}`,
          description: PermissionSummaryStrings.ACCOUNTS_DESC,
          icon: AppResources.IDENTITY_ICON,
          accentStart: AppColors.WARNING,
          accentEnd: AppColors.GRADIENT_IDENTITY_END,
          currentTheme: this.currentTheme
        })
          .layoutWeight(1)

        CompactSummaryCard({
          title: PermissionSummaryStrings.APPLICATIONS_TITLE,
          valueText: `${this.viewModel.state.summary.appCount}`,
          description: PermissionSummaryStrings.APPLICATIONS_DESC,
          icon: AppResources.PERMISSION_ICON,
          accentStart: AppColors.GRADIENT_PERMISSION_START,
          accentEnd: AppColors.GRADIENT_PERMISSION_END,
          currentTheme: this.currentTheme
        })
          .layoutWeight(1)

        CompactSummaryCard({
          title: PermissionSummaryStrings.POLICIES_TITLE,
          valueText: `${this.viewModel.state.summary.managedCount}`,
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
    Column({ space: 14 }) {
      StyledTextInput({
        text: this.viewModel.state.searchKeyword,
        placeholder: PermissionSearchStrings.PLACEHOLDER,
        controlHeight: 36,
        radius: AppStyles.RADIUS_SM,
        currentTheme: this.currentTheme,
        onChange: (value: string) => {
          this.viewModel.setSearchKeyword(value)
        }
      })

      if (this.viewModel.state.filteredApplications.length === 0) {
        EmptyStatePanel({
          title: this.getApplicationEmptyText(),
          currentTheme: this.currentTheme,
          verticalPadding: 36
        })
      } else {
        Row({ space: 16 }) {
          Column({ space: 10 }) {
            ForEach(this.viewModel.state.filteredApplications, (app: ManagedApplicationInfo) => {
              this.applicationListItem(app)
            }, (app: ManagedApplicationInfo): string => app.key)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          this.applicationDetail(this.getSelectedApplication())
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
    }
    .width('100%')
    .padding(16)
  }

  private getApplicationEmptyText(): string {
    if (this.viewModel.state.searchKeyword.trim().length > 0 && this.viewModel.state.applications.length > 0) {
      return PermissionEmptyStrings.SEARCH_RESULT
    }
    return this.viewModel.state.inventoryMessage.length > 0 ? this.viewModel.state.inventoryMessage : PermissionEmptyStrings.APPLICATIONS
  }

  private isApplicationSelected(app: ManagedApplicationInfo): boolean {
    return app.key === this.viewModel.state.selectedAppKey
  }

  @Builder
  private applicationListItem(app: ManagedApplicationInfo) {
    Row({ space: 10 }) {
      Column() {
        Image(AppResources.PERMISSION_ICON)
          .width(18)
          .height(18)
          .fillColor(this.isApplicationSelected(app) ? Color.White : AppColors.BRAND_PRIMARY)
          .draggable(false)
      }
      .width(36)
      .height(36)
      .borderRadius(AppStyles.RADIUS_SM)
      .backgroundColor(this.isApplicationSelected(app) ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 3 }) {
        Text(app.label)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isApplicationSelected(app) ? Color.White : AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(app.bundleName)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(this.isApplicationSelected(app) ? Color.White : AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(this.isApplicationSelected(app) ? 0.82 : AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(this.isApplicationSelected(app) ? AppColors.BRAND_PRIMARY : AppColors.TRANSPARENT)
    .borderRadius(AppStyles.RADIUS_MD)
    .onClick(() => {
      this.viewModel.selectApplication(app.key)
    })
  }

  @Builder
  private applicationDetail(app: ManagedApplicationInfo | undefined) {
    Column({ space: 10 }) {
      Text(PermissionSectionStrings.APPLICATION_DETAIL)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

      if (app === undefined) {
        Text(PermissionEmptyStrings.DETAIL)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      } else {
        this.detailLine(PermissionApplicationStrings.BUNDLE_NAME, app.bundleName)
        this.detailLine(PermissionApplicationStrings.VERSION_NAME, app.versionName.length > 0 ? app.versionName : '--')
        this.detailLine(PermissionApplicationStrings.UID, `${app.uid}`)
        this.detailLine(PermissionApplicationStrings.INSTALL_POLICY, this.formatPolicy(app.installPolicy))
        this.detailLine(PermissionApplicationStrings.UNINSTALL_PROTECTED, this.formatEnabled(app.uninstallProtected))
        this.detailLine(PermissionApplicationStrings.RUNNING_POLICY, this.formatPolicy(app.runningPolicy))
        this.detailLine(PermissionApplicationStrings.NETWORK_POLICY, this.formatPolicy(app.networkPolicy))
        this.detailLine(PermissionApplicationStrings.KEEP_ALIVE, this.formatEnabled(app.keepAliveEnabled))
        this.detailLine(PermissionApplicationStrings.AUTO_START, this.formatEnabled(app.autoStartEnabled))
      }
    }
    .width(360)
    .padding(14)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_COMPONENT)
    .borderRadius(AppStyles.RADIUS_MD)
    .alignItems(HorizontalAlign.Start)
  }

  private formatPolicy(policy: PermissionPolicyState): string {
    if (policy === 'allowed') {
      return PermissionApplicationStrings.POLICY_ALLOWED
    }
    if (policy === 'denied') {
      return PermissionApplicationStrings.POLICY_DENIED
    }
    return PermissionApplicationStrings.POLICY_DEFAULT
  }

  private formatEnabled(enabled: boolean): string {
    return enabled ? PermissionApplicationStrings.ENABLED : PermissionApplicationStrings.DISABLED
  }

  @Builder
  private detailLine(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      Blank()
      Text(value)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
  }
}
