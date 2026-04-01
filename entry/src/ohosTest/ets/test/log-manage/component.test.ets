/**
 * LogManage module UI smoke test.
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'LogManageComponentTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(resolve, ms)
  })
}

export default function logManageComponentTest() {
  describe('LogManage Component UI Test', () => {
    let driver: Driver

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, 'LogManage component tests starting...')
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
      hilog.info(DOMAIN, TAG, 'LogManage component tests completed')
    })

    it('should navigate to log manage page via sidebar', 0, async () => {
      let navItem = await driver.findComponent(ON.text('日志管理'))
      expect(navItem !== null).assertTrue()
      await navItem!.click()
      await driver.delayMs(1000)
    })

    it('should display page title and description', 0, async () => {
      await driver.assertComponentExist(ON.text('日志管理'))
      await driver.assertComponentExist(ON.text('监控崩溃与关键安全日志'))
      await driver.assertComponentExist(ON.text('存储设置'))
    })

    it('should display statistics and actions', 0, async () => {
      await driver.assertComponentExist(ON.text('总计'))
      await driver.assertComponentExist(ON.text('今日'))
      await driver.assertComponentExist(ON.text('当前显示'))
      await driver.assertComponentExist(ON.text('导出日志'))
      await driver.assertComponentExist(ON.text('清空日志'))
      await driver.assertComponentExist(ON.text('刷新'))
    })
  })
}
