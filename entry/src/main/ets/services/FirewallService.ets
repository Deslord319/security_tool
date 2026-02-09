import { netFirewall } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'FirewallService'
const DOMAIN = 0x0001
const DEFAULT_USER_ID = 100

export class FirewallService {
  // 获取防火墙策略（含开关状态）
  static async getFirewallPolicy(): Promise<netFirewall.NetFirewallPolicy | null> {
    try {
      let policy = await netFirewall.getNetFirewallPolicy(DEFAULT_USER_ID)
      return policy
    } catch (err) {
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
      hilog.error(DOMAIN, TAG, `setFirewallEnabled failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 获取所有防火墙规则（分页获取全部）
  static async getAllRules(): Promise<netFirewall.NetFirewallRule[]> {
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
      hilog.error(DOMAIN, TAG, `getAllRules failed: ${JSON.stringify(err)}`)
      return []
    }
  }

  // 添加防火墙规则
  static async addRule(rule: netFirewall.NetFirewallRule): Promise<number> {
    try {
      let ruleId = await netFirewall.addNetFirewallRule(rule)
      hilog.info(DOMAIN, TAG, `addRule success, ruleId: ${ruleId}`)
      return ruleId
    } catch (err) {
      hilog.error(DOMAIN, TAG, `addRule failed: ${JSON.stringify(err)}`)
      return -1
    }
  }

  // 删除防火墙规则
  static async removeRule(ruleId: number): Promise<boolean> {
    try {
      await netFirewall.removeNetFirewallRule(DEFAULT_USER_ID, ruleId)
      hilog.info(DOMAIN, TAG, `removeRule success, ruleId: ${ruleId}`)
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `removeRule failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 更新防火墙规则
  static async updateRule(rule: netFirewall.NetFirewallRule): Promise<boolean> {
    try {
      await netFirewall.updateNetFirewallRule(rule)
      hilog.info(DOMAIN, TAG, `updateRule success`)
      return true
    } catch (err) {
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
