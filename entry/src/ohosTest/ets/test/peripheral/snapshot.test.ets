/**
 * 外设模块 - 页面快照测试
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
      const dashboardNav = await driver.findComponent(ON.text('总览'))
      if (dashboardNav) {
        await dashboardNav.click()
        await driver.delayMs(500)
      }
      hilog.info(DOMAIN, TAG, 'Peripheral snapshot tests completed')
    })

    describe('Peripheral Page Snapshot', () => {
      it('should render peripheral page correctly', 0, async () => {
        const peripheralNav = await driver.findComponent(ON.text('外设管理'))
        expect(peripheralNav !== null).assertTrue()
        await peripheralNav.click()
        await driver.delayMs(500)
      })
    })
  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
