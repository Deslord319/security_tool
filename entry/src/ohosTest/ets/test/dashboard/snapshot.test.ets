/**
 * Dashboard 妯″潡 - 椤甸潰蹇収娴嬭瘯
 * 楠岃瘉 Dashboard 椤甸潰鐨勬暣浣撳竷灞€鍜屽厓绱犳覆鏌?
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
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
        hilog.info(DOMAIN, TAG, 'Verifying dashboard layout...')

        await driver.assertComponentExist(ON.text('瀹夊叏绠＄悊涓績'))
        await driver.assertComponentExist(ON.text('瀹夊叏鎬昏'))
        await driver.assertComponentExist(ON.text('蹇嵎鍔熻兘'))

        hilog.info(DOMAIN, TAG, 'Dashboard layout verified')
      })

      it('should render all stat cards', 0, async () => {
        hilog.info(DOMAIN, TAG, 'Verifying stat cards...')

        await driver.assertComponentExist(ON.text('闃茬伀澧欑姸鎬?))
        await driver.assertComponentExist(ON.text('浠婃棩瀹¤浜嬩欢'))
        await driver.assertComponentExist(ON.text('宸查樆鏂簨浠?))
        await driver.assertComponentExist(ON.text('鏃ュ織鎬婚噺'))

        hilog.info(DOMAIN, TAG, 'All stat cards verified')
      })

      it('should render all quick action cards', 0, async () => {
        hilog.info(DOMAIN, TAG, 'Verifying quick action cards...')

        await driver.assertComponentExist(ON.text('闃茬伀澧欑鐞?))
        await driver.assertComponentExist(ON.text('鏃ュ織绠＄悊'))
        await driver.assertComponentExist(ON.text('澶栬绠＄悊'))
        await driver.assertComponentExist(ON.text('韬唤閴村埆'))
        await driver.assertComponentExist(ON.text('闃茬伀澧欒鍒?))
        await driver.assertComponentExist(ON.text('宸ュ叿璁剧疆'))

        hilog.info(DOMAIN, TAG, 'All quick action cards verified')
      })
    })

  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

