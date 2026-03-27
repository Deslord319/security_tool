/**
 * ToolSettingsPage 页面冒烟测试
 * 只覆盖当前真实能力，避免历史设计残留持续误导重构。
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'ToolSettingsPageTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

export default function toolSettingsPageTest() {
  describe('ToolSettingsPage Test', () => {
    let driver: Driver

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, 'ToolSettingsPage tests starting...')

      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        moduleName: 'entry',
        abilityName: ABILITY_NAME,
        parameters: {
          skip_startup_auth: 'true'
        }
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
      hilog.info(DOMAIN, TAG, 'ToolSettingsPage tests completed')
    })

    describe('Page Header', () => {
      it('should display title subtitle and save button', 0, async () => {
        await driver.assertComponentExist(ON.text('工具设置'))
        await driver.assertComponentExist(ON.text('配置启动认证与系统密码修改入口等工具级安全能力'))
        await driver.assertComponentExist(ON.text('保存设置'))
      })
    })

    describe('Current Capabilities', () => {
      it('should display startup auth card content', 0, async () => {
        await driver.assertComponentExist(ON.text('启动认证设置'))
        await driver.assertComponentExist(ON.text('启动时身份校验'))
        await driver.assertComponentExist(ON.text('开启后，进入工具前需要先完成系统认证'))
        await driver.assertComponentExist(ON.text('认证方式'))
        await driver.assertComponentExist(ON.text('选择启动时身份校验使用的系统认证方式'))
        await driver.assertComponentExist(ON.text('修改密码'))
        await driver.assertComponentExist(ON.text('打开系统设置中的“生物识别和密码”，修改系统 PIN/密码'))
      })

      it('should render current auth controls', 0, async () => {
        const toggle = await driver.findComponent(ON.type('Toggle'))
        const select = await driver.findComponent(ON.type('Select'))
        const hasPin = await driver.exists(ON.text('PIN'))
        const hasFingerprint = await driver.exists(ON.text('指纹'))

        expect(toggle !== null).assertTrue()
        expect(select !== null).assertTrue()
        expect(hasPin || hasFingerprint).assertTrue()
      })

      it('should not render legacy password form fields', 0, async () => {
        const currentPassword = await driver.exists(ON.text('当前密码'))
        const newPassword = await driver.exists(ON.text('新密码'))
        const confirmPassword = await driver.exists(ON.text('确认密码'))

        expect(currentPassword).assertFalse()
        expect(newPassword).assertFalse()
        expect(confirmPassword).assertFalse()
      })
    })

    describe('Save Feedback', () => {
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
  })
}
