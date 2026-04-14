import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'

import {
  FirewallManagedRuleMetadata,
  FirewallPresetMode,
  FirewallUserApplyMode,
  UserScopedFirewallRuleBucket,
  UserFirewallModeApplyResult,
  UserFirewallModeBinding,
  UserFirewallModeReapplySummary,
  UserFirewallModeState
} from '../../../models/DataModels'
import { CommonErrorUtils } from '../../../utils/CommonErrorUtils'
import { FirewallOperationStrings } from '../../../constants/modules/FirewallStrings'
import { FirewallModeRepository } from '../repositories/FirewallModeRepository'
import { FirewallRepository } from '../repositories/FirewallRepository'
import { FirewallUserBindingsRepository } from '../repositories/FirewallUserBindingsRepository'
import { FirewallRulesService } from '../rules/FirewallRulesService'
import { SystemUserProvider } from '../providers/SystemUserProvider'
import { LogUtils } from '../../../utils/LogUtils'
import { ErrorLike } from '../../../types/LooseValueTypes'

const TAG = 'FirewallStore'

interface CustomRuleApplySnapshot {
  userId: number
  policy: netFirewall.NetFirewallPolicy
  rules: netFirewall.NetFirewallRule[]
}

export class FirewallStore {
  static async initialize(context: common.UIAbilityContext): Promise<void> {
    let storedModeValue = await FirewallModeRepository.getStoredModeValue(context)
    if (storedModeValue.length === 0) {
      await FirewallModeRepository.saveCurrentMode(context, 'custom')
    }
  }

  static async getCurrentMode(context: common.UIAbilityContext): Promise<FirewallPresetMode> {
    return FirewallModeRepository.getCurrentMode(context)
  }

  static async saveCurrentMode(context: common.UIAbilityContext, mode: FirewallPresetMode): Promise<void> {
    await FirewallModeRepository.saveCurrentMode(context, mode)
  }

  static async loadUserBindings(context: common.UIAbilityContext): Promise<UserFirewallModeBinding[]> {
    return FirewallUserBindingsRepository.loadBindings(context)
  }

  static async getUserModeState(
    context: common.UIAbilityContext,
    userId: number
  ): Promise<UserFirewallModeState> {
    let policyResult = await SystemUserProvider.getPolicy(userId)
    if (policyResult.errorCode !== undefined) {
      return {
        userId: userId,
        isManaged: false,
        isOpen: policyResult.isOpen,
        inAction: policyResult.inAction,
        outAction: policyResult.outAction,
        errorCode: policyResult.errorCode,
        message: policyResult.message
      }
    }

    let bindingMode = await FirewallStore.getBindingMode(context, userId)
    return {
      userId: userId,
      bindingMode: bindingMode,
      isManaged: bindingMode !== undefined,
      isOpen: policyResult.isOpen,
      inAction: policyResult.inAction,
      outAction: policyResult.outAction
    }
  }

  static async applyUserMode(
    context: common.UIAbilityContext,
    userId: number,
    mode: FirewallUserApplyMode
  ): Promise<UserFirewallModeApplyResult> {
    let result = await FirewallStore.applyUserModeInternal(userId, mode)
    if (!result.success) {
      return result
    }
    let saved = await FirewallStore.saveBindingMode(context, userId, mode)
    if (!saved) {
      return {
        success: false,
        userId: userId,
        mode: mode,
        appliedRuleCount: 0,
        errorCode: undefined,
        errorMessage: CommonErrorUtils.resolveErrorMessage(FirewallOperationStrings.SAVE_USER_MODE_BINDINGS, undefined)
      }
    }
    return result
  }

  static async applyCustomRuleBuckets(
    context: common.UIAbilityContext,
    buckets: UserScopedFirewallRuleBucket[]
  ): Promise<UserFirewallModeReapplySummary> {
    let activeUsersResult = await SystemUserProvider.loadAvailableUserIds()
    let activeUserIds = activeUsersResult.users.map((item) => item.userId)
    let bucketMap = new Map<number, netFirewall.NetFirewallRule[]>()
    buckets.forEach((bucket: UserScopedFirewallRuleBucket) => {
      bucketMap.set(bucket.userId, bucket.rules)
    })

    let summary: UserFirewallModeReapplySummary = {
      totalUsers: activeUserIds.length,
      successCount: 0,
      failedCount: 0,
      failedUsers: []
    }
    let snapshots = await FirewallStore.captureCustomRuleApplySnapshots(activeUserIds)
    if (snapshots.length !== activeUserIds.length) {
      summary.failedCount = 1
      summary.failedUsers = activeUserIds.filter((userId: number) =>
        !snapshots.some((snapshot: CustomRuleApplySnapshot): boolean => snapshot.userId === userId)
      )
      if (summary.failedUsers.length === 0 && activeUserIds.length > 0) {
        summary.failedUsers = [activeUserIds[0]]
      }
      return summary
    }

    for (let i = 0; i < activeUserIds.length; i++) {
      let userId = activeUserIds[i]
      let result = await FirewallStore.applyCustomRulesForUser(userId, bucketMap.get(userId) ?? [])
      if (result) {
        summary.successCount++
        continue
      }
      await FirewallStore.rollbackCustomRuleApplySnapshots(snapshots)
      summary.successCount = 0
      summary.failedCount++
      summary.failedUsers.push(userId)
      break
    }

    LogUtils.info(TAG,
      'applyCustomRuleBuckets finished: total=%{public}d, success=%{public}d, failed=%{public}d',
      summary.totalUsers,
      summary.successCount,
      summary.failedCount
    )
    return summary
  }

  static async saveUserBindings(
    context: common.UIAbilityContext,
    bindings: UserFirewallModeBinding[]
  ): Promise<boolean> {
    return FirewallUserBindingsRepository.saveBindings(context, bindings)
  }

  static async getBindingMode(
    context: common.UIAbilityContext,
    userId: number
  ): Promise<FirewallUserApplyMode | undefined> {
    return FirewallUserBindingsRepository.getBindingMode(context, userId)
  }

  private static async saveBindingMode(
    context: common.UIAbilityContext,
    userId: number,
    mode: FirewallUserApplyMode
  ): Promise<boolean> {
    return FirewallUserBindingsRepository.saveBindingMode(context, userId, mode)
  }

  private static clearLastError(): void {
    FirewallStore.lastErrorCode = undefined
    FirewallStore.lastErrorMessage = ''
  }

  private static recordStoreError(action: string, err: ErrorLike): void {
    let code = CommonErrorUtils.extractErrorCode(err)
    FirewallStore.lastErrorCode = code
    FirewallStore.lastErrorMessage = CommonErrorUtils.resolveErrorMessage(action, code)
  }

  private static getLastErrorCode(): number | undefined {
    return FirewallStore.lastErrorCode
  }

  private static getLastErrorMessage(): string {
    return FirewallStore.lastErrorMessage
  }

  private static async applyUserModeInternal(
    userId: number,
    mode: FirewallUserApplyMode
  ): Promise<UserFirewallModeApplyResult> {
    FirewallStore.clearLastError()
    let policy = await SystemUserProvider.getPolicy(userId)
    if (policy.errorCode !== undefined) {
      return {
        success: false,
        userId: userId,
        mode: mode,
        appliedRuleCount: 0,
        errorCode: policy.errorCode,
        errorMessage: policy.message
      }
    }

    LogUtils.info(TAG,
      'applyUserMode start: userId=%{public}d, mode=%{public}s, policyOnly=%{public}s',
      userId,
      mode,
      'true'
    )

    let targetPolicy: netFirewall.NetFirewallPolicy = {
      isOpen: policy.isOpen,
      inAction: mode === 'allowlist'
        ? netFirewall.FirewallRuleAction.RULE_ALLOW
        : netFirewall.FirewallRuleAction.RULE_DENY,
      outAction: mode === 'allowlist'
        ? netFirewall.FirewallRuleAction.RULE_ALLOW
        : netFirewall.FirewallRuleAction.RULE_DENY
    }
    if (!await FirewallStore.setPolicy(userId, targetPolicy)) {
      return FirewallStore.buildFailedResult(userId, mode, 0)
    }

    LogUtils.info(TAG,
      'applyUserMode success: userId=%{public}d, mode=%{public}s, policyOnly=%{public}s',
      userId,
      mode,
      'true'
    )
    return {
      success: true,
      userId: userId,
      mode: mode,
      appliedRuleCount: 0
    }
  }

  private static async applyCustomRulesForUser(
    userId: number,
    targetRules: netFirewall.NetFirewallRule[]
  ): Promise<boolean> {
    FirewallStore.clearLastError()
    let snapshotRules = await FirewallStore.getManagedRules(userId)
    if (!await FirewallStore.clearManagedRules(userId)) {
      return false
    }
    if (targetRules.length === 0) {
      return true
    }
    if (await FirewallStore.addRules(targetRules)) {
      return true
    }
    await FirewallStore.restoreManagedRules(userId, snapshotRules)
    return false
  }

  private static async captureCustomRuleApplySnapshots(userIds: number[]): Promise<CustomRuleApplySnapshot[]> {
    let snapshots: CustomRuleApplySnapshot[] = []
    for (let i = 0; i < userIds.length; i++) {
      let userId = userIds[i]
      let policyResult = await SystemUserProvider.getPolicy(userId)
      if (policyResult.errorCode !== undefined) {
        LogUtils.error(TAG, 'captureCustomRuleApplySnapshots getPolicy failed: userId=%{public}d, code=%{public}s',
          userId,
          `${policyResult.errorCode}`
        )
        return snapshots
      }
      let snapshotRules = await FirewallStore.getManagedRules(userId)
      if (FirewallStore.getLastErrorMessage().length > 0) {
        LogUtils.error(TAG, 'captureCustomRuleApplySnapshots getManagedRules failed: userId=%{public}d', userId)
        return snapshots
      }
      snapshots.push({
        userId: userId,
        policy: {
          isOpen: policyResult.isOpen,
          inAction: policyResult.inAction,
          outAction: policyResult.outAction
        },
        rules: snapshotRules
      })
    }
    return snapshots
  }

  private static async rollbackCustomRuleApplySnapshots(snapshots: CustomRuleApplySnapshot[]): Promise<void> {
    for (let i = 0; i < snapshots.length; i++) {
      let snapshot = snapshots[i]
      await FirewallStore.restoreManagedRulesAndPolicy(snapshot.userId, snapshot.policy, snapshot.rules)
    }
  }

  private static getManagedRuleMetadata(rule: netFirewall.NetFirewallRule): FirewallManagedRuleMetadata | null {
    return FirewallRulesService.parseManagedRuleDescription(rule.description)
  }

  private static async getManagedRules(userId: number): Promise<netFirewall.NetFirewallRule[]> {
    let allRules = await FirewallStore.getRules(userId)
    return allRules.filter((rule: netFirewall.NetFirewallRule): boolean =>
      FirewallStore.getManagedRuleMetadata(rule) !== null
    )
  }

  private static async getRules(userId: number): Promise<netFirewall.NetFirewallRule[]> {
    try {
      return await FirewallRepository.getAllRules(userId)
    } catch (err) {
      FirewallStore.recordStoreError(FirewallOperationStrings.READ_USER_RULES, err as ErrorLike)
      LogUtils.error(TAG, 'getRules failed, userId=%{public}d, err=%{public}s', userId, JSON.stringify(err))
      return []
    }
  }

  private static async clearManagedRules(userId: number): Promise<boolean> {
    FirewallStore.clearLastError()
    let managedRules = await FirewallStore.getManagedRules(userId)
    if (managedRules.length === 0 && FirewallStore.getLastErrorMessage().length > 0) {
      return false
    }
    LogUtils.info(TAG, 'clearManagedRules start: userId=%{public}d, count=%{public}d', userId, managedRules.length)
    for (let i = 0; i < managedRules.length; i++) {
      let ruleId = FirewallRepository.getRulePrimaryKey(managedRules[i])
      if (ruleId === undefined) {
        continue
      }
      try {
        await netFirewall.removeNetFirewallRule(userId, ruleId)
      } catch (err) {
        FirewallStore.recordStoreError(FirewallOperationStrings.DELETE_USER_RULES, err as ErrorLike)
        LogUtils.error(TAG,
          'clearManagedRules failed, userId=%{public}d, ruleId=%{public}d, err=%{public}s',
          userId,
          ruleId,
          JSON.stringify(err)
        )
        return false
      }
    }
    return true
  }

  private static async setPolicy(userId: number, policy: netFirewall.NetFirewallPolicy): Promise<boolean> {
    try {
      await netFirewall.setNetFirewallPolicy(userId, policy)
      LogUtils.info(TAG,
        'setPolicy success: userId=%{public}d, isOpen=%{public}s, inAction=%{public}d, outAction=%{public}d',
        userId,
        String(policy.isOpen),
        policy.inAction,
        policy.outAction
      )
      return true
    } catch (err) {
      FirewallStore.recordStoreError(FirewallOperationStrings.WRITE_USER_POLICY, err as ErrorLike)
      LogUtils.error(TAG, 'setPolicy failed, userId=%{public}d, err=%{public}s', userId, JSON.stringify(err))
      return false
    }
  }

  private static async addRules(rules: netFirewall.NetFirewallRule[]): Promise<boolean> {
    for (let i = 0; i < rules.length; i++) {
      let ruleId = await FirewallRepository.addRule(rules[i])
      if (ruleId <= 0) {
        FirewallStore.lastErrorCode = undefined
        FirewallStore.lastErrorMessage = ''
        return false
      }
    }
    return true
  }

  // 保留给自定义规则主链路使用；用户模式切换已不再调用这些恢复函数。
  private static async restoreManagedRulesAndPolicy(
    userId: number,
    policy: netFirewall.NetFirewallPolicy,
    snapshotRules: netFirewall.NetFirewallRule[]
  ): Promise<void> {
    await FirewallStore.clearManagedRules(userId)
    await FirewallStore.setPolicy(userId, policy)
    await FirewallStore.addRules(snapshotRules.map((rule: netFirewall.NetFirewallRule) => FirewallRepository.cloneRuleForCreate(rule)))
    LogUtils.info(TAG, 'restoreManagedRulesAndPolicy finished: userId=%{public}d, rules=%{public}d', userId, snapshotRules.length)
  }

  // 保留给自定义规则主链路使用；用户模式切换已不再调用这些恢复函数。
  private static async restoreManagedRules(userId: number, snapshotRules: netFirewall.NetFirewallRule[]): Promise<void> {
    await FirewallStore.clearManagedRules(userId)
    await FirewallStore.addRules(snapshotRules.map((rule: netFirewall.NetFirewallRule) => FirewallRepository.cloneRuleForCreate(rule)))
    LogUtils.info(TAG, 'restoreManagedRules finished: userId=%{public}d, rules=%{public}d', userId, snapshotRules.length)
  }

  private static buildFailedResult(
    userId: number,
    mode: FirewallUserApplyMode,
    appliedRuleCount: number
  ): UserFirewallModeApplyResult {
    return {
      success: false,
      userId: userId,
      mode: mode,
      appliedRuleCount: appliedRuleCount,
      errorCode: FirewallStore.getLastErrorCode(),
      errorMessage: FirewallStore.getLastErrorMessage()
    }
  }

  private static lastErrorCode: number | undefined = undefined
  private static lastErrorMessage: string = ''
}
