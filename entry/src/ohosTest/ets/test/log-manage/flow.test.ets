/**
 * Log manage flow smoke test.
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { TestLogUtils } from '../../utils/TestLogUtils'

const TAG = 'LogManageFlowTest'
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(resolve, ms)
  })
}

export default function logManageFlowTest() {
  describe('LogManage E2E Flow Test', () => {
    let driver: Driver

    beforeAll(async () => {
      TestLogUtils.info(TAG, 'LogManage E2E flow tests starting...')
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
      TestLogUtils.info(TAG, 'LogManage E2E flow tests completed')
    })

    it('should enter log manage from dashboard', 0, async () => {
      await driver.assertComponentExist(ON.text('安全总览'))
      let navItem = await driver.findComponent(ON.text('日志管理'))
      expect(navItem !== null).assertTrue()
      await navItem!.click()
      await driver.delayMs(1000)

      await driver.assertComponentExist(ON.text('日志管理'))
      await driver.assertComponentExist(ON.text('监控崩溃与关键安全日志'))
    })

    it('should display statistics and refresh action', 0, async () => {
      await driver.assertComponentExist(ON.text('总计'))
      await driver.assertComponentExist(ON.text('今日'))
      await driver.assertComponentExist(ON.text('当前显示'))

      let refreshBtn = await driver.findComponent(ON.text('刷新'))
      expect(refreshBtn !== null).assertTrue()
      await refreshBtn!.click()
      await driver.delayMs(500)
    })

    it('should open storage settings', 0, async () => {
      let settingsBtn = await driver.findComponent(ON.text('存储设置'))
      expect(settingsBtn !== null).assertTrue()
      await settingsBtn!.click()
      await driver.delayMs(500)

      await driver.assertComponentExist(ON.text('日志存储配置'))
      await driver.assertComponentExist(ON.text('最大存储条数'))
      await driver.assertComponentExist(ON.text('日志保留天数'))
    })
  })
}
