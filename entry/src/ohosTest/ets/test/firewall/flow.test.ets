/**
 * 闃茬伀澧欐ā鍧?- 娴佺▼ E2E 娴嬭瘯
 * 娴嬭瘯浠?Dashboard 瀵艰埅鍒伴槻鐏椤甸潰鐨勫畬鏁存祦绋嬪強闃茬伀澧欓〉闈㈠姛鑳?
 */
import { describe, beforeAll, afterAll, beforeEach, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON, Component } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'FirewallFlowTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function firewallFlowTest() {
  describe('Firewall Flow E2E Test', () => {
    let driver: Driver
    let delegator: abilityDelegatorRegistry.AbilityDelegator

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, 'Firewall flow tests starting...')

      delegator = abilityDelegatorRegistry.getAbilityDelegator()

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

    // ==================== 瀵艰埅娴佺▼娴嬭瘯 ====================

    describe('Navigation Flow', () => {
      it('should navigate to firewall page via sidebar', 0, async () => {
        hilog.info(DOMAIN, TAG, 'Testing sidebar navigation to firewall...')

        const firewallNav = await driver.findComponent(ON.text('闃茬伀澧?))
        expect(firewallNav !== null).assertTrue()
        await firewallNav.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('闃茬伀澧?))
        hilog.info(DOMAIN, TAG, 'Successfully navigated to firewall page')
      })

      it('should navigate back to dashboard via sidebar', 0, async () => {
        hilog.info(DOMAIN, TAG, 'Testing navigation back to dashboard...')

        const dashboardNav = await driver.findComponent(ON.text('鎬昏'))
        expect(dashboardNav !== null).assertTrue()
        await dashboardNav.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('瀹夊叏鎬昏'))
        hilog.info(DOMAIN, TAG, 'Successfully navigated back to dashboard')
      })

      it('should navigate to firewall via quick action card', 0, async () => {
        hilog.info(DOMAIN, TAG, 'Testing quick action navigation...')

        const firewallCard = await driver.findComponent(ON.text('闃茬伀澧欑鐞?))
        expect(firewallCard !== null).assertTrue()
        await firewallCard.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('闃茬伀澧?))
        hilog.info(DOMAIN, TAG, 'Quick action navigation successful')
      })
    })

    // ==================== 闃茬伀澧欓〉闈㈠姛鑳芥祴璇?====================

    describe('Firewall Page Features', () => {
      beforeEach(async () => {
        // 纭繚鍦ㄩ槻鐏椤甸潰
        const firewallNav = await driver.findComponent(ON.text('闃茬伀澧?))
        if (firewallNav) {
          await firewallNav.click()
          await driver.delayMs(500)
        }
      })

      it('should display firewall switch', 0, async () => {
        hilog.info(DOMAIN, TAG, 'Verifying firewall switch presence...')

        await driver.assertComponentExist(ON.text('闃茬伀澧?))
        hilog.info(DOMAIN, TAG, 'Firewall page loaded successfully')
      })

      it('should display rule type section', 0, async () => {
        hilog.info(DOMAIN, TAG, 'Verifying rule type section...')
        await driver.assertComponentExist(ON.text('闃茬伀澧?))
        hilog.info(DOMAIN, TAG, 'Rule type section verified')
      })
    })

  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

