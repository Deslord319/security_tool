/**
 * 日志管理模块 - E2E 流程测试 (L4)
 * 测试日志管理模块的完整用户流程
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'LogManageFlowTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.example.securitytool'
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

    // ==================== 完整导航流程 ====================

    describe('Full navigation flow', () => {

      it('should start from dashboard', 0, async () => {
        await driver.assertComponentExist(ON.text('安全总览'))
        hilog.info(DOMAIN, TAG, 'Starting from dashboard')
      })

      it('should navigate to log manage via sidebar', 0, async () => {
        let navItem = await driver.findComponent(ON.text('日志管理'))
        expect(navItem !== null).assertTrue()
        await navItem.click()
        await driver.delayMs(1000)

        // 验证页面标题
        await driver.assertComponentExist(ON.text('监控和审计系统安全事件日志'))
        hilog.info(DOMAIN, TAG, 'Navigated to log manage page')
      })
    })

    // ==================== 日志查看流程 ====================

    describe('Log viewing flow', () => {

      it('should display statistics bar', 0, async () => {
        await driver.assertComponentExist(ON.text('总计'))
        await driver.assertComponentExist(ON.text('今日'))
        await driver.assertComponentExist(ON.text('已阻止'))
        hilog.info(DOMAIN, TAG, 'Statistics bar displayed')
      })

      it('should show refresh button and click it', 0, async () => {
        let refreshBtn = await driver.findComponent(ON.text('刷新'))
        expect(refreshBtn !== null).assertTrue()
        await refreshBtn.click()
        await driver.delayMs(500)
        hilog.info(DOMAIN, TAG, 'Refresh clicked successfully')
      })
    })

    // ==================== 存储设置完整流程 ====================

    describe('Storage settings flow', () => {

      it('should open storage settings', 0, async () => {
        let settingsBtn = await driver.findComponent(ON.text('存储设置'))
        expect(settingsBtn !== null).assertTrue()
        await settingsBtn.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('日志存储配置'))
        hilog.info(DOMAIN, TAG, 'Storage settings opened')
      })

      it('should display all configuration options', 0, async () => {
        await driver.assertComponentExist(ON.text('最大存储条数'))
        await driver.assertComponentExist(ON.text('日志保留天数'))
        await driver.assertComponentExist(ON.text('自动导出'))
        hilog.info(DOMAIN, TAG, 'All config options displayed')
      })

      it('should display permission info', 0, async () => {
        await driver.assertComponentExist(ON.text('权限信息'))
        await driver.assertComponentExist(ON.text('ohos.permission.QUERY_AUDIT_EVENT'))
        hilog.info(DOMAIN, TAG, 'Permission info displayed')
      })

      it('should save settings successfully', 0, async () => {
        let saveBtn = await driver.findComponent(ON.text('保存设置'))
        expect(saveBtn !== null).assertTrue()
        await saveBtn.click()
        await driver.delayMs(1000)
        hilog.info(DOMAIN, TAG, 'Settings saved')
      })

      it('should navigate back to log list', 0, async () => {
        let backBtn = await driver.findComponent(ON.text('返回日志'))
        expect(backBtn !== null).assertTrue()
        await backBtn.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('总计'))
        hilog.info(DOMAIN, TAG, 'Navigated back to log list')
      })
    })

    // ==================== 导出流程 ====================

    describe('Export flow', () => {

      it('should trigger JSON export', 0, async () => {
        let exportBtn = await driver.findComponent(ON.text('导出 JSON'))
        expect(exportBtn !== null).assertTrue()
        await exportBtn.click()
        await driver.delayMs(500)
        hilog.info(DOMAIN, TAG, 'JSON export triggered')
      })

      it('should trigger CSV export', 0, async () => {
        let exportBtn = await driver.findComponent(ON.text('导出 CSV'))
        expect(exportBtn !== null).assertTrue()
        await exportBtn.click()
        await driver.delayMs(500)
        hilog.info(DOMAIN, TAG, 'CSV export triggered')
      })
    })

    // ==================== 跨模块导航 ====================

    describe('Cross-module navigation', () => {

      it('should navigate from log manage to other modules and back', 0, async () => {
        // 先到防火墙
        let firewallNav = await driver.findComponent(ON.text('防火墙'))
        expect(firewallNav !== null).assertTrue()
        await firewallNav.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('防火墙'))

        // 再回到日志管理
        let logNav = await driver.findComponent(ON.text('日志管理'))
        expect(logNav !== null).assertTrue()
        await logNav.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('监控和审计系统安全事件日志'))
        hilog.info(DOMAIN, TAG, 'Cross-module navigation successful')
      })

      it('should navigate back to dashboard at the end', 0, async () => {
        let dashNav = await driver.findComponent(ON.text('总览'))
        expect(dashNav !== null).assertTrue()
        await dashNav.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('安全总览'))
        hilog.info(DOMAIN, TAG, 'Back to dashboard, flow test complete')
      })
    })

  })
}
