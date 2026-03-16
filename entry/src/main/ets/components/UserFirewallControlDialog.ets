import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { AppColors, AppStyles } from '../constants/AppConstants'
import {
  FirewallToggleRejectReason,
  UserFirewallOption
} from '../models/DataModels'
import { FirewallToggleAuthService } from '../services/FirewallToggleAuthService'
import { UserFirewallPolicyService } from '../services/UserFirewallPolicyService'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { FormControlUtils } from '../utils/FormControlUtils'

@CustomDialog
export struct UserFirewallControlDialog {
  controller: CustomDialogController
  onActionCompleted: () => void = () => {}

  @State users: UserFirewallOption[] = []
  @State selectedIndex: number = 0
  @State selectedUserId: number = -1
  @State isLoadingUsers: boolean = false
  @State isLoadingPolicy: boolean = false
  @State isSubmitting: boolean = false
  @State statusReady: boolean = false
  @State currentStatusText: string = ''
  @State statusHintText: string = ''
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  aboutToAppear(): void {
    this.loadUsers()
  }

  private async loadUsers(): Promise<void> {
    this.isLoadingUsers = true
    this.statusReady = false
    this.currentStatusText = ''
    this.statusHintText = ''

    let result = await UserFirewallPolicyService.loadAvailableUserIds()
    this.isLoadingUsers = false

    if (result.users.length === 0) {
      this.users = []
      this.selectedIndex = 0
      this.selectedUserId = -1
      this.statusHintText = result.message ?? '\u672a\u627e\u5230\u53ef\u7528\u7528\u6237'
      if (this.statusHintText.length > 0) {
        promptAction.showToast({ message: this.statusHintText })
      }
      return
    }

    this.users = result.users
    let selectedUserId = result.selectedUserId ?? result.users[0].userId
    let selectedIndex = result.users.findIndex((item: UserFirewallOption): boolean => item.userId === selectedUserId)
    this.selectedIndex = selectedIndex >= 0 ? selectedIndex : 0
    this.selectedUserId = result.users[this.selectedIndex].userId
    await this.loadPolicyForSelectedUser()
  }

  private async loadPolicyForSelectedUser(): Promise<void> {
    if (this.selectedUserId < 0) {
      return
    }

    this.isLoadingPolicy = true
    this.statusReady = false
    this.currentStatusText = ''
    this.statusHintText = ''

    let result = await UserFirewallPolicyService.getPolicy(this.selectedUserId)
    this.isLoadingPolicy = false

    if (result.errorCode !== undefined) {
      this.statusHintText = result.message ?? '\u65e0\u6cd5\u83b7\u53d6\u8be5\u7528\u6237\u5f53\u524d\u9632\u706b\u5899\u72b6\u6001'
      promptAction.showToast({ message: this.statusHintText })
      return
    }

    this.statusReady = true
    this.currentStatusText = result.isOpen ? '\u5df2\u5f00\u542f' : '\u5df2\u5173\u95ed'
    this.statusHintText = result.isOpen ?
      '\u5f53\u524d\u7528\u6237\u7684\u4e3b\u9632\u706b\u5899\u7b56\u7565\u5904\u4e8e\u542f\u7528\u72b6\u6001' :
      '\u5f53\u524d\u7528\u6237\u7684\u4e3b\u9632\u706b\u5899\u7b56\u7565\u5904\u4e8e\u5173\u95ed\u72b6\u6001'
  }

  private async handleSetEnabled(enabled: boolean): Promise<void> {
    if (this.selectedUserId < 0 || !this.statusReady) {
      promptAction.showToast({ message: '\u8bf7\u5148\u9009\u62e9\u5e76\u8bfb\u53d6\u6709\u6548\u7528\u6237\u72b6\u6001' })
      return
    }

    this.isSubmitting = true
    let context = getContext(this) as common.UIAbilityContext
    let result = await FirewallToggleAuthService.executeToggleForUser(
      context,
      this.selectedUserId,
      this.currentStatusText === '\u5df2\u5f00\u542f',
      enabled
    )
    this.isSubmitting = false

    if (!result.success) {
      promptAction.showToast({
        message: result.errorMessage ?? this.buildToggleFailedMessage(result.reason, result.lockRemainingSec)
      })
      return
    }

    promptAction.showToast({
      message: enabled ?
        `\u7528\u6237 ${this.selectedUserId} \u9632\u706b\u5899\u5df2\u5f00\u542f` :
        `\u7528\u6237 ${this.selectedUserId} \u9632\u706b\u5899\u5df2\u5173\u95ed`
    })
    this.onActionCompleted()
    await this.loadPolicyForSelectedUser()
  }

  private buildToggleFailedMessage(
    reason: FirewallToggleRejectReason | undefined,
    lockRemainingSec: number | undefined
  ): string {
    switch (reason) {
      case 'lockout':
        return `PIN \u8ba4\u8bc1\u5931\u8d25\u6b21\u6570\u8fc7\u591a\uff0c\u8bf7\u5728 ${lockRemainingSec ?? 60} \u79d2\u540e\u91cd\u8bd5`
      case 'pin_unavailable':
        return '\u7cfb\u7edf PIN \u8ba4\u8bc1\u6682\u4e0d\u53ef\u7528'
      case 'pin_failed':
        return 'PIN \u9a8c\u8bc1\u5931\u8d25\uff0c\u5df2\u53d6\u6d88\u672c\u6b21\u53d8\u66f4'
      case 'policy_apply_failed':
        return '\u9632\u706b\u5899\u72b6\u6001\u66f4\u65b0\u5931\u8d25'
      default:
        return '\u9632\u706b\u5899\u72b6\u6001\u66f4\u65b0\u5931\u8d25'
    }
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Text('\u6309\u7528\u6237ID\u63a7\u5236')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .layoutWeight(1)

        Text('\u00D7')
          .fontSize(20)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .onClick(() => {
            this.controller.close()
          })
      }
      .width('100%')

      Text('\u4ece\u7cfb\u7edf\u5df2\u6fc0\u6d3b\u7684\u7528\u6237\u5217\u8868\u4e2d\u9009\u62e9\u76ee\u6807 userId\uff0c\u8bfb\u53d6\u5e76\u5207\u6362\u8be5\u7528\u6237\u7684\u4e3b\u9632\u706b\u5899\u72b6\u6001\u3002')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .width('100%')

      if (this.isLoadingUsers) {
        Column({ space: 10 }) {
          LoadingProgress()
            .width(36)
            .height(36)
          Text('\u6b63\u5728\u52a0\u8f7d\u7528\u6237\u5217\u8868...')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .padding({ top: 20, bottom: 20 })
      } else if (this.users.length === 0) {
        Column({ space: 10 }) {
          Text('\u6682\u65e0\u53ef\u9009\u7528\u6237')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

          Text(this.statusHintText.length > 0 ? this.statusHintText : '\u8bf7\u68c0\u67e5\u8d26\u6237\u6743\u9650\u6216\u7cfb\u7edf\u8d26\u6237\u72b6\u6001')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .padding({ top: 20, bottom: 20 })
      } else {
        Column({ space: 6 }) {
          Text('\u76ee\u6807\u7528\u6237')
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
              this.loadPolicyForSelectedUser()
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 8 }) {
          Text('\u5f53\u524d\u72b6\u6001')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

          if (this.isLoadingPolicy) {
            Text('\u6b63\u5728\u8bfb\u53d6\u9632\u706b\u5899\u72b6\u6001...')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          } else {
            Text(this.currentStatusText.length > 0 ? this.currentStatusText : '\u72b6\u6001\u672a\u77e5')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.statusReady ? AppColors.SUCCESS : AppColors.WARNING)

            Text(this.statusHintText.length > 0 ? this.statusHintText : '\u8bf7\u5148\u8bfb\u53d6\u72b6\u6001')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          }
        }
        .width('100%')
        .padding(14)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_COMPONENT)
        .borderRadius(AppStyles.RADIUS_MD)

        Row({ space: 12 }) {
          Button('\u5f00\u542f\u9632\u706b\u5899')
            .layoutWeight(1)
            .height(40)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(Color.White)
            .backgroundColor(AppColors.SUCCESS)
            .borderRadius(AppStyles.RADIUS_MD)
            .enabled(!this.isSubmitting && this.statusReady)
            .opacity(!this.isSubmitting && this.statusReady ? 1 : 0.5)
            .onClick(() => {
              this.handleSetEnabled(true)
            })

          Button('\u5173\u95ed\u9632\u706b\u5899')
            .layoutWeight(1)
            .height(40)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(Color.White)
            .backgroundColor(AppColors.DANGER)
            .borderRadius(AppStyles.RADIUS_MD)
            .enabled(!this.isSubmitting && this.statusReady)
            .opacity(!this.isSubmitting && this.statusReady ? 1 : 0.5)
            .onClick(() => {
              this.handleSetEnabled(false)
            })
        }
        .width('100%')
      }
    }
    .width(520)
    .padding(20)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_XL)
  }
}
