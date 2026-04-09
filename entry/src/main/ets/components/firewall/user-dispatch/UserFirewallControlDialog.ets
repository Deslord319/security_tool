import { LogUtils } from '../../../utils/LogUtils'
import { common } from '@kit.AbilityKit'
import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { MessageText, StatusText } from '../../../constants/StringCatalog'
import { FirewallUserApplyMode } from '../../../models/DataModels'
import { FirewallUserDispatchViewModel } from '../../../viewmodels/firewall/user-dispatch/FirewallUserDispatchViewModel'
import { ThemeMode } from '../../../theme/ThemeColors'
import { FormControlUtils } from '../../../utils/FormControlUtils'
import { DialogService } from '../../../utils/DialogService'
import { EmptyStateStrings, FirewallDialogStrings, LoadingStrings } from '../../../constants/modules/DialogStrings'
import { DetailDialogShell } from '../../DetailDialogShell'

const TAG = 'UserFirewallDialog'

interface ModeOption {
  mode: FirewallUserApplyMode
  label: string
}

@CustomDialog
export struct UserFirewallControlDialog {
  controller: CustomDialogController
  onActionCompleted: (userId: number, mode: FirewallUserApplyMode) => Promise<void> =
    async (_userId: number, _mode: FirewallUserApplyMode) => {}
  currentTheme: ThemeMode = ThemeMode.LIGHT

  viewModel: FirewallUserDispatchViewModel = new FirewallUserDispatchViewModel()
  private modeOptions: ModeOption[] = [
    { mode: 'allowlist', label: FirewallDialogStrings.MODE_ALLOWLIST } as ModeOption,
    { mode: 'denylist', label: FirewallDialogStrings.MODE_DENYLIST } as ModeOption
  ]

  async aboutToAppear(): Promise<void> {
    LogUtils.info(TAG, 'aboutToAppear')
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    await this.viewModel.initialize(context)
    if (this.viewModel.users.length === 0 && this.viewModel.statusHintText.length > 0) {
      DialogService.openFailure(this.getUIContext(), this.viewModel.statusHintText)
    }
  }

  aboutToDisappear(): void {
    LogUtils.info(TAG, 'aboutToDisappear')
  }

  @Builder
  private dialogContent() {
    Column({ space: 16 }) {
      if (this.viewModel.isLoadingUsers) {
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
        .alignItems(HorizontalAlign.Center)
      } else if (this.viewModel.users.length === 0) {
        Column({ space: 10 }) {
          Text(EmptyStateStrings.NO_USERS)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

          Text(this.viewModel.statusHintText.length > 0 ? this.viewModel.statusHintText : MessageText.CHECK_PERMISSIONS)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .padding({ top: 20, bottom: 20 })
        .alignItems(HorizontalAlign.Start)
      } else {
        Column({ space: 12 }) {
          Column({ space: 6 }) {
            Text(FirewallDialogStrings.TARGET_USER)
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

            Select(this.viewModel.users.map((item): SelectOption => {
              return { value: item.label } as SelectOption
            }))
              .selected(this.viewModel.selectedIndex)
              .value(this.viewModel.users.length > 0 ? this.viewModel.users[this.viewModel.selectedIndex].label : '')
              .fontColor(FormControlUtils.text(this.currentTheme))
              .font({ size: AppStyles.FONT_SIZE_BODY })
              .width('100%')
              .height(40)
              .backgroundColor(FormControlUtils.background(this.currentTheme))
              .borderRadius(AppStyles.RADIUS_MD)
              .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
              .onSelect((index: number) => {
                this.viewModel.selectUser(index)
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text(StatusText.CURRENT_MODE)
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

            Text(this.viewModel.currentModeText)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

            Text(this.viewModel.currentPolicyText.length > 0 ? this.viewModel.currentPolicyText : FirewallDialogStrings.ERROR_PLEASE_READ_STATUS)
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
              .selected(this.viewModel.selectedModeIndex)
              .value(this.modeOptions[this.viewModel.selectedModeIndex].label)
              .fontColor(FormControlUtils.text(this.currentTheme))
              .font({ size: AppStyles.FONT_SIZE_BODY })
              .width('100%')
              .height(40)
              .backgroundColor(FormControlUtils.background(this.currentTheme))
              .borderRadius(AppStyles.RADIUS_MD)
              .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
              .onSelect((index: number) => {
                this.viewModel.selectMode(index)
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          if (this.viewModel.isLoadingPolicy) {
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
            .enabled(!this.viewModel.isSubmitting && !this.viewModel.isLoadingPolicy)
            .opacity(!this.viewModel.isSubmitting && !this.viewModel.isLoadingPolicy ? 1 : 0.5)
            .onClick(async () => {
              let success = await this.viewModel.applySelectedMode()
              if (!success) {
                DialogService.openFailure(
                  this.getUIContext(),
                  this.viewModel.statusHintText.length > 0
                    ? this.viewModel.statusHintText
                    : FirewallDialogStrings.APPLY_MODE_FAILED
                )
                return
              }

              let selectedUser = this.viewModel.getSelectedUser()
              if (selectedUser === undefined) {
                DialogService.openFailure(this.getUIContext(), FirewallDialogStrings.APPLY_MODE_FAILED)
                return
              }

              try {
                await this.onActionCompleted(selectedUser.userId, this.viewModel.getSelectedMode())
              } catch (_err) {
                LogUtils.warn(TAG, 'onActionCompleted failed')
              }
              await DialogService.openSuccess(
                this.getUIContext(),
                FirewallDialogStrings.buildApplyModeSuccess(
                  this.viewModel.lastApplyResult !== null ? this.viewModel.lastApplyResult.appliedRuleCount : 0
                )
              )
            })
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  build() {
    DetailDialogShell({
      title: FirewallDialogStrings.USER_FIREWALL_TITLE,
      dialogWidth: 560,
      maxBodyHeight: 520,
      currentTheme: this.currentTheme,
      onClose: () => {
        this.controller.close()
      },
      content: () => {
        this.dialogContent()
      }
    })
  }
}
