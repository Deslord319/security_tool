/**
 * Dashboard module UI smoke test.
 */
import { describe, beforeAll, afterAll, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'DashboardComponentTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function dashboardComponentTest() {
  describe('Dashboard Component UI Test', () => {
    let driver: Driver

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, 'Dashboard component tests starting...')
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
      hilog.info(DOMAIN, TAG, 'Dashboard component tests completed')
    })

    it('should display dashboard title and cards', 0, async () => {
      await driver.assertComponentExist(ON.text('安全管理中心'))
      await driver.assertComponentExist(ON.text('安全总览'))
      await driver.assertComponentExist(ON.text('管理员'))
      await driver.assertComponentExist(ON.text('防火墙'))
    })

    it('should display sidebar nav items', 0, async () => {
      await driver.assertComponentExist(ON.text('安全总览'))
      await driver.assertComponentExist(ON.text('防火墙管理'))
      await driver.assertComponentExist(ON.text('日志管理'))
      await driver.assertComponentExist(ON.text('外设管理'))
    })
  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
