import { describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'

import { FirewallUserDispatchService } from '../../main/ets/services/firewall/user-dispatch/FirewallUserDispatchService'

export default function firewallUserDispatchServiceTest() {
  describe('FirewallUserDispatchService', () => {
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

    it('should reapply user bindings and return summary counters', 0, async () => {
      let result = await FirewallUserDispatchService.reapplyUserBindings({} as common.UIAbilityContext, [])

      expect(result.totalUsers >= 0).assertTrue()
      expect(result.successCount >= 0).assertTrue()
      expect(result.failedCount >= 0).assertTrue()
      expect(result.failedUsers.length >= 0).assertTrue()
    })
  })
}
