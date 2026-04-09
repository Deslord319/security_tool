import { LogUtils } from '../../../utils/LogUtils'
import { common } from '@kit.AbilityKit'

import { AuthService } from '../../identity/auth/AuthService'
import { FirewallRepository } from '../repositories/FirewallRepository'
import { FirewallAuthStateStore } from '../stores'
import {
  AuthMethod,
  FirewallToggleResult,
  FirewallUserApplyMode,
  LogEntry,
  LogEventResult,
  LogEventType,
  UserFirewallModeApplyResult,
  generateLogEntryId
} from '../../../models/DataModels'
import { buildFirewallToggleFailedMessage } from '../../../constants/modules/FirewallStrings'
import { LogRepository } from '../../log-manage/repository/LogRepository'

const TAG = 'FirewallAuthService'

export class FirewallAuthService {
  static async executeToggle(
    context: common.UIAbilityContext,
    currentEnabled: boolean,
    targetEnabled: boolean
  ): Promise<FirewallToggleResult> {
    return FirewallAuthService.executeToggleInternal(
      context,
      currentEnabled,
      targetEnabled,
      async (enabled: boolean): Promise<boolean> => FirewallRepository.setFirewallEnabled(enabled),
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
    if (!applyResult.success) {
      await FirewallAuthService.appendGenericAuditEntry(
        LogEventResult.FAILED,
        `firewall user mode apply ${userId} ${mode} failed`,
        applyResult.errorCode
      )
      return applyResult
    }
    await FirewallAuthService.appendGenericAuditEntry(
      LogEventResult.SUCCESS,
      `firewall user mode apply ${userId} ${mode} success`
    )
    return applyResult
  }

  static async getLockState(
    context: common.UIAbilityContext,
    now: number = Date.now()
  ) {
    return FirewallAuthStateStore.getLockState(context, now)
  }

  static async recordFailure(
    context: common.UIAbilityContext,
    now: number = Date.now()
  ) {
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
      await FirewallAuthService.appendAuditEntry(
        currentEnabled,
        targetEnabled,
        LogEventResult.FAILED,
        `${auditPrefix} failed: policy apply failed`,
      )
      return applyFailedResult
    }

    let successResult: FirewallToggleResult = {
      success: true,
      targetEnabled: targetEnabled
    }
    await FirewallAuthService.appendAuditEntry(
      currentEnabled,
      targetEnabled,
      LogEventResult.SUCCESS,
      `${auditPrefix} success`
    )
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
      if (currentEnabled !== undefined && targetEnabled !== undefined) {
        await FirewallAuthService.appendAuditEntry(
          currentEnabled,
          targetEnabled,
          LogEventResult.BLOCKED,
          `${auditPrefix} blocked: locked ${lockState.remainingSec}s`
        )
      } else {
        await FirewallAuthService.appendGenericAuditEntry(
          LogEventResult.BLOCKED,
          `${auditPrefix} blocked: locked ${lockState.remainingSec}s`
        )
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
      if (currentEnabled !== undefined && targetEnabled !== undefined) {
        await FirewallAuthService.appendAuditEntry(
          currentEnabled,
          targetEnabled,
          LogEventResult.BLOCKED,
          `${auditPrefix} blocked: pin unavailable`,
          authResult.errorCode
        )
      } else {
        await FirewallAuthService.appendGenericAuditEntry(
          LogEventResult.BLOCKED,
          `${auditPrefix} blocked: pin unavailable`,
          authResult.errorCode
        )
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
      if (currentEnabled !== undefined && targetEnabled !== undefined) {
        await FirewallAuthService.appendAuditEntry(
          currentEnabled,
          targetEnabled,
          LogEventResult.BLOCKED,
          failureUpdate.locked ?
            `${auditPrefix} blocked: pin failed and locked ${failureUpdate.remainingSec}s` :
            `${auditPrefix} blocked: pin failed`,
          authResult.errorCode
        )
      } else {
        await FirewallAuthService.appendGenericAuditEntry(
          LogEventResult.BLOCKED,
          failureUpdate.locked ?
            `${auditPrefix} blocked: pin failed and locked ${failureUpdate.remainingSec}s` :
            `${auditPrefix} blocked: pin failed`,
          authResult.errorCode
        )
      }
      return failedResult
    }

    await FirewallAuthStateStore.clearFailures(context)
    return {
      success: true,
      targetEnabled: targetEnabled ?? false
    }
  }

  private static async appendAuditEntry(
    beforeEnabled: boolean,
    afterEnabled: boolean,
    result: LogEventResult,
    detail: string,
    errorCode?: number
  ): Promise<void> {
    let normalizedDetail = detail
    if (errorCode !== undefined) {
      normalizedDetail = `${detail}, errorCode=${errorCode}`
    }
    let entry: LogEntry = {
      id: generateLogEntryId(),
      timestamp: Date.now(),
      eventType: LogEventType.ACCOUNT,
      detail: normalizedDetail,
      processName: 'firewall-toggle-auth',
      result: result,
      rawEventName: beforeEnabled ? 'firewall_state_on' : 'firewall_state_off',
      rawOutcome: afterEnabled ? 'target_on' : 'target_off'
    }
    let saved = await LogRepository.addEntry(entry)
    if (!saved.success) {
      LogUtils.warn(TAG, `appendAuditEntry failed: ${detail}`)
    }
  }

  private static async appendGenericAuditEntry(
    result: LogEventResult,
    detail: string,
    errorCode?: number
  ): Promise<void> {
    let normalizedDetail = detail
    if (errorCode !== undefined) {
      normalizedDetail = `${detail}, errorCode=${errorCode}`
    }
    let entry: LogEntry = {
      id: generateLogEntryId(),
      timestamp: Date.now(),
      eventType: LogEventType.ACCOUNT,
      detail: normalizedDetail,
      processName: 'firewall-user-mode-auth',
      result: result,
      rawEventName: 'firewall_user_mode_apply',
      rawOutcome: result === LogEventResult.SUCCESS ? 'success' : 'blocked_or_failed'
    }
    let saved = await LogRepository.addEntry(entry)
    if (!saved.success) {
      LogUtils.warn(TAG, `appendGenericAuditEntry failed: ${detail}`)
    }
  }
}
