import { netFirewall } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'FirewallService'
const DOMAIN = 0x0001
const DEFAULT_USER_ID = 100
export type FirewallErrorKind = 'invalid_argument' | 'permission' | 'unknown'

export class FirewallService {
  private static lastErrorCode: number | undefined = undefined
  private static lastErrorMessage: string = ''
  private static lastErrorKind: FirewallErrorKind = 'unknown'

  static clearLastError(): void {
    FirewallService.lastErrorCode = undefined
    FirewallService.lastErrorMessage = ''
    FirewallService.lastErrorKind = 'unknown'
  }

  static getLastErrorText(): string {
    if (FirewallService.lastErrorMessage.length === 0) {
      return ''
    }
    if (FirewallService.lastErrorCode !== undefined) {
      return `${FirewallService.lastErrorMessage}（错误码 ${FirewallService.lastErrorCode}）`
    }
    return FirewallService.lastErrorMessage
  }

  static getLastErrorCode(): number | undefined {
    return FirewallService.lastErrorCode
  }

  static getLastErrorKind(): FirewallErrorKind {
    return FirewallService.lastErrorKind
  }

  private static recordError(action: string, err: Object): void {
    let code = FirewallService.extractErrorCode(err)
    let message = FirewallService.extractErrorMessage(err)
    FirewallService.lastErrorCode = code
    FirewallService.lastErrorKind = FirewallService.classifyError(code, message)
    FirewallService.lastErrorMessage = message.length > 0 ? message : `${action}失败`
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
    let messageValue = (err as Record<string, Object>)['message']
    if (typeof messageValue === 'string') {
      return messageValue
    }
    let dataValue = (err as Record<string, Object>)['data']
    if (typeof dataValue === 'string') {
      return dataValue
    }
    return ''
  }

  private static classifyError(code: number | undefined, message: string): FirewallErrorKind {
    let normalized = message.toLowerCase()
    if (normalized.includes('permission') ||
      normalized.includes('denied') ||
      normalized.includes('admin') ||
      normalized.includes('unauthorized') ||
      code === 9200001) {
      return 'permission'
    }
    if (normalized.includes('invalid') ||
      normalized.includes('argument') ||
      normalized.includes('param') ||
      normalized.includes('format') ||
      normalized.includes('value')) {
      return 'invalid_argument'
    }
    return 'unknown'
  }

  // 获取防火墙策略（含开关状态）
  static async getFirewallPolicy(): Promise<netFirewall.NetFirewallPolicy | null> {
    FirewallService.clearLastError()
    try {
      let policy = await netFirewall.getNetFirewallPolicy(DEFAULT_USER_ID)
      return policy
    } catch (err) {
      FirewallService.recordError('读取防火墙策略', err as Object)
      hilog.error(DOMAIN, TAG, `getFirewallPolicy failed: ${JSON.stringify(err)}`)
      return null
    }
  }

  // 获取防火墙开关状态
  static async getFirewallStatus(): Promise<boolean> {
    let policy = await FirewallService.getFirewallPolicy()
    return policy !== null ? policy.isOpen : false
  }

  // 启用/禁用防火墙
  static async setFirewallEnabled(enabled: boolean): Promise<boolean> {
    FirewallService.clearLastError()
    try {
      let policy: netFirewall.NetFirewallPolicy = {
        isOpen: enabled,
        inAction: netFirewall.FirewallRuleAction.RULE_ALLOW,
        outAction: netFirewall.FirewallRuleAction.RULE_ALLOW
      }
      await netFirewall.setNetFirewallPolicy(DEFAULT_USER_ID, policy)
      hilog.info(DOMAIN, TAG, `setFirewallEnabled: ${enabled}`)
      return true
    } catch (err) {
      FirewallService.recordError('设置防火墙状态', err as Object)
      hilog.error(DOMAIN, TAG, `setFirewallEnabled failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 获取所有防火墙规则（分页获取全部）
  static async getAllRules(): Promise<netFirewall.NetFirewallRule[]> {
    FirewallService.clearLastError()
    try {
      let requestParam: netFirewall.RequestParam = {
        page: 1,
        pageSize: 50,
        orderField: netFirewall.NetFirewallOrderField.ORDER_BY_RULE_NAME,
        orderType: netFirewall.NetFirewallOrderType.ORDER_ASC
      }
      let result = await netFirewall.getNetFirewallRules(DEFAULT_USER_ID, requestParam)
      return result.data ?? []
    } catch (err) {
      FirewallService.recordError('读取防火墙规则', err as Object)
      hilog.error(DOMAIN, TAG, `getAllRules failed: ${JSON.stringify(err)}`)
      return []
    }
  }

  // 添加防火墙规则
  static async addRule(rule: netFirewall.NetFirewallRule): Promise<number> {
    FirewallService.clearLastError()
    try {
      let ruleId = await netFirewall.addNetFirewallRule(rule)
      hilog.info(DOMAIN, TAG, `addRule success, ruleId: ${ruleId}`)
      return ruleId
    } catch (err) {
      FirewallService.recordError('新增防火墙规则', err as Object)
      hilog.error(DOMAIN, TAG, `addRule failed: ${JSON.stringify(err)}`)
      return -1
    }
  }

  // 删除防火墙规则
  static async removeRule(ruleId: number): Promise<boolean> {
    FirewallService.clearLastError()
    try {
      await netFirewall.removeNetFirewallRule(DEFAULT_USER_ID, ruleId)
      hilog.info(DOMAIN, TAG, `removeRule success, ruleId: ${ruleId}`)
      return true
    } catch (err) {
      FirewallService.recordError('删除防火墙规则', err as Object)
      hilog.error(DOMAIN, TAG, `removeRule failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 更新防火墙规则
  static async updateRule(rule: netFirewall.NetFirewallRule): Promise<boolean> {
    FirewallService.clearLastError()
    try {
      await netFirewall.updateNetFirewallRule(rule)
      hilog.info(DOMAIN, TAG, `updateRule success`)
      return true
    } catch (err) {
      FirewallService.recordError('更新防火墙规则', err as Object)
      hilog.error(DOMAIN, TAG, `updateRule failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 按规则类型统计数量
  static countByType(rules: netFirewall.NetFirewallRule[], type: netFirewall.NetFirewallRuleType): number {
    return rules.filter((r: netFirewall.NetFirewallRule) => r.type === type).length
  }

  // 按方向统计数量
  static countByDirection(rules: netFirewall.NetFirewallRule[], direction: netFirewall.NetFirewallRuleDirection): number {
    return rules.filter((r: netFirewall.NetFirewallRule) => r.direction === direction).length
  }
}
