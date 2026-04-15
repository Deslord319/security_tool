import { common } from '@kit.AbilityKit'

import { AuthService } from '../../identity/auth/AuthService'
import { FirewallRepository } from '../repositories/FirewallRepository'
import {
  FirewallAuthFailureUpdate,
  FirewallAuthLockState,
  FirewallAuthStateStore
} from '../stores/FirewallAuthStateStore'
import {
  AuthMethod,
  FirewallToggleResult,
  FirewallUserApplyMode,
  UserFirewallModeApplyResult
} from '../../../models/DataModels'
import { buildFirewallToggleFailedMessage } from '../../../constants/modules/FirewallStrings'

export class FirewallAuthService {
  static async executeToggle(
    context: common.UIAbilityContext,
    currentEnabled: boolean,
    targetEnabled: boolean,
    applyPolicy?: (enabled: boolean) => Promise<boolean>
  ): Promise<FirewallToggleResult> {
    return FirewallAuthService.executeToggleInternal(
      context,
      currentEnabled,
      targetEnabled,
      applyPolicy ?? (async (enabled: boolean): Promise<boolean> => FirewallRepository.setFirewallEnabled(enabled)),
      'firewall toggle'
    )
  }

  static async executeUserModeApply(
    context: common.UIAbilityContext,
    userId: number,
    mode: FirewallUserApplyMode,
    applyAction: () => Promise<UserFirewallModeApplyResult>
  ): Promise<UserFirewallModeApplyResult> {
    let authResult = await FirewallAuthService.authenticateProtectedAction(
      context,
      `firewall user mode apply ${userId} ${mode}`
    )
    if (!authResult.success) {
      return {
        success: false,
        userId: userId,
        mode: mode,
        appliedRuleCount: 0,
        errorCode: authResult.errorCode,
        errorMessage: authResult.errorMessage
      }
    }
    let applyResult = await applyAction()
    return applyResult
  }

  static async getLockState(
    context: common.UIAbilityContext,
    now: number = Date.now()
  ): Promise<FirewallAuthLockState> {
    return FirewallAuthStateStore.getLockState(context, now)
  }

  static async recordFailure(
    context: common.UIAbilityContext,
    now: number = Date.now()
  ): Promise<FirewallAuthFailureUpdate> {
    return FirewallAuthStateStore.recordFailure(context, now)
  }

  static async clearFailures(context: common.UIAbilityContext): Promise<void> {
    await FirewallAuthStateStore.clearFailures(context)
  }

  private static async executeToggleInternal(
    context: common.UIAbilityContext,
    currentEnabled: boolean,
    targetEnabled: boolean,
    applyPolicy: (enabled: boolean) => Promise<boolean>,
    auditPrefix: string
  ): Promise<FirewallToggleResult> {
    let authResult = await FirewallAuthService.authenticateProtectedAction(context, auditPrefix, currentEnabled, targetEnabled)
    if (!authResult.success) {
      return {
        success: false,
        targetEnabled: targetEnabled,
        reason: authResult.reason,
        lockRemainingSec: authResult.lockRemainingSec,
        errorCode: authResult.errorCode,
        errorMessage: authResult.errorMessage
      }
    }

    let applySuccess = await applyPolicy(targetEnabled)
    if (!applySuccess) {
      let errorMessage = buildFirewallToggleFailedMessage('policy_apply_failed', undefined)
      let applyFailedResult: FirewallToggleResult = {
        success: false,
        targetEnabled: targetEnabled,
        reason: 'policy_apply_failed',
        errorCode: undefined,
        errorMessage: errorMessage
      }
      return applyFailedResult
    }

    let successResult: FirewallToggleResult = {
      success: true,
      targetEnabled: targetEnabled
    }
    return successResult
  }

  private static async authenticateProtectedAction(
    context: common.UIAbilityContext,
    auditPrefix: string,
    currentEnabled?: boolean,
    targetEnabled?: boolean
  ): Promise<FirewallToggleResult> {
    let lockState = await FirewallAuthStateStore.getLockState(context)
    if (lockState.locked) {
      let blockedResult: FirewallToggleResult = {
        success: false,
        targetEnabled: targetEnabled ?? false,
        reason: 'lockout',
        lockRemainingSec: lockState.remainingSec,
        errorMessage: buildFirewallToggleFailedMessage('lockout', lockState.remainingSec)
      }
      return blockedResult
    }

    let authResult = await AuthService.authenticate(AuthMethod.PIN)
    if (!authResult.success && authResult.reason === 'unavailable') {
      let unavailableResult: FirewallToggleResult = {
        success: false,
        targetEnabled: targetEnabled ?? false,
        reason: 'pin_unavailable',
        errorCode: authResult.errorCode,
        errorMessage: authResult.message
      }
      return unavailableResult
    }

    if (!authResult.success) {
      let failureUpdate = await FirewallAuthStateStore.recordFailure(context)
      let failedResult: FirewallToggleResult = {
        success: false,
        targetEnabled: targetEnabled ?? false,
        reason: 'pin_failed',
        errorCode: authResult.errorCode,
        errorMessage: authResult.message ?? buildFirewallToggleFailedMessage('pin_failed', undefined)
      }
      if (failureUpdate.locked) {
        failedResult.lockRemainingSec = failureUpdate.remainingSec
      }
      return failedResult
    }

    await FirewallAuthStateStore.clearFailures(context)
    return {
      success: true,
      targetEnabled: targetEnabled ?? false
    }
  }
}
