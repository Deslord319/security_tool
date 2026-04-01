import { LogUtils } from '../utils/LogUtils'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { netFirewall } from '@kit.NetworkKit'

import {
  FirewallUserApplyMode,
  PREF_KEY_FIREWALL_USER_BINDINGS,
  PREF_STORE_NAME_FIREWALL_USER_BINDINGS,
  UserFirewallModeApplyResult,
  UserFirewallModeBinding,
  UserFirewallModeReapplySummary,
  UserFirewallModeState
} from '../models/DataModels'
import { CommonErrorUtils } from '../utils/CommonErrorUtils'
import { FirewallService } from './FirewallService'
import { UserFirewallPolicyService } from './UserFirewallPolicyService'
import { FirewallStrings } from '../constants/modules/FirewallStrings'

const TAG = 'UserFirewallModeService'

export class UserFirewallModeService {
  private static lastErrorCode: number | undefined = undefined
  private static lastErrorMessage: string = ''

  private static clearLastError(): void {
    UserFirewallModeService.lastErrorCode = undefined
    UserFirewallModeService.lastErrorMessage = ''
  }

  static getLastErrorCode(): number | undefined {
    return UserFirewallModeService.lastErrorCode
  }

  static getLastErrorMessage(): string {
    return UserFirewallModeService.lastErrorMessage
  }

  private static recordError(action: string, err: Object): void {
    let code = CommonErrorUtils.extractErrorCode(err)
    UserFirewallModeService.lastErrorCode = code
    UserFirewallModeService.lastErrorMessage = CommonErrorUtils.resolveErrorMessage(action, code)
  }

  static async getModeState(
    context: common.UIAbilityContext,
    userId: number
  ): Promise<UserFirewallModeState> {
    let policyResult = await UserFirewallPolicyService.getPolicy(userId)
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

    let bindingMode = await UserFirewallModeService.getBindingMode(context, userId)
    return {
      userId: userId,
      bindingMode: bindingMode,
      isManaged: bindingMode !== undefined,
      isOpen: policyResult.isOpen,
      inAction: policyResult.inAction,
      outAction: policyResult.outAction
    }
  }

  static async getBindingMode(
    context: common.UIAbilityContext,
    userId: number
  ): Promise<FirewallUserApplyMode | undefined> {
    let bindings = await UserFirewallModeService.loadBindings(context)
    let matched = bindings.find((item: UserFirewallModeBinding): boolean => item.userId === userId)
    return matched?.mode
  }

  static async applyMode(
    context: common.UIAbilityContext,
    userId: number,
    mode: FirewallUserApplyMode,
    sharedRules: netFirewall.NetFirewallRule[]
  ): Promise<UserFirewallModeApplyResult> {
    let result = await UserFirewallModeService.applyModeInternal(userId, mode, sharedRules)
    if (!result.success) {
      return result
    }
    let saved = await UserFirewallModeService.saveBindingMode(context, userId, mode)
    if (!saved) {
      return {
        success: false,
        userId: userId,
        mode: mode,
        appliedRuleCount: 0,
        errorCode: UserFirewallModeService.getLastErrorCode(),
        errorMessage: UserFirewallModeService.getLastErrorMessage()
      }
    }
    return result
  }

  static async reapplyBindings(
    context: common.UIAbilityContext,
    sharedRules: netFirewall.NetFirewallRule[]
  ): Promise<UserFirewallModeReapplySummary> {
    let activeUsersResult = await UserFirewallPolicyService.loadAvailableUserIds()
    let activeUserIds = activeUsersResult.users.map((item) => item.userId)
    let bindings = await UserFirewallModeService.loadBindings(context)
    let validBindings = bindings.filter((item: UserFirewallModeBinding): boolean => activeUserIds.includes(item.userId))
    if (validBindings.length !== bindings.length) {
      await UserFirewallModeService.saveBindings(context, validBindings)
    }

    let summary: UserFirewallModeReapplySummary = {
      totalUsers: validBindings.length,
      successCount: 0,
      failedCount: 0,
      failedUsers: []
    }
    for (let i = 0; i < validBindings.length; i++) {
      let binding = validBindings[i]
      let result = await UserFirewallModeService.applyModeInternal(binding.userId, binding.mode, sharedRules)
      if (result.success) {
        summary.successCount++
        continue
      }
      summary.failedCount++
      summary.failedUsers.push(binding.userId)
    }
    LogUtils.info(TAG,
      'reapplyBindings finished: total=%{public}d, success=%{public}d, failed=%{public}d',
      summary.totalUsers,
      summary.successCount,
      summary.failedCount
    )
    return summary
  }

  static async loadBindings(context: common.UIAbilityContext): Promise<UserFirewallModeBinding[]> {
    try {
      let store = await preferences.getPreferences(context, PREF_STORE_NAME_FIREWALL_USER_BINDINGS)
      let rawValue = await store.get(PREF_KEY_FIREWALL_USER_BINDINGS, '[]')
      let serialized = typeof rawValue === 'string' ? rawValue : '[]'
      let parsed = JSON.parse(serialized) as UserFirewallModeBinding[]
      if (!Array.isArray(parsed)) {
        return []
      }
      return parsed.filter((item: UserFirewallModeBinding): boolean => {
        return typeof item.userId === 'number' &&
          (item.mode === 'allowlist' || item.mode === 'denylist' || item.mode === 'non_standard')
      })
    } catch (err) {
      UserFirewallModeService.recordError(FirewallStrings.readUserModeBindingsAction, err as Object)
      LogUtils.error(TAG, 'loadBindings failed: %{public}s', JSON.stringify(err))
      return []
    }
  }

  private static async saveBindingMode(
    context: common.UIAbilityContext,
    userId: number,
    mode: FirewallUserApplyMode
  ): Promise<boolean> {
    let bindings = await UserFirewallModeService.loadBindings(context)
    let nextBindings = bindings.filter((item: UserFirewallModeBinding): boolean => item.userId !== userId)
    nextBindings.push({
      userId: userId,
      mode: mode
    })
    return UserFirewallModeService.saveBindings(context, nextBindings)
  }

  private static async saveBindings(
    context: common.UIAbilityContext,
    bindings: UserFirewallModeBinding[]
  ): Promise<boolean> {
    try {
      let store = await preferences.getPreferences(context, PREF_STORE_NAME_FIREWALL_USER_BINDINGS)
      await store.put(PREF_KEY_FIREWALL_USER_BINDINGS, JSON.stringify(bindings))
      await store.flush()
      return true
    } catch (err) {
      UserFirewallModeService.recordError(FirewallStrings.saveUserModeBindingsAction, err as Object)
      LogUtils.error(TAG, 'saveBindings failed: %{public}s', JSON.stringify(err))
      return false
    }
  }

  private static async applyModeInternal(
    userId: number,
    mode: FirewallUserApplyMode,
    sharedRules: netFirewall.NetFirewallRule[]
  ): Promise<UserFirewallModeApplyResult> {
    UserFirewallModeService.clearLastError()
    let policy = await UserFirewallPolicyService.getPolicy(userId)
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

    let snapshotRules = await UserFirewallModeService.getManagedRules(userId)
    let targetRules = UserFirewallModeService.buildRulesForMode(userId, mode, sharedRules)
    LogUtils.info(TAG,
      'applyMode start: userId=%{public}d, mode=%{public}s, totalRules=%{public}d',
      userId,
      mode,
      targetRules.length
    )

    if (!await UserFirewallModeService.clearManagedRules(userId)) {
      return UserFirewallModeService.buildFailedResult(userId, mode, 0)
    }

    if (mode !== 'non_standard') {
      let targetPolicy: netFirewall.NetFirewallPolicy = {
        isOpen: policy.isOpen,
        inAction: mode === 'allowlist'
          ? netFirewall.FirewallRuleAction.RULE_DENY
          : netFirewall.FirewallRuleAction.RULE_ALLOW,
        outAction: mode === 'allowlist'
          ? netFirewall.FirewallRuleAction.RULE_DENY
          : netFirewall.FirewallRuleAction.RULE_ALLOW
      }
      if (!await UserFirewallModeService.setPolicy(userId, targetPolicy)) {
        await UserFirewallModeService.restoreManagedRules(userId, snapshotRules)
        return UserFirewallModeService.buildFailedResult(userId, mode, 0)
      }
    }

    if (!await UserFirewallModeService.addRules(targetRules)) {
      if (mode !== 'non_standard') {
        let originalPolicy: netFirewall.NetFirewallPolicy = {
          isOpen: policy.isOpen,
          inAction: policy.inAction,
          outAction: policy.outAction
        }
        await UserFirewallModeService.restoreManagedRulesAndPolicy(userId, originalPolicy, snapshotRules)
      } else {
        await UserFirewallModeService.restoreManagedRules(userId, snapshotRules)
      }
      return UserFirewallModeService.buildFailedResult(userId, mode, 0)
    }

    LogUtils.info(TAG,
      'applyMode success: userId=%{public}d, mode=%{public}s, applied=%{public}d',
      userId,
      mode,
      targetRules.length
    )
    return {
      success: true,
      userId: userId,
      mode: mode,
      appliedRuleCount: targetRules.length
    }
  }

  private static buildRulesForMode(
    userId: number,
    mode: FirewallUserApplyMode,
    sharedRules: netFirewall.NetFirewallRule[]
  ): netFirewall.NetFirewallRule[] {
    let filteredRules = sharedRules.filter((rule: netFirewall.NetFirewallRule): boolean => {
      if (mode === 'allowlist') {
        return rule.action === netFirewall.FirewallRuleAction.RULE_ALLOW
      }
      if (mode === 'denylist') {
        return rule.action === netFirewall.FirewallRuleAction.RULE_DENY
      }
      return true
    })
    return filteredRules.map((rule: netFirewall.NetFirewallRule): netFirewall.NetFirewallRule => {
      let clonedRule = FirewallService.cloneRuleForCreate(rule)
      clonedRule.userId = userId
      return FirewallService.applyManagedRuleMetadata(clonedRule, {
        owner: 'security_tool',
        mode: 'custom',
        kind: 'custom',
        customRuleId: FirewallService.parseManagedRuleDescription(rule.description)?.customRuleId
      })
    })
  }

  private static async getManagedRules(userId: number): Promise<netFirewall.NetFirewallRule[]> {
    let allRules = await UserFirewallModeService.getRules(userId)
    return allRules.filter((rule: netFirewall.NetFirewallRule): boolean =>
      FirewallService.parseManagedRuleDescription(rule.description) !== null
    )
  }

  private static async getRules(userId: number): Promise<netFirewall.NetFirewallRule[]> {
    try {
      let allRules: netFirewall.NetFirewallRule[] = []
      let page = 1
      while (true) {
        let requestParam: netFirewall.RequestParam = {
          page: page,
          pageSize: 50,
          orderField: netFirewall.NetFirewallOrderField.ORDER_BY_RULE_NAME,
          orderType: netFirewall.NetFirewallOrderType.ORDER_ASC
        }
        let result = await netFirewall.getNetFirewallRules(userId, requestParam)
        let pageRules = result.data ?? []
        allRules.push(...pageRules)
        if (pageRules.length < requestParam.pageSize) {
          break
        }
        page++
      }
      LogUtils.info(TAG, 'getRules success: userId=%{public}d, count=%{public}d', userId, allRules.length)
      return allRules
    } catch (err) {
      UserFirewallModeService.recordError(FirewallStrings.readUserRulesAction, err as Object)
      LogUtils.error(TAG, 'getRules failed, userId=%{public}d, err=%{public}s', userId, JSON.stringify(err))
      return []
    }
  }

  private static async clearManagedRules(userId: number): Promise<boolean> {
    UserFirewallModeService.clearLastError()
    let managedRules = await UserFirewallModeService.getManagedRules(userId)
    if (managedRules.length === 0 && UserFirewallModeService.lastErrorMessage.length > 0) {
      return false
    }
    LogUtils.info(TAG, 'clearManagedRules start: userId=%{public}d, count=%{public}d', userId, managedRules.length)
    for (let i = 0; i < managedRules.length; i++) {
      let ruleId = FirewallService.getRulePrimaryKey(managedRules[i])
      if (ruleId === undefined) {
        continue
      }
      try {
        await netFirewall.removeNetFirewallRule(userId, ruleId)
      } catch (err) {
        UserFirewallModeService.recordError(FirewallStrings.deleteUserRulesAction, err as Object)
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
      UserFirewallModeService.recordError(FirewallStrings.writeUserPolicyAction, err as Object)
      LogUtils.error(TAG, 'setPolicy failed, userId=%{public}d, err=%{public}s', userId, JSON.stringify(err))
      return false
    }
  }

  private static async addRules(rules: netFirewall.NetFirewallRule[]): Promise<boolean> {
    for (let i = 0; i < rules.length; i++) {
      let ruleId = await FirewallService.addRule(rules[i])
      if (ruleId <= 0) {
        UserFirewallModeService.lastErrorCode = FirewallService.getLastErrorCode()
        UserFirewallModeService.lastErrorMessage = FirewallService.getLastErrorText()
        return false
      }
    }
    return true
  }

  private static async restoreManagedRulesAndPolicy(
    userId: number,
    policy: netFirewall.NetFirewallPolicy,
    snapshotRules: netFirewall.NetFirewallRule[]
  ): Promise<void> {
    await UserFirewallModeService.clearManagedRules(userId)
    await UserFirewallModeService.setPolicy(userId, policy)
    await UserFirewallModeService.addRules(snapshotRules.map((rule: netFirewall.NetFirewallRule) => FirewallService.cloneRuleForCreate(rule)))
    LogUtils.info(TAG, 'restoreManagedRulesAndPolicy finished: userId=%{public}d, rules=%{public}d', userId, snapshotRules.length)
  }

  private static async restoreManagedRules(userId: number, snapshotRules: netFirewall.NetFirewallRule[]): Promise<void> {
    await UserFirewallModeService.clearManagedRules(userId)
    await UserFirewallModeService.addRules(snapshotRules.map((rule: netFirewall.NetFirewallRule) => FirewallService.cloneRuleForCreate(rule)))
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
      errorCode: UserFirewallModeService.getLastErrorCode(),
      errorMessage: UserFirewallModeService.getLastErrorMessage()
    }
  }
}
