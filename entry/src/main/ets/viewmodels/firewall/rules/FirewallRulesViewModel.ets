import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'

import { FirewallStrings } from '../../../constants/modules/FirewallStrings'
import {
  FirewallOperationResult,
  FirewallPresetMode,
  FirewallRulesSaveResult
} from '../../../models/firewall/firewall_service_contracts'
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

@ObservedV2
export class FirewallRulesViewModel {
  @Trace currentMode: FirewallPresetMode = 'custom'
  @Trace rules: netFirewall.NetFirewallRule[] = []
  @Trace conflictNotice: string = ''
  @Trace currentTab: number = 0
  @Trace isLoading: boolean = false
  @Trace lastSaveResult: FirewallRulesSaveResult | null = null
  @Trace lastOperationMessage: string = ''

  async initialize(
    context: common.UIAbilityContext,
    currentMode: FirewallPresetMode = 'custom'
  ): Promise<FirewallOperationResult> {
    this.currentMode = currentMode
    if (currentMode !== 'custom') {
      this.rules = []
      this.conflictNotice = ''
      this.lastSaveResult = null
      this.lastOperationMessage = FirewallStrings.rulesOnlyCustomMode
      return {
        success: false,
        errorMessage: FirewallStrings.rulesOnlyCustomMode
      }
    }
    return this.loadRules(context)
  }

  async loadRules(context: common.UIAbilityContext): Promise<FirewallOperationResult> {
    this.isLoading = true
    try {
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
      this.lastOperationMessage = FirewallStrings.customRulesApplyFailed
      return {
        success: false,
        errorMessage: FirewallStrings.customRulesApplyFailed
      }
    } finally {
      this.isLoading = false
    }
  }

  setCurrentTab(index: number): void {
    this.currentTab = index < 0 ? 0 : index
  }

  getFilteredRules(): netFirewall.NetFirewallRule[] {
    if (this.currentTab === 0) {
      return this.rules
    }

    const targetType = this.getTargetRuleType()
    if (targetType === null) {
      return this.rules
    }
    return this.rules.filter((rule: netFirewall.NetFirewallRule) => rule.type === targetType)
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
    const previousRules = this.rules.map((rule: netFirewall.NetFirewallRule) =>
      FirewallService.cloneRuleForCreate(rule)
    )
    this.isLoading = true
    try {
      const result = await FirewallService.saveCustomRules(context, nextRules)
      this.lastSaveResult = result
      if (result.success) {
      this.rules = nextRules.map((rule: netFirewall.NetFirewallRule) => FirewallService.cloneRuleForCreate(rule))
      this.refreshConflictNotice()
      const reapplySuccessCount = result.reapplySuccessCount ?? 0
      const reapplyFailedCount = result.reapplyFailedCount ?? 0
      this.lastOperationMessage = reapplyFailedCount > 0
        ? FirewallStrings.buildReapplyPartialFailedMessage(reapplySuccessCount, reapplyFailedCount)
        : successMessage
      return result
      }

      this.lastOperationMessage = result.errorMessage ?? FirewallStrings.customRulesApplyFailed
      await this.restoreRules(context, previousRules)
      return result
    } catch (err) {
      LogUtils.error(TAG, `saveRules failed: ${JSON.stringify(err)}`)
      this.lastSaveResult = {
        success: false,
        errorMessage: FirewallStrings.customRulesApplyFailed
      }
      this.lastOperationMessage = FirewallStrings.customRulesApplyFailed
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
    return this.saveRules(context, [...this.rules, rule], FirewallStrings.addRuleSuccess)
  }

  async updateRule(
    context: common.UIAbilityContext,
    rule: netFirewall.NetFirewallRule
  ): Promise<FirewallRulesSaveResult> {
    const localRuleId = this.getLocalRuleId(rule)
    const nextRules = this.rules.map((item: netFirewall.NetFirewallRule) =>
      this.getLocalRuleId(item) === localRuleId ? rule : item
    )
    return this.saveRules(context, nextRules, FirewallStrings.updateRuleSuccess)
  }

  async deleteRule(
    context: common.UIAbilityContext,
    rule: netFirewall.NetFirewallRule
  ): Promise<FirewallRulesSaveResult> {
    const localRuleId = this.getLocalRuleId(rule)
    const nextRules = this.rules.filter((item: netFirewall.NetFirewallRule) => this.getLocalRuleId(item) !== localRuleId)
    return this.saveRules(context, nextRules, FirewallStrings.deleteRuleSuccess)
  }

  refreshConflictNotice(): void {
    const summary = FirewallService.summarizeConflicts(this.rules)
    this.conflictNotice = FirewallStrings.buildConflictNotice(
      summary.duplicates,
      summary.hardConflicts,
      summary.overlapConflicts
    )
  }

  private async reloadRules(context: common.UIAbilityContext): Promise<void> {
    const rules = await FirewallService.listCustomRules(context)
    this.rules = rules.map((rule: netFirewall.NetFirewallRule) => FirewallService.cloneRuleForCreate(rule))
    this.refreshConflictNotice()
  }

  private async restoreRules(
    context: common.UIAbilityContext,
    previousRules: netFirewall.NetFirewallRule[]
  ): Promise<void> {
    try {
      const rules = await FirewallService.listCustomRules(context)
      this.rules = rules.map((rule: netFirewall.NetFirewallRule) => FirewallService.cloneRuleForCreate(rule))
    } catch (err) {
      LogUtils.error(TAG, `restoreRules fallback failed: ${JSON.stringify(err)}`)
      this.rules = previousRules.map((rule: netFirewall.NetFirewallRule) => FirewallService.cloneRuleForCreate(rule))
    }
    this.refreshConflictNotice()
  }

  private getTargetRuleType(): netFirewall.NetFirewallRuleType | null {
    switch (this.currentTab) {
      case 1:
        return netFirewall.NetFirewallRuleType.RULE_IP
      case 2:
        return netFirewall.NetFirewallRuleType.RULE_DOMAIN
      case 3:
        return netFirewall.NetFirewallRuleType.RULE_DNS
      default:
        return null
    }
  }
}
