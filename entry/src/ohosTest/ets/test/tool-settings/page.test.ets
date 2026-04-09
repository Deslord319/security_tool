/**
 * Tool settings page smoke test.
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { TestLogUtils } from '../../utils/TestLogUtils'

const TAG = 'ToolSettingsPageTest'
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

export default function toolSettingsPageTest() {
  describe('ToolSettingsPage Test', () => {
    let driver: Driver

    beforeAll(async () => {
      TestLogUtils.info(TAG, 'ToolSettingsPage tests starting...')

      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        moduleName: 'entry',
        abilityName: ABILITY_NAME
      })

      await sleep(1200)
      driver = Driver.create()
      await driver.delayMs(800)

      const toolSettingsNav = await driver.findComponent(ON.text('工具设置'))
      expect(toolSettingsNav !== null).assertTrue()
      await toolSettingsNav!.click()
      await driver.delayMs(800)
    })

    afterAll(async () => {
      TestLogUtils.info(TAG, 'ToolSettingsPage tests completed')
    })

    it('should display title subtitle and save button', 0, async () => {
      await driver.assertComponentExist(ON.text('工具设置'))
      await driver.assertComponentExist(ON.text('保存设置'))
    })

    it('should display startup auth settings', 0, async () => {
      await driver.assertComponentExist(ON.text('启动认证设置'))
      await driver.assertComponentExist(ON.text('启动时身份校验'))
      await driver.assertComponentExist(ON.text('认证方式'))
      await driver.assertComponentExist(ON.text('修改密码'))
    })

    it('should show no changes feedback when saving without edits', 0, async () => {
      const saveButton = await driver.findComponent(ON.text('保存设置'))
      expect(saveButton !== null).assertTrue()
      await saveButton!.click()
      await driver.delayMs(600)

      await driver.assertComponentExist(ON.text('当前没有需要保存的更改'))

      const confirmButton = await driver.findComponent(ON.text('我知道了'))
      expect(confirmButton !== null).assertTrue()
      await confirmButton!.click()
      await driver.delayMs(300)
    })
  })
}
