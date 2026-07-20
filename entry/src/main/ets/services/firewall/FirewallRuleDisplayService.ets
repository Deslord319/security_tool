import { netFirewall } from '@kit.NetworkKit'
import { FirewallLocalRepository } from './FirewallLocalRepository'
import {
  FirewallConflictSummary,
  FirewallRuleConflictMatch,
  FirewallRuleDeployment,
  FirewallRuleDisplayItem,
  FirewallRuleIntent,
  FirewallScopedRule,
  UserFirewallOption
} from '../../models/firewall/FirewallModels'
import { FirewallRuleMutationService } from './FirewallRuleMutationService'
import { FirewallRuleUtils } from './FirewallRuleUtils'
import { common } from '@kit.AbilityKit'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'FirewallRuleDisplayService'

export class FirewallRuleDisplayService {
  static async reconcileRulesForUsers(context: common.UIAbilityContext, users: UserFirewallOption[]): Promise<boolean> {
    if (users.length === 0) {
      return true
    }
    let pruned = await FirewallLocalRepository.pruneUnavailableUsers(
      context,
      users.map((user: UserFirewallOption): number => user.userId)
    )
    if (!pruned) {
      LogUtils.warn(TAG, 'reconcileRulesForUsers failed')
    }
    return pruned
  }

  static async listRulesForDisplay(context: common.UIAbilityContext): Promise<FirewallRuleDisplayItem[]> {
    let data = await FirewallLocalRepository.loadRuleIntentMappingData(context)
    return data.ruleIntents.map((intent: FirewallRuleIntent): FirewallRuleDisplayItem => {
      let deployments = data.ruleDeployments.filter((item: FirewallRuleDeployment): boolean => item.localRuleId === intent.localRuleId)
      return FirewallRuleUtils.cloneDisplayRuleFromIntent(intent, deployments)
    })
  }

  static findRuleConflict(
    existingRules: netFirewall.NetFirewallRule[],
    targetRule: netFirewall.NetFirewallRule
  ): FirewallRuleConflictMatch | null {
    let existingIntents = existingRules.map((rule: netFirewall.NetFirewallRule): FirewallRuleIntent =>
      FirewallRuleDisplayService.displayRuleToIntent(rule, `display_${FirewallRuleDisplayService.readDisplayLocalRuleId(rule) ?? ''}`)
    )
    let targetIntent = FirewallRuleDisplayService.displayRuleToIntent(targetRule, 'target')
    return FirewallRuleUtils.findRuleConflict(existingIntents, targetIntent, FirewallRuleDisplayService.readDisplayLocalRuleId(targetRule))
  }

  static summarizeConflicts(rules: netFirewall.NetFirewallRule[]): FirewallConflictSummary {
    return FirewallRuleUtils.summarizeConflicts(
      rules.map((rule: netFirewall.NetFirewallRule): FirewallRuleIntent =>
        FirewallRuleDisplayService.displayRuleToIntent(
          rule,
          FirewallRuleDisplayService.readDisplayLocalRuleId(rule) ?? FirewallRuleMutationService.generateLocalRuleId()
        )
      )
    )
  }

  private static displayRuleToIntent(rule: netFirewall.NetFirewallRule, fallbackLocalRuleId: string): FirewallRuleIntent {
    let input = FirewallRuleUtils.buildIntentInputFromRule(rule, FirewallRuleDisplayService.readDisplayTargetUserIds(rule))
    return FirewallRuleUtils.buildIntentFromInput(
      input.localRuleId ?? fallbackLocalRuleId,
      input,
      Date.now()
    )
  }

  private static readDisplayLocalRuleId(rule: netFirewall.NetFirewallRule): string | undefined {
    let source = rule as FirewallScopedRule
    return source.localRuleId
  }

  private static readDisplayTargetUserIds(rule: netFirewall.NetFirewallRule): number[] {
    let source = rule as FirewallScopedRule
    return Array.isArray(source.targetUserIds) ? source.targetUserIds : []
  }
}
