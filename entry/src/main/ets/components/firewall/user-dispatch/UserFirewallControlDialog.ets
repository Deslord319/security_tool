import { LogUtils } from '../../../utils/LogUtils'
import { common } from '@kit.AbilityKit'
import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { ActionText } from '../../../constants/StringCatalog'
import { FirewallUserPolicyMode, UserFirewallOption } from '../../../models/firewall/FirewallModels'
import { FirewallUserDispatchViewModel } from '../../../viewmodels/firewall/user-dispatch/FirewallUserDispatchViewModel'
import { ThemeMode } from '../../../theme/ThemeColors'
import { DialogService } from '../../../utils/DialogService'
import { EmptyStateStrings, LoadingStrings } from '../../../constants/modules/DialogStrings'
import { FirewallDialogStrings } from '../../../constants/modules/FirewallStrings'
import { DetailDialogShell } from '../../DetailDialogShell'
import { LoadingStatePanel } from '../../LoadingStatePanel'
import { StyledSelect } from '../../StyledSelect'

const TAG = 'UserFirewallDialog'

interface ModeOption {
  mode: FirewallUserPolicyMode
  label: string
}

@CustomDialog
export struct UserFirewallControlDialog {
  controller: CustomDialogController
  onActionCompleted: (userId: number, mode: FirewallUserPolicyMode) => Promise<void> =
    async (_userId: number, _mode: FirewallUserPolicyMode) => {}
  currentTheme: ThemeMode = ThemeMode.LIGHT
  users: UserFirewallOption[] = []

  viewModel: FirewallUserDispatchViewModel = new FirewallUserDispatchViewModel()
  private modeOptions: ModeOption[] = [
    { mode: 'allowlist', label: FirewallDialogStrings.MODE_ALLOWLIST } as ModeOption,
    { mode: 'denylist', label: FirewallDialogStrings.MODE_DENYLIST } as ModeOption
  ]

  async aboutToAppear(): Promise<void> {
    let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    await this.viewModel.initialize(context, this.users)
    if (this.viewModel.users.length === 0 && this.viewModel.statusHintText.length > 0) {
      DialogService.openFailure(this.getUIContext(), this.viewModel.statusHintText)
    }
  }

  aboutToDisappear(): void {
  }

  @Builder
  private dialogContent() {
    Column({ space: 20 }) {
      if (this.viewModel.isLoadingUsers) {
        LoadingStatePanel({
          message: LoadingStrings.LOADING_USERS,
          indicatorSize: 36,
          currentTheme: this.currentTheme
        })
          .padding({ top: 20, bottom: 20 })
      } else if (this.viewModel.users.length === 0) {
        Column() {
          Text(EmptyStateStrings.NO_USERS)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        }
        .width('100%')
        .padding({ top: 20, bottom: 20 })
        .alignItems(HorizontalAlign.Center)
      } else {
        Column({ space: 16 }) {
          Column({ space: 6 }) {
            Text(FirewallDialogStrings.TARGET_USER)
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

            StyledSelect({
              options: this.viewModel.users.map((item): SelectOption => {
                return { value: item.label } as SelectOption
              }),
              selectedIndex: this.viewModel.selectedIndex,
              value: this.viewModel.users.length > 0 ? this.viewModel.users[this.viewModel.selectedIndex].label : '',
              currentTheme: this.currentTheme,
              onSelect: (index: number) => {
                let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
                this.viewModel.selectUser(context, index)
              }
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 6 }) {
            Text(FirewallDialogStrings.TARGET_MODE)
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

            StyledSelect({
              options: this.modeOptions.map((item: ModeOption): SelectOption => {
                return { value: item.label } as SelectOption
              }),
              selectedIndex: this.viewModel.selectedModeIndex,
              value: this.modeOptions[this.viewModel.selectedModeIndex].label,
              currentTheme: this.currentTheme,
              onSelect: (index: number) => {
                this.viewModel.selectMode(index)
              }
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Row({ space: 16 }) {
            Button(ActionText.CANCEL)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .backgroundColor(this.currentTheme === ThemeMode.DARK
                ? AppColors.INTERACTIVE_SECONDARY_BG_DARK
                : AppColors.getColors(this.currentTheme).BG_PAGE)
              .borderRadius(AppStyles.RADIUS_MD)
              .border({ width: AppStyles.DIVIDER_HEIGHT, color: AppColors.getColors(this.currentTheme).BORDER, style: BorderStyle.Solid })
              .layoutWeight(1)
              .height(AppStyles.BUTTON_HEIGHT)
              .enabled(!this.viewModel.isSubmitting)
              .opacity(this.viewModel.isSubmitting ? 0.5 : 1)
              .onClick(() => {
                this.controller.close()
              })

            Button(ActionText.ADD)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(Color.White)
              .backgroundColor(AppColors.BRAND_PRIMARY)
              .borderRadius(AppStyles.RADIUS_MD)
              .layoutWeight(1)
              .height(AppStyles.BUTTON_HEIGHT)
              .enabled(!this.viewModel.isSubmitting && !this.viewModel.isLoadingPolicy)
              .opacity(!this.viewModel.isSubmitting && !this.viewModel.isLoadingPolicy ? 1 : 0.5)
              .onClick(async () => {
                let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
                let success = await this.viewModel.applySelectedMode(context)
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
                  FirewallDialogStrings.APPLY_MODE_SUCCESS
                )
                this.controller.close()
              })
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
  }

  build() {
    DetailDialogShell({
      dialogWidth: 480,
      maxBodyHeight: 360,
      currentTheme: this.currentTheme,
      showHeader: false,
      showCloseAction: false,
      onClose: () => {
        this.controller.close()
      },
      content: () => {
        this.dialogContent()
      }
    })
  }
}
