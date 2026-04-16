import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'

import {
  FirewallUserApplyMode,
  FirewallModeSwitchResult,
  FirewallPresetMode,
  UserFirewallOption,
  UserScopedFirewallRuleBucket
} from '../../../models/DataModels'
import { FirewallModeRepository } from '../repositories/FirewallModeRepository'
import { FirewallUserBindingsRepository } from '../repositories/FirewallUserBindingsRepository'
import { FirewallRepository } from '../repositories/FirewallRepository'
import { CustomModeStrategy } from './CustomModeStrategy'
import { FirewallModeStrategy } from './FirewallModeStrategy'
import { PresetModeStrategy } from './PresetModeStrategy'
import { FirewallRulesService } from '../rules/FirewallRulesService'
import { SystemUserProvider } from '../providers/SystemUserProvider'

interface UserManagedSnapshot {
  userId: number
  policy: netFirewall.NetFirewallPolicy
  managedRules: netFirewall.NetFirewallRule[]
}

class CustomModeStrategyAdapter implements FirewallModeStrategy {
  readonly mode: FirewallPresetMode = 'custom'

  async buildRules(context: common.UIAbilityContext): Promise<netFirewall.NetFirewallRule[]> {
    return CustomModeStrategy.buildRulesForApply(context)
  }
}

export class FirewallModeStrategyFactory {
  private static readonly publicStrategy: FirewallModeStrategy = new PresetModeStrategy('public')
  private static readonly privateStrategy: FirewallModeStrategy = new PresetModeStrategy('private')
  private static readonly customStrategy: FirewallModeStrategy = new CustomModeStrategyAdapter()

  static getStrategy(mode: FirewallPresetMode): FirewallModeStrategy {
    switch (mode) {
      case 'public':
        return FirewallModeStrategyFactory.publicStrategy
      case 'private':
        return FirewallModeStrategyFactory.privateStrategy
      case 'custom':
      default:
        return FirewallModeStrategyFactory.customStrategy
    }
  }

  static async buildRulesForMode(
    context: common.UIAbilityContext,
    mode: FirewallPresetMode
  ): Promise<netFirewall.NetFirewallRule[]> {
    return FirewallModeStrategyFactory.getStrategy(mode).buildRules(context)
  }

  static async initialize(context: common.UIAbilityContext): Promise<void> {
    let storedModeValue = await FirewallModeRepository.getStoredModeValue(context)
    if (storedModeValue.length > 0) {
      return
    }
    let currentRules = await FirewallRepository.getAllRules()
    await CustomModeStrategy.initializeFromSystemIfEmpty(context, currentRules)
    await FirewallModeRepository.saveCurrentMode(context, 'custom')
  }

  static async getCurrentMode(context: common.UIAbilityContext): Promise<FirewallPresetMode> {
    return FirewallModeRepository.getCurrentMode(context)
  }

  static async switchMode(
    context: common.UIAbilityContext,
    mode: FirewallPresetMode
  ): Promise<FirewallModeSwitchResult> {
    await FirewallModeStrategyFactory.initialize(context)
    if (mode === 'custom') {
      let targetRules = await FirewallModeStrategyFactory.buildCustomRulesForApply(context)
      return FirewallModeStrategyFactory.applyCustomRules(context, targetRules)
    }
    let targetRules = await FirewallModeStrategyFactory.buildRulesForMode(context, mode)
    return FirewallModeStrategyFactory.applyModeRules(context, mode, targetRules)
  }

  static async applyCustomRules(
    context: common.UIAbilityContext,
    rules: netFirewall.NetFirewallRule[]
  ): Promise<FirewallModeSwitchResult> {
    await FirewallModeStrategyFactory.initialize(context)
    let usersResult = await SystemUserProvider.loadAvailableUserIds()
    let users = usersResult.users
    if (users.length === 0) {
      await FirewallModeRepository.saveCurrentMode(context, 'custom')
      return {
        success: true,
        mode: 'custom',
        appliedRuleCount: rules.length
      }
    }

    let snapshots = await FirewallModeStrategyFactory.captureUserSnapshots(users)
    if (snapshots === null) {
      return FirewallModeStrategyFactory.buildFailedSwitchResult('custom')
    }

    let bucketMap = FirewallModeStrategyFactory.buildBucketMap(CustomModeStrategy.buildRuleBucketsByUser(rules))
    for (let i = 0; i < snapshots.length; i++) {
      let snapshot = snapshots[i]
      let cleared = await FirewallModeStrategyFactory.clearManagedRules(snapshot.userId)
      if (!cleared) {
        await FirewallModeStrategyFactory.rollbackUserSnapshots(snapshots)
        return FirewallModeStrategyFactory.buildFailedSwitchResult('custom')
      }

      let bindingMode = await FirewallUserBindingsRepository.getBindingMode(context, snapshot.userId)
      let policyApplied = await FirewallRepository.setFirewallPolicyByUserId(
        snapshot.userId,
        FirewallModeStrategyFactory.buildCustomPolicy(bindingMode)
      )
      if (!policyApplied) {
        await FirewallModeStrategyFactory.rollbackUserSnapshots(snapshots)
        return FirewallModeStrategyFactory.buildFailedSwitchResult('custom')
      }

      let userRules = bucketMap.get(snapshot.userId) ?? []
      let rulesApplied = await FirewallModeStrategyFactory.addRulesForUser(snapshot.userId, userRules)
      if (!rulesApplied) {
        await FirewallModeStrategyFactory.rollbackUserSnapshots(snapshots)
        return FirewallModeStrategyFactory.buildFailedSwitchResult('custom')
      }
    }

    await FirewallModeRepository.saveCurrentMode(context, 'custom')
    return {
      success: true,
      mode: 'custom',
      appliedRuleCount: rules.length
    }
  }

  static async listCustomRules(context: common.UIAbilityContext): Promise<netFirewall.NetFirewallRule[]> {
    return CustomModeStrategy.listRules(context)
  }

  static async buildCustomRulesForApply(context: common.UIAbilityContext): Promise<netFirewall.NetFirewallRule[]> {
    return CustomModeStrategy.buildRulesForApply(context)
  }

  static async initializeCustomRulesFromSystemIfEmpty(
    context: common.UIAbilityContext,
    systemRules: netFirewall.NetFirewallRule[]
  ): Promise<void> {
    await CustomModeStrategy.initializeFromSystemIfEmpty(context, systemRules)
  }

  static async replaceAllCustomRules(
    context: common.UIAbilityContext,
    rules: netFirewall.NetFirewallRule[]
  ): Promise<boolean> {
    return CustomModeStrategy.replaceAllRules(context, rules)
  }

  static getCustomRuleId(rule: netFirewall.NetFirewallRule): string | undefined {
    return CustomModeStrategy.getCustomRuleId(rule)
  }

  private static buildFailedSwitchResult(targetMode: FirewallPresetMode): FirewallModeSwitchResult {
    return {
      success: false,
      mode: targetMode,
      appliedRuleCount: 0,
      errorCode: undefined,
      errorMessage: undefined
    }
  }

  private static async applyModeRules(
    context: common.UIAbilityContext,
    targetMode: FirewallPresetMode,
    targetRules: netFirewall.NetFirewallRule[]
  ): Promise<FirewallModeSwitchResult> {
    let usersResult = await SystemUserProvider.loadAvailableUserIds()
    let users = usersResult.users
    if (users.length === 0) {
      await FirewallModeRepository.saveCurrentMode(context, targetMode)
      return {
        success: true,
        mode: targetMode,
        appliedRuleCount: targetRules.length
      }
    }

    let snapshots = await FirewallModeStrategyFactory.captureUserSnapshots(users)
    if (snapshots === null) {
      return FirewallModeStrategyFactory.buildFailedSwitchResult(targetMode)
    }

    for (let i = 0; i < snapshots.length; i++) {
      let snapshot = snapshots[i]
      let cleared = await FirewallModeStrategyFactory.clearManagedRules(snapshot.userId)
      if (!cleared) {
        await FirewallModeStrategyFactory.rollbackUserSnapshots(snapshots)
        return FirewallModeStrategyFactory.buildFailedSwitchResult(targetMode)
      }

      let targetPolicy: netFirewall.NetFirewallPolicy = {
        isOpen: true,
        inAction: snapshot.policy.inAction,
        outAction: snapshot.policy.outAction
      }
      let policyApplied = await FirewallRepository.setFirewallPolicyByUserId(snapshot.userId, targetPolicy)
      if (!policyApplied) {
        await FirewallModeStrategyFactory.rollbackUserSnapshots(snapshots)
        return FirewallModeStrategyFactory.buildFailedSwitchResult(targetMode)
      }

      let rulesApplied = await FirewallModeStrategyFactory.addRulesForUser(snapshot.userId, targetRules)
      if (!rulesApplied) {
        await FirewallModeStrategyFactory.rollbackUserSnapshots(snapshots)
        return FirewallModeStrategyFactory.buildFailedSwitchResult(targetMode)
      }
    }

    await FirewallModeRepository.saveCurrentMode(context, targetMode)
    return {
      success: true,
      mode: targetMode,
      appliedRuleCount: targetRules.length
    }
  }

  private static buildCustomPolicy(bindingMode: FirewallUserApplyMode | undefined): netFirewall.NetFirewallPolicy {
    if (bindingMode === 'denylist') {
      return {
        isOpen: true,
        inAction: netFirewall.FirewallRuleAction.RULE_DENY,
        outAction: netFirewall.FirewallRuleAction.RULE_DENY
      }
    }
    return {
      isOpen: true,
      inAction: netFirewall.FirewallRuleAction.RULE_ALLOW,
      outAction: netFirewall.FirewallRuleAction.RULE_ALLOW
    }
  }

  private static buildBucketMap(
    buckets: UserScopedFirewallRuleBucket[]
  ): Map<number, netFirewall.NetFirewallRule[]> {
    let bucketMap = new Map<number, netFirewall.NetFirewallRule[]>()
    buckets.forEach((bucket) => {
      bucketMap.set(bucket.userId, bucket.rules)
    })
    return bucketMap
  }

  private static async captureUserSnapshots(users: UserFirewallOption[]): Promise<UserManagedSnapshot[] | null> {
    let snapshots: UserManagedSnapshot[] = []
    for (let i = 0; i < users.length; i++) {
      let userId = users[i].userId
      let policy = await FirewallRepository.getFirewallPolicyByUserId(userId)
      if (policy === null) {
        return null
      }
      let managedRules = await FirewallModeStrategyFactory.getManagedRules(userId)
      snapshots.push({
        userId,
        policy: {
          isOpen: policy.isOpen,
          inAction: policy.inAction,
          outAction: policy.outAction
        },
        managedRules
      })
    }
    return snapshots
  }

  private static async rollbackUserSnapshots(snapshots: UserManagedSnapshot[]): Promise<void> {
    for (let i = 0; i < snapshots.length; i++) {
      let snapshot = snapshots[i]
      await FirewallModeStrategyFactory.clearManagedRules(snapshot.userId)
      await FirewallRepository.setFirewallPolicyByUserId(snapshot.userId, snapshot.policy)
      await FirewallModeStrategyFactory.addRulesForUser(snapshot.userId, snapshot.managedRules)
    }
  }

  private static async getManagedRules(userId: number): Promise<netFirewall.NetFirewallRule[]> {
    let rules = await FirewallRepository.getAllRules(userId)
    return rules.filter((rule: netFirewall.NetFirewallRule): boolean =>
      FirewallRulesService.parseManagedRuleDescription(rule.description) !== null
    )
  }

  private static async clearManagedRules(userId: number): Promise<boolean> {
    let managedRules = await FirewallModeStrategyFactory.getManagedRules(userId)
    for (let i = 0; i < managedRules.length; i++) {
      let ruleId = FirewallRepository.getRulePrimaryKey(managedRules[i])
      if (ruleId === undefined) {
        continue
      }
      let removed = await FirewallRepository.removeRuleByUserId(userId, ruleId)
      if (!removed) {
        return false
      }
    }
    return true
  }

  private static async addRulesForUser(
    userId: number,
    rules: netFirewall.NetFirewallRule[]
  ): Promise<boolean> {
    for (let i = 0; i < rules.length; i++) {
      let clonedRule = FirewallRepository.cloneRuleForCreate(rules[i])
      clonedRule.userId = userId
      let ruleId = await FirewallRepository.addRule(clonedRule)
      if (ruleId <= 0) {
        return false
      }
    }
    return true
  }
}
