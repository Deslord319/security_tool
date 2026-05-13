import { netFirewall } from '@kit.NetworkKit'
import { FirewallSystemErrorStrings } from '../../constants/modules/FirewallErrorStrings'
import { LogUtils } from '../../utils/LogUtils'
import { CommonErrorUtils } from '../../utils/CommonErrorUtils'
import { FirewallBatchOperationResult, FirewallFailedItem, FirewallScopedRule } from './FirewallModels'

const TAG = 'FirewallSystemRepository'

export class FirewallSystemRepository {
  static async getPolicy(userId: number): Promise<netFirewall.NetFirewallPolicy | null> {
    try {
      return await netFirewall.getNetFirewallPolicy(userId)
    } catch (err) {
      LogUtils.error(TAG, `getPolicy failed: userId=${userId}, err=${JSON.stringify(err)}`)
      return null
    }
  }

  static async setPolicy(userId: number, policy: netFirewall.NetFirewallPolicy): Promise<boolean> {
    try {
      await netFirewall.setNetFirewallPolicy(userId, policy)
      return true
    } catch (err) {
      LogUtils.error(TAG, `setPolicy failed: userId=${userId}, err=${JSON.stringify(err)}`)
      return false
    }
  }

  static async listRules(userId: number): Promise<netFirewall.NetFirewallRule[]> {
    try {
      let allRules: netFirewall.NetFirewallRule[] = []
      let page = 1
      const pageSize = 50
      while (true) {
        let requestParam: netFirewall.RequestParam = {
          page: page,
          pageSize: pageSize,
          orderField: netFirewall.NetFirewallOrderField.ORDER_BY_RULE_NAME,
          orderType: netFirewall.NetFirewallOrderType.ORDER_ASC
        }
        let result = await netFirewall.getNetFirewallRules(userId, requestParam)
        let pageRules = result.data ?? []
        allRules.push(...pageRules)
        if (pageRules.length < pageSize) {
          break
        }
        page++
      }
      return allRules
    } catch (err) {
      LogUtils.error(TAG, `listRules failed: userId=${userId}, err=${JSON.stringify(err)}`)
      return []
    }
  }

  static async addRule(rule: netFirewall.NetFirewallRule): Promise<FirewallAddRuleRawResult> {
    try {
      return {
        systemRuleId: await netFirewall.addNetFirewallRule(rule)
      }
    } catch (err) {
      let errorCode = CommonErrorUtils.extractErrorCode(err)
      let errorMessage = CommonErrorUtils.extractErrorMessage(err)
      LogUtils.error(TAG, `addRule failed: userId=${rule.userId}, payload=${JSON.stringify(rule)}, err=${JSON.stringify(err)}`)
      return {
        errorCode: errorCode,
        errorMessage: errorMessage
      }
    }
  }

  static async removeRule(userId: number, systemRuleId: number): Promise<boolean> {
    try {
      await netFirewall.removeNetFirewallRule(userId, systemRuleId)
      return true
    } catch (err) {
      LogUtils.error(TAG, `removeRule failed: userId=${userId}, systemRuleId=${systemRuleId}, err=${JSON.stringify(err)}`)
      return false
    }
  }

  static async clearRules(userId: number): Promise<FirewallBatchOperationResult> {
    let rules = await FirewallSystemRepository.listRules(userId)
    let failedItems: FirewallFailedItem[] = []
    for (let i = 0; i < rules.length; i++) {
      let ruleId = FirewallSystemRepository.readSystemRuleId(rules[i])
      if (ruleId === undefined) {
        failedItems.push({ userId: userId, errorMessage: FirewallSystemErrorStrings.MISSING_SYSTEM_RULE_ID })
        continue
      }
      let removed = await FirewallSystemRepository.removeRule(userId, ruleId)
      if (!removed) {
        failedItems.push({ userId: userId, systemRuleId: ruleId })
      }
    }
    return {
      success: failedItems.length === 0,
      failedItems: failedItems
    }
  }

  private static readSystemRuleId(rule: netFirewall.NetFirewallRule): number | undefined {
    let source = rule as FirewallScopedRule
    return typeof source.id === 'number' ? source.id : undefined
  }
}

export interface FirewallAddRuleRawResult {
  systemRuleId?: number
  errorCode?: number
  errorMessage?: string
}
