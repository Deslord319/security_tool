import { ActionButtonStyles, AppColors, AppStyles } from '../../../constants/AppConstants'
import { AppResources } from '../../../constants/AppResources'
import { ActionText, ModuleText } from '../../../constants/StringCatalog'
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
import { SectionLabel, SectionSelectRow, SectionToggleRow } from '../../../components/SectionRows'
import { SectionCard } from '../../../components/SettingsSectionCard'
import { SubPageHeader } from '../../../components/SubPageHeader'
import { StyledTextInput } from '../../../components/StyledTextInput'
import { IconTextActionButton } from '../../../components/IconTextActionButton'
import {
  ApplicationPermissionProfile,
  ManagedApplicationInfo,
  PermissionActionResult,
  PermissionManagedAccount,
  PermissionPolicyRecord,
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
  @Local private hoveredPolicyActionKey: string = ''
  @Local private activePolicyActionKey: string = ''

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

  private canSubmitInstallBlock(): boolean {
    return !this.viewModel.state.processingAction && this.viewModel.state.installBlockKeyword.trim().length > 0
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

  private getPolicyDeleteButtonBackground(recordKey: string): ResourceColor {
    return ActionButtonStyles.getDangerBackground(
      this.currentTheme,
      this.hoveredPolicyActionKey === recordKey,
      this.activePolicyActionKey === recordKey
    )
  }

  private getPolicyDeleteButtonForeground(): ResourceColor {
    return ActionButtonStyles.getDangerForeground(this.currentTheme)
  }

  private showDeletePolicyConfirm(recordKey: string): void {
    DialogService.openConfirm(this.getUIContext(), {
      title: PermissionApplicationStrings.DELETE_POLICY_CONFIRM_TITLE,
      message: PermissionApplicationStrings.DELETE_POLICY_CONFIRM_MESSAGE,
      confirmText: ActionText.DELETE,
      cancelText: ActionText.CANCEL,
      onConfirm: () => {
        this.deletePolicyRecord(recordKey)
      }
    })
  }

  private deletePolicyRecord(recordKey: string): void {
    this.executePolicyAction((): Promise<PermissionActionResult> =>
      this.viewModel.deletePolicyRecord(recordKey)
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

          if (this.viewModel.state.initialized) {
            SectionCard({
              title: PermissionSectionStrings.CURRENT_POLICIES,
              currentTheme: this.currentTheme,
              content: () => {
                this.currentPolicyContent()
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
    if (!this.viewModel.state.initialized) {
      LoadingStatePanel({
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
    if (!this.viewModel.state.initialized) {
      LoadingStatePanel({
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

      this.installBlockInputRow()

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

  @Builder
  private installBlockInputRow() {
    Row() {
      SectionLabel({
        title: PermissionApplicationStrings.INSTALL_BLOCK_TARGET,
        description: PermissionApplicationStrings.INSTALL_BLOCK_TARGET_DESC,
        currentTheme: this.currentTheme
      })

      Row({ space: 10 }) {
        StyledTextInput({
          text: this.viewModel.state.installBlockKeyword,
          placeholder: PermissionApplicationStrings.INSTALL_BLOCK_PLACEHOLDER,
          controlWidth: 280,
          controlHeight: 36,
          radius: AppStyles.RADIUS_SM,
          currentTheme: this.currentTheme,
          onChange: (value: string) => {
            this.viewModel.setInstallBlockKeyword(value)
          }
        })

        IconTextActionButton({
          label: PermissionApplicationStrings.INSTALL_BLOCK_ACTION,
          icon: AppResources.ALERT_ICON,
          kind: 'danger',
          isEnabled: this.canSubmitInstallBlock(),
          currentTheme: this.currentTheme,
          onTap: () => {
            this.executePolicyAction((): Promise<PermissionActionResult> =>
              this.viewModel.setDisallowedInstallByKeyword()
            )
          }
        })
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 14,
      bottom: 14
    })
  }

  private getApplicationEmptyText(): string {
    return this.viewModel.state.inventoryMessage.length > 0 ? this.viewModel.state.inventoryMessage : PermissionEmptyStrings.APPLICATIONS
  }

  @Builder
  private currentPolicyContent() {
    if (this.viewModel.state.policyLoading && this.viewModel.state.policyRecords.length === 0) {
      LoadingStatePanel({
        indicatorSize: 22,
        currentTheme: this.currentTheme
      })
        .height(92)
    } else if (this.viewModel.state.policyRecords.length === 0) {
      Text(PermissionEmptyStrings.POLICIES)
        .width('100%')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .textAlign(TextAlign.Center)
        .padding({
          left: AppStyles.TABLE_HORIZONTAL_PADDING,
          right: AppStyles.TABLE_HORIZONTAL_PADDING,
          top: 28,
          bottom: 28
        })
    } else {
      Column({ space: 0 }) {
        this.policyTableHeader()
        ForEach(this.viewModel.state.policyRecords, (record: PermissionPolicyRecord, index: number) => {
          Column({ space: 0 }) {
            this.policyTableRow(record)
            if (index < this.viewModel.state.policyRecords.length - 1) {
              Divider()
                .color(AppColors.getColors(this.currentTheme).BORDER)
                .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
                .margin({
                  left: AppStyles.TABLE_DIVIDER_MARGIN,
                  right: AppStyles.TABLE_DIVIDER_MARGIN
                })
            }
          }
        }, (record: PermissionPolicyRecord): string => record.key)
      }
      .width('100%')
    }
  }

  @Builder
  private policyTableHeader() {
    Row() {
      this.policyHeaderCell(PermissionApplicationStrings.POLICY_TABLE_TYPE, 1.15)
      this.policyHeaderCell(PermissionApplicationStrings.POLICY_TABLE_TARGET, 2.2)
      this.policyHeaderCell(PermissionApplicationStrings.POLICY_TABLE_STATUS, 0.9)
      this.policyHeaderCell(PermissionApplicationStrings.POLICY_TABLE_SCOPE, 1.1)
      this.policyHeaderCell(PermissionApplicationStrings.POLICY_TABLE_ACTION, 0.8)
    }
    .width('100%')
    .padding({
      left: AppStyles.TABLE_HORIZONTAL_PADDING,
      right: AppStyles.TABLE_HORIZONTAL_PADDING,
      top: AppStyles.TABLE_HEADER_VERTICAL_PADDING,
      bottom: AppStyles.TABLE_HEADER_VERTICAL_PADDING
    })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  private policyHeaderCell(label: string, weight: number) {
    Text(label)
      .fontSize(AppStyles.FONT_SIZE_CAPTION)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .layoutWeight(weight)
  }

  @Builder
  private policyTableRow(record: PermissionPolicyRecord) {
    Row() {
      this.policyTextCell(record.policyType, 1.15)
      this.policyTargetCell(record, 2.2)
      this.policyTextCell(record.statusLabel, 0.9)
      this.policyTextCell(record.scopeLabel, 1.1)
      this.policyDeleteActionCell(record, 0.8)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      left: AppStyles.TABLE_HORIZONTAL_PADDING,
      right: AppStyles.TABLE_HORIZONTAL_PADDING,
      top: AppStyles.TABLE_ROW_VERTICAL_PADDING,
      bottom: AppStyles.TABLE_ROW_VERTICAL_PADDING
    })
  }

  @Builder
  private policyTextCell(value: string, weight: number) {
    Text(value)
      .fontSize(AppStyles.FONT_SIZE_BODY)
      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .layoutWeight(weight)
  }

  @Builder
  private policyTargetCell(record: PermissionPolicyRecord, weight: number) {
    Column({ space: 2 }) {
      Text(record.targetName)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(record.targetDetail)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(weight)
  }

  @Builder
  private policyDeleteActionCell(record: PermissionPolicyRecord, weight: number) {
    Row() {
      Text(PermissionApplicationStrings.DELETE_POLICY_ACTION)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Regular)
        .fontColor(this.getPolicyDeleteButtonForeground())
    }
    .height(ActionButtonStyles.CHIP_HEIGHT)
    .padding({
      left: ActionButtonStyles.CHIP_HORIZONTAL_PADDING,
      right: ActionButtonStyles.CHIP_HORIZONTAL_PADDING
    })
    .justifyContent(FlexAlign.Center)
    .borderRadius(AppStyles.RADIUS_MD)
    .backgroundColor(this.getPolicyDeleteButtonBackground(record.key))
    .opacity(this.viewModel.state.processingAction ? 0.56 : 1)
    .layoutWeight(weight)
    .onHover((isHover: boolean) => {
      if (this.viewModel.state.processingAction) {
        return
      }
      this.hoveredPolicyActionKey = isHover ? record.key : ''
    })
    .onTouch((event: TouchEvent) => {
      if (this.viewModel.state.processingAction) {
        return
      }
      if (event.type === TouchType.Down) {
        this.activePolicyActionKey = record.key
        return
      }
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.activePolicyActionKey = ''
      }
    })
    .onClick(() => {
      if (this.viewModel.state.processingAction) {
        return
      }
      this.activePolicyActionKey = ''
      this.showDeletePolicyConfirm(record.key)
    })
  }

  @Builder
  private applicationControlRows(app: ManagedApplicationInfo) {
    SectionToggleRow({
      title: PermissionApplicationStrings.UNINSTALL_PROTECTED,
      description: this.formatDescriptionWithState(
        PermissionApplicationStrings.UNINSTALL_PROTECTED_DESC,
        app.uninstallProtected ? PermissionApplicationStrings.ENABLED : PermissionApplicationStrings.DISABLED
      ),
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
      description: this.formatDescriptionWithState(PermissionApplicationStrings.RUNNING_POLICY_DESC, this.formatPolicy(app.runningPolicy)),
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
      description: app.uid > 0
        ? this.formatDescriptionWithState(PermissionApplicationStrings.NETWORK_POLICY_DESC, this.formatPolicy(app.networkPolicy))
        : PermissionApplicationStrings.MISSING_UID,
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

  }

  @Builder
  private sixDPermissionRows(
    app: ManagedApplicationInfo,
    profile: ApplicationPermissionProfile | null
  ) {
    if (profile !== null && profile.message.length > 0 && profile.sixDGroups.length === 0) {
      Text(profile.message)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
    } else {
      ForEach(this.getSixDItems(profile), (item: SixDPermissionItem) => {
        SectionSelectRow({
          title: item.title,
          description: this.getSixDDescription(item),
          options: this.getSixDOptions(),
          selectedIndex: this.getSixDStateIndex(item.managedState),
          value: this.formatSixDState(item.managedState),
          selectWidth: 116,
          processing: this.viewModel.state.processingAction,
          enabledValue: item.canManage,
          currentTheme: this.currentTheme,
          onSelect: (index: number) => {
            let nextState = this.sixDStateByIndex(index)
            if (item.canManage && nextState !== item.managedState) {
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

  private getSixDItems(profile: ApplicationPermissionProfile | null): SixDPermissionItem[] {
    if (profile !== null) {
      return profile.sixDGroups
    }
    return [
      this.createPendingSixDItem('downloads', PermissionSixDStrings.DOWNLOADS),
      this.createPendingSixDItem('desktop', PermissionSixDStrings.DESKTOP),
      this.createPendingSixDItem('documents', PermissionSixDStrings.DOCUMENTS),
      this.createPendingSixDItem('gallery', PermissionSixDStrings.GALLERY),
      this.createPendingSixDItem('music', PermissionSixDStrings.MUSIC),
      this.createPendingSixDItem('document_file', PermissionSixDStrings.DOCUMENT_FILE)
    ]
  }

  private createPendingSixDItem(groupKey: string, title: string): SixDPermissionItem {
    return {
      groupKey: groupKey,
      title: title,
      permissionNames: [],
      declaredPermissions: [],
      managedState: 'unsupported',
      canManage: false,
      disabledReason: PermissionSixDStrings.DETAIL_LOADING
    } as SixDPermissionItem
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

  private formatDescriptionWithState(description: string, state: string): string {
    return `${description} · ${PermissionApplicationStrings.CURRENT_STATE_PREFIX}：${state}`
  }

  private getSixDDescription(item: SixDPermissionItem): string {
    if (!item.canManage) {
      return item.disabledReason
    }
    return item.disabledReason.length > 0 ? item.disabledReason : PermissionApplicationStrings.SIX_D_GROUP_DESC
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
