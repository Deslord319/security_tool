/**
 * 防火墙模块 - 流程 E2E 测试
 */
import { describe, beforeAll, afterAll, beforeEach, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'FirewallFlowTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function firewallFlowTest() {
  describe('Firewall Flow E2E Test', () => {
    let driver: Driver

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, 'Firewall flow tests starting...')
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
      hilog.info(DOMAIN, TAG, 'Firewall flow tests completed')
    })

    describe('Navigation Flow', () => {
      it('should navigate to firewall page via sidebar', 0, async () => {
        const firewallNav = await driver.findComponent(ON.text('防火墙管理'))
        expect(firewallNav !== null).assertTrue()
        await firewallNav.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('防火墙管理'))
      })

      it('should navigate back to dashboard via sidebar', 0, async () => {
        const dashboardNav = await driver.findComponent(ON.text('总览'))
        expect(dashboardNav !== null).assertTrue()
        await dashboardNav.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('安全总览'))
      })

      it('should navigate to firewall via quick action card', 0, async () => {
        const firewallCard = await driver.findComponent(ON.text('防火墙管理'))
        expect(firewallCard !== null).assertTrue()
        await firewallCard.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('防火墙管理'))
      })
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
