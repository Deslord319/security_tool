/**
 * Dashboard 模块 - 组件 UI 测试
 * 测试 Dashboard 页面上的统计卡片、快捷功能区和侧边栏导航渲染
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'DashboardComponentTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.example.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function dashboardComponentTest() {
  describe('Dashboard Component UI Test', () => {
    let driver: Driver

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, 'Dashboard component tests starting...')

      // 启动主应用
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        abilityName: ABILITY_NAME
      })

      // 等待应用启动完成
      await sleep(2000)

      // 创建 UI 驱动
      driver = Driver.create()
      await driver.delayMs(1000)
    })

    afterAll(async () => {
      hilog.info(DOMAIN, TAG, 'Dashboard component tests completed')
    })

    // ==================== Dashboard 页面渲染测试 ====================

    describe('Dashboard Page Rendering', () => {
      it('should display app title', 0, async () => {
        await driver.assertComponentExist(ON.text('安全管理中心'))
        hilog.info(DOMAIN, TAG, 'App title verified')
      })

      it('should display dashboard page title', 0, async () => {
        await driver.assertComponentExist(ON.text('安全总览'))
        hilog.info(DOMAIN, TAG, 'Dashboard title verified')
      })

      it('should display firewall status card', 0, async () => {
        await driver.assertComponentExist(ON.text('防火墙状态'))
        hilog.info(DOMAIN, TAG, 'Firewall status card verified')
      })

      it('should display audit events card', 0, async () => {
        await driver.assertComponentExist(ON.text('今日审计事件'))
        hilog.info(DOMAIN, TAG, 'Audit events card verified')
      })

      it('should display connected devices card', 0, async () => {
        await driver.assertComponentExist(ON.text('已连接外设'))
        hilog.info(DOMAIN, TAG, 'Connected devices card verified')
      })

      it('should display identity policy card', 0, async () => {
        await driver.assertComponentExist(ON.text('身份策略状态'))
        hilog.info(DOMAIN, TAG, 'Identity policy card verified')
      })
    })

    // ==================== 快捷功能区测试 ====================

    describe('Quick Actions Section', () => {
      it('should display quick actions title', 0, async () => {
        await driver.assertComponentExist(ON.text('快捷功能'))
        hilog.info(DOMAIN, TAG, 'Quick actions title verified')
      })

      it('should display firewall management card', 0, async () => {
        await driver.assertComponentExist(ON.text('防火墙管理'))
        hilog.info(DOMAIN, TAG, 'Firewall management card verified')
      })

      it('should display log management card', 0, async () => {
        await driver.assertComponentExist(ON.text('日志管理'))
        hilog.info(DOMAIN, TAG, 'Log management card verified')
      })

      it('should display peripheral management card', 0, async () => {
        await driver.assertComponentExist(ON.text('外设管理'))
        hilog.info(DOMAIN, TAG, 'Peripheral management card verified')
      })
    })

    // ==================== 侧边栏导航测试 ====================

    describe('Sidebar Navigation', () => {
      it('should display sidebar nav items', 0, async () => {
        await driver.assertComponentExist(ON.text('总览'))
        await driver.assertComponentExist(ON.text('防火墙'))
        await driver.assertComponentExist(ON.text('日志管理'))
        hilog.info(DOMAIN, TAG, 'Sidebar nav items verified')
      })
    })

  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
