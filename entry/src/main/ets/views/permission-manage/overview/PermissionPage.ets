import { ActionButtonStyles, AppColors, AppStyles } from '../../../constants/AppConstants'
import { AppResources } from '../../../constants/AppResources'
import { ActionText, ModuleText } from '../../../constants/StringCatalog'
import {
  PermissionEmptyStrings,
  PermissionAccountStrings,
  PermissionApplicationStrings,
  PermissionLoadingStrings,
  PermissionPageStrings,
  PermissionSectionStrings,
  PermissionSixDStrings,
  PermissionSummaryStrings
} from '../../../constants/modules/PermissionStrings'
import { ThemeMode } from '../../../theme/ThemeColors'
import { CompactSummaryCard } from '../../../components/CompactSummaryCard'
import { EmptyStatePanel } from '../../../components/EmptyStatePanel'
import { LoadingStatePanel } from '../../../components/LoadingStatePanel'
import { SectionLabel } from '../../../components/SectionRows'
import { SectionCard } from '../../../components/SettingsSectionCard'
import { SubPageHeader } from '../../../components/SubPageHeader'
import { StyledTextInput } from '../../../components/StyledTextInput'
import { IconTextActionButton } from '../../../components/IconTextActionButton'
import { AsyncSelectRow } from '../../../components/AsyncSelectRow'
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
import { TimedLoadingDialogRunner } from '../../../utils/TimedLoadingDialogRunner'

const TAG = 'PermissionPage'
const PERMISSION_LOADING_MIN_DURATION_MS = 500
const PERMISSION_LOADING_RENDER_READY_DELAY_MS = 32

@ComponentV2
export struct PermissionPage {
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param viewModel: PermissionViewModel = new PermissionViewModel()
  @Event onBack: () => void = () => {}
  @Local private hoveredPolicyActionKey: string = ''
  @Local private activePolicyActionKey: string = ''
  private readonly loadingRunner: TimedLoadingDialogRunner = new TimedLoadingDialogRunner(TAG)

  aboutToAppear() {
    if (this.viewModel.state.loading) {
      return
    }
    if (!this.viewModel.state.initialized) {
      this.viewModel.loadInitialState().catch((err: Error) => {
        LogUtils.warn(TAG, `loadInitialState failed: ${JSON.stringify(err)}`)
      })
      return
    }
    this.viewModel.refreshApplicationList().catch((err: Error) => {
      LogUtils.warn(TAG, `refreshApplicationList on appear failed: ${JSON.stringify(err)}`)
    })
  }

  private getAccountOptions(): string[] {
    return this.viewModel.state.accounts.map((account: PermissionManagedAccount): string => account.displayName)
  }

  private getSelectedAccountIndex(): number {
    let index = this.viewModel.state.accounts.findIndex((account: PermissionManagedAccount): boolean =>
      account.accountId === this.viewModel.state.selectedAccountId
    )
    return index >= 0 ? index : 0
  }

  private async switchAccountByIndex(index: number): Promise<boolean> {
    let account = this.viewModel.state.accounts[index]
    if (!account) {
      return false
    }
    if (account.accountId === this.viewModel.state.selectedAccountId) {
      return true
    }
    try {
      return await this.runWithLoading(
        'permission-account-switch',
        PermissionLoadingStrings.ACCOUNT_SWITCH,
        async (): Promise<boolean> => await this.viewModel.switchAccount(account.accountId)
      )
    } catch (err) {
      LogUtils.warn(TAG, `switchAccount failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private getSelectedApplication(): ManagedApplicationInfo | undefined {
    return this.viewModel.state.filteredApplications.find((app: ManagedApplicationInfo): boolean =>
      app.key === this.viewModel.state.selectedAppKey
    )
  }

  private getApplicationOptions(): string[] {
    let options: string[] = [PermissionSectionStrings.TARGET_APPLICATION_PLACEHOLDER]
    this.viewModel.state.filteredApplications.forEach((app: ManagedApplicationInfo): void => {
      options.push(this.formatApplicationOption(app))
    })
    return options
  }

  private formatApplicationOption(app: ManagedApplicationInfo): string {
    if (app.label === app.bundleName) {
      return app.bundleName
    }
    return `${app.label} (${app.bundleName})`
  }

  private getSelectedApplicationIndex(): number {
    let index = this.viewModel.state.filteredApplications.findIndex((app: ManagedApplicationInfo): boolean =>
      app.key === this.viewModel.state.selectedAppKey
    )
    if (index < 0) {
      return 0
    }
    return index + 1
  }

  private async selectApplicationByIndex(index: number): Promise<boolean> {
    if (index <= 0) {
      this.viewModel.selectApplication('')
      return true
    }
    let appIndex = index - 1
    let app = this.viewModel.state.filteredApplications[appIndex]
    if (!app) {
      return false
    }
    if (app.key === this.viewModel.state.selectedAppKey) {
      return true
    }
    try {
      return await this.runWithLoading(
        'permission-target-application',
        PermissionLoadingStrings.TARGET_APPLICATION,
        async (): Promise<boolean> => {
          await this.viewModel.selectApplicationAndLoadDetails(app.key)
          return true
        }
      )
    } catch (err) {
      LogUtils.warn(TAG, `selectApplicationByIndex failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private getRunningPolicyOptions(): string[] {
    return [
      PermissionApplicationStrings.POLICY_ALLOWED,
      PermissionApplicationStrings.POLICY_DENIED
    ]
  }

  private getNetworkPolicyOptions(): string[] {
    return [
      PermissionApplicationStrings.POLICY_ALLOWED,
      PermissionApplicationStrings.POLICY_DENIED
    ]
  }

  private getUninstallProtectedOptions(): string[] {
    return [
      PermissionApplicationStrings.DISABLED,
      PermissionApplicationStrings.ENABLED
    ]
  }

  private getSixDOptions(): string[] {
    return [
      PermissionApplicationStrings.POLICY_DEFAULT,
      PermissionApplicationStrings.POLICY_ALLOWED,
      PermissionApplicationStrings.POLICY_DENIED
    ]
  }

  private getSixDOptionsForItem(item: SixDPermissionItem): string[] {
    if (item.canManage) {
      return this.getSixDOptions()
    }
    return [this.formatSixDState(item.managedState)]
  }

  private runningPolicyByIndex(index: number): PermissionPolicyState {
    return index === 1 ? 'denied' : 'default'
  }

  private networkPolicyByIndex(index: number): PermissionPolicyState {
    return index === 1 ? 'denied' : 'default'
  }

  private uninstallProtectedByIndex(index: number): boolean {
    return index === 1
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

  private getRunningPolicyIndex(policy: PermissionPolicyState): number {
    return policy === 'denied' ? 1 : 0
  }

  private getNetworkPolicyIndex(policy: PermissionPolicyState): number {
    return policy === 'denied' ? 1 : 0
  }

  private getUninstallProtectedIndex(enabled: boolean): number {
    return enabled ? 1 : 0
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

  private getSixDStateIndexForItem(item: SixDPermissionItem): number {
    return item.canManage ? this.getSixDStateIndex(item.managedState) : 0
  }

  private canSubmitInstallBlock(): boolean {
    return !this.viewModel.state.processingAction && this.viewModel.state.installBlockKeyword.trim().length > 0
  }

  private hasProcessingAction(): boolean {
    return this.viewModel.state.processingAction
  }

  private isActionProcessing(actionKey: string): boolean {
    return this.viewModel.state.processingActionKey === actionKey
  }

  private canOperateAction(actionKey: string): boolean {
    return !this.hasProcessingAction() || this.isActionProcessing(actionKey)
  }

  private getInstallActionKey(): string {
    return 'install-deny'
  }

  private getUninstallActionKey(app: ManagedApplicationInfo): string {
    return `uninstall:${app.key}`
  }

  private getRunningActionKey(app: ManagedApplicationInfo): string {
    return `running:${app.key}`
  }

  private getNetworkActionKey(app: ManagedApplicationInfo): string {
    return `network:${app.key}`
  }

  private getSixDActionKey(app: ManagedApplicationInfo, item: SixDPermissionItem): string {
    return `sixd:${app.key}:${item.groupKey}`
  }

  private getDeletePolicyActionKey(recordKey: string): string {
    return `delete-policy:${recordKey}`
  }

  private executePolicyAction(
    action: () => Promise<PermissionActionResult>,
    sceneTag: string = 'permission-policy-action',
    loadingMessage: string = PermissionLoadingStrings.POLICY_ACTION
  ): void {
    this.executePolicyActionAsync(action, sceneTag, loadingMessage).catch((err: Error) => {
      LogUtils.warn(TAG, `executePolicyAction failed: ${JSON.stringify(err)}`)
    })
  }

  private async executePolicyActionAsync(
    action: () => Promise<PermissionActionResult>,
    sceneTag: string,
    loadingMessage: string
  ): Promise<void> {
    await this.executePolicyActionWithResult(action, sceneTag, loadingMessage)
  }

  private async executePolicyActionWithResult(
    action: () => Promise<PermissionActionResult>,
    sceneTag: string = 'permission-policy-action',
    loadingMessage: string = PermissionLoadingStrings.POLICY_ACTION
  ): Promise<boolean> {
    let result = await this.runWithLoading(
      sceneTag,
      loadingMessage,
      async (): Promise<PermissionActionResult> => await action()
    )
    if (!result.success) {
      DialogService.openFailure(this.getUIContext(), result.message)
      return false
    }
    return true
  }

  private getPolicyDeleteButtonBackground(recordKey: string): ResourceColor {
    return ActionButtonStyles.getDangerBackground(
      this.currentTheme,
      this.hoveredPolicyActionKey === recordKey && !this.hasProcessingAction(),
      this.activePolicyActionKey === recordKey && !this.hasProcessingAction()
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
    this.executePolicyAction(
      (): Promise<PermissionActionResult> => this.viewModel.deletePolicyRecord(recordKey),
      'permission-policy-delete',
      PermissionLoadingStrings.POLICY_DELETE
    )
  }

  private async runWithLoading<T>(
    sceneTag: string,
    message: string,
    task: () => Promise<T>
  ): Promise<T> {
    return await this.loadingRunner.run(
      sceneTag,
      message,
      task,
      (dialogMessage: string): CustomDialogController =>
        DialogService.createLoadingController(dialogMessage, this.currentTheme),
      PERMISSION_LOADING_MIN_DURATION_MS,
      PERMISSION_LOADING_RENDER_READY_DELAY_MS
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

          SectionCard({
            title: PermissionSectionStrings.APPLICATION_CONTROL,
            currentTheme: this.currentTheme,
            content: () => {
              this.applicationPolicyContent()
            }
          })

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
      AsyncSelectRow({
        label: PermissionAccountStrings.SELECT_TITLE,
        description: PermissionAccountStrings.SELECT_DESC,
        options: this.getAccountOptions(),
        selectedIndex: this.getSelectedAccountIndex(),
        selectWidth: AppStyles.SELECT_WIDTH_DEFAULT,
        processing: this.viewModel.state.loading || this.viewModel.state.accounts.length === 0,
        enabledValue: !this.hasProcessingAction() && !this.viewModel.state.selectedAppRefreshing,
        currentTheme: this.currentTheme,
        onSelectAsync: async (index: number): Promise<boolean> => {
          return await this.switchAccountByIndex(index)
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
        this.targetApplicationSelectRow()
      }
    }
  }

  @Builder
  private targetApplicationSelectRow() {
    AsyncSelectRow({
      label: PermissionSectionStrings.TARGET_APPLICATION,
      description: PermissionSectionStrings.TARGET_APPLICATION_DESC,
      options: this.getApplicationOptions(),
      selectedIndex: this.getSelectedApplicationIndex(),
      selectWidth: 280,
      processing: this.viewModel.state.selectedAppRefreshing,
      enabledValue: !this.hasProcessingAction(),
      currentTheme: this.currentTheme,
      onSelectAsync: async (index: number): Promise<boolean> => {
        return await this.selectApplicationByIndex(index)
      }
    })
  }

  @Builder
  private applicationPolicyContent() {
    if (this.getSelectedApplication() === undefined) {
      EmptyStatePanel({
        title: PermissionEmptyStrings.SELECT_APPLICATION_FIRST,
        currentTheme: this.currentTheme,
        verticalPadding: 28
      })
    } else {
      Column({ space: 0 }) {
        if (this.viewModel.state.selectedAppRefreshing) {
          Row({ space: 8 }) {
            LoadingProgress()
              .width(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
              .height(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
              .color(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

            Text(PermissionSixDStrings.DETAIL_LOADING)
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding({ left: 16, right: 16, top: 12, bottom: 8 })
        }

        this.applicationControlRows(this.getSelectedApplication() as ManagedApplicationInfo)

        Divider()
          .color(AppColors.getColors(this.currentTheme).BORDER)
          .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

        this.sixDPermissionRows(
          this.getSelectedApplication() as ManagedApplicationInfo,
          this.viewModel.state.selectedPermissionProfile
        )
      }
      .width('100%')
      .id(`permission-policy-content-${this.viewModel.state.selectedAppKey}`)
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
          enabledValue: !this.hasProcessingAction(),
          currentTheme: this.currentTheme,
          onChange: (value: string) => {
            this.viewModel.setInstallBlockKeyword(value)
          }
        })

        if (this.isActionProcessing(this.getInstallActionKey())) {
          LoadingProgress()
            .width(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
            .height(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
            .color(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        }

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
    Row({ space: 6 }) {
      if (this.isActionProcessing(this.getDeletePolicyActionKey(record.key))) {
        LoadingProgress()
          .width(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
          .height(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
          .color(this.getPolicyDeleteButtonForeground())
      }

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
    .opacity(this.canOperateAction(this.getDeletePolicyActionKey(record.key)) ? 1 : 0.56)
    .layoutWeight(weight)
    .onHover((isHover: boolean) => {
      if (this.hasProcessingAction()) {
        return
      }
      this.hoveredPolicyActionKey = isHover ? record.key : ''
    })
    .onTouch((event: TouchEvent) => {
      if (this.hasProcessingAction()) {
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
      if (this.hasProcessingAction()) {
        return
      }
      this.activePolicyActionKey = ''
      this.showDeletePolicyConfirm(record.key)
    })
  }

  @Builder
  private applicationControlRows(app: ManagedApplicationInfo) {
    this.uninstallProtectedActionRow(app)

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    AsyncSelectRow({
      label: PermissionApplicationStrings.RUNNING_POLICY,
      description: this.formatDescriptionWithState(PermissionApplicationStrings.RUNNING_POLICY_DESC, this.formatRuntimePolicy(app.runningPolicy)),
      options: this.getRunningPolicyOptions(),
      selectedIndex: this.getRunningPolicyIndex(app.runningPolicy),
      selectWidth: 116,
      processing: this.isActionProcessing(this.getRunningActionKey(app)),
      enabledValue: this.canOperateAction(this.getRunningActionKey(app)),
      currentTheme: this.currentTheme,
      onSelectAsync: async (index: number): Promise<boolean> => {
        let nextPolicy = this.runningPolicyByIndex(index)
        if (nextPolicy !== app.runningPolicy) {
          return await this.executePolicyActionWithResult((): Promise<PermissionActionResult> =>
            this.viewModel.setSelectedRunningPolicy(nextPolicy)
          )
        }
        return true
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    AsyncSelectRow({
      label: PermissionApplicationStrings.NETWORK_POLICY,
      description: app.uid > 0
        ? this.formatDescriptionWithState(PermissionApplicationStrings.NETWORK_POLICY_DESC, this.formatRuntimePolicy(app.networkPolicy))
        : PermissionApplicationStrings.MISSING_UID,
      options: this.getNetworkPolicyOptions(),
      selectedIndex: this.getNetworkPolicyIndex(app.networkPolicy),
      selectWidth: 116,
      processing: this.isActionProcessing(this.getNetworkActionKey(app)),
      enabledValue: this.canOperateAction(this.getNetworkActionKey(app)) && app.uid > 0,
      currentTheme: this.currentTheme,
      onSelectAsync: async (index: number): Promise<boolean> => {
        let nextPolicy = this.networkPolicyByIndex(index)
        if (nextPolicy !== app.networkPolicy) {
          return await this.executePolicyActionWithResult((): Promise<PermissionActionResult> =>
            this.viewModel.setSelectedNetworkPolicy(nextPolicy)
          )
        }
        return true
      }
    })

  }

  @Builder
  private uninstallProtectedActionRow(app: ManagedApplicationInfo) {
    AsyncSelectRow({
      label: PermissionApplicationStrings.UNINSTALL_PROTECTED,
      description: this.formatDescriptionWithState(
        PermissionApplicationStrings.UNINSTALL_PROTECTED_DESC,
        app.uninstallProtected ? PermissionApplicationStrings.ENABLED : PermissionApplicationStrings.DISABLED
      ),
      options: this.getUninstallProtectedOptions(),
      selectedIndex: this.getUninstallProtectedIndex(app.uninstallProtected),
      selectWidth: 116,
      processing: this.isActionProcessing(this.getUninstallActionKey(app)),
      enabledValue: this.canOperateAction(this.getUninstallActionKey(app)),
      currentTheme: this.currentTheme,
      onSelectAsync: async (index: number): Promise<boolean> => {
        let nextEnabled = this.uninstallProtectedByIndex(index)
        if (nextEnabled !== app.uninstallProtected) {
          return await this.executePolicyActionWithResult((): Promise<PermissionActionResult> =>
            this.viewModel.setSelectedUninstallProtected(nextEnabled)
          )
        }
        return true
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
        AsyncSelectRow({
          label: item.title,
          description: this.getSixDDescription(item),
          options: this.getSixDOptionsForItem(item),
          selectedIndex: this.getSixDStateIndexForItem(item),
          selectWidth: 116,
          processing: this.isActionProcessing(this.getSixDActionKey(app, item)),
          enabledValue: this.canOperateAction(this.getSixDActionKey(app, item)) && item.canManage,
          currentTheme: this.currentTheme,
          onSelectAsync: async (index: number): Promise<boolean> => {
            let nextState = this.sixDStateByIndex(index)
            if (item.canManage && nextState !== item.managedState) {
              return await this.executePolicyActionWithResult((): Promise<PermissionActionResult> =>
                this.viewModel.setSelectedSixDPermissionState(item.groupKey, nextState)
              )
            }
            return item.canManage
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
      this.createPendingSixDItem('documents', PermissionSixDStrings.DOCUMENTS)
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

  private formatRuntimePolicy(policy: PermissionPolicyState): string {
    return policy === 'denied' ? PermissionApplicationStrings.POLICY_DENIED : PermissionApplicationStrings.POLICY_ALLOWED
  }

  private formatDescriptionWithState(description: string, state: string): string {
    return `${description} · ${PermissionApplicationStrings.CURRENT_STATE_PREFIX}：${state}`
  }

  private getSixDDescription(item: SixDPermissionItem): string {
    let baseDescription = this.getSixDBaseDescription(item.groupKey)
    if (item.canManage && item.disabledReason.length > 0) {
      return `${baseDescription} · ${item.disabledReason}`
    }
    return baseDescription
  }

  private getSixDBaseDescription(groupKey: string): string {
    if (groupKey === 'downloads') {
      return PermissionSixDStrings.DOWNLOADS_DESC
    }
    if (groupKey === 'desktop') {
      return PermissionSixDStrings.DESKTOP_DESC
    }
    if (groupKey === 'documents') {
      return PermissionSixDStrings.DOCUMENTS_DESC
    }
    return PermissionApplicationStrings.SIX_D_GROUP_DESC
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
