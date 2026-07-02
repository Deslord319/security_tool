import { netFirewall } from '@kit.NetworkKit'
import { FirewallSystemErrorStrings } from '../../constants/modules/FirewallErrorStrings'
import { SafeRunner } from '../../utils/SafeRunner'
import { CommonErrorUtils } from '../../utils/CommonErrorUtils'
import { FirewallBatchOperationResult, FirewallFailedItem } from './FirewallModels'
import { FirewallRuleUtils } from './FirewallRuleUtils'

const TAG = 'FirewallSystemRepository'

export class FirewallSystemRepository {
  static async getPolicy(userId: number): Promise<netFirewall.NetFirewallPolicy | null> {
    return SafeRunner.runAsync(
      TAG,
      `getPolicy userId=${userId}`,
      () => netFirewall.getNetFirewallPolicy(userId),
      () => null
    )
  }

  static async setPolicy(userId: number, policy: netFirewall.NetFirewallPolicy): Promise<boolean> {
    return SafeRunner.runAsync(
      TAG,
      `setPolicy userId=${userId}`,
      async () => {
        await netFirewall.setNetFirewallPolicy(userId, policy)
        return true
      },
      () => false
    )
  }

  static async listRules(userId: number): Promise<netFirewall.NetFirewallRule[]> {
    return SafeRunner.runAsync(
      TAG,
      `listRules userId=${userId}`,
      async () => {
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
      },
      () => [] as netFirewall.NetFirewallRule[]
    )
  }

  static async addRule(rule: netFirewall.NetFirewallRule): Promise<FirewallAddRuleRawResult> {
    return SafeRunner.runAsync(
      TAG,
      `addRule userId=${rule.userId}`,
      async () => {
        return {
          systemRuleId: await netFirewall.addNetFirewallRule(rule)
        } as FirewallAddRuleRawResult
      },
      (err) => ({
        errorCode: CommonErrorUtils.extractErrorCode(err),
        errorMessage: CommonErrorUtils.extractErrorMessage(err)
      } as FirewallAddRuleRawResult)
    )
  }

  static async removeRule(userId: number, systemRuleId: number): Promise<boolean> {
    return SafeRunner.runAsync(
      TAG,
      `removeRule userId=${userId} systemRuleId=${systemRuleId}`,
      async () => {
        await netFirewall.removeNetFirewallRule(userId, systemRuleId)
        return true
      },
      () => false
    )
  }

  static async updateRule(rule: netFirewall.NetFirewallRule): Promise<FirewallSystemRuleMutationResult> {
    return SafeRunner.runAsync(
      TAG,
      `updateRule userId=${rule.userId}`,
      async () => {
        await netFirewall.updateNetFirewallRule(rule)
        return { success: true } as FirewallSystemRuleMutationResult
      },
      (err) => ({
        success: false,
        errorCode: CommonErrorUtils.extractErrorCode(err),
        errorMessage: CommonErrorUtils.extractErrorMessage(err)
      } as FirewallSystemRuleMutationResult)
    )
  }

  static async clearRules(userId: number): Promise<FirewallBatchOperationResult> {
    let rules = await FirewallSystemRepository.listRules(userId)
    let failedItems: FirewallFailedItem[] = []
    for (let i = 0; i < rules.length; i++) {
      let ruleId = FirewallRuleUtils.readSystemRuleId(rules[i])
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
}

interface FirewallAddRuleRawResult {
  systemRuleId?: number
  errorCode?: number
  errorMessage?: string
}

interface FirewallSystemRuleMutationResult {
  success: boolean
  errorCode?: number
  errorMessage?: string
}
