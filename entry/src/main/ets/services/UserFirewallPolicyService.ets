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

  private static safeStringifyForDiag(value: Object): string {
    try {
      return JSON.stringify(value)
    } catch (_err) {
      return '[unserializable]'
    }
  }

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

  private static extractErrorMessage(err: Object): string {
    let messageValue = (err as Object as Record<string, Object>)['message']
    return typeof messageValue === 'string' ? messageValue : ''
  }

  private static extractErrorName(err: Object): string {
    let nameValue = (err as Object as Record<string, Object>)['name']
    return typeof nameValue === 'string' ? nameValue : ''
  }

  private static extractErrorStackFirstLine(err: Object): string {
    let stackValue = (err as Object as Record<string, Object>)['stack']
    if (typeof stackValue !== 'string' || stackValue.length === 0) {
      return ''
    }
    let firstLine = stackValue.split('\n')[0]
    return firstLine ?? ''
  }

  private static buildErrorDiag(err: Object): string {
    let codeValue = UserFirewallPolicyService.extractErrorCode(err)
    let nameValue = UserFirewallPolicyService.extractErrorName(err)
    let messageValue = UserFirewallPolicyService.extractErrorMessage(err)
    let stackFirstLine = UserFirewallPolicyService.extractErrorStackFirstLine(err)
    let jsonValue = UserFirewallPolicyService.safeStringifyForDiag(err)
    return `type=${typeof err}, name=${nameValue.length > 0 ? nameValue : '[empty]'}, code=${String(codeValue ?? '')}, message=${messageValue.length > 0 ? messageValue : '[empty]'}, stack=${stackFirstLine.length > 0 ? stackFirstLine : '[empty]'}, json=${jsonValue}`
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
    hilog.info(DOMAIN, TAG, '[DIAG][UserFirewall] loadAvailableUserIds start')
    try {
      let accountManager = osAccount.getAccountManager()
      hilog.info(DOMAIN, TAG, '[DIAG][UserFirewall] invoking getActivatedOsAccountLocalIds')
      let ids = await accountManager.getActivatedOsAccountLocalIds()
      hilog.info(
        DOMAIN,
        TAG,
        '[DIAG][UserFirewall] getActivatedOsAccountLocalIds result raw=%{public}s count=%{public}d',
        UserFirewallPolicyService.safeStringifyForDiag(ids),
        ids.length
      )
      if (ids.length === 0) {
        hilog.warn(DOMAIN, TAG, '[DIAG][UserFirewall] no activated users returned')
        return {
          users: [],
          message: '未找到已激活用户'
        } as UserFirewallListResult
      }

      let sortedIds = [...ids].sort((left: number, right: number) => left - right)
      hilog.info(
        DOMAIN,
        TAG,
        '[DIAG][UserFirewall] activated ids sorted=%{public}s',
        UserFirewallPolicyService.safeStringifyForDiag(sortedIds)
      )
      let foregroundId: number | undefined = undefined
      try {
        foregroundId = await accountManager.getForegroundOsAccountLocalId()
        hilog.info(DOMAIN, TAG, '[DIAG][UserFirewall] foreground localId=%{public}d', foregroundId)
      } catch (err) {
        hilog.warn(
          DOMAIN,
          TAG,
          '[DIAG][UserFirewall] getForegroundOsAccountLocalId failed: %{public}s',
          UserFirewallPolicyService.buildErrorDiag(err as Object)
        )
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
      hilog.info(
        DOMAIN,
        TAG,
        '[DIAG][UserFirewall] mapped users=%{public}s selectedUserId=%{public}d',
        UserFirewallPolicyService.safeStringifyForDiag(users as Object),
        selectedUserId
      )

      return {
        users: users,
        selectedUserId: selectedUserId
      } as UserFirewallListResult
    } catch (err) {
      UserFirewallPolicyService.recordError('读取用户列表', err as Object)
      hilog.error(
        DOMAIN,
        TAG,
        '[DIAG][UserFirewall] loadAvailableUserIds failed: %{public}s',
        UserFirewallPolicyService.buildErrorDiag(err as Object)
      )
      return {
        users: [],
        errorCode: UserFirewallPolicyService.getLastErrorCode(),
        message: UserFirewallPolicyService.getLastErrorMessage()
      } as UserFirewallListResult
    }
  }

  static async getPolicy(userId: number): Promise<UserFirewallPolicyResult> {
    UserFirewallPolicyService.clearLastError()
    hilog.info(DOMAIN, TAG, '[DIAG][UserFirewall] getPolicy start userId=%{public}d', userId)
    try {
      let policy = await netFirewall.getNetFirewallPolicy(userId)
      hilog.info(
        DOMAIN,
        TAG,
        '[DIAG][UserFirewall] getPolicy success userId=%{public}d isOpen=%{public}s inAction=%{public}d outAction=%{public}d',
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
      hilog.error(
        DOMAIN,
        TAG,
        '[DIAG][UserFirewall] getPolicy failed userId=%{public}d errorCode=%{public}s',
        userId,
        String(UserFirewallPolicyService.getLastErrorCode() ?? '')
      )
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
