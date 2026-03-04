/**
 * 闃茬伀澧欐ā鍧?- 缁勪欢蹇収娴嬭瘯
 * 楠岃瘉闃茬伀澧欓〉闈㈢殑鍩烘湰娓叉煋
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'FirewallComponentTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function firewallComponentTest() {
  describe('Firewall Component Test', () => {
    let driver: Driver

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, 'Firewall component tests starting...')

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
      // 杩斿洖鎬昏椤甸潰锛岄伩鍏嶅奖鍝嶅悗缁祴璇?
      const dashboardNav = await driver.findComponent(ON.text('鎬昏'))
      if (dashboardNav) {
        await dashboardNav.click()
        await driver.delayMs(500)
      }
      hilog.info(DOMAIN, TAG, 'Firewall component tests completed')
    })

    describe('Firewall Page Snapshot', () => {
      it('should render firewall page correctly', 0, async () => {
        hilog.info(DOMAIN, TAG, 'Navigating to firewall page...')

        // 瀵艰埅鍒伴槻鐏椤甸潰
        const firewallNav = await driver.findComponent(ON.text('闃茬伀澧?))
        expect(firewallNav !== null).assertTrue()
        await firewallNav.click()
        await driver.delayMs(500)

        // 楠岃瘉椤甸潰鏍囬
        await driver.assertComponentExist(ON.text('闃茬伀澧?))
        hilog.info(DOMAIN, TAG, 'Firewall page rendered correctly')
      })
    })

  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

