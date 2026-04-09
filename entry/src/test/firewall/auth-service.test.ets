import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { AuthMethod } from '../../main/ets/models/DataModels'
import { AuthService } from '../../main/ets/services/identity/auth/AuthService'
import { FirewallAuthService } from '../../main/ets/services/firewall/auth/FirewallAuthService'
import { FirewallRepository } from '../../main/ets/services/firewall/repositories/FirewallRepository'
import { FirewallAuthStateStore } from '../../main/ets/services/firewall/stores/FirewallAuthStateStore'
import { LogRepository } from '../../main/ets/services/log-manage/repository/LogRepository'

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
      let addEntryMock = mockKit.mockFunc(LogRepository, LogRepository.addEntry)
      when(getLockStateMock)(context).afterReturn({
        locked: true,
        remainingSec: 48,
        state: { failedCount: 0, lockUntil: Date.now() + 48000 }
      })
      when(addEntryMock)(ArgumentMatchers.any).afterReturn({ success: true, code: 'ok' })

      let result = await FirewallAuthService.executeToggle(context, false, true)

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('lockout')
      expect(result.lockRemainingSec).assertEqual(48)
    })

    it('should block toggle when pin is unavailable', 0, async () => {
      let getLockStateMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.getLockState)
      let authenticateMock = mockKit.mockFunc(AuthService, AuthService.authenticate)
      let addEntryMock = mockKit.mockFunc(LogRepository, LogRepository.addEntry)
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
      when(addEntryMock)(ArgumentMatchers.any).afterReturn({ success: true, code: 'ok' })

      let result = await FirewallAuthService.executeToggle(context, false, true)

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('pin_unavailable')
      expect(result.errorCode).assertEqual(201)
    })

    it('should record pin failure and return lock time when threshold reached', 0, async () => {
      let getLockStateMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.getLockState)
      let authenticateMock = mockKit.mockFunc(AuthService, AuthService.authenticate)
      let recordFailureMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.recordFailure)
      let addEntryMock = mockKit.mockFunc(LogRepository, LogRepository.addEntry)
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
      when(addEntryMock)(ArgumentMatchers.any).afterReturn({ success: true, code: 'ok' })

      let result = await FirewallAuthService.executeToggle(context, true, false)

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('pin_failed')
      expect(result.lockRemainingSec).assertEqual(60)
    })

    it('should return policy apply failure when repository toggle fails', 0, async () => {
      let getLockStateMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.getLockState)
      let authenticateMock = mockKit.mockFunc(AuthService, AuthService.authenticate)
      let clearFailuresMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.clearFailures)
      let setEnabledMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.setFirewallEnabled)
      let addEntryMock = mockKit.mockFunc(LogRepository, LogRepository.addEntry)
      when(getLockStateMock)(context).afterReturn({
        locked: false,
        remainingSec: 0,
        state: { failedCount: 0, lockUntil: 0 }
      })
      when(authenticateMock)(AuthMethod.PIN).afterReturn({ success: true })
      when(clearFailuresMock)(context).afterReturn(undefined)
      when(setEnabledMock)(false).afterReturn(false)
      when(addEntryMock)(ArgumentMatchers.any).afterReturn({ success: true, code: 'ok' })

      let result = await FirewallAuthService.executeToggle(context, true, false)

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('policy_apply_failed')
    })

    it('should return success after auth and policy update succeed', 0, async () => {
      let getLockStateMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.getLockState)
      let authenticateMock = mockKit.mockFunc(AuthService, AuthService.authenticate)
      let clearFailuresMock = mockKit.mockFunc(FirewallAuthStateStore, FirewallAuthStateStore.clearFailures)
      let setEnabledMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.setFirewallEnabled)
      let addEntryMock = mockKit.mockFunc(LogRepository, LogRepository.addEntry)
      when(getLockStateMock)(context).afterReturn({
        locked: false,
        remainingSec: 0,
        state: { failedCount: 0, lockUntil: 0 }
      })
      when(authenticateMock)(AuthMethod.PIN).afterReturn({ success: true })
      when(clearFailuresMock)(context).afterReturn(undefined)
      when(setEnabledMock)(true).afterReturn(true)
      when(addEntryMock)(ArgumentMatchers.any).afterReturn({ success: true, code: 'ok' })

      let result = await FirewallAuthService.executeToggle(context, false, true)

      expect(result.success).assertTrue()
      expect(result.targetEnabled).assertTrue()
    })
  })
}
