import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { AppResources } from '../../../constants/AppResources'
import { ActionText, MessageText, ModuleText } from '../../../constants/StringCatalog'
import {
  PermissionEmptyStrings,
  PermissionApplicationStrings,
  PermissionLoadingStrings,
  PermissionPageStrings,
  PermissionSectionStrings,
  PermissionSummaryStrings
} from '../../../constants/modules/PermissionStrings'
import { ThemeMode } from '../../../theme/ThemeColors'
import { CompactSummaryCard } from '../../../components/CompactSummaryCard'
import { LoadingStatePanel } from '../../../components/LoadingStatePanel'
import { SectionCard } from '../../../components/SettingsSectionCard'
import { SubPageHeader } from '../../../components/SubPageHeader'
import { IconTextActionButton } from '../../../components/IconTextActionButton'
import { PermissionApplicationPolicyPanel } from '../../../components/permission-manage/ApplicationPolicyPanel'
import { PermissionPolicyTable } from '../../../components/permission-manage/PermissionPolicyTable'
import { PermissionTargetPanel } from '../../../components/permission-manage/PermissionTargetPanel'
import {
  PermissionActionResult,
  PermissionAppSnapshot,
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
const POLICY_EMPTY_VERTICAL_PADDING = 28

@ComponentV2
export struct PermissionPage {
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param viewModel: PermissionViewModel = new PermissionViewModel()
  @Event onBack: () => void = () => {}
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

  private async switchAccount(accountId: number): Promise<boolean> {
    if (accountId === this.viewModel.state.selectedAccountId) {
      return true
    }
    try {
      return await this.runWithLoading(
        'permission-account-switch',
        PermissionLoadingStrings.ACCOUNT_SWITCH,
        async (): Promise<boolean> => await this.viewModel.switchAccount(accountId)
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

  private async selectApplication(appKey: string): Promise<boolean> {
    if (appKey.length === 0) {
      this.viewModel.selectApplication('')
      return true
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
      LogUtils.warn(TAG, `selectApplication failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private hasProcessingAction(): boolean {
    return this.viewModel.state.processingActionKey.length > 0
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
    PermissionTargetPanel({
      initialized: this.viewModel.state.initialized,
      accounts: this.viewModel.state.accounts,
      selectedAccountId: this.viewModel.state.selectedAccountId,
      appSnapshots: this.viewModel.state.appSnapshots,
      filteredAppKeys: this.viewModel.state.filteredAppKeys,
      selectedAppKey: this.viewModel.state.selectedAppKey,
      installBlockKeyword: this.viewModel.state.installBlockKeyword,
      inventoryMessage: this.viewModel.state.inventoryMessage,
      loading: this.viewModel.state.loading,
      loadingSelectedApp: this.viewModel.state.loadingSelectedApp,
      processingActionKey: this.viewModel.state.processingActionKey,
      currentTheme: this.currentTheme,
      onSelectAccount: async (accountId: number): Promise<boolean> => {
        return await this.switchAccount(accountId)
      },
      onSelectApplication: async (appKey: string): Promise<boolean> => {
        return await this.selectApplication(appKey)
      },
      onInstallBlockKeywordChange: (value: string): void => {
        this.viewModel.setInstallBlockKeyword(value)
      },
      onSubmitInstallBlock: (): void => {
        this.executePolicyAction((): Promise<PermissionActionResult> =>
          this.viewModel.setDisallowedInstallByKeyword()
        )
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
  private currentPolicyContent() {
    PermissionPolicyTable({
      records: this.viewModel.state.policyRecords,
      loadingSelectedApp: this.viewModel.state.loadingSelectedApp,
      processingActionKey: this.viewModel.state.processingActionKey,
      currentTheme: this.currentTheme,
      onRequestDelete: (recordKey: string): void => {
        this.showDeletePolicyConfirm(recordKey)
      }
    })
  }

}
