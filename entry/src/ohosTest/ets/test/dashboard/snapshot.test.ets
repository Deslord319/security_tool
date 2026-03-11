/**
 * Dashboard 模块 - 页面快照测试
 */
import { describe, beforeAll, afterAll, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'DashboardSnapshotTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function dashboardSnapshotTest() {
  describe('Dashboard Snapshot Test', () => {
    let driver: Driver

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, 'Dashboard snapshot tests starting...')
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
      hilog.info(DOMAIN, TAG, 'Dashboard snapshot tests completed')
    })

    describe('Dashboard Page Snapshot', () => {
      it('should render dashboard layout correctly', 0, async () => {
        await driver.assertComponentExist(ON.text('安全管理中心'))
        await driver.assertComponentExist(ON.text('安全总览'))
        await driver.assertComponentExist(ON.text('快捷功能'))
      })

      it('should render all stat cards', 0, async () => {
        await driver.assertComponentExist(ON.text('防火墙状态'))
        await driver.assertComponentExist(ON.text('今日审计事件'))
        await driver.assertComponentExist(ON.text('已阻止事件'))
        await driver.assertComponentExist(ON.text('日志总量'))
      })

      it('should render all quick action cards', 0, async () => {
        await driver.assertComponentExist(ON.text('防火墙管理'))
        await driver.assertComponentExist(ON.text('日志管理'))
        await driver.assertComponentExist(ON.text('外设管理'))
        await driver.assertComponentExist(ON.text('身份鉴别'))
        await driver.assertComponentExist(ON.text('防火墙规则'))
        await driver.assertComponentExist(ON.text('工具设置'))
      })
    })
  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
