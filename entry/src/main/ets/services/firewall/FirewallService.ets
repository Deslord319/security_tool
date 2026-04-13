import { LogUtils } from '../../utils/LogUtils'
import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import {
  FirewallOperationResult,
  FirewallOverviewState,
  FirewallRulesSaveResult,
  FirewallToggleOperationResult,
  FirewallUserApplyResult,
  FirewallUserModeStateResult,
  FirewallPresetMode,
  FirewallUserApplyMode,
  UserFirewallOption
} from '../../models/firewall/firewall_service_contracts'
import { FirewallManagedRuleMetadata } from '../../models/DataModels'
import { FirewallRuleStrings } from '../../constants/modules/FirewallStrings'
import { FirewallStore } from './stores/FirewallStore'
import { FirewallRepository } from './repositories/FirewallRepository'
import {
  FirewallConflictSummary,
  FirewallRulesService,
  FirewallRuleConflictMatch
} from './rules/FirewallRulesService'
import { FirewallUserDispatchService } from './user-dispatch/FirewallUserDispatchService'
import { FirewallAuthService } from './auth/FirewallAuthService'
import { FirewallModeStrategyFactory } from './mode-strategies/FirewallModeStrategyFactory'

const TAG = 'FirewallService'

export class FirewallService {
  static async loadOverviewState(context: common.UIAbilityContext): Promise<FirewallOverviewState> {
    await FirewallModeStrategyFactory.initialize(context)
    let policy = await FirewallRepository.getFirewallPolicy()
    if (policy === null) {
      LogUtils.warn(TAG, 'loadOverviewState fallback to default state because getFirewallPolicy returned null')
      return {
        enabled: false,
        currentMode: 'custom'
      }
    }

    return {
      enabled: policy.isOpen,
      currentMode: await FirewallStore.getCurrentMode(context)
    }
  }

  static async toggleFirewall(
    context: common.UIAbilityContext,
    currentEnabled: boolean,
    targetEnabled: boolean
  ): Promise<FirewallToggleOperationResult> {
    let result = await FirewallAuthService.executeToggle(context, currentEnabled, targetEnabled)
    return {
      success: result.success,
      targetEnabled: result.targetEnabled,
      reason: result.reason,
      lockRemainingSec: result.lockRemainingSec,
      errorCode: result.errorCode,
      errorMessage: result.errorMessage
    }
  }

  static async switchMode(
    context: common.UIAbilityContext,
    targetMode: FirewallPresetMode
  ): Promise<FirewallOperationResult> {
    let result = await FirewallModeStrategyFactory.switchMode(context, targetMode)
    if (!result.success) {
      return {
        success: false,
        errorCode: result.errorCode,
        errorMessage: result.errorMessage
      }
    }
    return {
      success: true
    }
  }

  static async listCustomRules(context: common.UIAbilityContext): Promise<netFirewall.NetFirewallRule[]> {
    await FirewallModeStrategyFactory.initialize(context)
    return FirewallModeStrategyFactory.listCustomRules(context)
  }

  static async saveCustomRules(
    context: common.UIAbilityContext,
    nextRules: netFirewall.NetFirewallRule[]
  ): Promise<FirewallRulesSaveResult> {
    await FirewallModeStrategyFactory.initialize(context)
    let previousRules = await FirewallModeStrategyFactory.listCustomRules(context)
    let applyResult = await FirewallModeStrategyFactory.applyCustomRules(context, nextRules)
    if (!applyResult.success) {
      return {
        success: false,
        errorCode: applyResult.errorCode,
        errorMessage: applyResult.errorMessage,
        appliedRuleCount: 0,
        reapplyTotalUsers: 0,
        reapplySuccessCount: 0,
        reapplyFailedCount: 0,
        failedUsers: []
      }
    }

    let saved = await FirewallModeStrategyFactory.replaceAllCustomRules(context, nextRules)
    if (!saved) {
      let rollbackResult = await FirewallModeStrategyFactory.applyCustomRules(context, previousRules)
      if (!rollbackResult.success) {
        return {
          success: false,
          errorCode: rollbackResult.errorCode,
          errorMessage: FirewallRuleStrings.LOCAL_SAVE_FAILED,
          appliedRuleCount: 0,
          reapplyTotalUsers: 0,
          reapplySuccessCount: 0,
          reapplyFailedCount: 0,
          failedUsers: []
        }
      }
      return {
        success: false,
        errorCode: applyResult.errorCode,
        errorMessage: FirewallRuleStrings.ROLLBACK_SUCCESS,
        appliedRuleCount: 0,
        reapplyTotalUsers: 0,
        reapplySuccessCount: 0,
        reapplyFailedCount: 0,
        failedUsers: []
      }
    }

    let reapplySummary = await FirewallUserDispatchService.reapplyUserBindings(context, nextRules)
    return {
      success: true,
      appliedRuleCount: nextRules.length,
      reapplyTotalUsers: reapplySummary.totalUsers,
      reapplySuccessCount: reapplySummary.successCount,
      reapplyFailedCount: reapplySummary.failedCount,
      failedUsers: reapplySummary.failedUsers
    }
  }

  static async loadUserOptions(): Promise<UserFirewallOption[]> {
    return FirewallUserDispatchService.loadUserOptions()
  }

  static async loadUserModeState(
    context: common.UIAbilityContext,
    userId: number
  ): Promise<FirewallUserModeStateResult> {
    return FirewallUserDispatchService.loadUserModeState(context, userId)
  }

  static async applyUserMode(
    context: common.UIAbilityContext,
    userId: number,
    mode: FirewallUserApplyMode
  ): Promise<FirewallUserApplyResult> {
    return FirewallUserDispatchService.applyUserMode(context, userId, mode)
  }

  static async getFirewallPolicy(): Promise<netFirewall.NetFirewallPolicy | null> {
    return FirewallRepository.getFirewallPolicy()
  }

  static async getAllRules(): Promise<netFirewall.NetFirewallRule[]> {
    return FirewallRepository.getAllRules()
  }

  static async setFirewallEnabled(enabled: boolean): Promise<boolean> {
    return FirewallRepository.setFirewallEnabled(enabled)
  }

  static async setFirewallPolicy(policy: netFirewall.NetFirewallPolicy): Promise<boolean> {
    return FirewallRepository.setFirewallPolicy(policy)
  }

  static async addRule(rule: netFirewall.NetFirewallRule): Promise<number> {
    return FirewallRepository.addRule(rule)
  }

  static async removeRule(ruleId: number): Promise<boolean> {
    return FirewallRepository.removeRule(ruleId)
  }

  static async updateRule(rule: netFirewall.NetFirewallRule): Promise<boolean> {
    return FirewallRepository.updateRule(rule)
  }

  static async replaceRule(oldRuleId: number, newRule: netFirewall.NetFirewallRule): Promise<number> {
    return FirewallRepository.replaceRule(oldRuleId, newRule)
  }

  static async addRules(rules: netFirewall.NetFirewallRule[]): Promise<boolean> {
    return FirewallRepository.addRules(rules)
  }

  static async clearAllRules(): Promise<boolean> {
    return FirewallRepository.clearAllRules()
  }

  static cloneRuleForCreate(
    rule: netFirewall.NetFirewallRule,
    normalizedRemoteIps?: netFirewall.NetFirewallIpParams[],
    preserveEmptyRemoteIps: boolean = false,
    copyRuleIpRemoteIps: boolean = true
  ): netFirewall.NetFirewallRule {
    return FirewallRepository.cloneRuleForCreate(rule, normalizedRemoteIps, preserveEmptyRemoteIps, copyRuleIpRemoteIps)
  }

  static getRulePrimaryKey(rule: netFirewall.NetFirewallRule): number | undefined {
    return FirewallRepository.getRulePrimaryKey(rule)
  }

  static buildManagedRuleDescription(metadata: FirewallManagedRuleMetadata): string {
    return FirewallRulesService.buildManagedRuleDescription(metadata)
  }

  static parseManagedRuleDescription(description?: string): FirewallManagedRuleMetadata | null {
    return FirewallRulesService.parseManagedRuleDescription(description)
  }

  static applyManagedRuleMetadata(
    rule: netFirewall.NetFirewallRule,
    metadata: FirewallManagedRuleMetadata
  ): netFirewall.NetFirewallRule {
    return FirewallRulesService.applyManagedRuleMetadata(rule, metadata)
  }

  static findRuleConflict(
    existingRules: netFirewall.NetFirewallRule[],
    targetRule: netFirewall.NetFirewallRule
  ): FirewallRuleConflictMatch | null {
    return FirewallRulesService.findRuleConflict(existingRules, targetRule)
  }

  static summarizeConflicts(rules: netFirewall.NetFirewallRule[]): FirewallConflictSummary {
    return FirewallRulesService.summarizeConflicts(rules)
  }

  static countByType(rules: netFirewall.NetFirewallRule[], type: netFirewall.NetFirewallRuleType): number {
    return FirewallRulesService.countByType(rules, type)
  }

  static countByDirection(rules: netFirewall.NetFirewallRule[], direction: netFirewall.NetFirewallRuleDirection): number {
    return FirewallRulesService.countByDirection(rules, direction)
  }
}
