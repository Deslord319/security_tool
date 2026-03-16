import { netFirewall } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import osAccount from '@ohos.account.osAccount'
import {
  UserFirewallActionResult,
  UserFirewallListResult,
  UserFirewallOption,
  UserFirewallPolicyResult
} from '../models/DataModels'

const TAG = 'UserFirewallPolicyService'
const DOMAIN = 0x0001

export class UserFirewallPolicyService {
  private static lastErrorCode: number | undefined = undefined
  private static lastErrorMessage: string = ''

  private static clearLastError(): void {
    UserFirewallPolicyService.lastErrorCode = undefined
    UserFirewallPolicyService.lastErrorMessage = ''
  }

  static getLastErrorCode(): number | undefined {
    return UserFirewallPolicyService.lastErrorCode
  }

  static getLastErrorMessage(): string {
    return UserFirewallPolicyService.lastErrorMessage
  }

  private static recordError(action: string, err: Object): void {
    let code = UserFirewallPolicyService.extractErrorCode(err)
    UserFirewallPolicyService.lastErrorCode = code
    UserFirewallPolicyService.lastErrorMessage = UserFirewallPolicyService.resolveErrorMessage(action, code)
  }

  private static extractErrorCode(err: Object): number | undefined {
    let codeValue = (err as Record<string, Object>)['code']
    if (typeof codeValue === 'number') {
      return codeValue
    }
    if (typeof codeValue === 'string') {
      let parsed = Number(codeValue)
      return Number.isNaN(parsed) ? undefined : parsed
    }
    return undefined
  }

  private static resolveErrorMessage(action: string, code: number | undefined): string {
    switch (code) {
      case 201:
        return '\u7f3a\u5c11\u8d26\u6237\u6216\u9632\u706b\u5899\u7ba1\u7406\u6743\u9650'
      case 401:
      case 2100001:
        return '\u7528\u6237 ID \u53c2\u6570\u4e0d\u5408\u6cd5'
      case 2100002:
        return '\u7cfb\u7edf\u670d\u52a1\u8fde\u63a5\u5931\u8d25'
      case 2100003:
        return '\u7cfb\u7edf\u5185\u90e8\u9519\u8bef'
      case 29400000:
        return '\u76ee\u6807\u7528\u6237\u4e0d\u5b58\u5728\u6216\u5df2\u5931\u6548'
      default:
        return `${action}\u5931\u8d25`
    }
  }

  static async loadAvailableUserIds(): Promise<UserFirewallListResult> {
    UserFirewallPolicyService.clearLastError()
    try {
      let accountManager = osAccount.getAccountManager()
      let ids = await accountManager.getActivatedOsAccountLocalIds()
      if (ids.length === 0) {
        return {
          users: [],
          message: '\u672a\u627e\u5230\u53ef\u7528\u7528\u6237'
        } as UserFirewallListResult
      }

      let sortedIds = [...ids].sort((left: number, right: number) => left - right)
      let foregroundId: number | undefined = undefined
      try {
        foregroundId = await accountManager.getForegroundOsAccountLocalId()
      } catch (err) {
        hilog.warn(DOMAIN, TAG, `getForegroundOsAccountLocalId failed: ${JSON.stringify(err)}`)
      }

      let users: UserFirewallOption[] = sortedIds.map((userId: number): UserFirewallOption => {
        let isForeground = foregroundId === userId
        return {
          userId: userId,
          label: isForeground ? `\u7528\u6237 ${userId}\uff08\u5f53\u524d\uff09` : `\u7528\u6237 ${userId}`,
          isForeground: isForeground
        } as UserFirewallOption
      })

      return {
        users: users,
        selectedUserId: foregroundId !== undefined && sortedIds.includes(foregroundId) ? foregroundId : sortedIds[0]
      } as UserFirewallListResult
    } catch (err) {
      UserFirewallPolicyService.recordError('\u8bfb\u53d6\u7528\u6237\u5217\u8868', err as Object)
      hilog.error(DOMAIN, TAG, `loadAvailableUserIds failed: ${JSON.stringify(err)}`)
      return {
        users: [],
        errorCode: UserFirewallPolicyService.getLastErrorCode(),
        message: UserFirewallPolicyService.getLastErrorMessage()
      } as UserFirewallListResult
    }
  }

  static async getPolicy(userId: number): Promise<UserFirewallPolicyResult> {
    UserFirewallPolicyService.clearLastError()
    try {
      let policy = await netFirewall.getNetFirewallPolicy(userId)
      return {
        userId: userId,
        isOpen: policy.isOpen,
        inAction: policy.inAction,
        outAction: policy.outAction
      } as UserFirewallPolicyResult
    } catch (err) {
      UserFirewallPolicyService.recordError('\u8bfb\u53d6\u7528\u6237\u9632\u706b\u5899\u72b6\u6001', err as Object)
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

  static async setEnabled(userId: number, enabled: boolean): Promise<UserFirewallActionResult> {
    UserFirewallPolicyService.clearLastError()
    try {
      let policy: netFirewall.NetFirewallPolicy = {
        isOpen: enabled,
        inAction: netFirewall.FirewallRuleAction.RULE_ALLOW,
        outAction: netFirewall.FirewallRuleAction.RULE_ALLOW
      }
      await netFirewall.setNetFirewallPolicy(userId, policy)
      hilog.info(DOMAIN, TAG, `setEnabled success, userId=${userId}, enabled=${enabled}`)
      return {
        success: true,
        userId: userId
      } as UserFirewallActionResult
    } catch (err) {
      UserFirewallPolicyService.recordError('\u8bbe\u7f6e\u7528\u6237\u9632\u706b\u5899\u72b6\u6001', err as Object)
      hilog.error(DOMAIN, TAG, `setEnabled failed, userId=${userId}, enabled=${enabled}, err=${JSON.stringify(err)}`)
      return {
        success: false,
        userId: userId,
        errorCode: UserFirewallPolicyService.getLastErrorCode(),
        message: UserFirewallPolicyService.getLastErrorMessage()
      } as UserFirewallActionResult
    }
  }
}
