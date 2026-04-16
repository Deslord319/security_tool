import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { AuthMethod } from '../../main/ets/models/DataModels'
import { FirewallAuthService } from '../../main/ets/services/firewall/auth/FirewallAuthService'
import { FirewallAuthStateStore } from '../../main/ets/services/firewall/stores/FirewallAuthStateStore'
import { AuthService } from '../../main/ets/services/identity/auth/AuthService'
import { LogStorageMaintenanceService } from '../../main/ets/services/log-manage/maintenance/LogStorageMaintenanceService'

export default function firewallAuthServiceTest() {
  describe('FirewallAuthService', () => {
    let mockKit: MockKit
    let context: common.UIAbilityContext

    beforeEach(() => {
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should block toggle when lockout is active', 0, async () => {
      let getLockStateMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.getLockState)
      let appendEntriesMock = mockKit.mockFunc(LogStorageMaintenanceService, LogStorageMaintenanceService.appendEntries)
      when(getLockStateMock)(context).afterReturn({
        locked: true,
        remainingSec: 48,
        state: { failedCount: 0, lockUntil: Date.now() + 48000 }
      })
      when(appendEntriesMock)(ArgumentMatchers.anyObj).afterReturn({ success: true, code: 'ok' })

      let result = await FirewallAuthService.executeToggle(context, false, true)

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('lockout')
      expect(result.lockRemainingSec).assertEqual(48)
    })

    it('should block toggle when pin is unavailable', 0, async () => {
      let getLockStateMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.getLockState)
      let authenticateMock = mockKit.mockFunc(AuthService, AuthService.authenticate)
      let appendEntriesMock = mockKit.mockFunc(LogStorageMaintenanceService, LogStorageMaintenanceService.appendEntries)
      when(getLockStateMock)(context).afterReturn({
        locked: false,
        remainingSec: 0,
        state: { failedCount: 0, lockUntil: 0 }
      })
      when(authenticateMock)(AuthMethod.PIN).afterReturn({
        success: false,
        reason: 'unavailable',
        errorCode: 201,
        message: 'permission denied'
      })
      when(appendEntriesMock)(ArgumentMatchers.anyObj).afterReturn({ success: true, code: 'ok' })

      let result = await FirewallAuthService.executeToggle(context, false, true)

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('pin_unavailable')
      expect(result.errorCode).assertEqual(201)
    })

    it('should use injected toggle action and return apply failure on false', 0, async () => {
      let getLockStateMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.getLockState)
      let authenticateMock = mockKit.mockFunc(AuthService, AuthService.authenticate)
      let clearFailuresMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.clearFailures)
      let appendEntriesMock = mockKit.mockFunc(LogStorageMaintenanceService, LogStorageMaintenanceService.appendEntries)
      let observedEnabled = false
      when(getLockStateMock)(context).afterReturn({
        locked: false,
        remainingSec: 0,
        state: { failedCount: 0, lockUntil: 0 }
      })
      when(authenticateMock)(AuthMethod.PIN).afterReturn({ success: true })
      when(clearFailuresMock)(context).afterReturn(undefined)
      when(appendEntriesMock)(ArgumentMatchers.anyObj).afterReturn({ success: true, code: 'ok' })

      let result = await FirewallAuthService.executeToggle(
        context,
        true,
        false,
        async (enabled: boolean): Promise<boolean> => {
          observedEnabled = enabled
          return false
        }
      )

      expect(observedEnabled).assertFalse()
      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('policy_apply_failed')
    })

    it('should return success after auth and injected toggle action succeed', 0, async () => {
      let getLockStateMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.getLockState)
      let authenticateMock = mockKit.mockFunc(AuthService, AuthService.authenticate)
      let clearFailuresMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.clearFailures)
      let appendEntriesMock = mockKit.mockFunc(LogStorageMaintenanceService, LogStorageMaintenanceService.appendEntries)
      let observedEnabled = false
      when(getLockStateMock)(context).afterReturn({
        locked: false,
        remainingSec: 0,
        state: { failedCount: 0, lockUntil: 0 }
      })
      when(authenticateMock)(AuthMethod.PIN).afterReturn({ success: true })
      when(clearFailuresMock)(context).afterReturn(undefined)
      when(appendEntriesMock)(ArgumentMatchers.anyObj).afterReturn({ success: true, code: 'ok' })

      let result = await FirewallAuthService.executeToggle(
        context,
        false,
        true,
        async (enabled: boolean): Promise<boolean> => {
          observedEnabled = enabled
          return true
        }
      )

      expect(observedEnabled).assertTrue()
      expect(result.success).assertTrue()
      expect(result.targetEnabled).assertTrue()
    })

    it('should execute user mode action after pin auth succeeds', 0, async () => {
      let getLockStateMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.getLockState)
      let authenticateMock = mockKit.mockFunc(AuthService, AuthService.authenticate)
      let clearFailuresMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.clearFailures)
      let appendEntriesMock = mockKit.mockFunc(LogStorageMaintenanceService, LogStorageMaintenanceService.appendEntries)
      when(getLockStateMock)(context).afterReturn({
        locked: false,
        remainingSec: 0,
        state: { failedCount: 0, lockUntil: 0 }
      })
      when(authenticateMock)(AuthMethod.PIN).afterReturn({ success: true })
      when(clearFailuresMock)(context).afterReturn(undefined)
      when(appendEntriesMock)(ArgumentMatchers.anyObj).afterReturn({ success: true, code: 'ok' })

      let result = await FirewallAuthService.executeUserModeApply(
        context,
        100,
        'allowlist',
        async (): Promise<{ success: boolean; userId: number; mode: 'allowlist'; appliedRuleCount: number }> => {
          return {
            success: true,
            userId: 100,
            mode: 'allowlist',
            appliedRuleCount: 0
          }
        }
      )

      expect(result.success).assertTrue()
      expect(result.userId).assertEqual(100)
      expect(result.mode).assertEqual('allowlist')
    })

    it('should record pin failure and return lock time when threshold reached', 0, async () => {
      let getLockStateMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.getLockState)
      let authenticateMock = mockKit.mockFunc(AuthService, AuthService.authenticate)
      let recordFailureMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.recordFailure)
      let appendEntriesMock = mockKit.mockFunc(LogStorageMaintenanceService, LogStorageMaintenanceService.appendEntries)
      when(getLockStateMock)(context).afterReturn({
        locked: false,
        remainingSec: 0,
        state: { failedCount: 2, lockUntil: 0 }
      })
      when(authenticateMock)(AuthMethod.PIN).afterReturn({
        success: false,
        reason: 'failed',
        errorCode: 12500001,
        message: 'pin failed'
      })
      when(recordFailureMock)(context).afterReturn({
        failedCount: 0,
        locked: true,
        remainingSec: 60
      })
      when(appendEntriesMock)(ArgumentMatchers.anyObj).afterReturn({ success: true, code: 'ok' })

      let result = await FirewallAuthService.executeToggle(context, true, false)

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('pin_failed')
      expect(result.lockRemainingSec).assertEqual(60)
    })

    it('should not execute user mode action when pin fails', 0, async () => {
      let getLockStateMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.getLockState)
      let authenticateMock = mockKit.mockFunc(AuthService, AuthService.authenticate)
      let recordFailureMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.recordFailure)
      let appendEntriesMock = mockKit.mockFunc(LogStorageMaintenanceService, LogStorageMaintenanceService.appendEntries)
      let applyInvoked = false
      when(getLockStateMock)(context).afterReturn({
        locked: false,
        remainingSec: 0,
        state: { failedCount: 0, lockUntil: 0 }
      })
      when(authenticateMock)(AuthMethod.PIN).afterReturn({
        success: false,
        reason: 'failed',
        errorCode: 12500001,
        message: 'pin failed'
      })
      when(recordFailureMock)(context).afterReturn({
        failedCount: 1,
        locked: false,
        remainingSec: 0
      })
      when(appendEntriesMock)(ArgumentMatchers.anyObj).afterReturn({ success: true, code: 'ok' })

      let result = await FirewallAuthService.executeUserModeApply(
        context,
        101,
        'denylist',
        async (): Promise<{ success: boolean; userId: number; mode: 'denylist'; appliedRuleCount: number }> => {
          applyInvoked = true
          return {
            success: true,
            userId: 101,
            mode: 'denylist',
            appliedRuleCount: 0
          }
        }
      )

      expect(result.success).assertFalse()
      expect(result.userId).assertEqual(101)
      expect(result.mode).assertEqual('denylist')
      expect(applyInvoked).assertFalse()
    })

  })
}
