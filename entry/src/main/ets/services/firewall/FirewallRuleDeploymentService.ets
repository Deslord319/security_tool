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

interface SingleDeployOutcome {
  deployment?: FirewallRuleDeployment
  failedItem?: FirewallFailedItem
}

export class FirewallRuleDeploymentService {
  static async applyRuleIntentDeployments(
    intent: FirewallRuleIntent
  ): Promise<FirewallRuleDeploymentApplyResult> {
    let deployments: FirewallRuleDeployment[] = []
    let failedItems: FirewallFailedItem[] = []

    for (let i = 0; i < intent.targetUserIds.length; i++) {
      let userId = intent.targetUserIds[i]
      let outcome = await FirewallRuleDeploymentService.deploySingleRule(
        intent,
        userId,
        FirewallRuleDeploymentErrorStrings.ADD_RULE_FAILED
      )
      if (outcome.deployment) {
        deployments.push(outcome.deployment)
        continue
      }
      if (outcome.failedItem) {
        failedItems.push(outcome.failedItem)
      }
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
      let failedItem = await FirewallRuleDeploymentService.removeDeploymentSilently(
        localRuleId,
        deployment,
        FirewallRuleDeploymentErrorStrings.REMOVE_SYSTEM_RULE_FAILED
      )
      if (failedItem === null) {
        removedDeployments.push(deployment)
        continue
      }
      failedItems.push(failedItem)
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
      let failedItem = await FirewallRuleDeploymentService.removeDeploymentSilently(localRuleId, deployment, errorMessage)
      if (failedItem !== null) {
        failedItems.push(failedItem)
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
      let outcome = await FirewallRuleDeploymentService.deploySingleRule(
        intent,
        removedDeployment.userId,
        FirewallRuleDeploymentErrorStrings.RESTORE_OLD_SYSTEM_RULE_FAILED
      )
      if (outcome.deployment) {
        restoredDeployments.push(outcome.deployment)
        continue
      }
      if (outcome.failedItem) {
        failedItems.push(outcome.failedItem)
      }
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
      let failedItem = await FirewallRuleDeploymentService.removeDeploymentSilently(
        localRuleId,
        deployment,
        FirewallRuleDeploymentErrorStrings.REMOVE_SYSTEM_RULE_FAILED
      )
      if (failedItem !== null) {
        remainingDeployments.push(deployment)
        failedItems.push(failedItem)
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

  private static async deploySingleRule(
    intent: FirewallRuleIntent,
    userId: number,
    failureMessage: string
  ): Promise<SingleDeployOutcome> {
    let rule = FirewallRuleUtils.buildSystemRuleFromIntent(intent, userId)
    let normalizedRule = FirewallRuleUtils.normalizeRuleForCreate(rule)
    let addRuleResult = await FirewallSystemRepository.addRule(normalizedRule)
    if ((addRuleResult.systemRuleId ?? -1) > 0) {
      return {
        deployment: {
          localRuleId: intent.localRuleId,
          userId: userId,
          systemRuleId: addRuleResult.systemRuleId as number
        }
      }
    }
    return {
      failedItem: {
        localRuleId: intent.localRuleId,
        userId: userId,
        errorCode: addRuleResult.errorCode,
        errorMessage: addRuleResult.errorMessage ?? failureMessage
      }
    }
  }

  private static async removeDeploymentSilently(
    localRuleId: string,
    deployment: FirewallRuleDeployment,
    failureMessage: string
  ): Promise<FirewallFailedItem | null> {
    let removed = await FirewallSystemRepository.removeRule(deployment.userId, deployment.systemRuleId)
    if (removed) {
      return null
    }
    return {
      localRuleId: localRuleId,
      userId: deployment.userId,
      systemRuleId: deployment.systemRuleId,
      errorMessage: failureMessage
    }
  }

  private static containsDeployment(deployments: FirewallRuleDeployment[], target: FirewallRuleDeployment): boolean {
    return deployments.some((deployment: FirewallRuleDeployment): boolean =>
      deployment.localRuleId === target.localRuleId &&
        deployment.userId === target.userId &&
        deployment.systemRuleId === target.systemRuleId
    )
  }
}
