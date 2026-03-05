/**
 * 鏃ュ織绠＄悊妯″潡 - E2E 娴佺▼娴嬭瘯 (L4)
 * 娴嬭瘯鏃ュ織绠＄悊妯″潡鐨勫畬鏁寸敤鎴锋祦绋?
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

    // ==================== 瀹屾暣瀵艰埅娴佺▼ ====================

    describe('Full navigation flow', () => {

      it('should start from dashboard', 0, async () => {
        await driver.assertComponentExist(ON.text('瀹夊叏鎬昏'))
        hilog.info(DOMAIN, TAG, 'Starting from dashboard')
      })

      it('should navigate to log manage via sidebar', 0, async () => {
        let navItem = await driver.findComponent(ON.text('鏃ュ織绠＄悊'))
        expect(navItem !== null).assertTrue()
        await navItem.click()
        await driver.delayMs(1000)

        // 楠岃瘉椤甸潰鏍囬
        await driver.assertComponentExist(ON.text('鐩戞帶鍜屽璁＄郴缁熷畨鍏ㄤ簨浠舵棩蹇?))
        hilog.info(DOMAIN, TAG, 'Navigated to log manage page')
      })
    })

    // ==================== 鏃ュ織鏌ョ湅娴佺▼ ====================

    describe('Log viewing flow', () => {

      it('should display statistics bar', 0, async () => {
        await driver.assertComponentExist(ON.text('鎬昏'))
        await driver.assertComponentExist(ON.text('浠婃棩'))
        await driver.assertComponentExist(ON.text('宸查樆姝?))
        hilog.info(DOMAIN, TAG, 'Statistics bar displayed')
      })

      it('should show refresh button and click it', 0, async () => {
        let refreshBtn = await driver.findComponent(ON.text('鍒锋柊'))
        expect(refreshBtn !== null).assertTrue()
        await refreshBtn.click()
        await driver.delayMs(500)
        hilog.info(DOMAIN, TAG, 'Refresh clicked successfully')
      })
    })

    // ==================== 瀛樺偍璁剧疆瀹屾暣娴佺▼ ====================

    describe('Storage settings flow', () => {

      it('should open storage settings', 0, async () => {
        let settingsBtn = await driver.findComponent(ON.text('瀛樺偍璁剧疆'))
        expect(settingsBtn !== null).assertTrue()
        await settingsBtn.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('鏃ュ織瀛樺偍閰嶇疆'))
        hilog.info(DOMAIN, TAG, 'Storage settings opened')
      })

      it('should display all configuration options', 0, async () => {
        await driver.assertComponentExist(ON.text('鏈€澶у瓨鍌ㄦ潯鏁?))
        await driver.assertComponentExist(ON.text('鏃ュ織淇濈暀澶╂暟'))
        await driver.assertComponentExist(ON.text('鑷姩瀵煎嚭'))
        await driver.assertComponentExist(ON.text('瀵煎嚭淇濆瓨浣嶇疆'))
        hilog.info(DOMAIN, TAG, 'All config options displayed')
      })

      it('should display permission info', 0, async () => {
        await driver.assertComponentExist(ON.text('鏉冮檺淇℃伅'))
        await driver.assertComponentExist(ON.text('ohos.permission.QUERY_AUDIT_EVENT'))
        await driver.assertComponentExist(ON.text('订阅模式'))
        hilog.info(DOMAIN, TAG, 'Permission info displayed')
      })

      it('should save settings successfully', 0, async () => {
        let saveBtn = await driver.findComponent(ON.text('淇濆瓨璁剧疆'))
        expect(saveBtn !== null).assertTrue()
        await saveBtn.click()
        await driver.delayMs(1000)
        hilog.info(DOMAIN, TAG, 'Settings saved')
      })

      it('should navigate back to log list', 0, async () => {
        let backBtn = await driver.findComponent(ON.text('杩斿洖鏃ュ織'))
        expect(backBtn !== null).assertTrue()
        await backBtn.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('鎬昏'))
        hilog.info(DOMAIN, TAG, 'Navigated back to log list')
      })
    })

    // ==================== 瀵煎嚭娴佺▼ ====================

    describe('Export flow', () => {

      it('should trigger JSON export', 0, async () => {
        let exportBtn = await driver.findComponent(ON.text('瀵煎嚭 JSON'))
        expect(exportBtn !== null).assertTrue()
        await exportBtn.click()
        await driver.delayMs(1000)
        let detailDialog = await driver.findComponent(ON.text('瀵煎嚭璇︽儏'))
        let noDataToast = await driver.findComponent(ON.text('娌℃湁鍙鍑虹殑鏃ュ織'))
        expect(detailDialog !== null || noDataToast !== null).assertTrue()
        hilog.info(DOMAIN, TAG, 'JSON export triggered')
      })

      it('should trigger CSV export', 0, async () => {
        let exportBtn = await driver.findComponent(ON.text('瀵煎嚭 CSV'))
        expect(exportBtn !== null).assertTrue()
        await exportBtn.click()
        await driver.delayMs(500)
        hilog.info(DOMAIN, TAG, 'CSV export triggered')
      })
    })

    // ==================== 璺ㄦā鍧楀鑸?====================

    describe('Cross-module navigation', () => {

      it('should navigate from log manage to other modules and back', 0, async () => {
        // 鍏堝埌闃茬伀澧?
        let firewallNav = await driver.findComponent(ON.text('闃茬伀澧?))
        expect(firewallNav !== null).assertTrue()
        await firewallNav.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('闃茬伀澧?))

        // 鍐嶅洖鍒版棩蹇楃鐞?
        let logNav = await driver.findComponent(ON.text('鏃ュ織绠＄悊'))
        expect(logNav !== null).assertTrue()
        await logNav.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('鐩戞帶鍜屽璁＄郴缁熷畨鍏ㄤ簨浠舵棩蹇?))
        hilog.info(DOMAIN, TAG, 'Cross-module navigation successful')
      })

      it('should navigate back to dashboard at the end', 0, async () => {
        let dashNav = await driver.findComponent(ON.text('鎬昏'))
        expect(dashNav !== null).assertTrue()
        await dashNav.click()
        await driver.delayMs(500)

        await driver.assertComponentExist(ON.text('瀹夊叏鎬昏'))
        hilog.info(DOMAIN, TAG, 'Back to dashboard, flow test complete')
      })
    })

  })
}

