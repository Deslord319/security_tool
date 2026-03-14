import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { AuthService } from './AuthService'
import { FirewallService } from './FirewallService'
import { FirewallAuthStateRepository } from './FirewallAuthStateRepository'
import { LogStorageService } from './LogStorageService'
import {
  AuthMethod,
  FirewallToggleResult,
  LogEntry,
  LogEventResult,
  LogEventType,
  generateLogEntryId
} from '../models/DataModels'

const TAG = 'FirewallToggleAuthService'
const DOMAIN = 0x000a

export class FirewallToggleAuthService {
  static async executeToggle(
    context: common.UIAbilityContext,
    currentEnabled: boolean,
    targetEnabled: boolean
  ): Promise<FirewallToggleResult> {
    let actionLabel = targetEnabled ? 'enable' : 'disable'
    let lockState = await FirewallAuthStateRepository.getLockState(context)
    if (lockState.locked) {
      let blockedResult: FirewallToggleResult = {
        success: false,
        targetEnabled: targetEnabled,
        reason: 'lockout',
        lockRemainingSec: lockState.remainingSec,
        errorMessage: `PIN \u8ba4\u8bc1\u5931\u8d25\u6b21\u6570\u8fc7\u591a\uff0c\u8bf7\u5728 ${lockState.remainingSec ?? 60} \u79d2\u540e\u91cd\u8bd5`
      }
      await FirewallToggleAuthService.appendAuditEntry(
        currentEnabled,
        targetEnabled,
        LogEventResult.BLOCKED,
        `firewall toggle ${actionLabel} blocked: locked ${lockState.remainingSec}s`
      )
      return blockedResult
    }

    let authResult = await AuthService.authenticate(AuthMethod.PIN)
    if (!authResult.success && authResult.reason === 'unavailable') {
      let unavailableResult: FirewallToggleResult = {
        success: false,
        targetEnabled: targetEnabled,
        reason: 'pin_unavailable',
        errorCode: authResult.errorCode,
        errorMessage: authResult.message
      }
      await FirewallToggleAuthService.appendAuditEntry(
        currentEnabled,
        targetEnabled,
        LogEventResult.BLOCKED,
        `firewall toggle ${actionLabel} blocked: pin unavailable`,
        authResult.errorCode
      )
      return unavailableResult
    }

    if (!authResult.success) {
      let failureUpdate = await FirewallAuthStateRepository.recordFailure(context)
      let failedResult: FirewallToggleResult = {
        success: false,
        targetEnabled: targetEnabled,
        reason: 'pin_failed',
        errorCode: authResult.errorCode,
        errorMessage: authResult.message ?? 'PIN \u9a8c\u8bc1\u5931\u8d25\uff0c\u5df2\u53d6\u6d88\u672c\u6b21\u53d8\u66f4'
      }
      if (failureUpdate.locked) {
        failedResult.lockRemainingSec = failureUpdate.remainingSec
      }
      await FirewallToggleAuthService.appendAuditEntry(
        currentEnabled,
        targetEnabled,
        LogEventResult.BLOCKED,
        failureUpdate.locked ?
          `firewall toggle ${actionLabel} blocked: pin failed and locked ${failureUpdate.remainingSec}s` :
          `firewall toggle ${actionLabel} blocked: pin failed`,
        authResult.errorCode
      )
      return failedResult
    }

    await FirewallAuthStateRepository.clearFailures(context)

    let applySuccess = await FirewallService.setFirewallEnabled(targetEnabled)
    if (!applySuccess) {
      let errorCode = FirewallService.getLastErrorCode()
      let applyFailedResult: FirewallToggleResult = {
        success: false,
        targetEnabled: targetEnabled,
        reason: 'policy_apply_failed',
        errorCode: errorCode,
        errorMessage: '\u9632\u706b\u5899\u72b6\u6001\u66f4\u65b0\u5931\u8d25'
      }
      await FirewallToggleAuthService.appendAuditEntry(
        currentEnabled,
        targetEnabled,
        LogEventResult.FAILED,
        `firewall toggle ${actionLabel} failed: policy apply failed`,
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
      `firewall toggle ${actionLabel} success`
    )
    return successResult
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
      eventType: LogEventType.EDM,
      detail: normalizedDetail,
      processName: 'firewall-toggle-auth',
      result: result,
      rawEventName: beforeEnabled ? 'firewall_state_on' : 'firewall_state_off',
      rawOutcome: afterEnabled ? 'target_on' : 'target_off'
    }
    let saved = await LogStorageService.addEntry(entry)
    if (!saved) {
      hilog.warn(DOMAIN, TAG, `appendAuditEntry failed: ${detail}`)
    }
  }
}
