/**
 * Theme menu popup smoke test.
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { TestLogUtils } from '../../utils/TestLogUtils'
import { clickById, clickByText, existsById, existsByText, safeDelay, sleep } from '../../utils/TestDriverUtils'

const TAG = 'ThemeMenuPopupTest'
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function themeMenuPopupTest() {
  describe('ThemeMenuPopup Component Test', () => {
    let driver: Driver

    beforeAll(async () => {
      TestLogUtils.info(TAG, 'ThemeMenuPopup tests starting...')
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        moduleName: 'entry',
        abilityName: ABILITY_NAME
      })
      await sleep(2000)
      driver = Driver.create()
      await driver.delayMs(1000)
    })

    afterAll(async () => {
      TestLogUtils.info(TAG, 'ThemeMenuPopup tests completed')
    })

    it('should open popup when clicking trigger', 0, async () => {
      const opened = await ensureMenuOpen(driver)
      expect(opened).assertTrue()
      const popupExists = await existsByText(driver, '显示模式')
      expect(popupExists).assertTrue()
    })

    it('should display theme and action entries', 0, async () => {
      const opened = await ensureMenuOpen(driver)
      expect(opened).assertTrue()
      await driver.assertComponentExist(ON.text('显示模式'))
      await driver.assertComponentExist(ON.text('跟随系统'))
      await driver.assertComponentExist(ON.text('浅色模式'))
      await driver.assertComponentExist(ON.text('深色模式'))
      await driver.assertComponentExist(ON.text('帮助与反馈'))
      await driver.assertComponentExist(ON.text('关于'))
    })

    it('should open about dialog and display app version', 0, async () => {
      const opened = await ensureMenuOpen(driver)
      expect(opened).assertTrue()

      const aboutClicked = await clickByText(driver, '关于')
      expect(aboutClicked).assertTrue()
      await safeDelay(driver, 500)

      const versionExists = await existsByText(driver, '版本 1.0.6')
      expect(versionExists).assertTrue()

      const confirmClicked = await clickByText(driver, '确定')
      expect(confirmClicked).assertTrue()
      await safeDelay(driver, 300)
    })

    it('should switch theme by menu id', 0, async () => {
      let opened = await ensureMenuOpen(driver)
      expect(opened).assertTrue()

      let lightClicked = await clickById(driver, 'theme-option-light')
      expect(lightClicked).assertTrue()
      await driver.delayMs(1000)
      const lightThemeMarker = await existsById(driver, 'theme-marker-light')
      expect(lightThemeMarker).assertTrue()

      opened = await ensureMenuOpen(driver)
      expect(opened).assertTrue()
      let darkClicked = await clickById(driver, 'theme-option-dark')
      expect(darkClicked).assertTrue()
      await driver.delayMs(1000)
      const darkThemeMarker = await existsById(driver, 'theme-marker-dark')
      expect(darkThemeMarker).assertTrue()
    })
  })
}

async function ensureMenuOpen(driver: Driver): Promise<boolean> {
  if (await existsByText(driver, '显示模式')) {
    return true
  }
  const clicked = await clickById(driver, 'top-menu-trigger')
  if (!clicked) {
    return false
  }
  await safeDelay(driver, 500)
  return await existsByText(driver, '显示模式')
}
