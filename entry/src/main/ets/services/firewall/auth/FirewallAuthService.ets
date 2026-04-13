import { LogUtils } from '../../../utils/LogUtils'
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
  LogEntry,
  LogEventResult,
  LogEventType,
  UserFirewallModeApplyResult,
  generateLogEntryId
} from '../../../models/DataModels'
import { buildFirewallToggleFailedMessage } from '../../../constants/modules/FirewallStrings'
import { LogStorageMaintenanceService } from '../../log-manage/maintenance/LogStorageMaintenanceService'

const TAG = 'FirewallAuthService'

interface FirewallAuditContext {
  beforeEnabled: boolean
  afterEnabled: boolean
}

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
      await FirewallAuthService.appendAuditEntry(
        LogEventResult.FAILED,
        `firewall user mode apply ${userId} ${mode} failed`,
        applyResult.errorCode
      )
      return applyResult
    }
    await FirewallAuthService.appendAuditEntry(
      LogEventResult.SUCCESS,
      `firewall user mode apply ${userId} ${mode} success`
    )
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
      await FirewallAuthService.appendAuditEntry(
        LogEventResult.FAILED,
        `${auditPrefix} failed: policy apply failed`,
        undefined,
        { beforeEnabled: currentEnabled, afterEnabled: targetEnabled }
      )
      return applyFailedResult
    }

    let successResult: FirewallToggleResult = {
      success: true,
      targetEnabled: targetEnabled
    }
    await FirewallAuthService.appendAuditEntry(
      LogEventResult.SUCCESS,
      `${auditPrefix} success`,
      undefined,
      { beforeEnabled: currentEnabled, afterEnabled: targetEnabled }
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
          LogEventResult.BLOCKED,
          `${auditPrefix} blocked: locked ${lockState.remainingSec}s`,
          undefined,
          { beforeEnabled: currentEnabled, afterEnabled: targetEnabled }
        )
      } else {
        await FirewallAuthService.appendAuditEntry(
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
          LogEventResult.BLOCKED,
          `${auditPrefix} blocked: pin unavailable`,
          authResult.errorCode,
          { beforeEnabled: currentEnabled, afterEnabled: targetEnabled }
        )
      } else {
        await FirewallAuthService.appendAuditEntry(
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
          LogEventResult.BLOCKED,
          failureUpdate.locked ?
            `${auditPrefix} blocked: pin failed and locked ${failureUpdate.remainingSec}s` :
            `${auditPrefix} blocked: pin failed`,
          authResult.errorCode,
          { beforeEnabled: currentEnabled, afterEnabled: targetEnabled }
        )
      } else {
        await FirewallAuthService.appendAuditEntry(
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
    result: LogEventResult,
    detail: string,
    errorCode?: number,
    context?: FirewallAuditContext
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
      processName: context ? 'firewall-toggle-auth' : 'firewall-user-mode-auth',
      result: result,
      rawEventName: context ? (context.beforeEnabled ? 'firewall_state_on' : 'firewall_state_off') : 'firewall_user_mode_apply',
      rawOutcome: context ? (context.afterEnabled ? 'target_on' : 'target_off') : (result === LogEventResult.SUCCESS ? 'success' : 'blocked_or_failed')
    }
    let saved = await LogStorageMaintenanceService.appendEntries([entry])
    if (!saved.success) {
      LogUtils.warn(TAG, `appendAuditEntry failed: ${detail}`)
    }
  }
}
