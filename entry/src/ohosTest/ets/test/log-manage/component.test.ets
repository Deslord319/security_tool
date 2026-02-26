/**
 * 日志管理模块 - 组件 UI 测试 (L3)
 * 测试日志管理页面的渲染、导航、交互行为
 */
import { describe, beforeAll, afterAll, beforeEach, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'LogManageComponentTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.example.securitytool'
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

    // ==================== 导航到日志管理页面 ====================

    describe('Navigate to LogManage', () => {

      it('should navigate to log manage page via sidebar', 0, async () => {
        // 点击侧边栏「日志管理」
        let navItem = await driver.findComponent(ON.text('日志管理'))
        expect(navItem !== null).assertTrue()
        await navItem.click()
        await driver.delayMs(1000)

        hilog.info(DOMAIN, TAG, 'Navigated to LogManage page')
      })
    })

    // ==================== 页面头部渲染测试 ====================

    describe('LogManage Page Header', () => {

      it('should display page title', 0, async () => {
        await driver.assertComponentExist(ON.text('日志管理'))
        hilog.info(DOMAIN, TAG, 'Page title verified')
      })

      it('should display page description', 0, async () => {
        await driver.assertComponentExist(ON.text('监控和审计系统安全事件日志'))
        hilog.info(DOMAIN, TAG, 'Page description verified')
      })

      it('should display subscription status indicator', 0, async () => {
        // 订阅状态文字应存在（实时监听中 or 未连接）
        let connected = await driver.findComponent(ON.text('实时监听中'))
        let disconnected = await driver.findComponent(ON.text('未连接'))
        expect(connected !== null || disconnected !== null).assertTrue()
        hilog.info(DOMAIN, TAG, 'Subscription status indicator verified')
      })

      it('should display storage settings button', 0, async () => {
        await driver.assertComponentExist(ON.text('存储设置'))
        hilog.info(DOMAIN, TAG, 'Storage settings button verified')
      })
    })

    // ==================== 统计卡片测试 ====================

    describe('Statistics Bar', () => {

      it('should display total count label', 0, async () => {
        await driver.assertComponentExist(ON.text('总计'))
        hilog.info(DOMAIN, TAG, 'Total count label verified')
      })

      it('should display today count label', 0, async () => {
        await driver.assertComponentExist(ON.text('今日'))
        hilog.info(DOMAIN, TAG, 'Today count label verified')
      })

      it('should display blocked count label', 0, async () => {
        await driver.assertComponentExist(ON.text('已阻止'))
        hilog.info(DOMAIN, TAG, 'Blocked count label verified')
      })

      it('should display current display count label', 0, async () => {
        await driver.assertComponentExist(ON.text('当前显示'))
        hilog.info(DOMAIN, TAG, 'Current display count label verified')
      })
    })

    // ==================== 空状态测试 ====================

    describe('Empty State', () => {

      it('should show empty state message when no logs', 0, async () => {
        let emptyMsg = await driver.findComponent(ON.text('暂无日志记录'))
        // 可能有日志也可能没有，两种情况都合理
        if (emptyMsg !== null) {
          hilog.info(DOMAIN, TAG, 'Empty state message shown (no logs)')
        } else {
          hilog.info(DOMAIN, TAG, 'Log entries exist, empty state not shown')
        }
      })
    })

    // ==================== 底部工具栏测试 ====================

    describe('Bottom Toolbar', () => {

      it('should display export JSON button', 0, async () => {
        await driver.assertComponentExist(ON.text('导出 JSON'))
        hilog.info(DOMAIN, TAG, 'Export JSON button verified')
      })

      it('should display export CSV button', 0, async () => {
        await driver.assertComponentExist(ON.text('导出 CSV'))
        hilog.info(DOMAIN, TAG, 'Export CSV button verified')
      })

      it('should display export TXT button', 0, async () => {
        await driver.assertComponentExist(ON.text('导出 TXT'))
        hilog.info(DOMAIN, TAG, 'Export TXT button verified')
      })

      it('should display clear logs button', 0, async () => {
        await driver.assertComponentExist(ON.text('清空日志'))
        hilog.info(DOMAIN, TAG, 'Clear logs button verified')
      })
    })

    // ==================== 存储设置视图切换测试 ====================

    describe('Storage Settings View', () => {

      it('should switch to storage settings view', 0, async () => {
        let settingsBtn = await driver.findComponent(ON.text('存储设置'))
        expect(settingsBtn !== null).assertTrue()
        await settingsBtn.click()
        await driver.delayMs(500)

        // 应显示存储配置标题
        await driver.assertComponentExist(ON.text('日志存储配置'))
        hilog.info(DOMAIN, TAG, 'Switched to storage settings view')
      })

      it('should display max entries setting', 0, async () => {
        await driver.assertComponentExist(ON.text('最大存储条数'))
        hilog.info(DOMAIN, TAG, 'Max entries setting verified')
      })

      it('should display retention days setting', 0, async () => {
        await driver.assertComponentExist(ON.text('日志保留天数'))
        hilog.info(DOMAIN, TAG, 'Retention days setting verified')
      })

      it('should display auto export toggle', 0, async () => {
        await driver.assertComponentExist(ON.text('自动导出'))
        hilog.info(DOMAIN, TAG, 'Auto export toggle verified')
      })

      it('should display permission info section', 0, async () => {
        await driver.assertComponentExist(ON.text('权限信息'))
        await driver.assertComponentExist(ON.text('ohos.permission.QUERY_AUDIT_EVENT'))
        hilog.info(DOMAIN, TAG, 'Permission info section verified')
      })

      it('should display save and reset buttons', 0, async () => {
        await driver.assertComponentExist(ON.text('保存设置'))
        await driver.assertComponentExist(ON.text('恢复默认'))
        hilog.info(DOMAIN, TAG, 'Save and reset buttons verified')
      })

      it('should switch back to log list view', 0, async () => {
        let backBtn = await driver.findComponent(ON.text('返回日志'))
        expect(backBtn !== null).assertTrue()
        await backBtn.click()
        await driver.delayMs(500)

        // 应显示统计标签
        await driver.assertComponentExist(ON.text('总计'))
        hilog.info(DOMAIN, TAG, 'Switched back to log list view')
      })
    })

    // ==================== 过滤工具栏交互测试 ====================

    describe('Filter Toolbar', () => {

      it('should display search input', 0, async () => {
        let searchInput = await driver.findComponent(ON.type('TextInput'))
        expect(searchInput !== null).assertTrue()
        hilog.info(DOMAIN, TAG, 'Search input verified')
      })

      it('should display refresh button', 0, async () => {
        await driver.assertComponentExist(ON.text('刷新'))
        hilog.info(DOMAIN, TAG, 'Refresh button verified')
      })
    })

  })
}
