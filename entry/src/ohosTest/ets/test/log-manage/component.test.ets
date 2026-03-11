/**
 * 日志管理模块 - 组件 UI 测试
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

    describe('Navigate to LogManage', () => {
      it('should navigate to log manage page via sidebar', 0, async () => {
        let navItem = await driver.findComponent(ON.text('日志管理'))
        expect(navItem !== null).assertTrue()
        await navItem.click()
        await driver.delayMs(1000)
      })
    })

    describe('LogManage Page Header', () => {
      it('should display page title and description', 0, async () => {
        await driver.assertComponentExist(ON.text('日志管理'))
        await driver.assertComponentExist(ON.text('监控和审计系统安全事件日志'))
        await driver.assertComponentExist(ON.text('进入存储设置'))
      })
    })

    describe('Statistics Bar', () => {
      it('should display statistics labels', 0, async () => {
        await driver.assertComponentExist(ON.text('总计'))
        await driver.assertComponentExist(ON.text('今日'))
        await driver.assertComponentExist(ON.text('已阻止'))
        await driver.assertComponentExist(ON.text('当前显示'))
      })
    })

    describe('Bottom Toolbar', () => {
      it('should display log actions', 0, async () => {
        await driver.assertComponentExist(ON.text('导出日志'))
        await driver.assertComponentExist(ON.text('清空日志'))
      })
    })

    describe('Storage Settings View', () => {
      it('should switch to storage settings view', 0, async () => {
        let settingsBtn = await driver.findComponent(ON.text('进入存储设置'))
        expect(settingsBtn !== null).assertTrue()
        await settingsBtn.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('日志存储设置'))
        await driver.assertComponentExist(ON.text('日志存储配置'))
      })

      it('should display storage settings content', 0, async () => {
        await driver.assertComponentExist(ON.text('最大存储条数'))
        await driver.assertComponentExist(ON.text('日志保留天数'))
        await driver.assertComponentExist(ON.text('自动导出'))
        await driver.assertComponentExist(ON.text('导出保存位置'))
        await driver.assertComponentExist(ON.text('权限信息'))
        await driver.assertComponentExist(ON.text('保存设置'))
      })

      it('should switch back to log list view', 0, async () => {
        let backBtn = await driver.findComponent(ON.text('返回日志列表'))
        expect(backBtn !== null).assertTrue()
        await backBtn.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('总计'))
      })
    })

    describe('Filter Toolbar', () => {
      it('should display search input and refresh button', 0, async () => {
        let searchInput = await driver.findComponent(ON.type('TextInput'))
        expect(searchInput !== null).assertTrue()
        await driver.assertComponentExist(ON.text('刷新'))
      })
    })
  })
}
