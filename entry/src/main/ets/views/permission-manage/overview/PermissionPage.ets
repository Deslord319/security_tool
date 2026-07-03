import { ActionButtonStyles, AppColors, AppStyles } from '../../../constants/AppConstants'
import { AppResources } from '../../../constants/AppResources'
import { ActionText, MessageText, ModuleText } from '../../../constants/StringCatalog'
import {
  PermissionEmptyStrings,
  PermissionAccountStrings,
  PermissionApplicationStrings,
  PermissionLoadingStrings,
  PermissionPageStrings,
  PermissionSectionStrings,
  PermissionSummaryStrings
} from '../../../constants/modules/PermissionStrings'
import { ThemeMode } from '../../../theme/ThemeColors'
import { CompactSummaryCard } from '../../../components/CompactSummaryCard'
import { LoadingStatePanel } from '../../../components/LoadingStatePanel'
import { SectionLabel } from '../../../components/SectionRows'
import { SectionCard } from '../../../components/SettingsSectionCard'
import { SubPageHeader } from '../../../components/SubPageHeader'
import { StyledTextInput } from '../../../components/StyledTextInput'
import { IconTextActionButton } from '../../../components/IconTextActionButton'
import { AsyncSelectRow } from '../../../components/AsyncSelectRow'
import { PermissionApplicationPolicyPanel } from '../../../components/permission-manage/ApplicationPolicyPanel'
import {
  PermissionActionResult,
  PermissionAppSnapshot,
  PermissionManagedAccount,
  PermissionPolicyRecord,
  PermissionPolicyState,
  ThreeDManagedState,
  ThreeDPermissionItem
} from '../../../models/PermissionModels'
import { PermissionViewModel } from '../../../viewmodels/permission-manage/PermissionViewModel'
import { DialogService } from '../../../utils/DialogService'
import { LogUtils } from '../../../utils/LogUtils'
import { TimedLoadingDialogRunner } from '../../../utils/TimedLoadingDialogRunner'

const TAG = 'PermissionPage'
const PERMISSION_LOADING_MIN_DURATION_MS = 500
const PERMISSION_LOADING_RENDER_READY_DELAY_MS = 32
const INSTALL_BLOCK_INPUT_WIDTH = 280
const TARGET_APPLICATION_SELECT_WIDTH =
  INSTALL_BLOCK_INPUT_WIDTH +
    ActionButtonStyles.HORIZONTAL_PADDING_START +
    ActionButtonStyles.ICON_SIZE +
    AppStyles.PADDING_SM +
    PermissionApplicationStrings.INSTALL_BLOCK_ACTION.length * ActionButtonStyles.FONT_SIZE +
    ActionButtonStyles.HORIZONTAL_PADDING_END +
    AppStyles.CONTROL_ROW_ACTION_GAP -
    (AppStyles.CONTROL_ROW_HORIZONTAL_PADDING - AppStyles.PADDING_MD)
const POLICY_EMPTY_VERTICAL_PADDING = 28
const POLICY_ACTION_COLUMN_WIDTH = 88

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
    this.viewModel.refreshAccountsAndApplicationList().catch((err: Error) => {
      LogUtils.warn(TAG, `refreshAccountsAndApplicationList on appear failed: ${JSON.stringify(err)}`)
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

  private getSelectedAppSnapshot(): PermissionAppSnapshot | undefined {
    let selectedAppKey = this.viewModel.state.selectedAppKey
    if (selectedAppKey.length === 0) {
      return undefined
    }
    return this.viewModel.state.appSnapshots.find((snapshot: PermissionAppSnapshot): boolean =>
      snapshot.appKey === selectedAppKey
    )
  }

  private getApplicationOptions(): string[] {
    let options: string[] = [PermissionSectionStrings.TARGET_APPLICATION_PLACEHOLDER]
    this.viewModel.state.filteredAppKeys.forEach((appKey: string): void => {
      let snapshot = this.viewModel.state.appSnapshots.find((s: PermissionAppSnapshot): boolean => s.appKey === appKey)
      if (snapshot !== undefined) {
        options.push(this.formatApplicationOption(snapshot))
      }
    })
    return options
  }

  private formatApplicationOption(snapshot: PermissionAppSnapshot): string {
    if (snapshot.label === snapshot.bundleName) {
      return snapshot.bundleName
    }
    return `${snapshot.label} (${snapshot.bundleName})`
  }

  private getSelectedApplicationIndex(): number {
    let index = this.viewModel.state.filteredAppKeys.indexOf(this.viewModel.state.selectedAppKey)
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
    let appKey = this.viewModel.state.filteredAppKeys[appIndex]
    if (!appKey) {
      return false
    }
    if (appKey === this.viewModel.state.selectedAppKey) {
      return true
    }
    try {
      this.viewModel.selectApplicationAndLoadDetails(appKey)
        .then((success: boolean): void => {
          if (!success) {
            DialogService.openFailure(
              this.getUIContext(),
              this.viewModel.state.errorMessage || PermissionApplicationStrings.POLICY_READ_FAILED
            )
          }
        })
        .catch((err: Error): void => {
          LogUtils.warn(TAG, `select application details failed: ${JSON.stringify(err)}`)
          DialogService.openFailure(this.getUIContext(), PermissionApplicationStrings.POLICY_READ_FAILED)
        })
      return true
    } catch (err) {
      LogUtils.warn(TAG, `selectApplicationByIndex failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private canSubmitInstallBlock(): boolean {
    return this.viewModel.state.processingActionKey.length === 0 && this.viewModel.state.installBlockKeyword.trim().length > 0
  }

  private hasProcessingAction(): boolean {
    return this.viewModel.state.processingActionKey.length > 0
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

  private getDeletePolicyActionKey(recordKey: string): string {
    return `delete-policy:${recordKey}`
  }

  private executePolicyAction(action: () => Promise<PermissionActionResult>): void {
    this.executePolicyActionAsync(action).catch((err: Error) => {
      LogUtils.warn(TAG, `executePolicyAction failed: ${JSON.stringify(err)}`)
    })
  }

  private async executePolicyActionAsync(action: () => Promise<PermissionActionResult>): Promise<void> {
    await this.executePolicyActionWithResult(action)
  }

  private async executePolicyActionWithResult(action: () => Promise<PermissionActionResult>): Promise<boolean> {
    let result = await action()
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
    this.executePolicyAction((): Promise<PermissionActionResult> => this.viewModel.deletePolicyRecord(recordKey))
  }

  private canRefreshApplicationInventory(): boolean {
    return this.viewModel.state.initialized &&
      !this.viewModel.state.loading &&
      !this.viewModel.state.loadingSelectedApp &&
      !this.hasProcessingAction()
  }

  private refreshApplicationInventory(): void {
    this.refreshApplicationInventoryAsync().catch((err: Error) => {
      LogUtils.warn(TAG, `refreshApplicationInventory failed: ${JSON.stringify(err)}`)
      DialogService.openFailure(this.getUIContext(), MessageText.RETRY_LATER)
    })
  }

  private async refreshApplicationInventoryAsync(): Promise<void> {
    let success = await this.viewModel.refreshAccountsAndApplicationList()
    if (!success) {
      DialogService.openFailure(this.getUIContext(), this.viewModel.state.errorMessage || MessageText.RETRY_LATER)
    }
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
            headerAction: () => {
              this.applicationRefreshAction()
            },
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
  private applicationRefreshAction() {
    Row({ space: AppStyles.PADDING_SM }) {
      if (this.viewModel.state.loading && this.viewModel.state.initialized) {
        LoadingProgress()
          .width(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
          .height(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
          .color(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      }

      IconTextActionButton({
        label: PermissionApplicationStrings.REFRESH_APPLICATIONS,
        showIcon: false,
        isEnabled: this.canRefreshApplicationInventory(),
        currentTheme: this.currentTheme,
        onTap: () => this.refreshApplicationInventory()
      })
    }
    .alignItems(VerticalAlign.Center)
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
        enabledValue: !this.hasProcessingAction() && !this.viewModel.state.loadingSelectedApp,
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

      if (this.viewModel.state.filteredAppKeys.length === 0) {
        this.applicationInventoryEmptyText()
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
      selectWidth: TARGET_APPLICATION_SELECT_WIDTH,
      processing: this.viewModel.state.loadingSelectedApp,
      enabledValue: !this.hasProcessingAction(),
      currentTheme: this.currentTheme,
      onSelectAsync: async (index: number): Promise<boolean> => {
        return await this.selectApplicationByIndex(index)
      }
    })
  }

  @Builder
  private applicationPolicyContent() {
    if (this.getSelectedAppSnapshot() === undefined) {
      Text(PermissionEmptyStrings.SELECT_APPLICATION_FIRST)
        .width('100%')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .textAlign(TextAlign.Center)
        .padding({
          left: AppStyles.TABLE_HORIZONTAL_PADDING,
          right: AppStyles.TABLE_HORIZONTAL_PADDING,
          top: POLICY_EMPTY_VERTICAL_PADDING,
          bottom: POLICY_EMPTY_VERTICAL_PADDING
        })
    } else {
      ForEach([this.getSelectedAppSnapshot() as PermissionAppSnapshot], (snapshot: PermissionAppSnapshot) => {
        PermissionApplicationPolicyPanel({
          appKey: snapshot.appKey,
          uid: snapshot.uid,
          uninstallProtected: snapshot.uninstallProtected,
          runningBlocked: snapshot.runningBlocked,
          networkBlocked: snapshot.networkBlocked,
          threeDGroups: snapshot.threeDGroups,
          threeDLoadState: snapshot.threeDLoadState,
          threeDMessage: snapshot.threeDMessage,
          loadingSelectedApp: this.viewModel.state.loadingSelectedApp,
          processingActionKey: this.viewModel.state.processingActionKey,
          currentTheme: this.currentTheme,
          onSetUninstallProtected: async (enabled: boolean): Promise<boolean> => {
            return await this.executePolicyActionWithResult((): Promise<PermissionActionResult> =>
              this.viewModel.setSelectedUninstallProtected(enabled)
            )
          },
          onSetRunningPolicy: async (policy: PermissionPolicyState): Promise<boolean> => {
            return await this.executePolicyActionWithResult((): Promise<PermissionActionResult> =>
              this.viewModel.setSelectedRunningPolicy(policy)
            )
          },
          onSetNetworkPolicy: async (policy: PermissionPolicyState): Promise<boolean> => {
            return await this.executePolicyActionWithResult((): Promise<PermissionActionResult> =>
              this.viewModel.setSelectedNetworkPolicy(policy)
            )
          },
          onSetThreeDPermissionState: async (groupKey: string, state: ThreeDManagedState): Promise<boolean> => {
            return await this.executePolicyActionWithResult((): Promise<PermissionActionResult> =>
              this.viewModel.setSelectedThreeDPermissionState(groupKey, state)
            )
          }
        })
      }, (snapshot: PermissionAppSnapshot): string => this.getApplicationPolicyRenderKey(snapshot))
    }
  }

  private getApplicationPolicyRenderKey(snapshot: PermissionAppSnapshot | undefined): string {
    if (snapshot === undefined) {
      return 'empty'
    }
    let threeDStateKey = snapshot.threeDGroups
      .map((item: ThreeDPermissionItem): string =>
        `${item.groupKey}:${item.managedState}:${item.canManage}:${item.disabledReason}`
      )
      .join('|')
    return `${snapshot.appKey}:${snapshot.uid}:${snapshot.uninstallProtected}:${snapshot.runningBlocked}:` +
      `${snapshot.networkBlocked}:${snapshot.threeDLoadState}:${snapshot.threeDMessage}:${threeDStateKey}`
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
          controlWidth: INSTALL_BLOCK_INPUT_WIDTH,
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
  private applicationInventoryEmptyText() {
    Text(this.getApplicationEmptyText())
      .width('100%')
      .fontSize(AppStyles.FONT_SIZE_BODY)
      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .textAlign(TextAlign.Center)
      .padding({
        left: AppStyles.TABLE_HORIZONTAL_PADDING,
        right: AppStyles.TABLE_HORIZONTAL_PADDING,
        top: POLICY_EMPTY_VERTICAL_PADDING,
        bottom: POLICY_EMPTY_VERTICAL_PADDING
      })
  }

  @Builder
  private currentPolicyContent() {
    if (this.viewModel.state.loadingSelectedApp && this.viewModel.state.policyRecords.length === 0) {
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
          top: POLICY_EMPTY_VERTICAL_PADDING,
          bottom: POLICY_EMPTY_VERTICAL_PADDING
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
      this.policyActionHeaderCell(PermissionApplicationStrings.POLICY_TABLE_ACTION)
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
  private policyActionHeaderCell(label: string) {
    Text(label)
      .fontSize(AppStyles.FONT_SIZE_CAPTION)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .textAlign(TextAlign.Center)
      .width(POLICY_ACTION_COLUMN_WIDTH)
  }

  @Builder
  private policyTableRow(record: PermissionPolicyRecord) {
    Row() {
      this.policyTextCell(record.policyType, 1.15)
      this.policyTargetCell(record, 2.2)
      this.policyTextCell(record.statusLabel, 0.9)
      this.policyTextCell(record.scopeLabel, 1.1)
      this.policyDeleteActionCell(record)
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
  private policyDeleteActionCell(record: PermissionPolicyRecord) {
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
    .width(POLICY_ACTION_COLUMN_WIDTH)
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

}
