import { describe, expect, it } from '@ohos/hypium'
import EnterpriseAdminAbility from '../../main/ets/enterpriseadminability/EnterpriseAdminAbility'

export default function enterpriseAdminAbilityTest() {
  describe('EnterpriseAdminAbility', () => {
    it('should allow lifecycle callbacks without throwing', 0, () => {
      let ability = new EnterpriseAdminAbility()

      ability.onAdminEnabled()
      ability.onAdminDisabled()
      ability.onAccountAdded(101)
      ability.onAccountRemoved(101)
      ability.onBundleAdded('com.example.demo')
      ability.onBundleRemoved('com.example.demo')

      expect(true).assertTrue()
    })
  })
}
