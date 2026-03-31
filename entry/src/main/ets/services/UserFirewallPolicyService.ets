import { netFirewall } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import osAccount from '@ohos.account.osAccount'
import { UserFirewallListResult, UserFirewallOption, UserFirewallPolicyResult } from '../models/DataModels'
import { CommonErrorUtils } from '../utils/CommonErrorUtils'

const TAG = 'UserFirewallPolicyService'
const DOMAIN = 0x0001

export class UserFirewallPolicyService {
  private static lastErrorCode: number | undefined = undefined
  private static lastErrorMessage: string = ''

  static getLastErrorCode(): number | undefined {
    return UserFirewallPolicyService.lastErrorCode
  }

  static getLastErrorMessage(): string {
    return UserFirewallPolicyService.lastErrorMessage
  }

  private static recordError(action: string, err: Object): void {
    let code = CommonErrorUtils.extractErrorCode(err)
    UserFirewallPolicyService.lastErrorCode = code
    UserFirewallPolicyService.lastErrorMessage = CommonErrorUtils.resolveErrorMessage(action, code)
  }

  static async loadAvailableUserIds(): Promise<UserFirewallListResult> {
    CommonErrorUtils.clearLastError({
      lastErrorCode: UserFirewallPolicyService.lastErrorCode,
      lastErrorMessage: UserFirewallPolicyService.lastErrorMessage
    })
    try {
      let accountManager = osAccount.getAccountManager()
      let ids = await accountManager.getActivatedOsAccountLocalIds()
      if (ids.length === 0) {
        return {
          users: [],
          message: '未找到已激活用户'
        } as UserFirewallListResult
      }

      let sortedIds = [...ids].sort((left: number, right: number) => left - right)
      let foregroundId: number | undefined = undefined
      try {
        foregroundId = await accountManager.getForegroundOsAccountLocalId()
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'getForegroundOsAccountLocalId failed: %{public}s', JSON.stringify(err))
      }

      let users: UserFirewallOption[] = sortedIds.map((userId: number): UserFirewallOption => {
        let isForeground = foregroundId === userId
        return {
          userId: userId,
          label: isForeground ? `用户 ${userId}（当前）` : `用户 ${userId}`,
          isForeground: isForeground
        } as UserFirewallOption
      })

      let selectedUserId = foregroundId !== undefined && sortedIds.includes(foregroundId) ? foregroundId : sortedIds[0]
      hilog.info(DOMAIN, TAG, 'loadAvailableUserIds success: count=%{public}d, selectedUserId=%{public}d', users.length, selectedUserId)

      return {
        users: users,
        selectedUserId: selectedUserId
      } as UserFirewallListResult
    } catch (err) {
      UserFirewallPolicyService.recordError('读取用户列表', err as Object)
      hilog.error(DOMAIN, TAG, `loadAvailableUserIds failed: ${JSON.stringify(err)}`)
      return {
        users: [],
        errorCode: UserFirewallPolicyService.getLastErrorCode(),
        message: UserFirewallPolicyService.getLastErrorMessage()
      } as UserFirewallListResult
    }
  }

  static async getPolicy(userId: number): Promise<UserFirewallPolicyResult> {
    CommonErrorUtils.clearLastError({
      lastErrorCode: UserFirewallPolicyService.lastErrorCode,
      lastErrorMessage: UserFirewallPolicyService.lastErrorMessage
    })
    try {
      let policy = await netFirewall.getNetFirewallPolicy(userId)
      hilog.info(
        DOMAIN,
        TAG,
        'getPolicy success: userId=%{public}d, isOpen=%{public}s, inAction=%{public}d, outAction=%{public}d',
        userId,
        String(policy.isOpen),
        policy.inAction,
        policy.outAction
      )
      return {
        userId: userId,
        isOpen: policy.isOpen,
        inAction: policy.inAction,
        outAction: policy.outAction
      } as UserFirewallPolicyResult
    } catch (err) {
      UserFirewallPolicyService.recordError('读取用户防火墙状态', err as Object)
      hilog.error(DOMAIN, TAG, `getPolicy failed, userId=${userId}, err=${JSON.stringify(err)}`)
      return {
        userId: userId,
        isOpen: false,
        inAction: netFirewall.FirewallRuleAction.RULE_ALLOW,
        outAction: netFirewall.FirewallRuleAction.RULE_ALLOW,
        errorCode: UserFirewallPolicyService.getLastErrorCode(),
        message: UserFirewallPolicyService.getLastErrorMessage()
      } as UserFirewallPolicyResult
    }
  }
}
