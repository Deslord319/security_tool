import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'

import {
  FirewallDialogStrings,
  FirewallRuleStrings,
  buildFirewallConflictNotice,
  buildFirewallReapplyPartialFailedMessage
} from '../../../constants/modules/FirewallStrings'
import {
  FirewallOperationResult,
  FirewallPresetMode,
  FirewallRulesSaveResult,
  UserFirewallOption
} from '../../../models/firewall/firewall_service_contracts'
import {
  attachFirewallRuleUserIds,
  FirewallScopedRule,
  getFirewallRuleUserIds,
  normalizeFirewallRuleUserIds as normalizeScopedUserIds
} from '../../../models/DataModels'
import { FirewallService } from '../../../services/firewall/FirewallService'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'FirewallRulesViewModel'

interface LocalRuleIdCarrier {
  ruleId?: number
  id?: number
}

export interface FirewallRulesConflictInfo {
  kind: string
  existingRule: netFirewall.NetFirewallRule | null
}

export function normalizeFirewallRuleUserIds(userIds: number[] | undefined | null): number[] {
  return normalizeScopedUserIds(userIds ?? [])
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

function cloneScopedRule(rule: netFirewall.NetFirewallRule): FirewallScopedRule {
  let clonedRule = FirewallService.cloneRuleForCreate(rule)
  return attachFirewallRuleUserIds(clonedRule, getFirewallRuleUserIds(rule))
}

@ObservedV2
export class FirewallRulesViewModel {
  @Trace currentMode: FirewallPresetMode = 'custom'
  @Trace rules: netFirewall.NetFirewallRule[] = []
  @Trace conflictNotice: string = ''
  @Trace currentTab: number = 0
  @Trace isLoading: boolean = false
  @Trace lastSaveResult: FirewallRulesSaveResult | null = null
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
      return {
        success: true
      }
    } catch (err) {
      LogUtils.error(TAG, `loadRules failed: ${JSON.stringify(err)}`)
      this.rules = []
      this.conflictNotice = ''
      this.lastSaveResult = null
      this.lastOperationMessage = FirewallRuleStrings.APPLY_FAILED
      return {
        success: false,
        errorMessage: FirewallRuleStrings.APPLY_FAILED
      }
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
    return this.rules.filter((rule: netFirewall.NetFirewallRule) => rule.type === type).length
  }

  countRulesByDirection(direction: netFirewall.NetFirewallRuleDirection): number {
    return this.rules.filter((rule: netFirewall.NetFirewallRule) => rule.direction === direction).length
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

  getLocalRuleId(rule: netFirewall.NetFirewallRule): number | undefined {
    const sourceRule = rule as LocalRuleIdCarrier
    if (typeof sourceRule.ruleId === 'number') {
      return sourceRule.ruleId
    }
    if (typeof sourceRule.id === 'number') {
      return sourceRule.id
    }
    return undefined
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
      existingRule: conflict.existingRule ?? null
    }
  }

  async saveRules(
    context: common.UIAbilityContext,
    nextRules: netFirewall.NetFirewallRule[],
    successMessage: string = ''
  ): Promise<FirewallRulesSaveResult> {
    const previousRules = this.rules.map((rule: netFirewall.NetFirewallRule) => cloneScopedRule(rule))
    this.isLoading = true
    try {
      const result = await FirewallService.saveCustomRules(context, nextRules)
      this.lastSaveResult = result
      if (result.success) {
        await this.reloadUserOptions()
        await this.reloadRules(context)
        const reapplySuccessCount = result.reapplySuccessCount ?? 0
        const reapplyFailedCount = result.reapplyFailedCount ?? 0
        this.lastOperationMessage = reapplyFailedCount > 0
          ? buildFirewallReapplyPartialFailedMessage(reapplySuccessCount, reapplyFailedCount)
          : successMessage
        return result
      }

      this.lastOperationMessage = result.errorMessage ?? FirewallRuleStrings.APPLY_FAILED
      await this.restoreRules(context, previousRules)
      return result
    } catch (err) {
      LogUtils.error(TAG, `saveRules failed: ${JSON.stringify(err)}`)
      this.lastSaveResult = {
        success: false,
        errorMessage: FirewallRuleStrings.APPLY_FAILED
      }
      this.lastOperationMessage = FirewallRuleStrings.APPLY_FAILED
      await this.restoreRules(context, previousRules)
      return this.lastSaveResult
    } finally {
      this.isLoading = false
    }
  }

  async addRule(
    context: common.UIAbilityContext,
    rule: netFirewall.NetFirewallRule
  ): Promise<FirewallRulesSaveResult> {
    return this.saveRules(context, [...this.rules, cloneScopedRule(rule)], FirewallRuleStrings.ADD_SUCCESS)
  }

  async updateRule(
    context: common.UIAbilityContext,
    rule: netFirewall.NetFirewallRule
  ): Promise<FirewallRulesSaveResult> {
    const localRuleId = this.getLocalRuleId(rule)
    const nextRules = this.rules.map((item: netFirewall.NetFirewallRule) =>
      this.getLocalRuleId(item) === localRuleId ? cloneScopedRule(rule) : cloneScopedRule(item)
    )
    return this.saveRules(context, nextRules, FirewallRuleStrings.UPDATE_SUCCESS)
  }

  async deleteRule(
    context: common.UIAbilityContext,
    rule: netFirewall.NetFirewallRule
  ): Promise<FirewallRulesSaveResult> {
    const localRuleId = this.getLocalRuleId(rule)
    const nextRules = this.rules
      .filter((item: netFirewall.NetFirewallRule) => this.getLocalRuleId(item) !== localRuleId)
      .map((item: netFirewall.NetFirewallRule) => cloneScopedRule(item))
    return this.saveRules(context, nextRules, FirewallRuleStrings.DELETE_SUCCESS)
  }

  refreshConflictNotice(): void {
    const summary = FirewallService.summarizeConflicts(this.rules)
    this.conflictNotice = buildFirewallConflictNotice(
      summary.duplicates,
      summary.hardConflicts,
      summary.overlapConflicts
    )
  }

  getRuleUserScopeLabel(rule: netFirewall.NetFirewallRule): string {
    return buildFirewallRuleUserScopeLabel(rule, this.userOptions)
  }

  private async reloadRules(context: common.UIAbilityContext): Promise<void> {
    const rules = await FirewallService.listCustomRules(context)
    this.rules = rules.map((rule: netFirewall.NetFirewallRule) => cloneScopedRule(rule))
    this.refreshConflictNotice()
  }

  private async reloadUserOptions(): Promise<void> {
    try {
      this.userOptions = await FirewallService.loadUserOptions()
    } catch (err) {
      LogUtils.error(TAG, `reloadUserOptions failed: ${JSON.stringify(err)}`)
      this.userOptions = []
    }
  }

  private async restoreRules(
    context: common.UIAbilityContext,
    previousRules: netFirewall.NetFirewallRule[]
  ): Promise<void> {
    try {
      const rules = await FirewallService.listCustomRules(context)
      this.rules = rules.map((rule: netFirewall.NetFirewallRule) => cloneScopedRule(rule))
    } catch (err) {
      LogUtils.error(TAG, `restoreRules fallback failed: ${JSON.stringify(err)}`)
      this.rules = previousRules.map((rule: netFirewall.NetFirewallRule) => cloneScopedRule(rule))
    }
    this.refreshConflictNotice()
  }
}
