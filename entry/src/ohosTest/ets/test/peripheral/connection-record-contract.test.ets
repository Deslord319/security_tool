import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { TestLogUtils } from '../../utils/TestLogUtils'
import { clickByText, safeDelay, sleep } from '../../utils/TestDriverUtils'

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
      await safeDelay(driver, 1000)
    })

    afterAll(async () => {
      if (await clickByText(driver, '安全总览')) {
        await safeDelay(driver, 500)
      }
      TestLogUtils.info(TAG, 'connection record contract tests completed')
    })

    it('should show device record tab and actions', 0, async () => {
      const peripheralClicked = await clickByText(driver, '外设管理')
      expect(peripheralClicked).assertTrue()
      await safeDelay(driver, 500)

      const recordTabClicked = await clickByText(driver, '设备连接记录')
      expect(recordTabClicked).assertTrue()
      await safeDelay(driver, 500)

      await driver.assertComponentExist(ON.text('导出记录'))
      await driver.assertComponentExist(ON.text('清理记录'))
    })
  })
}
