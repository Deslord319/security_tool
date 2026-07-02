import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import {
  FirewallConflictSummary,
  FirewallOperationResult,
  FirewallOverviewState,
  FirewallPresetMode,
  FirewallRuleConflictMatch,
  FirewallRuleDisplayItem,
  FirewallRuleIntentInput,
  FirewallRuleMutationResult,
  FirewallToggleOperationResult,
  FirewallUserPolicyApplyResult,
  FirewallUserPolicyMode,
  FirewallUserPolicyStateResult,
  UserFirewallOption
} from './FirewallModels'
import { FirewallModeSwitchService } from './FirewallModeSwitchService'
import { FirewallPolicyService } from './FirewallPolicyService'
import { FirewallRuleDisplayService } from './FirewallRuleDisplayService'
import { FirewallRuleMutationService } from './FirewallRuleMutationService'

export class FirewallService {
  static async loadOverviewState(context: common.UIAbilityContext): Promise<FirewallOverviewState> {
    return FirewallPolicyService.loadOverviewState(context)
  }

  static async setFirewallEnabledForAllUsers(
    context: common.UIAbilityContext,
    enabled: boolean
  ): Promise<FirewallToggleOperationResult> {
    return FirewallPolicyService.setFirewallEnabledForAllUsers(context, enabled)
  }

  static async switchMode(
    context: common.UIAbilityContext,
    targetMode: FirewallPresetMode
  ): Promise<FirewallOperationResult> {
    return FirewallModeSwitchService.switchMode(context, targetMode)
  }

  static async listRulesForDisplay(context: common.UIAbilityContext): Promise<FirewallRuleDisplayItem[]> {
    return FirewallRuleDisplayService.listRulesForDisplay(context)
  }

  static async reconcileRulesForUsers(
    context: common.UIAbilityContext,
    users: UserFirewallOption[]
  ): Promise<boolean> {
    return FirewallRuleDisplayService.reconcileRulesForUsers(context, users)
  }

  static async createRule(
    context: common.UIAbilityContext,
    input: FirewallRuleIntentInput
  ): Promise<FirewallRuleMutationResult> {
    return FirewallRuleMutationService.createRule(context, input)
  }

  static async updateRule(
    context: common.UIAbilityContext,
    localRuleId: string,
    input: FirewallRuleIntentInput
  ): Promise<FirewallRuleMutationResult> {
    return FirewallRuleMutationService.updateRule(context, localRuleId, input)
  }

  static async deleteRule(
    context: common.UIAbilityContext,
    localRuleId: string
  ): Promise<FirewallRuleMutationResult> {
    return FirewallRuleMutationService.deleteRule(context, localRuleId)
  }

  static async replaceConflictRule(
    context: common.UIAbilityContext,
    conflictLocalRuleId: string,
    nextLocalRuleId: string | undefined,
    input: FirewallRuleIntentInput,
    isEditMode: boolean
  ): Promise<FirewallRuleMutationResult> {
    return FirewallRuleMutationService.replaceConflictRule(
      context,
      conflictLocalRuleId,
      nextLocalRuleId,
      input,
      isEditMode
    )
  }

  static async applyUserPolicyMode(
    context: common.UIAbilityContext,
    userId: number,
    mode: FirewallUserPolicyMode
  ): Promise<FirewallUserPolicyApplyResult> {
    return FirewallPolicyService.applyUserPolicyMode(context, userId, mode)
  }

  static async loadUserPolicyState(
    context: common.UIAbilityContext,
    userId: number
  ): Promise<FirewallUserPolicyStateResult> {
    return FirewallPolicyService.loadUserPolicyState(context, userId)
  }

  static findRuleConflict(
    existingRules: netFirewall.NetFirewallRule[],
    targetRule: netFirewall.NetFirewallRule
  ): FirewallRuleConflictMatch | null {
    return FirewallRuleDisplayService.findRuleConflict(existingRules, targetRule)
  }

  static summarizeConflicts(rules: netFirewall.NetFirewallRule[]): FirewallConflictSummary {
    return FirewallRuleDisplayService.summarizeConflicts(rules)
  }
}
