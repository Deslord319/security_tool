/**
 * Multi-page navigation smoke test.
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { TestLogUtils } from '../../utils/TestLogUtils'

const TAG = 'MultiPageNavTest'
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function multiPageNavigationTest() {
  describe('Multi-Page Navigation Test', () => {
    let driver: Driver

    beforeAll(async () => {
      TestLogUtils.info(TAG, 'Multi-page navigation tests starting...')
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
      TestLogUtils.info(TAG, 'Multi-page navigation tests completed')
    })

    it('should navigate through main pages', 0, async () => {
      let logNav = await driver.findComponent(ON.text('日志管理'))
      if (logNav) {
        await logNav.click()
        await driver.delayMs(500)
      }

      let peripheralNav = await driver.findComponent(ON.text('外设管理'))
      if (peripheralNav) {
        await peripheralNav.click()
        await driver.delayMs(500)
      }

      let identityNav = await driver.findComponent(ON.text('身份鉴别'))
      if (identityNav) {
        await identityNav.click()
        await driver.delayMs(500)
      }

      let dashboardNav = await driver.findComponent(ON.text('安全总览'))
      if (dashboardNav) {
        await dashboardNav.click()
        await driver.delayMs(500)
        await driver.assertComponentExist(ON.text('安全总览'))
      }
    })

    it('should return to dashboard from firewall', 0, async () => {
      const firewallNav = await driver.findComponent(ON.text('防火墙管理'))
      if (firewallNav) {
        await firewallNav.click()
        await driver.delayMs(500)
      }

      const dashboardNav = await driver.findComponent(ON.text('安全总览'))
      expect(dashboardNav !== null).assertTrue()
      await dashboardNav!.click()
      await driver.delayMs(500)

      await driver.assertComponentExist(ON.text('安全总览'))
    })
  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
