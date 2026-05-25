import { common } from '@kit.AbilityKit'
import { FirewallRuleDeploymentErrorStrings } from '../../constants/modules/FirewallErrorStrings'
import { FirewallLocalRepository } from './FirewallLocalRepository'
import {
  FirewallFailedItem,
  FirewallRuleDeployment,
  FirewallRuleIntent,
  FirewallScopedRule
} from './FirewallModels'
import { FirewallRuleUtils } from './FirewallRuleUtils'
import { FirewallSystemRepository } from './FirewallSystemRepository'

const UPDATE_SYSTEM_RULE_FAILED = 'update system rule failed'

export interface FirewallRuleDeploymentApplyResult {
  deployments: FirewallRuleDeployment[]
  failedItems: FirewallFailedItem[]
}

export interface FirewallDeploymentRemoveResult {
  removedDeployments: FirewallRuleDeployment[]
  failedItems: FirewallFailedItem[]
}

export class FirewallRuleDeploymentService {
  static async applyRuleIntentDeployments(
    intent: FirewallRuleIntent
  ): Promise<FirewallRuleDeploymentApplyResult> {
    let deployments: FirewallRuleDeployment[] = []
    let failedItems: FirewallFailedItem[] = []

    for (let i = 0; i < intent.targetUserIds.length; i++) {
      let userId = intent.targetUserIds[i]
      let rule = FirewallRuleUtils.buildSystemRuleFromIntent(intent, userId)
      let normalizedRule = FirewallRuleUtils.normalizeRuleForCreate(rule)
      let addRuleResult = await FirewallSystemRepository.addRule(normalizedRule)
      if ((addRuleResult.systemRuleId ?? -1) > 0) {
        deployments.push({
          localRuleId: intent.localRuleId,
          userId: userId,
          systemRuleId: addRuleResult.systemRuleId as number
        })
        continue
      }
      failedItems.push({
        localRuleId: intent.localRuleId,
        userId: userId,
        errorCode: addRuleResult.errorCode,
        errorMessage: addRuleResult.errorMessage ?? FirewallRuleDeploymentErrorStrings.ADD_RULE_FAILED
      })
    }

    return {
      deployments: deployments,
      failedItems: failedItems
    }
  }

  static async removeDeploymentSystemRules(
    localRuleId: string,
    deployments: FirewallRuleDeployment[]
  ): Promise<FirewallDeploymentRemoveResult> {
    let removedDeployments: FirewallRuleDeployment[] = []
    let failedItems: FirewallFailedItem[] = []
    for (let i = 0; i < deployments.length; i++) {
      let deployment = deployments[i]
      let removed = await FirewallSystemRepository.removeRule(deployment.userId, deployment.systemRuleId)
      if (removed) {
        removedDeployments.push(deployment)
        continue
      }
      failedItems.push({
        localRuleId: localRuleId,
        userId: deployment.userId,
        systemRuleId: deployment.systemRuleId,
        errorMessage: FirewallRuleDeploymentErrorStrings.REMOVE_SYSTEM_RULE_FAILED
      })
    }
    return {
      removedDeployments: removedDeployments,
      failedItems: failedItems
    }
  }

  static async updateDeploymentSystemRule(
    intent: FirewallRuleIntent,
    deployment: FirewallRuleDeployment
  ): Promise<FirewallFailedItem | null> {
    let rule = FirewallRuleUtils.buildSystemRuleFromIntent(intent, deployment.userId)
    let normalizedRule = FirewallRuleUtils.normalizeRuleForCreate(rule)
    let scopedRule = normalizedRule as FirewallScopedRule
    scopedRule.id = deployment.systemRuleId
    let result = await FirewallSystemRepository.updateRule(normalizedRule)
    if (result.success) {
      return null
    }
    return {
      localRuleId: intent.localRuleId,
      userId: deployment.userId,
      systemRuleId: deployment.systemRuleId,
      errorCode: result.errorCode,
      errorMessage: result.errorMessage ?? UPDATE_SYSTEM_RULE_FAILED
    }
  }

  static async rollbackSystemDeployments(
    localRuleId: string,
    deployments: FirewallRuleDeployment[],
    errorMessage: string
  ): Promise<FirewallFailedItem[]> {
    let failedItems: FirewallFailedItem[] = []
    for (let i = 0; i < deployments.length; i++) {
      let deployment = deployments[i]
      let removed = await FirewallSystemRepository.removeRule(deployment.userId, deployment.systemRuleId)
      if (!removed) {
        failedItems.push({
          localRuleId: localRuleId,
          userId: deployment.userId,
          systemRuleId: deployment.systemRuleId,
          errorMessage: errorMessage
        })
      }
    }
    return failedItems
  }

  static async restoreRemovedDeployments(
    context: common.UIAbilityContext,
    intent: FirewallRuleIntent,
    previousDeployments: FirewallRuleDeployment[],
    removedDeployments: FirewallRuleDeployment[]
  ): Promise<FirewallRuleDeploymentApplyResult> {
    if (removedDeployments.length === 0) {
      return {
        deployments: previousDeployments,
        failedItems: []
      }
    }

    let restoredDeployments: FirewallRuleDeployment[] = previousDeployments.filter(
      (deployment: FirewallRuleDeployment): boolean => !FirewallRuleDeploymentService.containsDeployment(removedDeployments, deployment)
    )
    let failedItems: FirewallFailedItem[] = []

    for (let i = 0; i < removedDeployments.length; i++) {
      let removedDeployment = removedDeployments[i]
      let rule = FirewallRuleUtils.buildSystemRuleFromIntent(intent, removedDeployment.userId)
      let normalizedRule = FirewallRuleUtils.normalizeRuleForCreate(rule)
      let addRuleResult = await FirewallSystemRepository.addRule(normalizedRule)
      if ((addRuleResult.systemRuleId ?? -1) > 0) {
        restoredDeployments.push({
          localRuleId: intent.localRuleId,
          userId: removedDeployment.userId,
          systemRuleId: addRuleResult.systemRuleId as number
        })
        continue
      }
      failedItems.push({
        localRuleId: intent.localRuleId,
        userId: removedDeployment.userId,
        errorCode: addRuleResult.errorCode,
        errorMessage: addRuleResult.errorMessage ?? FirewallRuleDeploymentErrorStrings.RESTORE_OLD_SYSTEM_RULE_FAILED
      })
    }

    let saved = await FirewallLocalRepository.replaceRuleDeployments(context, intent.localRuleId, restoredDeployments)
    if (!saved) {
      failedItems.push({ localRuleId: intent.localRuleId, errorMessage: FirewallRuleDeploymentErrorStrings.RESTORE_OLD_DEPLOYMENTS_FAILED })
    }

    return {
      deployments: restoredDeployments,
      failedItems: failedItems
    }
  }

  static async deleteDeploymentsOnly(
    context: common.UIAbilityContext,
    localRuleId: string
  ): Promise<FirewallFailedItem[]> {
    let deployments = await FirewallLocalRepository.listRuleDeployments(context, localRuleId)
    let failedItems: FirewallFailedItem[] = []
    let remainingDeployments: FirewallRuleDeployment[] = []
    for (let i = 0; i < deployments.length; i++) {
      let deployment = deployments[i]
      let removed = await FirewallSystemRepository.removeRule(deployment.userId, deployment.systemRuleId)
      if (!removed) {
        remainingDeployments.push(deployment)
        failedItems.push({
          localRuleId: localRuleId,
          userId: deployment.userId,
          systemRuleId: deployment.systemRuleId,
          errorMessage: FirewallRuleDeploymentErrorStrings.REMOVE_SYSTEM_RULE_FAILED
        })
      }
    }
    if (failedItems.length > 0) {
      let localSaved = await FirewallLocalRepository.replaceRuleDeployments(context, localRuleId, remainingDeployments)
      if (!localSaved) {
        failedItems.push({ localRuleId: localRuleId, errorMessage: FirewallRuleDeploymentErrorStrings.PRESERVE_FAILED_DEPLOYMENTS_FAILED })
      }
      return failedItems
    }

    let localRemoved = await FirewallLocalRepository.removeRuleDeployments(context, localRuleId)
    if (!localRemoved) {
      failedItems.push({ localRuleId: localRuleId, errorMessage: FirewallRuleDeploymentErrorStrings.REMOVE_DEPLOYMENTS_FAILED })
    }
    return failedItems
  }

  private static containsDeployment(deployments: FirewallRuleDeployment[], target: FirewallRuleDeployment): boolean {
    return deployments.some((deployment: FirewallRuleDeployment): boolean =>
      deployment.localRuleId === target.localRuleId &&
        deployment.userId === target.userId &&
        deployment.systemRuleId === target.systemRuleId
    )
  }
}
