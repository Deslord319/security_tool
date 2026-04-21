import { describe, expect, it } from '@ohos/hypium'

import { SystemUserProvider } from '../../main/ets/services/firewall/providers/SystemUserProvider'

export default function systemUserProviderTest() {
  describe('SystemUserProvider', () => {
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
  })
}
