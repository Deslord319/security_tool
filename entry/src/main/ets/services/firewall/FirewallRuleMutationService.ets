import { common } from '@kit.AbilityKit'
import { FirewallRuleMutationErrorStrings } from '../../constants/modules/FirewallErrorStrings'
import { buildFirewallAddRuleFailedMessage } from '../../constants/modules/FirewallStrings'
import { LogUtils } from '../../utils/LogUtils'
import { generateRandomSuffix } from '../../utils/ValuePicker'
import { FirewallLocalRepository } from './FirewallLocalRepository'
import {
  FirewallFailedItem,
  FirewallRuleDeployment,
  FirewallRuleIntent,
  FirewallRuleIntentInput,
  FirewallRuleMutationResult
} from './FirewallModels'
import { FirewallRuleDeploymentService } from './FirewallRuleDeploymentService'
import { FirewallSystemRepository } from './FirewallSystemRepository'
import { FirewallRuleUtils } from './FirewallRuleUtils'

const TAG = 'FirewallRuleMutationService'

export class FirewallRuleMutationService {
  static async createRule(
    context: common.UIAbilityContext,
    input: FirewallRuleIntentInput
  ): Promise<FirewallRuleMutationResult> {
    let localRuleId = FirewallRuleMutationService.generateLocalRuleId()
    return FirewallRuleMutationService.createRuleWithLocalRuleId(context, localRuleId, input)
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
        errorMessage: FirewallRuleMutationErrorStrings.RULE_INTENT_NOT_FOUND
      }
    }

    let validation = FirewallRuleUtils.validateRuleIntentInput(input)
    if (!validation.success) {
      return {
        success: false,
        localRuleId: localRuleId,
        errorMessage: validation.errorMessage
      }
    }

    let now = Date.now()
    let nextIntent = FirewallRuleUtils.buildIntentFromInput(localRuleId, input, now, existingIntent.createdAt)
    let oldDeployments = await FirewallLocalRepository.listRuleDeployments(context, localRuleId)
    let transactionResult = await FirewallRuleMutationService.applyUpdateTransaction(
      context,
      existingIntent,
      oldDeployments,
      nextIntent
    )
    if (transactionResult.failedItems.length > 0) {
      let firstFailedItem = transactionResult.failedItems[0]
      return {
        success: false,
        localRuleId: localRuleId,
        failedItems: transactionResult.failedItems,
        errorCode: firstFailedItem?.errorCode,
        errorMessage: buildFirewallAddRuleFailedMessage(firstFailedItem?.errorCode)
      }
    }

    let intentSaved = await FirewallLocalRepository.saveRuleIntent(context, nextIntent)
    let deploymentsSaved = await FirewallLocalRepository.replaceRuleDeployments(context, localRuleId, transactionResult.deployments)
    if (!intentSaved || !deploymentsSaved) {
      LogUtils.error(TAG, `updateRule local save failed: localRuleId=${localRuleId}`)
      let rollbackFailedItems = await FirewallRuleMutationService.rollbackUpdateTransaction(
        context,
        existingIntent,
        oldDeployments,
        transactionResult.updatedDeployments,
        transactionResult.addedDeployments,
        transactionResult.removedDeployments
      )
      if (intentSaved) {
        let restoredIntent = await FirewallLocalRepository.saveRuleIntent(context, existingIntent)
        if (!restoredIntent) {
          rollbackFailedItems.push({ localRuleId: localRuleId, errorMessage: FirewallRuleMutationErrorStrings.RESTORE_OLD_INTENT_FAILED })
        }
      }
      if (transactionResult.removedDeployments.length === 0) {
        let restoredDeployments = await FirewallLocalRepository.replaceRuleDeployments(context, localRuleId, oldDeployments)
        if (!restoredDeployments) {
          rollbackFailedItems.push({ localRuleId: localRuleId, errorMessage: FirewallRuleMutationErrorStrings.ROLLBACK_LOCAL_DEPLOYMENTS_FAILED })
        }
      }
      return {
        success: false,
        localRuleId: localRuleId,
        successDeployments: transactionResult.deployments,
        failedItems: rollbackFailedItems,
        errorMessage: FirewallRuleMutationErrorStrings.LOCAL_SAVE_FAILED
      }
    }

    return {
      success: true,
      localRuleId: localRuleId,
      successDeployments: transactionResult.deployments,
      failedItems: []
    }
  }

  static async deleteRule(
    context: common.UIAbilityContext,
    localRuleId: string
  ): Promise<FirewallRuleMutationResult> {
    let existingIntent = await FirewallLocalRepository.getRuleIntent(context, localRuleId)
    if (existingIntent === null) {
      return {
        success: false,
        localRuleId: localRuleId,
        errorMessage: FirewallRuleMutationErrorStrings.RULE_INTENT_NOT_FOUND
      }
    }
    let oldDeployments = await FirewallLocalRepository.listRuleDeployments(context, localRuleId)
    let removeResult = await FirewallRuleDeploymentService.removeDeploymentSystemRules(localRuleId, oldDeployments)
    if (removeResult.failedItems.length > 0) {
      let restoreResult = await FirewallRuleDeploymentService.restoreRemovedDeployments(
        context,
        existingIntent,
        oldDeployments,
        removeResult.removedDeployments
      )
      return {
        success: false,
        localRuleId: localRuleId,
        failedItems: [...removeResult.failedItems, ...restoreResult.failedItems],
        errorMessage: FirewallRuleMutationErrorStrings.DELETE_RULE_COMPLETED_WITH_FAILED_ITEMS
      }
    }

    let deploymentsRemoved = await FirewallLocalRepository.removeRuleDeployments(context, localRuleId)
    let intentRemoved = await FirewallLocalRepository.removeRuleIntent(context, localRuleId)
    if (!deploymentsRemoved || !intentRemoved) {
      let restoreResult = await FirewallRuleDeploymentService.restoreRemovedDeployments(
        context,
        existingIntent,
        oldDeployments,
        oldDeployments
      )
      let failedItems: FirewallFailedItem[] = [...restoreResult.failedItems]
      if (!deploymentsRemoved) {
        failedItems.push({ localRuleId: localRuleId, errorMessage: FirewallRuleMutationErrorStrings.ROLLBACK_LOCAL_DEPLOYMENTS_FAILED })
      }
      if (!intentRemoved) {
        failedItems.push({ localRuleId: localRuleId, errorMessage: FirewallRuleMutationErrorStrings.REMOVE_RULE_INTENT_FAILED })
      }
      if (intentRemoved) {
        let restoredIntent = await FirewallLocalRepository.saveRuleIntent(context, existingIntent)
        if (!restoredIntent) {
          failedItems.push({ localRuleId: localRuleId, errorMessage: FirewallRuleMutationErrorStrings.RESTORE_OLD_INTENT_FAILED })
        }
      }
      return {
        success: false,
        localRuleId: localRuleId,
        failedItems: failedItems,
        errorMessage: FirewallRuleMutationErrorStrings.DELETE_RULE_COMPLETED_WITH_FAILED_ITEMS
      }
    }
    return {
      success: true,
      localRuleId: localRuleId,
      failedItems: []
    }
  }

  static async replaceConflictRule(
    context: common.UIAbilityContext,
    conflictLocalRuleId: string,
    nextLocalRuleId: string | undefined,
    input: FirewallRuleIntentInput,
    isEditMode: boolean
  ): Promise<FirewallRuleMutationResult> {
    let conflictIntent = await FirewallLocalRepository.getRuleIntent(context, conflictLocalRuleId)
    if (conflictIntent === null) {
      return {
        success: false,
        localRuleId: conflictLocalRuleId,
        errorMessage: FirewallRuleMutationErrorStrings.CONFLICT_RULE_INTENT_NOT_FOUND
      }
    }
    if (isEditMode && nextLocalRuleId === undefined) {
      return {
        success: false,
        localRuleId: conflictLocalRuleId,
        errorMessage: FirewallRuleMutationErrorStrings.TARGET_RULE_INTENT_NOT_FOUND
      }
    }

    let targetIntent: FirewallRuleIntent | null = null
    let targetDeployments: FirewallRuleDeployment[] = []
    if (isEditMode) {
      targetIntent = await FirewallLocalRepository.getRuleIntent(context, nextLocalRuleId as string)
      if (targetIntent === null) {
        return {
          success: false,
          localRuleId: nextLocalRuleId,
          errorMessage: FirewallRuleMutationErrorStrings.TARGET_RULE_INTENT_NOT_FOUND
        }
      }
      targetDeployments = await FirewallLocalRepository.listRuleDeployments(context, nextLocalRuleId as string)
    }

    let conflictDeployments = await FirewallLocalRepository.listRuleDeployments(context, conflictLocalRuleId)
    let deleteResult = await FirewallRuleMutationService.deleteRule(context, conflictLocalRuleId)
    if (!deleteResult.success) {
      return deleteResult
    }

    let nextResult = isEditMode
      ? await FirewallRuleMutationService.updateRule(context, nextLocalRuleId as string, input)
      : await FirewallRuleMutationService.createRule(context, input)
    if (nextResult.success) {
      return nextResult
    }

    let rollbackFailedItems: FirewallFailedItem[] = []
    if ((nextResult.successDeployments?.length ?? 0) > 0 && nextResult.localRuleId !== undefined) {
      rollbackFailedItems = isEditMode && targetIntent !== null
        ? await FirewallRuleMutationService.restoreUpdatedRule(
          context,
          targetIntent,
          targetDeployments,
          nextResult.successDeployments ?? []
        )
        : await FirewallRuleMutationService.rollbackCreatedRule(
          context,
          nextResult.localRuleId,
          nextResult.successDeployments ?? [],
          true
        )
    }
    let restoreFailedItems = await FirewallRuleMutationService.restoreDeletedRule(
      context,
      conflictIntent,
      conflictDeployments
    )
    if (restoreFailedItems.length > 0) {
      LogUtils.error(TAG,
        `replaceConflictRule restore old rule failed: conflictLocalRuleId=${conflictLocalRuleId}, ` +
          `nextLocalRuleId=${nextResult.localRuleId ?? ''}, failedItems=${restoreFailedItems.length}`
      )
    }
    return {
      success: false,
      localRuleId: nextResult.localRuleId,
      successDeployments: nextResult.successDeployments,
      failedItems: [
        ...(nextResult.failedItems ?? []),
        ...rollbackFailedItems,
        ...restoreFailedItems
      ],
      errorCode: nextResult.errorCode,
      errorMessage: restoreFailedItems.length > 0
        ? FirewallRuleMutationErrorStrings.REPLACE_FAILED_AND_RESTORE_OLD_FAILED
        : FirewallRuleMutationErrorStrings.REPLACE_FAILED_AND_RESTORED_OLD
    }
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
    let applyResult = await FirewallRuleDeploymentService.applyRuleIntentDeployments(intent)
    let deployments = applyResult.deployments
    let failedItems = applyResult.failedItems

    if (failedItems.length > 0) {
      let rollbackFailedItems = await FirewallRuleDeploymentService.rollbackSystemDeployments(
        localRuleId,
        deployments,
        FirewallRuleMutationErrorStrings.ROLLBACK_SYSTEM_RULE_FAILED
      )
      let firstFailedItem = failedItems[0]
      return {
        success: false,
        localRuleId: localRuleId,
        failedItems: [...failedItems, ...rollbackFailedItems],
        errorCode: firstFailedItem?.errorCode,
        errorMessage: buildFirewallAddRuleFailedMessage(firstFailedItem?.errorCode)
      }
    }

    let intentSaved = await FirewallLocalRepository.saveRuleIntent(context, intent)
    let deploymentsSaved = await FirewallLocalRepository.replaceRuleDeployments(context, localRuleId, deployments)
    if (!intentSaved || !deploymentsSaved) {
      LogUtils.error(TAG, `createRule local save failed: localRuleId=${localRuleId}`)
      let rollbackFailedItems = await FirewallRuleMutationService.rollbackCreatedRule(context, localRuleId, deployments, intentSaved)
      return {
        success: false,
        localRuleId: localRuleId,
        successDeployments: deployments,
        failedItems: [...failedItems, ...rollbackFailedItems],
        errorMessage: FirewallRuleMutationErrorStrings.LOCAL_SAVE_FAILED
      }
    }

    return {
      success: true,
      localRuleId: localRuleId,
      successDeployments: deployments,
      failedItems: []
    }
  }

  private static async restoreDeletedRule(
    context: common.UIAbilityContext,
    intent: FirewallRuleIntent,
    previousDeployments: FirewallRuleDeployment[]
  ): Promise<FirewallFailedItem[]> {
    let failedItems: FirewallFailedItem[] = []
    let intentSaved = await FirewallLocalRepository.saveRuleIntent(context, intent)
    if (!intentSaved) {
      failedItems.push({ localRuleId: intent.localRuleId, errorMessage: FirewallRuleMutationErrorStrings.RESTORE_OLD_INTENT_FAILED })
    }
    let restoreResult = await FirewallRuleDeploymentService.restoreRemovedDeployments(
      context,
      intent,
      previousDeployments,
      previousDeployments
    )
    failedItems.push(...restoreResult.failedItems)
    return failedItems
  }

  private static async applyUpdateTransaction(
    context: common.UIAbilityContext,
    existingIntent: FirewallRuleIntent,
    oldDeployments: FirewallRuleDeployment[],
    nextIntent: FirewallRuleIntent
  ): Promise<FirewallRuleUpdateTransactionResult> {
    let oldByUser = FirewallRuleMutationService.buildDeploymentByUser(oldDeployments)
    let nextUserSet = new Set<number>(nextIntent.targetUserIds)
    let keptDeployments = oldDeployments.filter((deployment: FirewallRuleDeployment): boolean =>
      nextUserSet.has(deployment.userId)
    )
    let addedUserIds = nextIntent.targetUserIds.filter((userId: number): boolean => !oldByUser.has(userId))
    let removedDeployments = oldDeployments.filter((deployment: FirewallRuleDeployment): boolean =>
      !nextUserSet.has(deployment.userId)
    )

    let nextDeployments: FirewallRuleDeployment[] = []
    let updatedDeployments: FirewallRuleDeployment[] = []
    let addedDeployments: FirewallRuleDeployment[] = []
    let actuallyRemovedDeployments: FirewallRuleDeployment[] = []
    let failedItems: FirewallFailedItem[] = []

    for (let i = 0; i < keptDeployments.length; i++) {
      let deployment = keptDeployments[i]
      let failedItem = await FirewallRuleDeploymentService.updateDeploymentSystemRule(nextIntent, deployment)
      if (failedItem !== null) {
        failedItems.push(failedItem)
        break
      }
      updatedDeployments.push(deployment)
      nextDeployments.push(deployment)
    }

    if (failedItems.length === 0) {
      for (let i = 0; i < addedUserIds.length; i++) {
        let addResult = await FirewallRuleMutationService.addDeploymentForUser(nextIntent, addedUserIds[i])
        if (addResult.failedItem !== undefined) {
          failedItems.push(addResult.failedItem)
          break
        }
        if (addResult.deployment !== undefined) {
          addedDeployments.push(addResult.deployment)
          nextDeployments.push(addResult.deployment)
        }
      }
    }

    if (failedItems.length === 0) {
      for (let i = 0; i < removedDeployments.length; i++) {
        let deployment = removedDeployments[i]
        let removed = await FirewallSystemRepository.removeRule(deployment.userId, deployment.systemRuleId)
        if (!removed) {
          failedItems.push({
            localRuleId: nextIntent.localRuleId,
            userId: deployment.userId,
            systemRuleId: deployment.systemRuleId,
            errorMessage: 'remove system rule failed'
          })
          break
        }
        actuallyRemovedDeployments.push(deployment)
      }
    }

    if (failedItems.length > 0) {
      let rollbackFailedItems = await FirewallRuleMutationService.rollbackUpdateTransaction(
        context,
        existingIntent,
        oldDeployments,
        updatedDeployments,
        addedDeployments,
        actuallyRemovedDeployments
      )
      return {
        deployments: [],
        updatedDeployments: updatedDeployments,
        addedDeployments: addedDeployments,
        removedDeployments: actuallyRemovedDeployments,
        failedItems: [...failedItems, ...rollbackFailedItems]
      }
    }

    return {
      deployments: nextDeployments,
      updatedDeployments: updatedDeployments,
      addedDeployments: addedDeployments,
      removedDeployments: actuallyRemovedDeployments,
      failedItems: []
    }
  }

  private static async rollbackUpdateTransaction(
    context: common.UIAbilityContext,
    existingIntent: FirewallRuleIntent,
    oldDeployments: FirewallRuleDeployment[],
    updatedDeployments: FirewallRuleDeployment[],
    addedDeployments: FirewallRuleDeployment[],
    removedDeployments: FirewallRuleDeployment[]
  ): Promise<FirewallFailedItem[]> {
    let failedItems: FirewallFailedItem[] = []
    for (let i = 0; i < updatedDeployments.length; i++) {
      let failedItem = await FirewallRuleDeploymentService.updateDeploymentSystemRule(existingIntent, updatedDeployments[i])
      if (failedItem !== null) {
        failedItems.push(failedItem)
      }
    }
    let rollbackAddedFailedItems = await FirewallRuleDeploymentService.rollbackSystemDeployments(
      existingIntent.localRuleId,
      addedDeployments,
      FirewallRuleMutationErrorStrings.ROLLBACK_SYSTEM_RULE_FAILED
    )
    failedItems.push(...rollbackAddedFailedItems)
    if (removedDeployments.length > 0) {
      let restoreResult = await FirewallRuleDeploymentService.restoreRemovedDeployments(
        context,
        existingIntent,
        oldDeployments,
        removedDeployments
      )
      failedItems.push(...restoreResult.failedItems)
    }
    return failedItems
  }

  private static async addDeploymentForUser(
    intent: FirewallRuleIntent,
    userId: number
  ): Promise<FirewallRuleSingleDeploymentResult> {
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
        errorMessage: addRuleResult.errorMessage ?? 'add rule failed'
      }
    }
  }

  private static buildDeploymentByUser(deployments: FirewallRuleDeployment[]): Map<number, FirewallRuleDeployment> {
    let result = new Map<number, FirewallRuleDeployment>()
    deployments.forEach((deployment: FirewallRuleDeployment) => {
      result.set(deployment.userId, deployment)
    })
    return result
  }

  private static async restoreUpdatedRule(
    context: common.UIAbilityContext,
    intent: FirewallRuleIntent,
    previousDeployments: FirewallRuleDeployment[],
    nextDeployments: FirewallRuleDeployment[]
  ): Promise<FirewallFailedItem[]> {
    let failedItems = await FirewallRuleDeploymentService.rollbackSystemDeployments(
      intent.localRuleId,
      nextDeployments,
      FirewallRuleMutationErrorStrings.ROLLBACK_UPDATED_SYSTEM_RULE_FAILED
    )
    let intentSaved = await FirewallLocalRepository.saveRuleIntent(context, intent)
    if (!intentSaved) {
      failedItems.push({ localRuleId: intent.localRuleId, errorMessage: FirewallRuleMutationErrorStrings.RESTORE_TARGET_INTENT_FAILED })
    }
    let restoreResult = await FirewallRuleDeploymentService.restoreRemovedDeployments(
      context,
      intent,
      previousDeployments,
      previousDeployments
    )
    failedItems.push(...restoreResult.failedItems)
    return failedItems
  }

  private static async rollbackCreatedRule(
    context: common.UIAbilityContext,
    localRuleId: string,
    deployments: FirewallRuleDeployment[],
    intentSaved: boolean
  ): Promise<FirewallFailedItem[]> {
    let failedItems = await FirewallRuleDeploymentService.rollbackSystemDeployments(
      localRuleId,
      deployments,
      FirewallRuleMutationErrorStrings.ROLLBACK_SYSTEM_RULE_FAILED
    )
    let deploymentsRemoved = await FirewallLocalRepository.removeRuleDeployments(context, localRuleId)
    if (!deploymentsRemoved) {
      failedItems.push({ localRuleId: localRuleId, errorMessage: FirewallRuleMutationErrorStrings.ROLLBACK_LOCAL_DEPLOYMENTS_FAILED })
    }
    if (intentSaved) {
      let intentRemoved = await FirewallLocalRepository.removeRuleIntent(context, localRuleId)
      if (!intentRemoved) {
        failedItems.push({ localRuleId: localRuleId, errorMessage: FirewallRuleMutationErrorStrings.ROLLBACK_LOCAL_INTENT_FAILED })
      }
    }
    return failedItems
  }

  static generateLocalRuleId(): string {
    return `fw_rule_${Date.now()}_${generateRandomSuffix(10)}`
  }
}

interface FirewallRuleUpdateTransactionResult {
  deployments: FirewallRuleDeployment[]
  updatedDeployments: FirewallRuleDeployment[]
  addedDeployments: FirewallRuleDeployment[]
  removedDeployments: FirewallRuleDeployment[]
  failedItems: FirewallFailedItem[]
}

interface FirewallRuleSingleDeploymentResult {
  deployment?: FirewallRuleDeployment
  failedItem?: FirewallFailedItem
}
