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
    if (action === '读取用户列表') {
      switch (code) {
        case 201:
          return '缺少系统用户列表读取权限'
        case 12300001:
        case 2100002:
          return '系统账号服务连接失败'
        default:
          return `${action}失败`
      }
    }
    switch (code) {
      case 201:
        return '缺少账户或防火墙管理权限'
      case 401:
      case 2100001:
        return '用户 ID 参数不合法'
      case 2100002:
        return '系统服务连接失败'
      case 2100003:
        return '系统内部错误'
      case 29400000:
        return '目标用户不存在或已失效'
      default:
        return `${action}失败`
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
      UserFirewallPolicyService.recordError('设置用户防火墙状态', err as Object)
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
