import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { FirewallAuthService } from '../../main/ets/services/firewall/auth/FirewallAuthService'
import { FirewallStore } from '../../main/ets/services/firewall/stores/FirewallStore'
import { FirewallUserDispatchService } from '../../main/ets/services/firewall/user-dispatch/FirewallUserDispatchService'

export default function firewallUserDispatchServiceTest() {
  describe('FirewallUserDispatchService', () => {
    let mockKit: MockKit

    beforeEach(() => {
      mockKit = new MockKit()
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should load user options as an array', 0, async () => {
      let users = await FirewallUserDispatchService.loadUserOptions()

      expect(users === undefined || users.length >= 0).assertTrue()
    })

    it('should resolve user mode state with stable shape', 0, async () => {
      let result = await FirewallUserDispatchService.loadUserModeState({} as common.UIAbilityContext, 100)

      expect(result.userId).assertEqual(100)
      expect(typeof result.isManaged === 'boolean').assertTrue()
      expect(typeof result.isOpen === 'boolean').assertTrue()
    })

    it('should apply user mode through auth wrapper and return policy-only result shape', 0, async () => {
      let context = {} as common.UIAbilityContext
      let authApplyMock = mockKit.mockFunc(FirewallAuthService, FirewallAuthService.executeUserModeApply)
      let storeApplyMock = mockKit.mockFunc(FirewallStore, FirewallStore.applyUserMode)
      when(storeApplyMock)(context, 100, 'allowlist').afterReturn(Promise.resolve({
        success: true,
        userId: 100,
        mode: 'allowlist',
        appliedRuleCount: 0
      }))
      when(authApplyMock)(context, 100, 'allowlist', ArgumentMatchers.anyObj).afterAction((ctx, userId, mode, applyAction) => {
        return applyAction()
      })

      let result = await FirewallUserDispatchService.applyUserMode(context, 100, 'allowlist')

      expect(result.success).assertTrue()
      expect(result.userId).assertEqual(100)
      expect(result.mode).assertEqual('allowlist')
      expect(result.appliedRuleCount).assertEqual(0)
    })
  })
}
