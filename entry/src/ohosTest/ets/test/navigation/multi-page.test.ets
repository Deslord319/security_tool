/**
 * 瀵艰埅妯″潡 - 澶氶〉闈㈠鑸祴璇?
 * 娴嬭瘯璺ㄦā鍧楃殑椤甸潰瀵艰埅鍜岃繑鍥?Dashboard 鍔熻兘
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'MultiPageNavTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.huawei.securitytool'
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

        // 瀵艰埅鍒版棩蹇楃鐞?
        let logNav = await driver.findComponent(ON.text('鏃ュ織绠＄悊'))
        if (logNav) {
          await logNav.click()
          await driver.delayMs(500)
          hilog.info(DOMAIN, TAG, 'Navigated to log management')
        }

        // 瀵艰埅鍒板璁剧鐞?
        let peripheralNav = await driver.findComponent(ON.text('澶栬绠＄悊'))
        if (peripheralNav) {
          await peripheralNav.click()
          await driver.delayMs(500)
          hilog.info(DOMAIN, TAG, 'Navigated to peripheral management')
        }

        // 瀵艰埅鍒拌韩浠介壌鍒?
        let identityNav = await driver.findComponent(ON.text('韬唤閴村埆'))
        if (identityNav) {
          await identityNav.click()
          await driver.delayMs(500)
          hilog.info(DOMAIN, TAG, 'Navigated to identity')
        }

        // 杩斿洖鎬昏
        let dashboardNav = await driver.findComponent(ON.text('鎬昏'))
        if (dashboardNav) {
          await dashboardNav.click()
          await driver.delayMs(500)
          await driver.assertComponentExist(ON.text('瀹夊叏鎬昏'))
          hilog.info(DOMAIN, TAG, 'All navigation tests passed')
        }
      })
    })

    describe('Return to Dashboard', () => {
      it('should return to dashboard from any page', 0, async () => {
        hilog.info(DOMAIN, TAG, 'Testing return to dashboard...')

        // 鍏堝鑸埌鍏朵粬椤甸潰
        const firewallNav = await driver.findComponent(ON.text('闃茬伀澧?))
        if (firewallNav) {
          await firewallNav.click()
          await driver.delayMs(500)
        }

        // 杩斿洖鎬昏椤甸潰
        const dashboardNav = await driver.findComponent(ON.text('鎬昏'))
        expect(dashboardNav !== null).assertTrue()
        await dashboardNav.click()
        await driver.delayMs(500)

        // 楠岃瘉鍥炲埌 Dashboard
        await driver.assertComponentExist(ON.text('瀹夊叏鎬昏'))
        hilog.info(DOMAIN, TAG, 'Returned to dashboard successfully')
      })
    })

  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

