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
import { SystemUserProvider } from './providers/SystemUserProvider'

const TAG = 'FirewallService'

interface UserPolicySnapshot {
  userId: number
  policy: netFirewall.NetFirewallPolicy
}

export class FirewallService {
  static async loadOverviewState(context: common.UIAbilityContext): Promise<FirewallOverviewState> {
    await FirewallModeStrategyFactory.initialize(context)
    let availableUsers = await SystemUserProvider.loadAvailableUserIds()
    if (availableUsers.users.length === 0) {
      LogUtils.warn(TAG, 'loadOverviewState fallback to default state because no available users')
      return {
        enabled: false,
        currentMode: 'custom'
      }
    }

    let enabled = true
    for (let i = 0; i < availableUsers.users.length; i++) {
      let policy = await SystemUserProvider.getPolicy(availableUsers.users[i].userId)
      if (!policy.isOpen) {
        enabled = false
        break
      }
    }

    return {
      enabled: enabled,
      currentMode: await FirewallStore.getCurrentMode(context)
    }
  }

  static async toggleFirewall(
    context: common.UIAbilityContext,
    currentEnabled: boolean,
    targetEnabled: boolean
  ): Promise<FirewallToggleOperationResult> {
    let result = await FirewallAuthService.executeToggle(
      context,
      currentEnabled,
      targetEnabled,
      async (enabled: boolean): Promise<boolean> => FirewallService.applyHomeToggleForAllUsers(context, enabled)
    )
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

    return {
      success: true,
      appliedRuleCount: nextRules.length,
      reapplyTotalUsers: 0,
      reapplySuccessCount: 0,
      reapplyFailedCount: 0,
      failedUsers: []
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

  private static async applyHomeToggleForAllUsers(
    context: common.UIAbilityContext,
    targetEnabled: boolean
  ): Promise<boolean> {
    let usersResult = await SystemUserProvider.loadAvailableUserIds()
    let users = usersResult.users
    if (users.length === 0) {
      return true
    }

    if (!targetEnabled) {
      return FirewallService.setOpenStateForUsers(users, false)
    }

    let currentMode = await FirewallModeStrategyFactory.getCurrentMode(context)
    let modeResult = await FirewallModeStrategyFactory.switchMode(context, currentMode)
    return modeResult.success
  }

  private static async setOpenStateForUsers(
    users: UserFirewallOption[],
    isOpen: boolean
  ): Promise<boolean> {
    let snapshots: UserPolicySnapshot[] = []
    for (let i = 0; i < users.length; i++) {
      let userId = users[i].userId
      let policy = await FirewallRepository.getFirewallPolicyByUserId(userId)
      if (policy === null) {
        return false
      }
      snapshots.push({
        userId: userId,
        policy: {
          isOpen: policy.isOpen,
          inAction: policy.inAction,
          outAction: policy.outAction
        }
      })
    }

    for (let i = 0; i < snapshots.length; i++) {
      let snapshot = snapshots[i]
      let nextPolicy: netFirewall.NetFirewallPolicy = {
        isOpen: isOpen,
        inAction: snapshot.policy.inAction,
        outAction: snapshot.policy.outAction
      }
      let applied = await FirewallRepository.setFirewallPolicyByUserId(snapshot.userId, nextPolicy)
      if (!applied) {
        LogUtils.error(TAG, `setOpenStateForUsers failed: userId=${snapshot.userId}`)
        for (let j = 0; j < i; j++) {
          let previous = snapshots[j]
          let rollbackApplied = await FirewallRepository.setFirewallPolicyByUserId(previous.userId, previous.policy)
          if (!rollbackApplied) {
            LogUtils.error(TAG, `setOpenStateForUsers rollback failed: userId=${previous.userId}`)
          }
        }
        return false
      }
    }

    return true
  }
}
