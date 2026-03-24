import { ResultDialogHelper } from '../utils/ResultDialogHelper'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
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

const TAG = 'UserFirewallDialog'
const DOMAIN = 0x0001

@CustomDialog
export struct UserFirewallControlDialog {
  controller: CustomDialogController
  onActionCompleted: (userId: number, enabled: boolean) => Promise<void> = async (_userId: number, _enabled: boolean) => {}

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
    hilog.info(DOMAIN, TAG, '[DIAG][UserFirewall] dialog appear')
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
      this.statusHintText = result.message ?? '未找到可用用户'
      if (this.statusHintText.length > 0) {
        ResultDialogHelper.openAlertDialog(this.getUIContext(), 'failure', this.statusHintText)
      }
      return
    }

    this.users = result.users
    let selectedUserId = result.selectedUserId ?? result.users[0].userId
    let selectedIndex = result.users.findIndex((item: UserFirewallOption): boolean => item.userId === selectedUserId)
    this.selectedIndex = selectedIndex >= 0 ? selectedIndex : 0
    this.selectedUserId = result.users[this.selectedIndex].userId
    hilog.info(
      DOMAIN,
      TAG,
      '[DIAG][UserFirewall] loadUsers completed count=%{public}d selectedUserId=%{public}d',
      this.users.length,
      this.selectedUserId
    )
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
      hilog.warn(
        DOMAIN,
        TAG,
        '[DIAG][UserFirewall] loadPolicyForSelectedUser failed userId=%{public}d errorCode=%{public}s',
        this.selectedUserId,
        String(result.errorCode)
      )
      this.statusHintText = result.message ?? '无法获取该用户当前防火墙状态'
      ResultDialogHelper.openAlertDialog(this.getUIContext(), 'failure', this.statusHintText)
      return
    }

    this.statusReady = true
    this.currentStatusText = result.isOpen ? '已开启' : '已关闭'
    this.statusHintText = result.isOpen ?
      '当前用户的主防火墙策略处于启用状态' :
      '当前用户的主防火墙策略处于关闭状态'
  }

  private async handleSetEnabled(enabled: boolean): Promise<void> {
    if (this.selectedUserId < 0 || !this.statusReady) {
      ResultDialogHelper.openAlertDialog(this.getUIContext(), 'failure', '请先选择并读取有效用户状态')
      return
    }

    this.isSubmitting = true
    let context = getContext(this) as common.UIAbilityContext
    let result = await FirewallToggleAuthService.executeToggleForUser(
      context,
      this.selectedUserId,
      this.currentStatusText === '已开启',
      enabled
    )
    this.isSubmitting = false

    if (!result.success) {
      ResultDialogHelper.openAlertDialog(
        this.getUIContext(),
        'failure',
        result.errorMessage ?? this.buildToggleFailedMessage(result.reason, result.lockRemainingSec)
      )
      return
    }

    hilog.info(DOMAIN, TAG, `user firewall updated, userId=${this.selectedUserId}, enabled=${enabled}`)

    try {
      await this.onActionCompleted(this.selectedUserId, enabled)
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `onActionCompleted failed: ${JSON.stringify(err)}`)
    }
    await this.loadPolicyForSelectedUser()
  }

  private buildToggleFailedMessage(
    reason: FirewallToggleRejectReason | undefined,
    lockRemainingSec: number | undefined
  ): string {
    switch (reason) {
      case 'lockout':
        return `PIN 认证失败次数过多，请在 ${lockRemainingSec ?? 60} 秒后重试`
      case 'pin_unavailable':
        return '系统 PIN 认证暂不可用'
      case 'pin_failed':
        return 'PIN 验证失败，已取消本次变更'
      case 'policy_apply_failed':
        return '防火墙状态更新失败'
      default:
        return '防火墙状态更新失败'
    }
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Text('按用户ID控制主防火墙')
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

      Text('从系统全部已创建用户列表中选择目标 userId，仅切换该用户的主防火墙开关状态，不会修改当前模式规则。执行前需完成 PIN 验证。')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .width('100%')

      if (this.isLoadingUsers) {
        Column({ space: 10 }) {
          LoadingProgress()
            .width(36)
            .height(36)
          Text('正在加载用户列表...')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .padding({ top: 20, bottom: 20 })
      } else if (this.users.length === 0) {
        Column({ space: 10 }) {
          Text('暂无可选用户')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

          Text(this.statusHintText.length > 0 ? this.statusHintText : '请检查账户权限或系统账户状态')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .padding({ top: 20, bottom: 20 })
      } else {
        Column({ space: 6 }) {
          Text('目标用户')
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
              hilog.info(
                DOMAIN,
                TAG,
                '[DIAG][UserFirewall] select user index=%{public}d userId=%{public}d',
                index,
                this.selectedUserId
              )
              this.loadPolicyForSelectedUser()
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 8 }) {
          Text('当前状态')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

          if (this.isLoadingPolicy) {
            Text('正在读取防火墙状态...')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          } else {
            Text(this.currentStatusText.length > 0 ? this.currentStatusText : '状态未知')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(
                this.statusReady
                  ? AppColors.SUCCESS
                  : AppColors.getColors(this.currentTheme).TEXT_PRIMARY
              )

            Text(this.statusHintText.length > 0 ? this.statusHintText : '请先读取状态')
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
          Button('开启防火墙')
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

          Button('关闭防火墙')
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
