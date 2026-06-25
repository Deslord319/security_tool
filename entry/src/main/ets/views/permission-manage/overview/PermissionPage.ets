import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { AppResources } from '../../../constants/AppResources'
import { ModuleText } from '../../../constants/StringCatalog'
import {
  PermissionEmptyStrings,
  PermissionAccountStrings,
  PermissionApplicationStrings,
  PermissionPageStrings,
  PermissionSectionStrings,
  PermissionSixDStrings,
  PermissionSummaryStrings
} from '../../../constants/modules/PermissionStrings'
import { ThemeMode } from '../../../theme/ThemeColors'
import { CompactSummaryCard } from '../../../components/CompactSummaryCard'
import { EmptyStatePanel } from '../../../components/EmptyStatePanel'
import { LoadingStatePanel } from '../../../components/LoadingStatePanel'
import { SectionSelectRow, SectionToggleRow } from '../../../components/SectionRows'
import { SectionCard } from '../../../components/SettingsSectionCard'
import { SubPageHeader } from '../../../components/SubPageHeader'
import {
  ApplicationPermissionProfile,
  ManagedApplicationInfo,
  PermissionActionResult,
  PermissionManagedAccount,
  PermissionPolicyState,
  SixDManagedState,
  SixDPermissionItem
} from '../../../models/PermissionModels'
import { PermissionViewModel } from '../../../viewmodels/permission-manage/PermissionViewModel'
import { DialogService } from '../../../utils/DialogService'
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

  private getApplicationOptions(): SelectOption[] {
    return this.viewModel.state.filteredApplications.map((app: ManagedApplicationInfo): SelectOption => ({
      value: app.label
    } as SelectOption))
  }

  private getSelectedApplicationIndex(): number {
    let index = this.viewModel.state.filteredApplications.findIndex((app: ManagedApplicationInfo): boolean =>
      app.key === this.viewModel.state.selectedAppKey
    )
    return index >= 0 ? index : 0
  }

  private getSelectedApplicationLabel(): string {
    let app = this.viewModel.state.filteredApplications[this.getSelectedApplicationIndex()]
    return app?.label ?? PermissionEmptyStrings.APPLICATIONS
  }

  private selectApplicationByIndex(index: number): void {
    let app = this.viewModel.state.filteredApplications[index]
    if (!app) {
      return
    }
    this.viewModel.selectApplicationAndLoadProfile(app.key).catch((err: Error) => {
      LogUtils.warn(TAG, `selectApplicationByIndex failed: ${JSON.stringify(err)}`)
    })
  }

  private getPolicyOptions(): SelectOption[] {
    return [
      { value: PermissionApplicationStrings.POLICY_DEFAULT } as SelectOption,
      { value: PermissionApplicationStrings.POLICY_ALLOWED } as SelectOption,
      { value: PermissionApplicationStrings.POLICY_DENIED } as SelectOption
    ]
  }

  private getNetworkPolicyOptions(): SelectOption[] {
    return [
      { value: PermissionApplicationStrings.POLICY_DEFAULT } as SelectOption,
      { value: PermissionApplicationStrings.POLICY_DENIED } as SelectOption
    ]
  }

  private getSixDOptions(): SelectOption[] {
    return [
      { value: PermissionApplicationStrings.POLICY_DEFAULT } as SelectOption,
      { value: PermissionApplicationStrings.POLICY_ALLOWED } as SelectOption,
      { value: PermissionApplicationStrings.POLICY_DENIED } as SelectOption
    ]
  }

  private policyByIndex(index: number): PermissionPolicyState {
    if (index === 1) {
      return 'allowed'
    }
    if (index === 2) {
      return 'denied'
    }
    return 'default'
  }

  private networkPolicyByIndex(index: number): PermissionPolicyState {
    return index === 1 ? 'denied' : 'default'
  }

  private sixDStateByIndex(index: number): SixDManagedState {
    if (index === 1) {
      return 'granted'
    }
    if (index === 2) {
      return 'denied'
    }
    return 'default'
  }

  private getPolicyIndex(policy: PermissionPolicyState): number {
    if (policy === 'allowed') {
      return 1
    }
    if (policy === 'denied') {
      return 2
    }
    return 0
  }

  private getNetworkPolicyIndex(policy: PermissionPolicyState): number {
    return policy === 'denied' ? 1 : 0
  }

  private getSixDStateIndex(state: SixDManagedState): number {
    if (state === 'granted') {
      return 1
    }
    if (state === 'denied') {
      return 2
    }
    return 0
  }

  private getAutoStartAbilityName(app: ManagedApplicationInfo): string {
    return this.viewModel.state.selectedPermissionProfile?.mainAbilityName ?? app.mainAbilityName
  }

  private executePolicyAction(action: () => Promise<PermissionActionResult>): void {
    this.executePolicyActionAsync(action).catch((err: Error) => {
      LogUtils.warn(TAG, `executePolicyAction failed: ${JSON.stringify(err)}`)
    })
  }

  private async executePolicyActionAsync(action: () => Promise<PermissionActionResult>): Promise<void> {
    let result = await action()
    if (!result.success) {
      DialogService.openFailure(this.getUIContext(), result.message)
    }
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
        Column({ space: 20 }) {
          this.summaryContent()

          SectionCard({
            title: PermissionSectionStrings.APPLICATIONS,
            currentTheme: this.currentTheme,
            content: () => {
              this.targetContent()
            }
          })

          if (this.getSelectedApplication() !== undefined) {
            SectionCard({
              title: PermissionSectionStrings.APPLICATION_CONTROL,
              currentTheme: this.currentTheme,
              content: () => {
                this.applicationPolicyContent()
              }
            })
          }
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
          icon: AppResources.SERVER_ICON,
          accentStart: AppColors.SUCCESS,
          accentEnd: AppColors.GRADIENT_LOG_END,
          currentTheme: this.currentTheme
        })
          .layoutWeight(1)
      }
      .width('100%')
      .height(92)
    }
  }

  @Builder
  private targetContent() {
    if (!this.viewModel.state.initialized || this.viewModel.state.loading) {
      LoadingStatePanel({
        message: PermissionPageStrings.LOADING,
        indicatorSize: 24,
        currentTheme: this.currentTheme
      })
        .height(128)
    } else {
      SectionSelectRow({
        title: PermissionAccountStrings.SELECT_TITLE,
        description: PermissionAccountStrings.SELECT_DESC,
        options: this.getAccountOptions(),
        selectedIndex: this.getSelectedAccountIndex(),
        value: this.getSelectedAccountLabel(),
        selectWidth: AppStyles.SELECT_WIDTH_DEFAULT,
        processing: this.viewModel.state.accounts.length === 0,
        currentTheme: this.currentTheme,
        onSelect: (index: number) => {
          this.switchAccountByIndex(index)
        }
      })

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      if (this.viewModel.state.filteredApplications.length === 0) {
        EmptyStatePanel({
          title: this.getApplicationEmptyText(),
          currentTheme: this.currentTheme,
          verticalPadding: 28
        })
      } else {
        SectionSelectRow({
          title: PermissionSectionStrings.TARGET_APPLICATION,
          description: PermissionSectionStrings.TARGET_APPLICATION_DESC,
          options: this.getApplicationOptions(),
          selectedIndex: this.getSelectedApplicationIndex(),
          value: this.getSelectedApplicationLabel(),
          selectWidth: 260,
          processing: false,
          currentTheme: this.currentTheme,
          onSelect: (index: number) => {
            this.selectApplicationByIndex(index)
          }
        })
      }
    }
  }

  @Builder
  private applicationPolicyContent() {
    if (this.getSelectedApplication() === undefined) {
      EmptyStatePanel({
        title: PermissionEmptyStrings.DETAIL,
        currentTheme: this.currentTheme,
        verticalPadding: 28
      })
    } else {
      this.applicationControlRows(this.getSelectedApplication() as ManagedApplicationInfo)

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

      this.sixDPermissionRows(
        this.getSelectedApplication() as ManagedApplicationInfo,
        this.viewModel.state.selectedPermissionProfile
      )
    }
  }

  private getApplicationEmptyText(): string {
    return this.viewModel.state.inventoryMessage.length > 0 ? this.viewModel.state.inventoryMessage : PermissionEmptyStrings.APPLICATIONS
  }

  @Builder
  private applicationControlRows(app: ManagedApplicationInfo) {
    SectionSelectRow({
      title: PermissionApplicationStrings.INSTALL_POLICY,
      description: PermissionApplicationStrings.INSTALL_POLICY_DESC,
      options: this.getPolicyOptions(),
      selectedIndex: this.getPolicyIndex(app.installPolicy),
      value: this.formatPolicy(app.installPolicy),
      selectWidth: 116,
      processing: this.viewModel.state.processingAction,
      currentTheme: this.currentTheme,
      onSelect: (index: number) => {
        let nextPolicy = this.policyByIndex(index)
        if (nextPolicy !== app.installPolicy) {
          this.executePolicyAction((): Promise<PermissionActionResult> => this.viewModel.setSelectedInstallPolicy(nextPolicy))
        }
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionToggleRow({
      title: PermissionApplicationStrings.UNINSTALL_PROTECTED,
      description: PermissionApplicationStrings.UNINSTALL_PROTECTED_DESC,
      isOn: app.uninstallProtected,
      enabledValue: !this.viewModel.state.processingAction,
      opacityValue: this.viewModel.state.processingAction ? 0.72 : 1,
      currentTheme: this.currentTheme,
      onChange: (enabled: boolean) => {
        if (enabled !== app.uninstallProtected) {
          this.executePolicyAction((): Promise<PermissionActionResult> => this.viewModel.setSelectedUninstallProtected(enabled))
        }
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionSelectRow({
      title: PermissionApplicationStrings.RUNNING_POLICY,
      description: PermissionApplicationStrings.RUNNING_POLICY_DESC,
      options: this.getPolicyOptions(),
      selectedIndex: this.getPolicyIndex(app.runningPolicy),
      value: this.formatPolicy(app.runningPolicy),
      selectWidth: 116,
      processing: this.viewModel.state.processingAction,
      currentTheme: this.currentTheme,
      onSelect: (index: number) => {
        let nextPolicy = this.policyByIndex(index)
        if (nextPolicy !== app.runningPolicy) {
          this.executePolicyAction((): Promise<PermissionActionResult> => this.viewModel.setSelectedRunningPolicy(nextPolicy))
        }
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionSelectRow({
      title: PermissionApplicationStrings.NETWORK_POLICY,
      description: app.uid > 0 ? PermissionApplicationStrings.NETWORK_POLICY_DESC : PermissionApplicationStrings.MISSING_UID,
      options: this.getNetworkPolicyOptions(),
      selectedIndex: this.getNetworkPolicyIndex(app.networkPolicy),
      value: this.formatPolicy(app.networkPolicy),
      selectWidth: 116,
      processing: this.viewModel.state.processingAction || app.uid <= 0,
      currentTheme: this.currentTheme,
      onSelect: (index: number) => {
        let nextPolicy = this.networkPolicyByIndex(index)
        if (nextPolicy !== app.networkPolicy) {
          this.executePolicyAction((): Promise<PermissionActionResult> => this.viewModel.setSelectedNetworkPolicy(nextPolicy))
        }
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionToggleRow({
      title: PermissionApplicationStrings.KEEP_ALIVE,
      description: PermissionApplicationStrings.KEEP_ALIVE_DESC,
      isOn: app.keepAliveEnabled,
      enabledValue: !this.viewModel.state.processingAction,
      opacityValue: this.viewModel.state.processingAction ? 0.72 : 1,
      currentTheme: this.currentTheme,
      onChange: (enabled: boolean) => {
        if (enabled !== app.keepAliveEnabled) {
          this.executePolicyAction((): Promise<PermissionActionResult> => this.viewModel.setSelectedKeepAlive(enabled))
        }
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionToggleRow({
      title: PermissionApplicationStrings.AUTO_START,
      description: this.getAutoStartAbilityName(app).length > 0
        ? PermissionApplicationStrings.AUTO_START_DESC
        : PermissionApplicationStrings.MISSING_ABILITY,
      isOn: app.autoStartEnabled,
      enabledValue: !this.viewModel.state.processingAction && this.getAutoStartAbilityName(app).length > 0,
      opacityValue: this.viewModel.state.processingAction || this.getAutoStartAbilityName(app).length === 0 ? 0.72 : 1,
      currentTheme: this.currentTheme,
      onChange: (enabled: boolean) => {
        if (enabled !== app.autoStartEnabled) {
          this.executePolicyAction((): Promise<PermissionActionResult> => this.viewModel.setSelectedAutoStart(enabled))
        }
      }
    })

  }

  @Builder
  private sixDPermissionRows(
    app: ManagedApplicationInfo,
    profile: ApplicationPermissionProfile | null
  ) {
    if (profile === null) {
      Blank()
        .height(0)
    } else if (profile.message.length > 0 && profile.sixDGroups.length === 0) {
      Text(profile.message)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
    } else {
      ForEach(profile.sixDGroups, (item: SixDPermissionItem) => {
        SectionSelectRow({
          title: item.title,
          description: item.canManage ? PermissionApplicationStrings.SIX_D_GROUP_DESC : item.disabledReason,
          options: this.getSixDOptions(),
          selectedIndex: this.getSixDStateIndex(item.managedState),
          value: this.formatSixDState(item.managedState),
          selectWidth: 116,
          processing: this.viewModel.state.processingAction,
          currentTheme: this.currentTheme,
          onSelect: (index: number) => {
            let nextState = this.sixDStateByIndex(index)
            if (nextState !== item.managedState) {
              this.executePolicyAction((): Promise<PermissionActionResult> =>
                this.viewModel.setSelectedSixDPermissionState(item.groupKey, nextState)
              )
            }
          }
        })

        Divider()
          .color(AppColors.getColors(this.currentTheme).BORDER)
          .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
      }, (item: SixDPermissionItem): string => item.groupKey)
    }
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

  private formatSixDState(state: SixDManagedState): string {
    if (state === 'granted') {
      return PermissionApplicationStrings.POLICY_ALLOWED
    }
    if (state === 'denied') {
      return PermissionApplicationStrings.POLICY_DENIED
    }
    if (state === 'undeclared') {
      return PermissionSixDStrings.NO_DECLARED
    }
    if (state === 'unsupported') {
      return PermissionApplicationStrings.SIX_D_UNSUPPORTED
    }
    return PermissionApplicationStrings.POLICY_DEFAULT
  }

}
