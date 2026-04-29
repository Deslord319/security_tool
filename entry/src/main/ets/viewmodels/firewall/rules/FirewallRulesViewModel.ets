import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'

import {
  FirewallDialogStrings,
  FirewallRuleStrings,
  buildFirewallConflictNotice
} from '../../../constants/modules/FirewallStrings'
import {
  attachFirewallRuleUserIds,
  FirewallOperationResult,
  FirewallPresetMode,
  FirewallRuleMutationResult,
  FirewallScopedRule,
  getFirewallRuleUserIds,
  normalizeFirewallRuleUserIds,
  UserFirewallOption
} from '../../../services/firewall/FirewallModels'
import { FirewallService } from '../../../services/firewall/FirewallService'
import { FirewallRuleUtils } from '../../../services/firewall/FirewallRuleUtils'
import { SystemUserProvider } from '../../../services/firewall/providers/SystemUserProvider'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'FirewallRulesViewModel'

export interface FirewallRulesConflictInfo {
  kind: string
  existingRule: netFirewall.NetFirewallRule | null
}

export function isFirewallRuleAllUsers(userIds: number[], availableUsers: UserFirewallOption[]): boolean {
  let normalizedUserIds = normalizeFirewallRuleUserIds(userIds)
  let normalizedAvailableUserIds = normalizeFirewallRuleUserIds(
    availableUsers.map((item: UserFirewallOption): number => item.userId)
  )
  if (normalizedUserIds.length === 0 || normalizedAvailableUserIds.length === 0) {
    return false
  }
  if (normalizedUserIds.length !== normalizedAvailableUserIds.length) {
    return false
  }
  return normalizedUserIds.every((userId: number, index: number): boolean => userId === normalizedAvailableUserIds[index])
}

export function buildFirewallRuleUserScopeLabel(
  rule: netFirewall.NetFirewallRule,
  availableUsers: UserFirewallOption[]
): string {
  let userIds = getFirewallRuleUserIds(rule)
  if (userIds.length === 0 || isFirewallRuleAllUsers(userIds, availableUsers)) {
    return FirewallDialogStrings.ALL_VALUE
  }
  let userLabelMap = new Map<number, string>()
  availableUsers.forEach((item: UserFirewallOption) => {
    userLabelMap.set(item.userId, item.label)
  })
  let labels = userIds.map((userId: number): string => userLabelMap.get(userId) ?? `用户 ${userId}`)
  return labels.join('、')
}

function cloneScopedRule(rule: netFirewall.NetFirewallRule): netFirewall.NetFirewallRule {
  let clonedRule = FirewallRuleUtils.cloneSystemRule(rule)
  let carrier = clonedRule as FirewallScopedRule
  carrier.localRuleId = (rule as FirewallScopedRule).localRuleId
  return attachFirewallRuleUserIds(clonedRule, getFirewallRuleUserIds(rule))
}

@ObservedV2
export class FirewallRulesViewModel {
  @Trace currentMode: FirewallPresetMode = 'custom'
  @Trace rules: netFirewall.NetFirewallRule[] = []
  @Trace conflictNotice: string = ''
  @Trace currentTab: number = 0
  @Trace isLoading: boolean = false
  @Trace lastSaveResult: FirewallRuleMutationResult | null = null
  @Trace lastOperationMessage: string = ''
  @Trace userOptions: UserFirewallOption[] = []

  async initialize(
    context: common.UIAbilityContext,
    currentMode: FirewallPresetMode = 'custom'
  ): Promise<FirewallOperationResult> {
    this.currentMode = currentMode
    if (currentMode !== 'custom') {
      this.rules = []
      this.conflictNotice = ''
      this.lastSaveResult = null
      this.lastOperationMessage = FirewallRuleStrings.ONLY_CUSTOM_MODE
      this.userOptions = []
      return {
        success: false,
        errorMessage: FirewallRuleStrings.ONLY_CUSTOM_MODE
      }
    }
    return this.loadRules(context)
  }

  async loadRules(context: common.UIAbilityContext): Promise<FirewallOperationResult> {
    this.isLoading = true
    try {
      await this.reloadUserOptions()
      await this.reloadRules(context)
      this.lastOperationMessage = ''
      return { success: true }
    } catch (err) {
      LogUtils.error(TAG, `loadRules failed: ${JSON.stringify(err)}`)
      this.rules = []
      this.conflictNotice = ''
      this.lastSaveResult = null
      this.lastOperationMessage = FirewallRuleStrings.APPLY_FAILED
      return { success: false, errorMessage: FirewallRuleStrings.APPLY_FAILED }
    } finally {
      this.isLoading = false
    }
  }

  setCurrentTab(index: number): void {
    this.currentTab = index < 0 ? 0 : index
  }

  getRulesByTab(index: number): netFirewall.NetFirewallRule[] {
    switch (index) {
      case 1:
        return this.rules.filter((rule: netFirewall.NetFirewallRule) => rule.type === netFirewall.NetFirewallRuleType.RULE_IP)
      case 2:
        return this.rules.filter((rule: netFirewall.NetFirewallRule) => rule.type === netFirewall.NetFirewallRuleType.RULE_DOMAIN)
      case 3:
        return this.rules.filter((rule: netFirewall.NetFirewallRule) => rule.type === netFirewall.NetFirewallRuleType.RULE_DNS)
      case 0:
      default:
        return this.rules
    }
  }

  countRulesByType(type: netFirewall.NetFirewallRuleType): number {
    return this.rules.filter((rule: netFirewall.NetFirewallRule): boolean => rule.type === type).length
  }

  countRulesByDirection(direction: netFirewall.NetFirewallRuleDirection): number {
    return this.rules.filter((rule: netFirewall.NetFirewallRule): boolean => rule.direction === direction).length
  }

  getTabCount(index: number): number {
    switch (index) {
      case 0:
        return this.rules.length
      case 1:
        return this.countRulesByType(netFirewall.NetFirewallRuleType.RULE_IP)
      case 2:
        return this.countRulesByType(netFirewall.NetFirewallRuleType.RULE_DOMAIN)
      case 3:
        return this.countRulesByType(netFirewall.NetFirewallRuleType.RULE_DNS)
      default:
        return 0
    }
  }

  getLocalRuleId(rule: netFirewall.NetFirewallRule): string | undefined {
    return (rule as FirewallScopedRule).localRuleId
  }

  findConflict(
    rule: netFirewall.NetFirewallRule,
    comparableRules: netFirewall.NetFirewallRule[] = this.rules
  ): FirewallRulesConflictInfo | null {
    const conflict = FirewallService.findRuleConflict(comparableRules, rule)
    if (!conflict) {
      return null
    }
    return {
      kind: conflict.kind,
      existingRule: FirewallRuleUtils.cloneDisplayRuleFromIntent(conflict.existingRule) ?? null
    }
  }

  async addRule(context: common.UIAbilityContext, rule: netFirewall.NetFirewallRule): Promise<FirewallRuleMutationResult> {
    this.isLoading = true
    try {
      const result = await FirewallService.createRule(
        context,
        FirewallRuleUtils.buildIntentInputFromRule(rule, getFirewallRuleUserIds(rule))
      )
      this.lastSaveResult = result
      if (result.success || (result.successDeployments?.length ?? 0) > 0) {
        await this.reloadRules(context)
        this.lastOperationMessage = FirewallRuleStrings.ADD_SUCCESS
      } else {
        this.lastOperationMessage = result.errorMessage ?? FirewallRuleStrings.APPLY_FAILED
      }
      return result
    } finally {
      this.isLoading = false
    }
  }

  async updateRule(context: common.UIAbilityContext, rule: netFirewall.NetFirewallRule): Promise<FirewallRuleMutationResult> {
    const localRuleId = this.getLocalRuleId(rule)
    if (localRuleId === undefined) {
      return { success: false, errorMessage: FirewallRuleStrings.APPLY_FAILED }
    }
    this.isLoading = true
    try {
      const result = await FirewallService.updateRule(
        context,
        localRuleId,
        FirewallRuleUtils.buildIntentInputFromRule(rule, getFirewallRuleUserIds(rule))
      )
      this.lastSaveResult = result
      if (result.success || (result.successDeployments?.length ?? 0) > 0) {
        await this.reloadRules(context)
        this.lastOperationMessage = FirewallRuleStrings.UPDATE_SUCCESS
      } else {
        this.lastOperationMessage = result.errorMessage ?? FirewallRuleStrings.APPLY_FAILED
      }
      return result
    } finally {
      this.isLoading = false
    }
  }

  async deleteRule(context: common.UIAbilityContext, rule: netFirewall.NetFirewallRule): Promise<FirewallRuleMutationResult> {
    const localRuleId = this.getLocalRuleId(rule)
    if (localRuleId === undefined) {
      return { success: false, errorMessage: FirewallRuleStrings.APPLY_FAILED }
    }
    this.isLoading = true
    try {
      const result = await FirewallService.deleteRule(context, localRuleId)
      this.lastSaveResult = result
      if (result.success) {
        await this.reloadRules(context)
        this.lastOperationMessage = FirewallRuleStrings.DELETE_SUCCESS
      } else {
        this.lastOperationMessage = result.errorMessage ?? FirewallRuleStrings.APPLY_FAILED
      }
      return result
    } finally {
      this.isLoading = false
    }
  }

  refreshConflictNotice(): void {
    const summary = FirewallService.summarizeConflicts(this.rules)
    this.conflictNotice = buildFirewallConflictNotice(summary.duplicates, summary.hardConflicts, summary.overlapConflicts)
  }

  getRuleUserScopeLabel(rule: netFirewall.NetFirewallRule): string {
    return buildFirewallRuleUserScopeLabel(rule, this.userOptions)
  }

  private async reloadRules(context: common.UIAbilityContext): Promise<void> {
    const rules = await FirewallService.listRulesForDisplay(context)
    this.rules = rules.map((rule: netFirewall.NetFirewallRule) => cloneScopedRule(rule))
    this.refreshConflictNotice()
  }

  private async reloadUserOptions(): Promise<void> {
    try {
      let result = await SystemUserProvider.loadAvailableUserIds()
      this.userOptions = result.users
    } catch (err) {
      LogUtils.error(TAG, `reloadUserOptions failed: ${JSON.stringify(err)}`)
      this.userOptions = []
    }
  }
}
