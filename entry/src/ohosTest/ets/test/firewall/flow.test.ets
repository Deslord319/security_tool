/**
 * Firewall navigation flow smoke test.
 */
import { describe, beforeAll, afterAll, beforeEach, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { TestLogUtils } from '../../utils/TestLogUtils'

const TAG = 'FirewallFlowTest'
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function firewallFlowTest() {
  describe('Firewall Flow E2E Test', () => {
    let driver: Driver

    beforeAll(async () => {
      TestLogUtils.info(TAG, 'Firewall flow tests starting...')
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
      TestLogUtils.info(TAG, 'Firewall flow tests completed')
    })

    it('should navigate to firewall page via sidebar', 0, async () => {
      const firewallNav = await driver.findComponent(ON.text('防火墙管理'))
      expect(firewallNav !== null).assertTrue()
      await firewallNav!.click()
      await driver.delayMs(500)
      await driver.assertComponentExist(ON.text('防火墙管理'))
    })

    it('should navigate back to dashboard via sidebar', 0, async () => {
      const dashboardNav = await driver.findComponent(ON.text('安全总览'))
      expect(dashboardNav !== null).assertTrue()
      await dashboardNav!.click()
      await driver.delayMs(500)
      await driver.assertComponentExist(ON.text('安全总览'))
    })

    describe('Firewall Page Features', () => {
      beforeEach(async () => {
        const firewallNav = await driver.findComponent(ON.text('防火墙管理'))
        if (firewallNav) {
          await firewallNav.click()
          await driver.delayMs(500)
        }
      })

      it('should display page title', 0, async () => {
        await driver.assertComponentExist(ON.text('防火墙管理'))
      })
    })
  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
