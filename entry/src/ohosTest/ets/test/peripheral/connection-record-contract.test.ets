import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { TestLogUtils } from '../../utils/TestLogUtils'

const TAG = 'PeripheralConnectionRecordContractTest'
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function peripheralConnectionRecordContractTest() {
  describe('Peripheral Connection Record Contract Test', () => {
    let driver: Driver

    beforeAll(async () => {
      TestLogUtils.info(TAG, 'connection record contract tests starting...')
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
      const dashboardNav = await driver.findComponent(ON.text('安全总览'))
      if (dashboardNav) {
        await dashboardNav.click()
        await driver.delayMs(500)
      }
      TestLogUtils.info(TAG, 'connection record contract tests completed')
    })

    it('should show device record tab and actions', 0, async () => {
      const peripheralNav = await driver.findComponent(ON.text('外设管理'))
      expect(peripheralNav !== null).assertTrue()
      await peripheralNav!.click()
      await driver.delayMs(500)

      const recordTab = await driver.findComponent(ON.text('设备连接记录'))
      expect(recordTab !== null).assertTrue()
      await recordTab!.click()
      await driver.delayMs(500)

      await driver.assertComponentExist(ON.text('导出记录'))
      await driver.assertComponentExist(ON.text('清理记录'))
    })
  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
