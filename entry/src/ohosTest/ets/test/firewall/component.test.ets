/**
 * Firewall page component smoke test.
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { TestLogUtils } from '../../utils/TestLogUtils'

const TAG = 'FirewallComponentTest'
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function firewallComponentTest() {
  describe('Firewall Component Test', () => {
    let driver: Driver

    beforeAll(async () => {
      TestLogUtils.info(TAG, 'Firewall component tests starting...')
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        abilityName: ABILITY_NAME
      })
      await sleep(2000)
      driver = Driver.create()
      await driver.delayMs(1000)
    })

    afterAll(async () => {
      const dashboardNav = await driver.findComponent(ON.text('安全总览'))
      if (dashboardNav) {
        await dashboardNav.click()
        await driver.delayMs(500)
      }
      TestLogUtils.info(TAG, 'Firewall component tests completed')
    })

    it('should render firewall page correctly', 0, async () => {
      const firewallNav = await driver.findComponent(ON.text('防火墙管理'))
      expect(firewallNav !== null).assertTrue()
      await firewallNav!.click()
      await driver.delayMs(500)
      await driver.assertComponentExist(ON.text('防火墙管理'))
    })
  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
