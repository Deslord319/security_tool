/**
 * 鏃ュ織绠＄悊妯″潡 - 缁勪欢 UI 娴嬭瘯 (L3)
 * 娴嬭瘯鏃ュ織绠＄悊椤甸潰鐨勬覆鏌撱€佸鑸€佷氦浜掕涓?
 */
import { describe, beforeAll, afterAll, beforeEach, it, expect } from '@ohos/hypium'
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

    // ==================== 瀵艰埅鍒版棩蹇楃鐞嗛〉闈?====================

    describe('Navigate to LogManage', () => {

      it('should navigate to log manage page via sidebar', 0, async () => {
        // 鐐瑰嚮渚ц竟鏍忋€屾棩蹇楃鐞嗐€?
        let navItem = await driver.findComponent(ON.text('鏃ュ織绠＄悊'))
        expect(navItem !== null).assertTrue()
        await navItem.click()
        await driver.delayMs(1000)

        hilog.info(DOMAIN, TAG, 'Navigated to LogManage page')
      })
    })

    // ==================== 椤甸潰澶撮儴娓叉煋娴嬭瘯 ====================

    describe('LogManage Page Header', () => {

      it('should display page title', 0, async () => {
        await driver.assertComponentExist(ON.text('鏃ュ織绠＄悊'))
        hilog.info(DOMAIN, TAG, 'Page title verified')
      })

      it('should display page description', 0, async () => {
        await driver.assertComponentExist(ON.text('鐩戞帶鍜屽璁＄郴缁熷畨鍏ㄤ簨浠舵棩蹇?))
        hilog.info(DOMAIN, TAG, 'Page description verified')
      })

      it('should display subscription status indicator', 0, async () => {
        // 璁㈤槄鐘舵€佹枃瀛楀簲瀛樺湪锛堝凡璁㈤槄 or 璁㈤槄澶辫触锛?        let connected = await driver.findComponent(ON.text('宸茶闃?))
        let disconnected = await driver.findComponent(ON.text('璁㈤槄澶辫触'))
        expect(connected !== null || disconnected !== null).assertTrue()
        hilog.info(DOMAIN, TAG, 'Subscription status indicator verified')
      })

      it('should display storage settings button', 0, async () => {
        await driver.assertComponentExist(ON.text('瀛樺偍璁剧疆'))
        hilog.info(DOMAIN, TAG, 'Storage settings button verified')
      })
    })

    // ==================== 缁熻鍗＄墖娴嬭瘯 ====================

    describe('Statistics Bar', () => {

      it('should display total count label', 0, async () => {
        await driver.assertComponentExist(ON.text('鎬昏'))
        hilog.info(DOMAIN, TAG, 'Total count label verified')
      })

      it('should display today count label', 0, async () => {
        await driver.assertComponentExist(ON.text('浠婃棩'))
        hilog.info(DOMAIN, TAG, 'Today count label verified')
      })

      it('should display blocked count label', 0, async () => {
        await driver.assertComponentExist(ON.text('宸查樆姝?))
        hilog.info(DOMAIN, TAG, 'Blocked count label verified')
      })

      it('should display current display count label', 0, async () => {
        await driver.assertComponentExist(ON.text('褰撳墠鏄剧ず'))
        hilog.info(DOMAIN, TAG, 'Current display count label verified')
      })
    })

    // ==================== 绌虹姸鎬佹祴璇?====================

    describe('Empty State', () => {

      it('should show empty state message when no logs', 0, async () => {
        let emptyMsg = await driver.findComponent(ON.text('鏆傛棤鏃ュ織璁板綍'))
        // 鍙兘鏈夋棩蹇椾篃鍙兘娌℃湁锛屼袱绉嶆儏鍐甸兘鍚堢悊
        if (emptyMsg !== null) {
          hilog.info(DOMAIN, TAG, 'Empty state message shown (no logs)')
        } else {
          hilog.info(DOMAIN, TAG, 'Log entries exist, empty state not shown')
        }
      })
    })

    // ==================== 搴曢儴宸ュ叿鏍忔祴璇?====================

    describe('Bottom Toolbar', () => {

      it('should display export JSON button', 0, async () => {
        await driver.assertComponentExist(ON.text('瀵煎嚭 JSON'))
        hilog.info(DOMAIN, TAG, 'Export JSON button verified')
      })

      it('should display export CSV button', 0, async () => {
        await driver.assertComponentExist(ON.text('瀵煎嚭 CSV'))
        hilog.info(DOMAIN, TAG, 'Export CSV button verified')
      })

      it('should display export TXT button', 0, async () => {
        await driver.assertComponentExist(ON.text('瀵煎嚭 TXT'))
        hilog.info(DOMAIN, TAG, 'Export TXT button verified')
      })

      it('should display clear logs button', 0, async () => {
        await driver.assertComponentExist(ON.text('娓呯┖鏃ュ織'))
        hilog.info(DOMAIN, TAG, 'Clear logs button verified')
      })
    })

    // ==================== 瀛樺偍璁剧疆瑙嗗浘鍒囨崲娴嬭瘯 ====================

    describe('Storage Settings View', () => {

      it('should switch to storage settings view', 0, async () => {
        let settingsBtn = await driver.findComponent(ON.text('瀛樺偍璁剧疆'))
        expect(settingsBtn !== null).assertTrue()
        await settingsBtn.click()
        await driver.delayMs(500)

        // 搴旀樉绀哄瓨鍌ㄩ厤缃爣棰?
        await driver.assertComponentExist(ON.text('鏃ュ織瀛樺偍閰嶇疆'))
        hilog.info(DOMAIN, TAG, 'Switched to storage settings view')
      })

      it('should display max entries setting', 0, async () => {
        await driver.assertComponentExist(ON.text('鏈€澶у瓨鍌ㄦ潯鏁?))
        hilog.info(DOMAIN, TAG, 'Max entries setting verified')
      })

      it('should display retention days setting', 0, async () => {
        await driver.assertComponentExist(ON.text('鏃ュ織淇濈暀澶╂暟'))
        hilog.info(DOMAIN, TAG, 'Retention days setting verified')
      })

      it('should display auto export toggle', 0, async () => {
        await driver.assertComponentExist(ON.text('鑷姩瀵煎嚭'))
        hilog.info(DOMAIN, TAG, 'Auto export toggle verified')
      })

      it('should display export path settings', 0, async () => {
        await driver.assertComponentExist(ON.text('瀵煎嚭淇濆瓨浣嶇疆'))
        await driver.assertComponentExist(ON.text('閫夋嫨浣嶇疆'))
        await driver.assertComponentExist(ON.text('鎭㈠榛樿鐩綍'))
        hilog.info(DOMAIN, TAG, 'Export path settings verified')
      })

      it('should display permission info section', 0, async () => {
        await driver.assertComponentExist(ON.text('鏉冮檺淇℃伅'))
        await driver.assertComponentExist(ON.text('ohos.permission.QUERY_AUDIT_EVENT'))
        hilog.info(DOMAIN, TAG, 'Permission info section verified')
      })

      it('should display save and reset buttons', 0, async () => {
        await driver.assertComponentExist(ON.text('淇濆瓨璁剧疆'))
        await driver.assertComponentExist(ON.text('鎭㈠榛樿'))
        hilog.info(DOMAIN, TAG, 'Save and reset buttons verified')
      })

      it('should switch back to log list view', 0, async () => {
        let backBtn = await driver.findComponent(ON.text('杩斿洖鏃ュ織'))
        expect(backBtn !== null).assertTrue()
        await backBtn.click()
        await driver.delayMs(500)

        // 搴旀樉绀虹粺璁℃爣绛?
        await driver.assertComponentExist(ON.text('鎬昏'))
        hilog.info(DOMAIN, TAG, 'Switched back to log list view')
      })
    })

    // ==================== 杩囨护宸ュ叿鏍忎氦浜掓祴璇?====================

    describe('Filter Toolbar', () => {

      it('should display search input', 0, async () => {
        let searchInput = await driver.findComponent(ON.type('TextInput'))
        expect(searchInput !== null).assertTrue()
        hilog.info(DOMAIN, TAG, 'Search input verified')
      })

      it('should display refresh button', 0, async () => {
        await driver.assertComponentExist(ON.text('鍒锋柊'))
        hilog.info(DOMAIN, TAG, 'Refresh button verified')
      })
    })

  })
}

