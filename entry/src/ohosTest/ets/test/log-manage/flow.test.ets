/**
 * 日志管理模块 - E2E 流程测试
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'LogManageFlowTest'
const DOMAIN = 0x0000
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
      hilog.info(DOMAIN, TAG, 'LogManage E2E flow tests starting...')
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
      hilog.info(DOMAIN, TAG, 'LogManage E2E flow tests completed')
    })

    describe('Full navigation flow', () => {
      it('should start from dashboard and enter log manage', 0, async () => {
        await driver.assertComponentExist(ON.text('安全总览'))
        let navItem = await driver.findComponent(ON.text('日志管理'))
        expect(navItem !== null).assertTrue()
        await navItem.click()
        await driver.delayMs(1000)

        await driver.assertComponentExist(ON.text('日志管理'))
        await driver.assertComponentExist(ON.text('监控和审计系统安全事件日志'))
      })
    })

    describe('Log viewing flow', () => {
      it('should display statistics and refresh', 0, async () => {
        await driver.assertComponentExist(ON.text('总计'))
        await driver.assertComponentExist(ON.text('今日'))
        await driver.assertComponentExist(ON.text('已阻止'))

        let refreshBtn = await driver.findComponent(ON.text('刷新'))
        expect(refreshBtn !== null).assertTrue()
        await refreshBtn.click()
        await driver.delayMs(500)
      })
    })

    describe('Storage settings flow', () => {
      it('should open and save storage settings', 0, async () => {
        let settingsBtn = await driver.findComponent(ON.text('进入存储设置'))
        expect(settingsBtn !== null).assertTrue()
        await settingsBtn.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('日志存储设置'))
        await driver.assertComponentExist(ON.text('日志存储配置'))
        await driver.assertComponentExist(ON.text('最大存储条数'))
        await driver.assertComponentExist(ON.text('日志保留天数'))
        await driver.assertComponentExist(ON.text('自动导出'))
        await driver.assertComponentExist(ON.text('导出保存位置'))
        await driver.assertComponentExist(ON.text('权限信息'))
        await driver.assertComponentExist(ON.text('订阅模式'))

        let saveBtn = await driver.findComponent(ON.text('保存设置'))
        expect(saveBtn !== null).assertTrue()
        await saveBtn.click()
        await driver.delayMs(500)
      })

      it('should navigate back to log list', 0, async () => {
        let backBtn = await driver.findComponent(ON.text('返回日志列表'))
        expect(backBtn !== null).assertTrue()
        await backBtn.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('总计'))
      })
    })

    describe('Export flow', () => {
      it('should trigger export feedback directly', 0, async () => {
        let exportBtn = await driver.findComponent(ON.text('导出日志'))
        expect(exportBtn !== null).assertTrue()
        await exportBtn.click()
        await driver.delayMs(800)

        const successExists = await driver.exists(ON.text('日志已导出，保存位置：下载\\安全管理中心\\'))
        const failureExists = await driver.exists(ON.text('操作失败 ❌'))
        const emptyExists = await driver.exists(ON.text('没有可导出的日志'))

        expect(successExists || failureExists || emptyExists).assertTrue()
      })
    })

    describe('Cross-module navigation', () => {
      it('should navigate to firewall and back', 0, async () => {
        let firewallNav = await driver.findComponent(ON.text('防火墙管理'))
        expect(firewallNav !== null).assertTrue()
        await firewallNav.click()
        await driver.delayMs(500)
        await driver.assertComponentExist(ON.text('防火墙管理'))

        let logNav = await driver.findComponent(ON.text('日志管理'))
        expect(logNav !== null).assertTrue()
        await logNav.click()
        await driver.delayMs(500)
        await driver.assertComponentExist(ON.text('日志管理'))
      })

      it('should navigate back to dashboard at the end', 0, async () => {
        let dashNav = await driver.findComponent(ON.text('总览'))
        expect(dashNav !== null).assertTrue()
        await dashNav.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('安全总览'))
      })
    })
  })
}
