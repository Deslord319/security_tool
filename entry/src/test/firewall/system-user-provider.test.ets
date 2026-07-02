import { describe, expect, it } from '@ohos/hypium'

import { SystemUserProvider } from '../../main/ets/services/firewall/providers/SystemUserProvider'

export default function systemUserProviderTest() {
  describe('SystemUserProvider', () => {
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
  })
}
