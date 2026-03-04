/**
 * Dashboard 妯″潡 - 缁勪欢 UI 娴嬭瘯
 * 娴嬭瘯 Dashboard 椤甸潰涓婄殑缁熻鍗＄墖銆佸揩鎹峰姛鑳藉尯鍜屼晶杈规爮瀵艰埅娓叉煋
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
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

      // 鍚姩涓诲簲鐢?
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        abilityName: ABILITY_NAME
      })

      // 绛夊緟搴旂敤鍚姩瀹屾垚
      await sleep(2000)

      // 鍒涘缓 UI 椹卞姩
      driver = Driver.create()
      await driver.delayMs(1000)
    })

    afterAll(async () => {
      hilog.info(DOMAIN, TAG, 'Dashboard component tests completed')
    })

    // ==================== Dashboard 椤甸潰娓叉煋娴嬭瘯 ====================

    describe('Dashboard Page Rendering', () => {
      it('should display app title', 0, async () => {
        await driver.assertComponentExist(ON.text('瀹夊叏绠＄悊涓績'))
        hilog.info(DOMAIN, TAG, 'App title verified')
      })

      it('should display dashboard page title', 0, async () => {
        await driver.assertComponentExist(ON.text('瀹夊叏鎬昏'))
        hilog.info(DOMAIN, TAG, 'Dashboard title verified')
      })

      it('should display firewall status card', 0, async () => {
        await driver.assertComponentExist(ON.text('闃茬伀澧欑姸鎬?))
        hilog.info(DOMAIN, TAG, 'Firewall status card verified')
      })

      it('should display audit events card', 0, async () => {
        await driver.assertComponentExist(ON.text('浠婃棩瀹¤浜嬩欢'))
        hilog.info(DOMAIN, TAG, 'Audit events card verified')
      })

      it('should display connected devices card', 0, async () => {
        await driver.assertComponentExist(ON.text('宸查樆鏂簨浠?))
        hilog.info(DOMAIN, TAG, 'Connected devices card verified')
      })

      it('should display identity policy card', 0, async () => {
        await driver.assertComponentExist(ON.text('鏃ュ織鎬婚噺'))
        hilog.info(DOMAIN, TAG, 'Identity policy card verified')
      })
    })

    // ==================== 蹇嵎鍔熻兘鍖烘祴璇?====================

    describe('Quick Actions Section', () => {
      it('should display quick actions title', 0, async () => {
        await driver.assertComponentExist(ON.text('蹇嵎鍔熻兘'))
        hilog.info(DOMAIN, TAG, 'Quick actions title verified')
      })

      it('should display firewall management card', 0, async () => {
        await driver.assertComponentExist(ON.text('闃茬伀澧欑鐞?))
        hilog.info(DOMAIN, TAG, 'Firewall management card verified')
      })

      it('should display log management card', 0, async () => {
        await driver.assertComponentExist(ON.text('鏃ュ織绠＄悊'))
        hilog.info(DOMAIN, TAG, 'Log management card verified')
      })

      it('should display peripheral management card', 0, async () => {
        await driver.assertComponentExist(ON.text('澶栬绠＄悊'))
        hilog.info(DOMAIN, TAG, 'Peripheral management card verified')
      })
    })

    // ==================== 渚ц竟鏍忓鑸祴璇?====================

    describe('Sidebar Navigation', () => {
      it('should display sidebar nav items', 0, async () => {
        await driver.assertComponentExist(ON.text('鎬昏'))
        await driver.assertComponentExist(ON.text('闃茬伀澧?))
        await driver.assertComponentExist(ON.text('鏃ュ織绠＄悊'))
        hilog.info(DOMAIN, TAG, 'Sidebar nav items verified')
      })
    })

  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

