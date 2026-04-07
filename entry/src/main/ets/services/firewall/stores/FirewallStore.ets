import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { netFirewall } from '@kit.NetworkKit'

import {
  FirewallManagedRuleMetadata,
  FirewallPresetMode,
  FirewallUserApplyMode,
  PREF_KEY_FIREWALL_ACTIVE_MODE,
  PREF_KEY_FIREWALL_CUSTOM_RULES,
  PREF_KEY_FIREWALL_USER_BINDINGS,
  PREF_STORE_NAME_FIREWALL_MODE,
  PREF_STORE_NAME_FIREWALL_CUSTOM_RULES,
  PREF_STORE_NAME_FIREWALL_USER_BINDINGS,
  UserFirewallModeApplyResult,
  UserFirewallModeBinding,
  UserFirewallModeReapplySummary,
  UserFirewallModeState
} from '../../../models/DataModels'
import { CommonErrorUtils } from '../../../utils/CommonErrorUtils'
import { FirewallStrings } from '../../../constants/modules/FirewallStrings'
import { FirewallRepository } from '../repositories/FirewallRepository'
import { FirewallRulesService } from '../rules/FirewallRulesService'
import { SystemUserProvider } from '../providers'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'FirewallStore'

interface StoredCustomFirewallRuleRecord {
  customRuleId: string
  rule: netFirewall.NetFirewallRule
}

export class FirewallStore {
  static async initialize(context: common.UIAbilityContext): Promise<void> {
    let storedModeValue = await FirewallStore.getStoredModeValue(context)
    if (storedModeValue.length === 0) {
      await FirewallStore.saveCurrentMode(context, 'custom')
    }
  }

  static async getCurrentMode(context: common.UIAbilityContext): Promise<FirewallPresetMode> {
    let storedModeValue = await FirewallStore.getStoredModeValue(context)
    if (storedModeValue === 'public' || storedModeValue === 'private' || storedModeValue === 'custom') {
      return storedModeValue
    }
    return 'custom'
  }

  static async saveCurrentMode(context: common.UIAbilityContext, mode: FirewallPresetMode): Promise<void> {
    try {
      let store = await preferences.getPreferences(context, PREF_STORE_NAME_FIREWALL_MODE)
      await store.put(PREF_KEY_FIREWALL_ACTIVE_MODE, mode)
      await store.flush()
    } catch (err) {
      LogUtils.error(TAG, `saveCurrentMode failed: ${JSON.stringify(err)}`)
    }
  }

  static async listCustomRules(context: common.UIAbilityContext): Promise<netFirewall.NetFirewallRule[]> {
    let records = await FirewallStore.loadCustomRuleRecords(context)
    return records.map((record: StoredCustomFirewallRuleRecord): netFirewall.NetFirewallRule =>
      FirewallStore.toDisplayRule(record)
    )
  }

  static async buildCustomRulesForApply(context: common.UIAbilityContext): Promise<netFirewall.NetFirewallRule[]> {
    return FirewallStore.listCustomRules(context)
  }

  static async initializeCustomRulesFromSystemIfEmpty(
    context: common.UIAbilityContext,
    currentRules: netFirewall.NetFirewallRule[]
  ): Promise<void> {
    let records = await FirewallStore.loadCustomRuleRecords(context)
    if (records.length > 0 || currentRules.length === 0) {
      return
    }
    let migratedRecords: StoredCustomFirewallRuleRecord[] = []
    currentRules.forEach((rule: netFirewall.NetFirewallRule) => {
      migratedRecords.push(FirewallStore.createCustomRuleRecord(
        FirewallStore.generateCustomRuleId(),
        FirewallStore.toStoredRule(rule)
      ))
    })
    await FirewallStore.saveCustomRuleRecords(context, migratedRecords)
  }

  static async replaceAllCustomRules(
    context: common.UIAbilityContext,
    nextRules: netFirewall.NetFirewallRule[]
  ): Promise<boolean> {
    let records: StoredCustomFirewallRuleRecord[] = []
    nextRules.forEach((rule: netFirewall.NetFirewallRule) => {
      records.push(FirewallStore.createCustomRuleRecord(
        FirewallStore.getCustomRuleId(rule) ?? FirewallStore.generateCustomRuleId(),
        FirewallStore.toStoredRule(rule)
      ))
    })
    return FirewallStore.saveCustomRuleRecords(context, records)
  }

  static getCustomRuleId(rule: netFirewall.NetFirewallRule): string | undefined {
    let metadata = FirewallRulesService.parseManagedRuleDescription(rule.description)
    return metadata?.kind === 'custom' ? metadata.customRuleId : undefined
  }

  static async loadUserBindings(context: common.UIAbilityContext): Promise<UserFirewallModeBinding[]> {
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
          (item.mode === 'allowlist' || item.mode === 'denylist')
      })
    } catch (err) {
      FirewallStore.recordStoreError(FirewallStrings.readUserModeBindingsAction, err as Object)
      LogUtils.error(TAG, `loadUserBindings failed: ${JSON.stringify(err)}`)
      return []
    }
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
    mode: FirewallUserApplyMode,
    sharedRules: netFirewall.NetFirewallRule[]
  ): Promise<UserFirewallModeApplyResult> {
    let result = await FirewallStore.applyUserModeInternal(userId, mode, sharedRules)
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
        errorCode: FirewallStore.getLastErrorCode(),
        errorMessage: FirewallStore.getLastErrorMessage()
      }
    }
    return result
  }

  static async reapplyUserBindings(
    context: common.UIAbilityContext,
    sharedRules: netFirewall.NetFirewallRule[]
  ): Promise<UserFirewallModeReapplySummary> {
    let activeUsersResult = await SystemUserProvider.loadAvailableUserIds()
    let activeUserIds = activeUsersResult.users.map((item) => item.userId)
    let bindings = await FirewallStore.loadUserBindings(context)
    let validBindings = bindings.filter((item: UserFirewallModeBinding): boolean => activeUserIds.includes(item.userId))
    if (validBindings.length !== bindings.length) {
      await FirewallStore.saveUserBindings(context, validBindings)
    }

    let summary: UserFirewallModeReapplySummary = {
      totalUsers: validBindings.length,
      successCount: 0,
      failedCount: 0,
      failedUsers: []
    }
    for (let i = 0; i < validBindings.length; i++) {
      let binding = validBindings[i]
      let result = await FirewallStore.applyUserModeInternal(binding.userId, binding.mode, sharedRules)
      if (result.success) {
        summary.successCount++
        continue
      }
      summary.failedCount++
      summary.failedUsers.push(binding.userId)
    }
    LogUtils.info(TAG,
      'reapplyUserBindings finished: total=%{public}d, success=%{public}d, failed=%{public}d',
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
    try {
      let store = await preferences.getPreferences(context, PREF_STORE_NAME_FIREWALL_USER_BINDINGS)
      await store.put(PREF_KEY_FIREWALL_USER_BINDINGS, JSON.stringify(bindings))
      await store.flush()
      return true
    } catch (err) {
      FirewallStore.recordStoreError(FirewallStrings.saveUserModeBindingsAction, err as Object)
      LogUtils.error(TAG, `saveUserBindings failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async getBindingMode(
    context: common.UIAbilityContext,
    userId: number
  ): Promise<FirewallUserApplyMode | undefined> {
    let bindings = await FirewallStore.loadUserBindings(context)
    let matched = bindings.find((item: UserFirewallModeBinding): boolean => item.userId === userId)
    return matched?.mode
  }

  private static async getStoredModeValue(context: common.UIAbilityContext): Promise<string> {
    try {
      let store = await preferences.getPreferences(context, PREF_STORE_NAME_FIREWALL_MODE)
      let rawValue = await store.get(PREF_KEY_FIREWALL_ACTIVE_MODE, '')
      return typeof rawValue === 'string' ? rawValue : ''
    } catch (err) {
      LogUtils.error(TAG, `getStoredModeValue failed: ${JSON.stringify(err)}`)
      return ''
    }
  }

  private static async loadCustomRuleRecords(context: common.UIAbilityContext): Promise<StoredCustomFirewallRuleRecord[]> {
    try {
      let store = await preferences.getPreferences(context, PREF_STORE_NAME_FIREWALL_CUSTOM_RULES)
      let rawValue = await store.get(PREF_KEY_FIREWALL_CUSTOM_RULES, '[]')
      let serialized = typeof rawValue === 'string' ? rawValue : '[]'
      let parsed = JSON.parse(serialized) as StoredCustomFirewallRuleRecord[]
      if (!Array.isArray(parsed)) {
        return []
      }
      let records: StoredCustomFirewallRuleRecord[] = []
      parsed.forEach((item: StoredCustomFirewallRuleRecord) => {
        if (typeof item.customRuleId === 'string' && !!item.rule) {
          records.push(FirewallStore.createCustomRuleRecord(
            item.customRuleId,
            FirewallStore.toStoredRule(item.rule)
          ))
        }
      })
      return records
    } catch (err) {
      LogUtils.error(TAG, `loadCustomRuleRecords failed: ${JSON.stringify(err)}`)
      return []
    }
  }

  private static async saveCustomRuleRecords(
    context: common.UIAbilityContext,
    records: StoredCustomFirewallRuleRecord[]
  ): Promise<boolean> {
    try {
      let store = await preferences.getPreferences(context, PREF_STORE_NAME_FIREWALL_CUSTOM_RULES)
      await store.put(PREF_KEY_FIREWALL_CUSTOM_RULES, JSON.stringify(records))
      await store.flush()
      return true
    } catch (err) {
      LogUtils.error(TAG, `saveCustomRuleRecords failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static toDisplayRule(record: StoredCustomFirewallRuleRecord): netFirewall.NetFirewallRule {
    let rule = FirewallRepository.cloneRuleForCreate(record.rule)
    let displayRule = FirewallRulesService.applyManagedRuleMetadata(rule, {
      owner: 'security_tool',
      mode: 'custom',
      kind: 'custom',
      customRuleId: record.customRuleId
    })
    displayRule.id = FirewallStore.hashRuleId(record.customRuleId)
    return displayRule
  }

  private static toStoredRule(rule: netFirewall.NetFirewallRule): netFirewall.NetFirewallRule {
    let clonedRule = FirewallRepository.cloneRuleForCreate(rule)
    clonedRule.description = undefined
    return clonedRule
  }

  private static createCustomRuleRecord(
    customRuleId: string,
    rule: netFirewall.NetFirewallRule
  ): StoredCustomFirewallRuleRecord {
    return {
      customRuleId: customRuleId,
      rule: rule
    }
  }

  private static generateCustomRuleId(): string {
    return `custom_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`
  }

  private static hashRuleId(customRuleId: string): number {
    let hash = 0
    for (let i = 0; i < customRuleId.length; i++) {
      hash = (hash * 31 + customRuleId.charCodeAt(i)) % 2147483647
    }
    return hash === 0 ? 1 : hash
  }

  private static async saveBindingMode(
    context: common.UIAbilityContext,
    userId: number,
    mode: FirewallUserApplyMode
  ): Promise<boolean> {
    let bindings = await FirewallStore.loadUserBindings(context)
    let nextBindings = bindings.filter((item: UserFirewallModeBinding): boolean => item.userId !== userId)
    nextBindings.push({
      userId: userId,
      mode: mode
    })
    return FirewallStore.saveUserBindings(context, nextBindings)
  }

  private static clearLastError(): void {
    FirewallStore.lastErrorCode = undefined
    FirewallStore.lastErrorMessage = ''
  }

  private static recordStoreError(action: string, err: Object): void {
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
    mode: FirewallUserApplyMode,
    sharedRules: netFirewall.NetFirewallRule[]
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

    let snapshotRules = await FirewallStore.getManagedRules(userId)
    let targetRules = FirewallStore.buildRulesForMode(userId, mode, sharedRules)
    LogUtils.info(TAG,
      'applyUserMode start: userId=%{public}d, mode=%{public}s, totalRules=%{public}d',
      userId,
      mode,
      targetRules.length
    )

    if (!await FirewallStore.clearManagedRules(userId)) {
      return FirewallStore.buildFailedResult(userId, mode, 0)
    }

    let targetPolicy: netFirewall.NetFirewallPolicy = {
      isOpen: policy.isOpen,
      inAction: mode === 'allowlist'
        ? netFirewall.FirewallRuleAction.RULE_DENY
        : netFirewall.FirewallRuleAction.RULE_ALLOW,
      outAction: mode === 'allowlist'
        ? netFirewall.FirewallRuleAction.RULE_DENY
        : netFirewall.FirewallRuleAction.RULE_ALLOW
    }
    if (!await FirewallStore.setPolicy(userId, targetPolicy)) {
      await FirewallStore.restoreManagedRules(userId, snapshotRules)
      return FirewallStore.buildFailedResult(userId, mode, 0)
    }

    if (!await FirewallStore.addRules(targetRules)) {
      let originalPolicy: netFirewall.NetFirewallPolicy = {
        isOpen: policy.isOpen,
        inAction: policy.inAction,
        outAction: policy.outAction
      }
      await FirewallStore.restoreManagedRulesAndPolicy(userId, originalPolicy, snapshotRules)
      return FirewallStore.buildFailedResult(userId, mode, 0)
    }

    LogUtils.info(TAG,
      'applyUserMode success: userId=%{public}d, mode=%{public}s, applied=%{public}d',
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
      return rule.action === netFirewall.FirewallRuleAction.RULE_DENY
    })
    return filteredRules.map((rule: netFirewall.NetFirewallRule): netFirewall.NetFirewallRule => {
      let clonedRule = FirewallRepository.cloneRuleForCreate(rule)
      clonedRule.userId = userId
      return FirewallRulesService.applyManagedRuleMetadata(clonedRule, {
        owner: 'security_tool',
        mode: 'custom',
        kind: 'custom',
        customRuleId: FirewallStore.getManagedRuleMetadata(rule)?.customRuleId
      })
    })
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
      return allRules
    } catch (err) {
      FirewallStore.recordStoreError(FirewallStrings.readUserRulesAction, err as Object)
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
        FirewallStore.recordStoreError(FirewallStrings.deleteUserRulesAction, err as Object)
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
      FirewallStore.recordStoreError(FirewallStrings.writeUserPolicyAction, err as Object)
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
