/**
 * 防火墙模块 - 组件快照测试
 * 验证防火墙页面的基本渲染
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'FirewallComponentTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.example.securitytool'
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
      // 返回总览页面，避免影响后续测试
      const dashboardNav = await driver.findComponent(ON.text('总览'))
      if (dashboardNav) {
        await dashboardNav.click()
        await driver.delayMs(500)
      }
      hilog.info(DOMAIN, TAG, 'Firewall component tests completed')
    })

    describe('Firewall Page Snapshot', () => {
      it('should render firewall page correctly', 0, async () => {
        hilog.info(DOMAIN, TAG, 'Navigating to firewall page...')

        // 导航到防火墙页面
        const firewallNav = await driver.findComponent(ON.text('防火墙'))
        expect(firewallNav !== null).assertTrue()
        await firewallNav.click()
        await driver.delayMs(500)

        // 验证页面标题
        await driver.assertComponentExist(ON.text('防火墙'))
        hilog.info(DOMAIN, TAG, 'Firewall page rendered correctly')
      })
    })

  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
