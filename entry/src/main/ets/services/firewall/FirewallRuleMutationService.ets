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
    let nextApplyResult = await FirewallRuleDeploymentService.applyRuleIntentDeployments(nextIntent)
    if (nextApplyResult.deployments.length === 0) {
      let firstFailedItem = nextApplyResult.failedItems[0]
      return {
        success: false,
        localRuleId: localRuleId,
        failedItems: nextApplyResult.failedItems,
        errorCode: firstFailedItem?.errorCode,
        errorMessage: buildFirewallAddRuleFailedMessage(firstFailedItem?.errorCode)
      }
    }

    let oldDeployments = await FirewallLocalRepository.listRuleDeployments(context, localRuleId)
    let removeResult = await FirewallRuleDeploymentService.removeDeploymentSystemRules(localRuleId, oldDeployments)
    if (removeResult.failedItems.length > 0) {
      let rollbackNewFailedItems = await FirewallRuleDeploymentService.rollbackSystemDeployments(
        localRuleId,
        nextApplyResult.deployments,
        FirewallRuleMutationErrorStrings.ROLLBACK_NEW_SYSTEM_RULE_FAILED
      )
      let restoreResult = await FirewallRuleDeploymentService.restoreRemovedDeployments(context, existingIntent, oldDeployments, removeResult.removedDeployments)
      return {
        success: false,
        localRuleId: localRuleId,
        successDeployments: nextApplyResult.deployments,
        failedItems: [
          ...nextApplyResult.failedItems,
          ...removeResult.failedItems,
          ...rollbackNewFailedItems,
          ...restoreResult.failedItems
        ],
        errorMessage: FirewallRuleMutationErrorStrings.UPDATE_FAILED_WHILE_REMOVING_OLD_DEPLOYMENTS
      }
    }

    let intentSaved = await FirewallLocalRepository.saveRuleIntent(context, nextIntent)
    let deploymentsSaved = await FirewallLocalRepository.replaceRuleDeployments(context, localRuleId, nextApplyResult.deployments)
    if (!intentSaved || !deploymentsSaved) {
      LogUtils.error(TAG, `updateRule local save failed: localRuleId=${localRuleId}`)
      let rollbackNewFailedItems = await FirewallRuleDeploymentService.rollbackSystemDeployments(
        localRuleId,
        nextApplyResult.deployments,
        FirewallRuleMutationErrorStrings.ROLLBACK_NEW_SYSTEM_RULE_FAILED
      )
      let restoreResult = await FirewallRuleDeploymentService.restoreRemovedDeployments(context, existingIntent, oldDeployments, oldDeployments)
      if (intentSaved) {
        let restoredIntent = await FirewallLocalRepository.saveRuleIntent(context, existingIntent)
        if (!restoredIntent) {
          restoreResult.failedItems.push({ localRuleId: localRuleId, errorMessage: FirewallRuleMutationErrorStrings.RESTORE_OLD_INTENT_FAILED })
        }
      }
      return {
        success: false,
        localRuleId: localRuleId,
        successDeployments: nextApplyResult.deployments,
        failedItems: [
          ...nextApplyResult.failedItems,
          ...rollbackNewFailedItems,
          ...restoreResult.failedItems
        ],
        errorMessage: FirewallRuleMutationErrorStrings.LOCAL_SAVE_FAILED
      }
    }

    return {
      success: nextApplyResult.failedItems.length === 0,
      localRuleId: localRuleId,
      successDeployments: nextApplyResult.deployments,
      failedItems: nextApplyResult.failedItems,
      errorMessage: nextApplyResult.failedItems.length === 0 ? undefined : FirewallRuleMutationErrorStrings.RULE_UPDATED_WITH_FAILED_ITEMS
    }
  }

  static async deleteRule(
    context: common.UIAbilityContext,
    localRuleId: string
  ): Promise<FirewallRuleMutationResult> {
    let failedItems = await FirewallRuleDeploymentService.deleteDeploymentsOnly(context, localRuleId)
    if (failedItems.length > 0) {
      return {
        success: false,
        localRuleId: localRuleId,
        failedItems: failedItems,
        errorMessage: FirewallRuleMutationErrorStrings.DELETE_RULE_COMPLETED_WITH_FAILED_ITEMS
      }
    }

    let intentRemoved = await FirewallLocalRepository.removeRuleIntent(context, localRuleId)
    if (!intentRemoved) {
      failedItems.push({ localRuleId: localRuleId, errorMessage: FirewallRuleMutationErrorStrings.REMOVE_RULE_INTENT_FAILED })
    }
    return {
      success: failedItems.length === 0,
      localRuleId: localRuleId,
      failedItems: failedItems,
      errorMessage: failedItems.length === 0 ? undefined : FirewallRuleMutationErrorStrings.DELETE_RULE_COMPLETED_WITH_FAILED_ITEMS
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
      success: failedItems.length === 0,
      localRuleId: localRuleId,
      successDeployments: deployments,
      failedItems: failedItems,
      errorMessage: failedItems.length === 0 ? undefined : FirewallRuleMutationErrorStrings.RULE_CREATED_WITH_FAILED_ITEMS
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
