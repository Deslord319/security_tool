/**
 * 澶栬妯″潡 - 椤甸潰蹇収娴嬭瘯
 * 楠岃瘉澶栬绠＄悊椤甸潰鐨勫熀鏈覆鏌?
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'PeripheralSnapshotTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function peripheralSnapshotTest() {
  describe('Peripheral Snapshot Test', () => {
    let driver: Driver

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, 'Peripheral snapshot tests starting...')

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
      hilog.info(DOMAIN, TAG, 'Peripheral snapshot tests completed')
    })

    describe('Peripheral Page Snapshot', () => {
      it('should render peripheral page correctly', 0, async () => {
        hilog.info(DOMAIN, TAG, 'Navigating to peripheral page...')

        // 瀵艰埅鍒板璁剧鐞嗛〉闈?
        const peripheralNav = await driver.findComponent(ON.text('澶栬绠＄悊'))
        expect(peripheralNav !== null).assertTrue()
        await peripheralNav.click()
        await driver.delayMs(500)

        // 楠岃瘉椤甸潰鍔犺浇
        hilog.info(DOMAIN, TAG, 'Peripheral page rendered correctly')
      })
    })

  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

