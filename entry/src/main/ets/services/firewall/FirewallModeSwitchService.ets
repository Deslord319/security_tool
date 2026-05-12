import { common } from '@kit.AbilityKit'
import {
  FirewallFailedItem,
  FirewallOperationResult,
  FirewallPresetMode,
  FirewallRuleDeployment
} from './FirewallModels'
import { FirewallLocalRepository } from './FirewallLocalRepository'
import { FirewallModeStrategy } from './FirewallModeStrategy'
import { FirewallPolicyService } from './FirewallPolicyService'
import { FirewallSystemRepository } from './FirewallSystemRepository'
import { SystemUserProvider } from './providers/SystemUserProvider'

export class FirewallModeSwitchService {
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

    let policyFailedItems = await FirewallPolicyService.applyPolicyForMode(context, targetMode, usersResult.users)
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

    if (failedItems.length === 0) {
      let modeSaved = await FirewallLocalRepository.saveCurrentMode(context, targetMode)
      if (!modeSaved) {
        failedItems.push({ errorMessage: 'save target mode failed' })
      }
    }

    return {
      success: failedItems.length === 0,
      failedItems: failedItems,
      errorMessage: failedItems.length === 0 ? undefined : 'mode switch completed with failed items'
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
}
