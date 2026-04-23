import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { buildFirewallAddRuleFailedMessage } from '../../constants/modules/FirewallStrings'
import { AuthMethod } from '../../models/DataModels'
import { LogUtils } from '../../utils/LogUtils'
import { AuthService } from '../identity/auth/AuthService'
import { FirewallLocalRepository } from './FirewallLocalRepository'
import {
  FirewallBatchOperationResult,
  FirewallFailedItem,
  FirewallOperationResult,
  FirewallOverviewState,
  FirewallPreparedRule,
  FirewallPresetMode,
  FirewallRuleDeployment,
  FirewallRuleDisplayItem,
  FirewallRuleIntent,
  FirewallRuleIntentInput,
  FirewallRuleMutationResult,
  FirewallToggleOperationResult,
  FirewallUserPolicyApplyResult,
  FirewallUserPolicyMode,
  FirewallUserPolicyModeRecord,
  FirewallUserPolicyStateResult,
  UserFirewallOption
} from './FirewallModels'
import { FirewallModeStrategy } from './FirewallModeStrategy'
import { FirewallRuleUtils } from './FirewallRuleUtils'
import { FirewallSystemRepository } from './FirewallSystemRepository'
import { SystemUserProvider } from './providers/SystemUserProvider'

const TAG = 'FirewallService'

export class FirewallService {
  static async loadOverviewState(context: common.UIAbilityContext): Promise<FirewallOverviewState> {
    let availableUsers = await SystemUserProvider.loadAvailableUserIds()
    if (availableUsers.users.length === 0) {
      LogUtils.warn(TAG, 'loadOverviewState fallback to default state because no available users')
      return {
        enabled: false,
        currentMode: await FirewallLocalRepository.getCurrentMode(context)
      }
    }

    let enabled = true
    for (let i = 0; i < availableUsers.users.length; i++) {
      let policy = await FirewallSystemRepository.getPolicy(availableUsers.users[i].userId)
      if (policy === null || !policy.isOpen) {
        enabled = false
        break
      }
    }

    return {
      enabled: enabled,
      currentMode: await FirewallLocalRepository.getCurrentMode(context)
    }
  }

  static async setFirewallEnabledForAllUsers(
    context: common.UIAbilityContext,
    enabled: boolean
  ): Promise<FirewallToggleOperationResult> {
    let authResult = await AuthService.authenticate(AuthMethod.PIN)
    if (!authResult.success) {
      return {
        success: false,
        targetEnabled: enabled,
        reason: authResult.reason === 'unavailable' ? 'pin_unavailable' : 'pin_failed',
        errorCode: authResult.errorCode,
        errorMessage: authResult.message
      }
    }

    let usersResult = await SystemUserProvider.loadAvailableUserIds()
    let users = usersResult.users
    let failedItems: FirewallFailedItem[] = []
    for (let i = 0; i < users.length; i++) {
      let userId = users[i].userId
      let existingPolicy = await FirewallSystemRepository.getPolicy(userId)
      if (existingPolicy === null) {
        failedItems.push({ userId: userId, errorMessage: 'read policy failed' })
        continue
      }
      let nextPolicy: netFirewall.NetFirewallPolicy = {
        isOpen: enabled,
        inAction: existingPolicy.inAction,
        outAction: existingPolicy.outAction
      }
      let applied = await FirewallSystemRepository.setPolicy(userId, nextPolicy)
      if (!applied) {
        failedItems.push({ userId: userId, errorMessage: 'set policy failed' })
      }
    }

    return {
      success: failedItems.length === 0,
      targetEnabled: enabled,
      reason: failedItems.length === 0 ? undefined : 'policy_apply_failed',
      failedItems: failedItems,
      errorMessage: failedItems.length === 0 ? undefined : 'policy apply failed'
    }
  }

  static async switchMode(
    context: common.UIAbilityContext,
    targetMode: FirewallPresetMode
  ): Promise<FirewallOperationResult> {
    let usersResult = await SystemUserProvider.loadAvailableUserIds()
    let failedItems: FirewallFailedItem[] = []

    for (let i = 0; i < usersResult.users.length; i++) {
      let userId = usersResult.users[i].userId
      let clearResult = await FirewallSystemRepository.clearRules(userId)
      failedItems.push(...clearResult.failedItems)
    }

    let policyFailedItems = await FirewallService.applyPolicyForMode(context, targetMode, usersResult.users)
    failedItems.push(...policyFailedItems)

    let deploymentsCleared = await FirewallLocalRepository.clearAllRuleDeployments(context)
    if (!deploymentsCleared) {
      failedItems.push({ errorMessage: 'clear local deployments failed' })
    }

    let preparedRules = await FirewallModeStrategy.buildRulesForMode(context, targetMode)
    let deploymentsByLocalRuleId = new Map<string, FirewallRuleDeployment[]>()
    for (let i = 0; i < preparedRules.length; i++) {
      let prepared = preparedRules[i]
      let addRuleResult = await FirewallSystemRepository.addRule(prepared.rule)
      if ((addRuleResult.systemRuleId ?? -1) > 0) {
        if (prepared.localRuleId !== undefined) {
          FirewallService.appendDeployment(deploymentsByLocalRuleId, prepared.localRuleId, {
            localRuleId: prepared.localRuleId,
            userId: prepared.userId,
            systemRuleId: addRuleResult.systemRuleId as number
          })
        }
        continue
      }
      failedItems.push({
        localRuleId: prepared.localRuleId,
        userId: prepared.userId,
        errorCode: addRuleResult.errorCode,
        errorMessage: addRuleResult.errorMessage ?? 'add rule failed'
      })
    }

    let localRuleIds = Array.from(deploymentsByLocalRuleId.keys())
    for (let i = 0; i < localRuleIds.length; i++) {
      let localRuleId = localRuleIds[i]
      let saved = await FirewallLocalRepository.replaceRuleDeployments(
        context,
        localRuleId,
        deploymentsByLocalRuleId.get(localRuleId) ?? []
      )
      if (!saved) {
        failedItems.push({ localRuleId: localRuleId, errorMessage: 'save deployments failed' })
      }
    }

    let modeSaved = await FirewallLocalRepository.saveCurrentMode(context, targetMode)
    if (!modeSaved) {
      failedItems.push({ errorMessage: 'save target mode failed' })
    }

    return {
      success: failedItems.length === 0,
      failedItems: failedItems,
      errorMessage: failedItems.length === 0 ? undefined : 'mode switch completed with failed items'
    }
  }

  static async listRulesForDisplay(context: common.UIAbilityContext): Promise<FirewallRuleDisplayItem[]> {
    let data = await FirewallLocalRepository.loadRuleIntentMappingData(context)
    return data.ruleIntents.map((intent: FirewallRuleIntent): FirewallRuleDisplayItem => {
      let deployments = data.ruleDeployments.filter((item: FirewallRuleDeployment): boolean => item.localRuleId === intent.localRuleId)
      return FirewallRuleUtils.cloneDisplayRuleFromIntent(intent, deployments) as FirewallRuleDisplayItem
    })
  }

  static async createRule(
    context: common.UIAbilityContext,
    input: FirewallRuleIntentInput
  ): Promise<FirewallRuleMutationResult> {
    let localRuleId = FirewallService.generateLocalRuleId()
    return FirewallService.createRuleWithLocalRuleId(context, localRuleId, input)
  }

  static async updateRule(
    context: common.UIAbilityContext,
    localRuleId: string,
    input: FirewallRuleIntentInput
  ): Promise<FirewallRuleMutationResult> {
    let existingIntent = await FirewallLocalRepository.getRuleIntent(context, localRuleId)
    if (existingIntent === null) {
      return {
        success: false,
        localRuleId: localRuleId,
        errorMessage: 'rule intent not found'
      }
    }

    let failedItems = await FirewallService.deleteDeploymentsOnly(context, localRuleId)
    let result = await FirewallService.createRuleWithLocalRuleId(
      context,
      localRuleId,
      input,
      existingIntent.createdAt
    )
    if (failedItems.length > 0) {
      result.failedItems = [...(result.failedItems ?? []), ...failedItems]
      result.success = false
    }
    return result
  }

  static async deleteRule(
    context: common.UIAbilityContext,
    localRuleId: string
  ): Promise<FirewallRuleMutationResult> {
    let failedItems = await FirewallService.deleteDeploymentsOnly(context, localRuleId)
    let intentRemoved = await FirewallLocalRepository.removeRuleIntent(context, localRuleId)
    if (!intentRemoved) {
      failedItems.push({ localRuleId: localRuleId, errorMessage: 'remove rule intent failed' })
    }
    return {
      success: failedItems.length === 0,
      localRuleId: localRuleId,
      failedItems: failedItems,
      errorMessage: failedItems.length === 0 ? undefined : 'delete rule completed with failed items'
    }
  }

  static async applyUserPolicyMode(
    context: common.UIAbilityContext,
    userId: number,
    mode: FirewallUserPolicyMode
  ): Promise<FirewallUserPolicyApplyResult> {
    let authResult = await AuthService.authenticate(AuthMethod.PIN)
    if (!authResult.success) {
      return {
        success: false,
        userId: userId,
        mode: mode,
        errorCode: authResult.errorCode,
        errorMessage: authResult.message
      }
    }

    let policy = FirewallService.buildPolicyForUserMode(mode)
    let applied = await FirewallSystemRepository.setPolicy(userId, policy)
    if (!applied) {
      return {
        success: false,
        userId: userId,
        mode: mode,
        errorMessage: 'set policy failed'
      }
    }

    let saved = await FirewallLocalRepository.saveUserPolicyMode(context, userId, mode)
    return {
      success: saved,
      userId: userId,
      mode: mode,
      errorMessage: saved ? undefined : 'save user policy mode failed'
    }
  }

  static async loadUserPolicyState(
    context: common.UIAbilityContext,
    userId: number
  ): Promise<FirewallUserPolicyStateResult> {
    let policy = await FirewallSystemRepository.getPolicy(userId)
    if (policy === null) {
      return {
        userId: userId,
        isManaged: false,
        isOpen: false,
        inAction: netFirewall.FirewallRuleAction.RULE_ALLOW,
        outAction: netFirewall.FirewallRuleAction.RULE_ALLOW,
        message: 'read policy failed'
      }
    }
    return {
      userId: userId,
      bindingMode: await FirewallLocalRepository.getUserPolicyMode(context, userId),
      isManaged: true,
      isOpen: policy.isOpen,
      inAction: policy.inAction,
      outAction: policy.outAction
    }
  }

  static findRuleConflict(
    existingRules: netFirewall.NetFirewallRule[],
    targetRule: netFirewall.NetFirewallRule
  ) {
    let existingIntents = existingRules.map((rule: netFirewall.NetFirewallRule): FirewallRuleIntent =>
      FirewallService.displayRuleToIntent(rule, `display_${FirewallService.readDisplayLocalRuleId(rule) ?? ''}`)
    )
    let targetIntent = FirewallService.displayRuleToIntent(targetRule, 'target')
    return FirewallRuleUtils.findRuleConflict(existingIntents, targetIntent, FirewallService.readDisplayLocalRuleId(targetRule))
  }

  static summarizeConflicts(rules: netFirewall.NetFirewallRule[]) {
    return FirewallRuleUtils.summarizeConflicts(
      rules.map((rule: netFirewall.NetFirewallRule): FirewallRuleIntent =>
        FirewallService.displayRuleToIntent(rule, FirewallService.readDisplayLocalRuleId(rule) ?? FirewallService.generateLocalRuleId())
      )
    )
  }

  private static async createRuleWithLocalRuleId(
    context: common.UIAbilityContext,
    localRuleId: string,
    input: FirewallRuleIntentInput,
    createdAt?: number
  ): Promise<FirewallRuleMutationResult> {
    let validation = FirewallRuleUtils.validateRuleIntentInput(input)
    if (!validation.success) {
      return {
        success: false,
        localRuleId: localRuleId,
        errorMessage: validation.errorMessage
      }
    }

    let now = Date.now()
    let intent = FirewallRuleUtils.buildIntentFromInput(localRuleId, input, now, createdAt)
    let deployments: FirewallRuleDeployment[] = []
    let failedItems: FirewallFailedItem[] = []

    for (let i = 0; i < intent.targetUserIds.length; i++) {
      let userId = intent.targetUserIds[i]
      let rule = FirewallRuleUtils.buildSystemRuleFromIntent(intent, userId)
      let normalizedRule = FirewallRuleUtils.normalizeRuleForCreate(rule)
      let addRuleResult = await FirewallSystemRepository.addRule(normalizedRule)
      if ((addRuleResult.systemRuleId ?? -1) > 0) {
        deployments.push({
          localRuleId: localRuleId,
          userId: userId,
          systemRuleId: addRuleResult.systemRuleId as number
        })
        continue
      }
      failedItems.push({
        localRuleId: localRuleId,
        userId: userId,
        errorCode: addRuleResult.errorCode,
        errorMessage: addRuleResult.errorMessage ?? 'add rule failed'
      })
    }

    if (deployments.length === 0) {
      let firstFailedItem = failedItems[0]
      return {
        success: false,
        localRuleId: localRuleId,
        failedItems: failedItems,
        errorCode: firstFailedItem?.errorCode,
        errorMessage: buildFirewallAddRuleFailedMessage(firstFailedItem?.errorCode)
      }
    }

    let intentSaved = await FirewallLocalRepository.saveRuleIntent(context, intent)
    let deploymentsSaved = await FirewallLocalRepository.replaceRuleDeployments(context, localRuleId, deployments)
    if (!intentSaved || !deploymentsSaved) {
      LogUtils.error(TAG, `createRule local save failed: localRuleId=${localRuleId}`)
      return {
        success: false,
        localRuleId: localRuleId,
        successDeployments: deployments,
        failedItems: failedItems,
        errorMessage: 'local save failed'
      }
    }

    return {
      success: failedItems.length === 0,
      localRuleId: localRuleId,
      successDeployments: deployments,
      failedItems: failedItems,
      errorMessage: failedItems.length === 0 ? undefined : 'rule created with failed items'
    }
  }

  private static async deleteDeploymentsOnly(
    context: common.UIAbilityContext,
    localRuleId: string
  ): Promise<FirewallFailedItem[]> {
    let deployments = await FirewallLocalRepository.listRuleDeployments(context, localRuleId)
    let failedItems: FirewallFailedItem[] = []
    for (let i = 0; i < deployments.length; i++) {
      let deployment = deployments[i]
      let removed = await FirewallSystemRepository.removeRule(deployment.userId, deployment.systemRuleId)
      if (!removed) {
        failedItems.push({
          localRuleId: localRuleId,
          userId: deployment.userId,
          systemRuleId: deployment.systemRuleId,
          errorMessage: 'remove system rule failed'
        })
      }
    }
    let localRemoved = await FirewallLocalRepository.removeRuleDeployments(context, localRuleId)
    if (!localRemoved) {
      failedItems.push({ localRuleId: localRuleId, errorMessage: 'remove deployments failed' })
    }
    return failedItems
  }

  private static async applyPolicyForMode(
    context: common.UIAbilityContext,
    targetMode: FirewallPresetMode,
    users: UserFirewallOption[]
  ): Promise<FirewallFailedItem[]> {
    let failedItems: FirewallFailedItem[] = []
    let modeRecords = targetMode === 'custom'
      ? await FirewallLocalRepository.listUserPolicyModes(context)
      : []

    for (let i = 0; i < users.length; i++) {
      let userId = users[i].userId
      let userMode = FirewallService.resolveUserPolicyModeForSwitch(targetMode, userId, modeRecords)
      let policy = FirewallService.buildPolicyForUserMode(userMode)
      let applied = await FirewallSystemRepository.setPolicy(userId, policy)
      if (!applied) {
        failedItems.push({ userId: userId, errorMessage: 'set mode policy failed' })
      }
    }
    return failedItems
  }

  private static resolveUserPolicyModeForSwitch(
    targetMode: FirewallPresetMode,
    userId: number,
    modeRecords: FirewallUserPolicyModeRecord[]
  ): FirewallUserPolicyMode | undefined {
    if (targetMode !== 'custom') {
      return undefined
    }
    return modeRecords.find((item: FirewallUserPolicyModeRecord): boolean => item.userId === userId)?.mode
  }

  private static buildPolicyForUserMode(mode?: FirewallUserPolicyMode): netFirewall.NetFirewallPolicy {
    if (mode === 'allowlist') {
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

  private static appendDeployment(
    deploymentsByLocalRuleId: Map<string, FirewallRuleDeployment[]>,
    localRuleId: string,
    deployment: FirewallRuleDeployment
  ): void {
    let deployments = deploymentsByLocalRuleId.get(localRuleId) ?? []
    deployments.push(deployment)
    deploymentsByLocalRuleId.set(localRuleId, deployments)
  }

  private static displayRuleToIntent(rule: netFirewall.NetFirewallRule, fallbackLocalRuleId: string): FirewallRuleIntent {
    let input = FirewallRuleUtils.buildIntentInputFromRule(rule, FirewallService.readDisplayTargetUserIds(rule))
    return FirewallRuleUtils.buildIntentFromInput(
      input.localRuleId ?? fallbackLocalRuleId,
      input,
      Date.now()
    )
  }

  private static readDisplayLocalRuleId(rule: netFirewall.NetFirewallRule): string | undefined {
    let source = rule as FirewallDisplayRuleCarrier
    return source.localRuleId
  }

  private static readDisplayTargetUserIds(rule: netFirewall.NetFirewallRule): number[] {
    let source = rule as FirewallDisplayRuleCarrier
    return Array.isArray(source.targetUserIds) ? source.targetUserIds : []
  }

  private static generateLocalRuleId(): string {
    return `fw_rule_${Date.now()}_${Math.floor(Math.random() * 1000000000).toString(36)}`
  }
}

interface FirewallDisplayRuleCarrier extends netFirewall.NetFirewallRule {
  localRuleId?: string
  targetUserIds?: number[]
}
