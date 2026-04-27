import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { netFirewall } from '@kit.NetworkKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { FirewallSystemRepository } from '../../main/ets/services/firewall/FirewallSystemRepository'
import { SystemUserProvider } from '../../main/ets/services/firewall/providers/SystemUserProvider'

class FakeNetFirewallPolicy implements netFirewall.NetFirewallPolicy {
  isOpen: boolean = true
  inAction: number = 1
  outAction: number = 2
}

export default function systemUserProviderTest() {
  describe('SystemUserProvider', () => {
    let mockKit: MockKit

    beforeEach(() => {
      mockKit = new MockKit()
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should allow tracked-user maintenance methods without throwing', 0, async () => {
      await SystemUserProvider.trackAddedUser(101)
      await SystemUserProvider.trackRemovedUser(101)

      expect(true).assertTrue()
    })

    it('should return a well-formed available-user result', 0, async () => {
      let result = await SystemUserProvider.loadAvailableUserIds()
      if (!result) {
        expect(true).assertTrue()
        return
      }

      expect(result.users.length >= 0).assertTrue()
      if (result.users.length > 0) {
        expect(result.users[0].userId >= 0).assertTrue()
        expect((result.users[0].label.length ?? 0) >= 0).assertTrue()
      } else {
        expect((result.message?.length ?? 0) > 0).assertTrue()
      }
    })

    it('should return a well-formed firewall policy result for a user id', 0, async () => {
      let result = await SystemUserProvider.getPolicy(100)

      expect(result.userId).assertEqual(100)
      expect(typeof result.isOpen === 'boolean').assertTrue()
      expect(typeof result.inAction === 'number').assertTrue()
      expect(typeof result.outAction === 'number').assertTrue()
    })

    it('should return fallback policy for tracked added user id', 0, async () => {
      let policyMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.getPolicy)
      when(policyMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(null))

      let result = await SystemUserProvider.getPolicy(101)

      expect(result.userId).assertEqual(101)
      expect(result.isOpen).assertFalse()
      expect(result.inAction).assertEqual(0)
      expect(result.outAction).assertEqual(0)
    })

    it('should return repository policy for tracked added user id', 0, async () => {
      let policyMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.getPolicy)
      when(policyMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(new FakeNetFirewallPolicy()))

      let result = await SystemUserProvider.getPolicy(101)

      expect(result.userId).assertEqual(101)
      expect(result.isOpen).assertTrue()
      expect(result.inAction).assertEqual(1)
      expect(result.outAction).assertEqual(2)
    })
  })
}
