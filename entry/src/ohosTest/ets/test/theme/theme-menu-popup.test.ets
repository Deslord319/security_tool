/**
 * Theme menu popup smoke test.
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'ThemeMenuPopupTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function themeMenuPopupTest() {
  describe('ThemeMenuPopup Component Test', () => {
    let driver: Driver

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, 'ThemeMenuPopup tests starting...')
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
      hilog.info(DOMAIN, TAG, 'ThemeMenuPopup tests completed')
    })

    it('should open popup when clicking trigger', 0, async () => {
      await driver.click(ON.id('top-menu-trigger'))
      await driver.delayMs(500)
      const popupExists = await driver.exists(ON.text('显示模式'))
      expect(popupExists).assertTrue()
    })

    it('should display theme and action entries', 0, async () => {
      await driver.assertComponentExist(ON.text('显示模式'))
      await driver.assertComponentExist(ON.text('跟随系统'))
      await driver.assertComponentExist(ON.text('浅色模式'))
      await driver.assertComponentExist(ON.text('深色模式'))
      await driver.assertComponentExist(ON.text('帮助与反馈'))
      await driver.assertComponentExist(ON.text('关于'))
    })

    it('should switch theme by menu id', 0, async () => {
      await driver.click(ON.id('theme-option-light'))
      await driver.delayMs(1000)
      const lightThemeMarker = await driver.exists(ON.id('theme-marker-light'))
      expect(lightThemeMarker).assertTrue()

      await driver.click(ON.id('top-menu-trigger'))
      await driver.delayMs(500)
      await driver.click(ON.id('theme-option-dark'))
      await driver.delayMs(1000)
      const darkThemeMarker = await driver.exists(ON.id('theme-marker-dark'))
      expect(darkThemeMarker).assertTrue()
    })
  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
