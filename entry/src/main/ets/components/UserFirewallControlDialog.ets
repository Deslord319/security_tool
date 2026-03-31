import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { netFirewall } from '@kit.NetworkKit'
import { AppColors, AppStyles } from '../constants/AppConstants'
import { FirewallUserApplyMode, UserFirewallOption } from '../models/DataModels'
import { FirewallCustomRuleService } from '../services/FirewallCustomRuleService'
import { FirewallToggleAuthService } from '../services/FirewallToggleAuthService'
import { UserFirewallModeService } from '../services/UserFirewallModeService'
import { UserFirewallPolicyService } from '../services/UserFirewallPolicyService'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { FormControlUtils } from '../utils/FormControlUtils'
import { DialogService } from '../utils/DialogService'
import { EmptyStateStrings, FirewallDialogStrings, LoadingStrings } from '../constants/modules/DialogStrings'

const TAG = 'UserFirewallDialog'
const DOMAIN = 0x0001

interface ModeOption {
  mode: FirewallUserApplyMode
  label: string
}

@CustomDialog
export struct UserFirewallControlDialog {
  controller: CustomDialogController
  onActionCompleted: (userId: number, mode: FirewallUserApplyMode) => Promise<void> =
    async (_userId: number, _mode: FirewallUserApplyMode) => {}

  @State users: UserFirewallOption[] = []
  @State selectedIndex: number = 0
  @State selectedUserId: number = -1
  @State selectedModeIndex: number = 0
  @State isLoadingUsers: boolean = false
  @State isLoadingPolicy: boolean = false
  @State isSubmitting: boolean = false
  @State statusHintText: string = ''
  @State currentModeText: string = FirewallDialogStrings.MODE_UNMANAGED
  @State currentPolicyText: string = ''
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  private modeOptions: ModeOption[] = [
    { mode: 'allowlist', label: FirewallDialogStrings.MODE_ALLOWLIST } as ModeOption,
    { mode: 'denylist', label: FirewallDialogStrings.MODE_DENYLIST } as ModeOption,
    { mode: 'non_standard', label: FirewallDialogStrings.MODE_NON_STANDARD } as ModeOption
  ]

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'aboutToAppear')
    this.loadUsers()
  }

  aboutToDisappear(): void {
    hilog.info(DOMAIN, TAG, 'aboutToDisappear')
  }

  private async loadUsers(): Promise<void> {
    this.isLoadingUsers = true
    this.statusHintText = ''
    let result = await UserFirewallPolicyService.loadAvailableUserIds()
    this.isLoadingUsers = false
    hilog.info(
      DOMAIN,
      TAG,
      'loadUsers finished: count=%{public}d, selectedUserId=%{public}d',
      result.users.length,
      result.selectedUserId ?? -1
    )

    if (result.users.length === 0) {
      this.users = []
      this.selectedIndex = 0
      this.selectedUserId = -1
      this.statusHintText = result.message ?? EmptyStateStrings.NO_USERS
      if (this.statusHintText.length > 0) {
        DialogService.openFailure(this.getUIContext(), this.statusHintText)
      }
      return
    }

    this.users = result.users
    let targetUserId = result.selectedUserId ?? result.users[0].userId
    let targetIndex = result.users.findIndex((item: UserFirewallOption): boolean => item.userId === targetUserId)
    this.selectedIndex = targetIndex >= 0 ? targetIndex : 0
    this.selectedUserId = result.users[this.selectedIndex].userId
    await this.loadStateForSelectedUser()
  }

  private async loadStateForSelectedUser(): Promise<void> {
    if (this.selectedUserId < 0) {
      return
    }

    this.isLoadingPolicy = true
    this.statusHintText = ''
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    let result = await UserFirewallModeService.getModeState(context, this.selectedUserId)
    this.isLoadingPolicy = false

    hilog.info(
      DOMAIN,
      TAG,
      'loadStateForSelectedUser finished: userId=%{public}d, managed=%{public}s, isOpen=%{public}s, inAction=%{public}d, outAction=%{public}d',
      this.selectedUserId,
      String(result.isManaged),
      String(result.isOpen),
      result.inAction,
      result.outAction
    )

    if (result.errorCode !== undefined) {
      this.statusHintText = result.message ?? FirewallDialogStrings.ERROR_CANNOT_GET_STATUS
      this.currentModeText = FirewallDialogStrings.MODE_UNMANAGED
      this.currentPolicyText = ''
      DialogService.openFailure(this.getUIContext(), this.statusHintText)
      return
    }

    this.currentModeText = this.getModeLabel(result.bindingMode)
    this.currentPolicyText = this.buildPolicySummary(result.isOpen, result.inAction, result.outAction)
    let selectedMode = result.bindingMode ?? this.modeOptions[0].mode
    this.selectedModeIndex = this.modeOptions.findIndex((item: ModeOption): boolean => item.mode === selectedMode)
    if (this.selectedModeIndex < 0) {
      this.selectedModeIndex = 0
    }
  }

  private buildPolicySummary(isOpen: boolean, inAction: number, outAction: number): string {
    return `主开关${isOpen ? '已开启' : '已关闭'}，默认入站${this.getActionLabel(inAction)}，默认出站${this.getActionLabel(outAction)}`
  }

  private getActionLabel(action: number): string {
    return action === netFirewall.FirewallRuleAction.RULE_DENY ? FirewallDialogStrings.ACTION_DENY : FirewallDialogStrings.ACTION_ALLOW
  }

  private getModeLabel(mode?: FirewallUserApplyMode): string {
    switch (mode) {
      case 'allowlist':
        return FirewallDialogStrings.MODE_ALLOWLIST
      case 'denylist':
        return FirewallDialogStrings.MODE_DENYLIST
      case 'non_standard':
        return FirewallDialogStrings.MODE_NON_STANDARD
      default:
        return FirewallDialogStrings.MODE_UNMANAGED
    }
  }

  private async handleApplyMode(): Promise<void> {
    if (this.selectedUserId < 0) {
      DialogService.openFailure(this.getUIContext(), FirewallDialogStrings.ERROR_PLEASE_READ_STATUS)
      return
    }

    this.isSubmitting = true
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    let targetMode = this.modeOptions[this.selectedModeIndex].mode
    let sharedRules = await FirewallCustomRuleService.buildRulesForApply(context)
    hilog.info(
      DOMAIN,
      TAG,
      'handleApplyMode start: userId=%{public}d, mode=%{public}s, ruleCount=%{public}d',
      this.selectedUserId,
      targetMode,
      sharedRules.length
    )
    let result = await FirewallToggleAuthService.executeUserModeApply(
      context,
      this.selectedUserId,
      targetMode,
      async () => UserFirewallModeService.applyMode(context, this.selectedUserId, targetMode, sharedRules)
    )
    this.isSubmitting = false

    if (!result.success) {
      DialogService.openFailure(
        this.getUIContext(),
        result.errorMessage ?? '策略下发失败'
      )
      return
    }

    try {
      await this.onActionCompleted(this.selectedUserId, targetMode)
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'onActionCompleted failed: %{public}s', JSON.stringify(err))
    }
    await this.loadStateForSelectedUser()
    await DialogService.openSuccess(this.getUIContext(), `策略下发成功，本次下发 ${result.appliedRuleCount} 条规则`)
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Text(FirewallDialogStrings.USER_FIREWALL_TITLE)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .layoutWeight(1)

        Text('×')
          .fontSize(20)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .onClick(() => {
            this.controller.close()
          })
      }
      .width('100%')

      Text(FirewallDialogStrings.USER_FIREWALL_DESCRIPTION)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .width('100%')

      if (this.isLoadingUsers) {
        Column({ space: 10 }) {
          LoadingProgress()
            .width(36)
            .height(36)
          Text(LoadingStrings.LOADING_USERS)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .padding({ top: 20, bottom: 20 })
      } else if (this.users.length === 0) {
        Column({ space: 10 }) {
          Text(EmptyStateStrings.NO_USERS)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

          Text(this.statusHintText.length > 0 ? this.statusHintText : EmptyStateStrings.CHECK_PERMISSIONS)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .padding({ top: 20, bottom: 20 })
      } else {
        Column({ space: 12 }) {
          Column({ space: 6 }) {
            Text(FirewallDialogStrings.TARGET_USER)
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

            Select(this.users.map((item: UserFirewallOption): SelectOption => {
              return { value: item.label } as SelectOption
            }))
              .selected(this.selectedIndex)
              .value(this.users.length > 0 ? this.users[this.selectedIndex].label : '')
              .fontColor(FormControlUtils.text(this.currentTheme))
              .font({ size: AppStyles.FONT_SIZE_BODY })
              .width('100%')
              .height(40)
              .backgroundColor(FormControlUtils.background(this.currentTheme))
              .borderRadius(AppStyles.RADIUS_MD)
              .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
              .onSelect((index: number) => {
                this.selectedIndex = index
                this.selectedUserId = this.users[index].userId
                this.loadStateForSelectedUser()
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text(FirewallDialogStrings.CURRENT_MODE)
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

            Text(this.currentModeText)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

            Text(this.currentPolicyText.length > 0 ? this.currentPolicyText : FirewallDialogStrings.ERROR_PLEASE_READ_STATUS)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          }
          .width('100%')
          .padding(14)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_COMPONENT)
          .borderRadius(AppStyles.RADIUS_MD)

          Column({ space: 6 }) {
            Text(FirewallDialogStrings.TARGET_MODE)
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

            Select(this.modeOptions.map((item: ModeOption): SelectOption => {
              return { value: item.label } as SelectOption
            }))
              .selected(this.selectedModeIndex)
              .value(this.modeOptions[this.selectedModeIndex].label)
              .fontColor(FormControlUtils.text(this.currentTheme))
              .font({ size: AppStyles.FONT_SIZE_BODY })
              .width('100%')
              .height(40)
              .backgroundColor(FormControlUtils.background(this.currentTheme))
              .borderRadius(AppStyles.RADIUS_MD)
              .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
              .onSelect((index: number) => {
                this.selectedModeIndex = index
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          if (this.isLoadingPolicy) {
            Text(LoadingStrings.LOADING_POLICY)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          }

          Button(FirewallDialogStrings.APPLY_MODE)
            .width('100%')
            .height(40)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(Color.White)
            .backgroundColor(AppColors.BRAND_PRIMARY)
            .borderRadius(AppStyles.RADIUS_MD)
            .enabled(!this.isSubmitting && !this.isLoadingPolicy)
            .opacity(!this.isSubmitting && !this.isLoadingPolicy ? 1 : 0.5)
            .onClick(() => {
              this.handleApplyMode()
            })
        }
        .width('100%')
      }
    }
    .width(560)
    .padding(20)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_XL)
  }
}
