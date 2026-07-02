import { describe, expect, it } from '@ohos/hypium'

import { AccountChangeCoordinator } from '../../main/ets/services/account/AccountChangeCoordinator'

export default function firewallAccountChangeCoordinatorTest() {
  describe('AccountChangeCoordinator', () => {
    it('should debounce account changes with the default delay', 0, () => {
      expect(AccountChangeCoordinator.resolveDebounceMs()).assertEqual(400)
    })
  })
}
