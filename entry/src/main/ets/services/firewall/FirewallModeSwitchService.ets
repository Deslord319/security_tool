import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { FirewallModeSwitchErrorStrings } from '../../constants/modules/FirewallErrorStrings'
import { buildAccountUserIdsSignature } from '../account/AccountSnapshotModels'
import {
  FirewallFailedItem,
  FirewallOperationResult,
  FirewallPresetMode,
  FirewallRuleDeployment,
  FirewallRuleIntentMappingData,
  FirewallScopedRule,
  UserFirewallOption
} from './FirewallModels'
import { FirewallLocalRepository } from './FirewallLocalRepository'
import { FirewallModeStrategy } from './FirewallModeStrategy'
import { FirewallPolicyService } from './FirewallPolicyService'
import { FirewallRuleUtils } from './FirewallRuleUtils'
import { FirewallSystemRepository } from './FirewallSystemRepository'
import { SystemUserProvider } from './providers/SystemUserProvider'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'FirewallModeSwitchService'

interface FirewallModeSwitchSnapshot {
  previousMode: FirewallPresetMode
  mappingData: FirewallRuleIntentMappingData
  policies: Map<number, netFirewall.NetFirewallPolicy>
  rules: Map<number, netFirewall.NetFirewallRule[]>
}

interface FirewallModeSwitchSnapshotResult {
  snapshot?: FirewallModeSwitchSnapshot
  failedItems: FirewallFailedItem[]
}

export class FirewallModeSwitchService {
  static async switchMode(
    context: common.UIAbilityContext,
    targetMode: FirewallPresetMode
  ): Promise<FirewallOperationResult> {
    let usersResult = await SystemUserProvider.loadAvailableUserIds()
    let failedItems: FirewallFailedItem[] = []
    if (usersResult.users.length === 0) {
      LogUtils.warn(TAG, `switchMode failed: no available users, message=${usersResult.message ?? 'unknown'}`)
      return {
        success: false,
        failedItems: failedItems,
        errorMessage: usersResult.message ?? FirewallModeSwitchErrorStrings.SNAPSHOT_FAILED
      }
    }
    let pruned = await FirewallLocalRepository.pruneUnavailableUsers(
      context,
      usersResult.users.map((user: UserFirewallOption): number => user.userId)
    )
    if (!pruned) {
      LogUtils.error(TAG, `switchMode failed: prune unavailable users, targetMode=${targetMode}`)
      return {
        success: false,
        failedItems: [{ errorMessage: FirewallModeSwitchErrorStrings.PRUNE_UNAVAILABLE_USERS_FAILED }],
        errorMessage: FirewallModeSwitchErrorStrings.PRUNE_UNAVAILABLE_USERS_FAILED
      }
    }
    return await FirewallModeSwitchService.applyModeToUsers(context, targetMode, usersResult.users)
  }

  static async applyModeToUsers(
    context: common.UIAbilityContext,
    targetMode: FirewallPresetMode,
    users: UserFirewallOption[],
    desiredEnabled?: boolean
  ): Promise<FirewallOperationResult> {
    let failedItems: FirewallFailedItem[] = []
    if (users.length === 0) {
      LogUtils.warn(TAG, `applyModeToUsers failed: no users, targetMode=${targetMode}`)
      return {
        success: false,
        failedItems: failedItems,
        errorMessage: FirewallModeSwitchErrorStrings.SNAPSHOT_FAILED
      }
    }

    let snapshotResult = await FirewallModeSwitchService.createSnapshot(context, users)
    failedItems.push(...snapshotResult.failedItems)
    if (failedItems.length > 0) {
      LogUtils.error(TAG, `applyModeToUsers failed: snapshot, targetMode=${targetMode}, failedCount=${failedItems.length}`)
      return {
        success: false,
        failedItems: failedItems,
        errorMessage: FirewallModeSwitchErrorStrings.SNAPSHOT_FAILED
      }
    }
    let snapshot = snapshotResult.snapshot as FirewallModeSwitchSnapshot

    for (let i = 0; i < users.length; i++) {
      let userId = users[i].userId
      let clearResult = await FirewallSystemRepository.clearRules(userId)
      failedItems.push(...clearResult.failedItems)
    }

    let policyFailedItems = await FirewallPolicyService.applyPolicyForMode(context, targetMode, users, desiredEnabled)
    failedItems.push(...policyFailedItems)

    let deploymentsCleared = await FirewallLocalRepository.clearAllRuleDeployments(context)
    if (!deploymentsCleared) {
        failedItems.push({ errorMessage: FirewallModeSwitchErrorStrings.CLEAR_LOCAL_DEPLOYMENTS_FAILED })
    }

    let preparedRules = await FirewallModeStrategy.buildRulesForMode(context, targetMode, users)
    let deploymentsByLocalRuleId = new Map<string, FirewallRuleDeployment[]>()
    for (let i = 0; i < preparedRules.length; i++) {
      let prepared = preparedRules[i]
      let addRuleResult = await FirewallSystemRepository.addRule(prepared.rule)
      if ((addRuleResult.systemRuleId ?? -1) > 0) {
        if (prepared.localRuleId !== undefined) {
          FirewallModeSwitchService.appendDeployment(deploymentsByLocalRuleId, prepared.localRuleId, {
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
        errorMessage: addRuleResult.errorMessage ?? FirewallModeSwitchErrorStrings.ADD_RULE_FAILED
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
        failedItems.push({ localRuleId: localRuleId, errorMessage: FirewallModeSwitchErrorStrings.SAVE_DEPLOYMENTS_FAILED })
      }
    }

    if (failedItems.length === 0) {
      let modeSaved = await FirewallLocalRepository.saveCurrentMode(context, targetMode)
      if (!modeSaved) {
        failedItems.push({ errorMessage: FirewallModeSwitchErrorStrings.SAVE_TARGET_MODE_FAILED })
      }
      let modeApplyStateSaved = await FirewallLocalRepository.saveModeApplyState(
        context,
        targetMode,
        buildAccountUserIdsSignature(users.map((user: UserFirewallOption): number => user.userId))
      )
      if (!modeApplyStateSaved) {
        failedItems.push({ errorMessage: FirewallModeSwitchErrorStrings.SAVE_MODE_APPLY_STATE_FAILED })
      }
    }
    if (failedItems.length > 0) {
      failedItems.push(...await FirewallModeSwitchService.rollbackToSnapshot(context, users, snapshot))
      LogUtils.error(
        TAG,
        `applyModeToUsers failed: targetMode=${targetMode}, failedCount=${failedItems.length}, rollbackAttempted=true`
      )
    }

    return {
      success: failedItems.length === 0,
      failedItems: failedItems,
      errorMessage: failedItems.length === 0 ? undefined : FirewallModeSwitchErrorStrings.COMPLETED_WITH_FAILED_ITEMS
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

  private static async createSnapshot(
    context: common.UIAbilityContext,
    users: UserFirewallOption[]
  ): Promise<FirewallModeSwitchSnapshotResult> {
    let failedItems: FirewallFailedItem[] = []
    let policies = new Map<number, netFirewall.NetFirewallPolicy>()
    let rules = new Map<number, netFirewall.NetFirewallRule[]>()

    for (let i = 0; i < users.length; i++) {
      let userId = users[i].userId
      let policy = await FirewallSystemRepository.getPolicy(userId)
      if (policy === null) {
        failedItems.push({ userId: userId, errorMessage: FirewallModeSwitchErrorStrings.READ_PREVIOUS_POLICY_FAILED })
        continue
      }
      policies.set(userId, FirewallModeSwitchService.clonePolicy(policy))
      rules.set(userId, (await FirewallSystemRepository.listRules(userId)).map(
        (rule: netFirewall.NetFirewallRule): netFirewall.NetFirewallRule => FirewallModeSwitchService.cloneRuleForSnapshot(rule)
      ))
    }

    return {
      failedItems: failedItems,
      snapshot: {
        previousMode: await FirewallLocalRepository.getCurrentMode(context),
        mappingData: await FirewallLocalRepository.loadRuleIntentMappingData(context),
        policies: policies,
        rules: rules
      }
    }
  }

  private static async rollbackToSnapshot(
    context: common.UIAbilityContext,
    users: UserFirewallOption[],
    snapshot: FirewallModeSwitchSnapshot
  ): Promise<FirewallFailedItem[]> {
    let failedItems: FirewallFailedItem[] = []
    let restoredRuleIds = new Map<string, number>()
    for (let i = 0; i < users.length; i++) {
      let userId = users[i].userId
      let clearResult = await FirewallSystemRepository.clearRules(userId)
      if (!clearResult.success) {
        failedItems.push(...clearResult.failedItems.map((item: FirewallFailedItem): FirewallFailedItem => {
          item.errorMessage = item.errorMessage ?? FirewallModeSwitchErrorStrings.ROLLBACK_CLEAR_CURRENT_RULES_FAILED
          return item
        }))
      }

      let previousPolicy = snapshot.policies.get(userId)
      if (previousPolicy !== undefined) {
        let policyRestored = await FirewallSystemRepository.setPolicy(userId, previousPolicy)
        if (!policyRestored) {
          failedItems.push({ userId: userId, errorMessage: FirewallModeSwitchErrorStrings.ROLLBACK_POLICY_FAILED })
        }
      }

      let previousRules = snapshot.rules.get(userId) ?? []
      for (let ruleIndex = 0; ruleIndex < previousRules.length; ruleIndex++) {
        let previousRule = previousRules[ruleIndex]
        let previousRuleId = FirewallRuleUtils.readSystemRuleId(previousRule)
        let addRuleResult = await FirewallSystemRepository.addRule(FirewallRuleUtils.normalizeRuleForCreate(previousRule))
        if ((addRuleResult.systemRuleId ?? -1) > 0) {
          if (previousRuleId !== undefined) {
            restoredRuleIds.set(FirewallModeSwitchService.buildRuleKey(userId, previousRuleId), addRuleResult.systemRuleId as number)
          }
          continue
        }
        failedItems.push({
          userId: userId,
          systemRuleId: previousRuleId,
          errorCode: addRuleResult.errorCode,
          errorMessage: addRuleResult.errorMessage ?? FirewallModeSwitchErrorStrings.ROLLBACK_RESTORE_RULE_FAILED
        })
      }
    }

    let restoredMapping = FirewallModeSwitchService.remapDeployments(snapshot.mappingData, restoredRuleIds)
    let mappingRestored = await FirewallLocalRepository.saveRuleIntentMappingData(context, restoredMapping)
    if (!mappingRestored) {
      failedItems.push({ errorMessage: FirewallModeSwitchErrorStrings.ROLLBACK_LOCAL_DEPLOYMENTS_FAILED })
    }
    let modeRestored = await FirewallLocalRepository.saveCurrentMode(context, snapshot.previousMode)
    if (!modeRestored) {
      failedItems.push({ errorMessage: FirewallModeSwitchErrorStrings.ROLLBACK_CURRENT_MODE_FAILED })
    }
    return failedItems
  }

  private static remapDeployments(
    mappingData: FirewallRuleIntentMappingData,
    restoredRuleIds: Map<string, number>
  ): FirewallRuleIntentMappingData {
    return {
      version: mappingData.version,
      ruleIntents: mappingData.ruleIntents,
      ruleDeployments: mappingData.ruleDeployments.map((deployment: FirewallRuleDeployment): FirewallRuleDeployment => {
        let restoredRuleId = restoredRuleIds.get(FirewallModeSwitchService.buildRuleKey(deployment.userId, deployment.systemRuleId))
        return {
          localRuleId: deployment.localRuleId,
          userId: deployment.userId,
          systemRuleId: restoredRuleId ?? deployment.systemRuleId
        }
      })
    }
  }

  private static buildRuleKey(userId: number, systemRuleId: number): string {
    return `${userId}:${systemRuleId}`
  }

  private static clonePolicy(policy: netFirewall.NetFirewallPolicy): netFirewall.NetFirewallPolicy {
    return {
      isOpen: policy.isOpen,
      inAction: policy.inAction,
      outAction: policy.outAction
    }
  }

  private static cloneRuleForSnapshot(rule: netFirewall.NetFirewallRule): netFirewall.NetFirewallRule {
    let clonedRule = FirewallRuleUtils.cloneSystemRule(rule) as FirewallScopedRule
    let ruleId = FirewallRuleUtils.readSystemRuleId(rule)
    if (ruleId !== undefined) {
      clonedRule.id = ruleId
    }
    return clonedRule as netFirewall.NetFirewallRule
  }
}
