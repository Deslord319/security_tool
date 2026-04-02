import { LogUtils } from '../utils/LogUtils'
import { common } from '@kit.AbilityKit'

import { AuthService } from './AuthService'
import { FirewallService } from './FirewallService'
import { FirewallAuthStateRepository } from './FirewallAuthStateRepository'
import { UserFirewallPolicyService } from './UserFirewallPolicyService'
import {
  AuthMethod,
  FirewallUserApplyMode,
  UserFirewallModeApplyResult,
  FirewallToggleResult,
  LogEntry,
  LogEventResult,
  LogEventType,
  generateLogEntryId
} from '../models/DataModels'
import { UserFirewallModeService } from './UserFirewallModeService'
import { FirewallStrings } from '../constants/modules/FirewallStrings'
import { LogRepository } from './log-manage/repository/LogRepository'

const TAG = 'FirewallToggleAuthService'

export class FirewallToggleAuthService {
  static async executeToggle(
    context: common.UIAbilityContext,
    currentEnabled: boolean,
    targetEnabled: boolean
  ): Promise<FirewallToggleResult> {
    return FirewallToggleAuthService.executeToggleInternal(
      context,
      currentEnabled,
      targetEnabled,
      async (enabled: boolean): Promise<boolean> => FirewallService.setFirewallEnabled(enabled),
      'firewall toggle'
    )
  }

  static async executeUserModeApply(
    context: common.UIAbilityContext,
    userId: number,
    mode: FirewallUserApplyMode,
    applyAction: () => Promise<UserFirewallModeApplyResult>
  ): Promise<UserFirewallModeApplyResult> {
    let authResult = await FirewallToggleAuthService.authenticateProtectedAction(
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
      let errorCode = applyResult.errorCode ?? UserFirewallModeService.getLastErrorCode()
      await FirewallToggleAuthService.appendGenericAuditEntry(
        LogEventResult.FAILED,
        `firewall user mode apply ${userId} ${mode} failed`,
        errorCode
      )
      return {
        success: false,
        userId: applyResult.userId,
        mode: applyResult.mode,
        appliedRuleCount: applyResult.appliedRuleCount,
        errorCode: errorCode,
        errorMessage: applyResult.errorMessage ?? UserFirewallModeService.getLastErrorMessage()
      }
    }
    await FirewallToggleAuthService.appendGenericAuditEntry(
      LogEventResult.SUCCESS,
      `firewall user mode apply ${userId} ${mode} success`
    )
    return applyResult
  }

  private static async executeToggleInternal(
    context: common.UIAbilityContext,
    currentEnabled: boolean,
    targetEnabled: boolean,
    applyPolicy: (enabled: boolean) => Promise<boolean>,
    auditPrefix: string
  ): Promise<FirewallToggleResult> {
    let authResult = await FirewallToggleAuthService.authenticateProtectedAction(context, auditPrefix, currentEnabled, targetEnabled)
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
      let errorCode = FirewallService.getLastErrorCode()
      let errorMessage = FirewallStrings.buildToggleFailedMessage('policy_apply_failed', undefined)
      if (errorCode === undefined) {
        errorCode = UserFirewallPolicyService.getLastErrorCode()
      }
      if (UserFirewallPolicyService.getLastErrorMessage().length > 0) {
        errorMessage = UserFirewallPolicyService.getLastErrorMessage()
      }
      let applyFailedResult: FirewallToggleResult = {
        success: false,
        targetEnabled: targetEnabled,
        reason: 'policy_apply_failed',
        errorCode: errorCode,
        errorMessage: errorMessage
      }
      await FirewallToggleAuthService.appendAuditEntry(
        currentEnabled,
        targetEnabled,
        LogEventResult.FAILED,
        `${auditPrefix} failed: policy apply failed`,
        errorCode
      )
      return applyFailedResult
    }

    let successResult: FirewallToggleResult = {
      success: true,
      targetEnabled: targetEnabled
    }
    await FirewallToggleAuthService.appendAuditEntry(
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
    let lockState = await FirewallAuthStateRepository.getLockState(context)
    if (lockState.locked) {
      let blockedResult: FirewallToggleResult = {
        success: false,
        targetEnabled: targetEnabled ?? false,
        reason: 'lockout',
        lockRemainingSec: lockState.remainingSec,
        errorMessage: FirewallStrings.buildToggleFailedMessage('lockout', lockState.remainingSec)
      }
      if (currentEnabled !== undefined && targetEnabled !== undefined) {
        await FirewallToggleAuthService.appendAuditEntry(
          currentEnabled,
          targetEnabled,
          LogEventResult.BLOCKED,
          `${auditPrefix} blocked: locked ${lockState.remainingSec}s`
        )
      } else {
        await FirewallToggleAuthService.appendGenericAuditEntry(
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
        await FirewallToggleAuthService.appendAuditEntry(
          currentEnabled,
          targetEnabled,
          LogEventResult.BLOCKED,
          `${auditPrefix} blocked: pin unavailable`,
          authResult.errorCode
        )
      } else {
        await FirewallToggleAuthService.appendGenericAuditEntry(
          LogEventResult.BLOCKED,
          `${auditPrefix} blocked: pin unavailable`,
          authResult.errorCode
        )
      }
      return unavailableResult
    }

    if (!authResult.success) {
      let failureUpdate = await FirewallAuthStateRepository.recordFailure(context)
      let failedResult: FirewallToggleResult = {
        success: false,
        targetEnabled: targetEnabled ?? false,
        reason: 'pin_failed',
        errorCode: authResult.errorCode,
        errorMessage: authResult.message ?? FirewallStrings.buildToggleFailedMessage('pin_failed', undefined)
      }
      if (failureUpdate.locked) {
        failedResult.lockRemainingSec = failureUpdate.remainingSec
      }
      if (currentEnabled !== undefined && targetEnabled !== undefined) {
        await FirewallToggleAuthService.appendAuditEntry(
          currentEnabled,
          targetEnabled,
          LogEventResult.BLOCKED,
          failureUpdate.locked ?
            `${auditPrefix} blocked: pin failed and locked ${failureUpdate.remainingSec}s` :
            `${auditPrefix} blocked: pin failed`,
          authResult.errorCode
        )
      } else {
        await FirewallToggleAuthService.appendGenericAuditEntry(
          LogEventResult.BLOCKED,
          failureUpdate.locked ?
            `${auditPrefix} blocked: pin failed and locked ${failureUpdate.remainingSec}s` :
            `${auditPrefix} blocked: pin failed`,
          authResult.errorCode
        )
      }
      return failedResult
    }

    await FirewallAuthStateRepository.clearFailures(context)
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
