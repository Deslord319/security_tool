/**
 * 导航模块 - 多页面导航测试
 * 测试跨模块的页面导航和返回 Dashboard 功能
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'MultiPageNavTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.example.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function multiPageNavigationTest() {
  describe('Multi-Page Navigation Test', () => {
    let driver: Driver

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, 'Multi-page navigation tests starting...')

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
      hilog.info(DOMAIN, TAG, 'Multi-page navigation tests completed')
    })

    describe('Navigate Through All Pages', () => {
      it('should navigate through all main pages', 0, async () => {
        hilog.info(DOMAIN, TAG, 'Testing navigation through all pages...')

        // 导航到日志管理
        let logNav = await driver.findComponent(ON.text('日志管理'))
        if (logNav) {
          await logNav.click()
          await driver.delayMs(500)
          hilog.info(DOMAIN, TAG, 'Navigated to log management')
        }

        // 导航到外设管理
        let peripheralNav = await driver.findComponent(ON.text('外设管理'))
        if (peripheralNav) {
          await peripheralNav.click()
          await driver.delayMs(500)
          hilog.info(DOMAIN, TAG, 'Navigated to peripheral management')
        }

        // 导航到身份鉴别
        let identityNav = await driver.findComponent(ON.text('身份鉴别'))
        if (identityNav) {
          await identityNav.click()
          await driver.delayMs(500)
          hilog.info(DOMAIN, TAG, 'Navigated to identity')
        }

        // 返回总览
        let dashboardNav = await driver.findComponent(ON.text('总览'))
        if (dashboardNav) {
          await dashboardNav.click()
          await driver.delayMs(500)
          await driver.assertComponentExist(ON.text('安全总览'))
          hilog.info(DOMAIN, TAG, 'All navigation tests passed')
        }
      })
    })

    describe('Return to Dashboard', () => {
      it('should return to dashboard from any page', 0, async () => {
        hilog.info(DOMAIN, TAG, 'Testing return to dashboard...')

        // 先导航到其他页面
        const firewallNav = await driver.findComponent(ON.text('防火墙'))
        if (firewallNav) {
          await firewallNav.click()
          await driver.delayMs(500)
        }

        // 返回总览页面
        const dashboardNav = await driver.findComponent(ON.text('总览'))
        expect(dashboardNav !== null).assertTrue()
        await dashboardNav.click()
        await driver.delayMs(500)

        // 验证回到 Dashboard
        await driver.assertComponentExist(ON.text('安全总览'))
        hilog.info(DOMAIN, TAG, 'Returned to dashboard successfully')
      })
    })

  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
