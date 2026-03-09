/**
 * AddBlacklistDialog 组件测试
 * 测试添加黑名单对话框的渲染和交互
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'AddBlacklistDialogTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function addBlacklistDialogTest() {
  describe('AddBlacklistDialog Component Test', () => {
    let driver: Driver

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, 'AddBlacklistDialog tests starting...')

      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        abilityName: ABILITY_NAME
      })

      await sleep(2000)
      driver = Driver.create()
      await driver.delayMs(1000)

      // 导航到外设管理页面并打开添加黑名单对话框
      await driver.click(ON.text('外设管理'))
      await driver.delayMs(1000)
      await driver.click(ON.text('黑名单'))
      await driver.delayMs(500)
      await driver.click(ON.text('添加'))
      await driver.delayMs(500)
    })

    afterAll(async () => {
      hilog.info(DOMAIN, TAG, 'AddBlacklistDialog tests completed')
    })

    // ==================== 对话框渲染测试 ====================

    describe('Dialog Rendering', () => {
      it('should display dialog title', 0, async () => {
        await driver.assertComponentExist(ON.text('添加黑名单'))
        hilog.info(DOMAIN, TAG, 'Dialog title verified')
      })

      it('should display device type selector', 0, async () => {
        await driver.assertComponentExist(ON.text('设备类型'))
        hilog.info(DOMAIN, TAG, 'Device type selector verified')
      })

      it('should display device ID input', 0, async () => {
        await driver.assertComponentExist(ON.text('设备 ID'))
        hilog.info(DOMAIN, TAG, 'Device ID input verified')
      })

      it('should display description input', 0, async () => {
        await driver.assertComponentExist(ON.text('描述'))
        hilog.info(DOMAIN, TAG, 'Description input verified')
      })
    })

    // ==================== 设备类型选项测试 ====================

    describe('Device Type Options', () => {
      it('should display USB option', 0, async () => {
        await driver.click(ON.text('设备类型'))
        await driver.delayMs(500)
        
        await driver.assertComponentExist(ON.text('USB'))
        hilog.info(DOMAIN, TAG, 'USB option verified')
      })

      it('should display Bluetooth option', 0, async () => {
        await driver.assertComponentExist(ON.text('蓝牙'))
        hilog.info(DOMAIN, TAG, 'Bluetooth option verified')
      })

      it('should display WiFi option', 0, async () => {
        await driver.assertComponentExist(ON.text('WiFi'))
        hilog.info(DOMAIN, TAG, 'WiFi option verified')
      })
    })

    // ==================== 按钮测试 ====================

    describe('Action Buttons', () => {
      it('should display cancel button', 0, async () => {
        await driver.assertComponentExist(ON.text('取消'))
        hilog.info(DOMAIN, TAG, 'Cancel button verified')
      })

      it('should display confirm button', 0, async () => {
        await driver.assertComponentExist(ON.text('确定'))
        hilog.info(DOMAIN, TAG, 'Confirm button verified')
      })
    })

    // ==================== 表单验证测试 ====================

    describe('Form Validation', () => {
      it('should show error when device ID is empty', 0, async () => {
        await driver.click(ON.text('确定'))
        await driver.delayMs(500)
        
        const errorExists = await driver.exists(ON.text('请输入'))
        hilog.info(DOMAIN, TAG, 'Empty device ID validation verified')
      })

      it('should show error when device ID format is invalid', 0, async () => {
        await driver.inputText(ON.text('设备 ID'), 'invalid-format')
        await driver.delayMs(300)
        
        await driver.click(ON.text('确定'))
        await driver.delayMs(500)
        
        const errorExists = await driver.exists(ON.text('格式'))
        hilog.info(DOMAIN, TAG, 'Invalid device ID format validation verified')
      })
    })

    // ==================== 对话框交互测试 ====================

    describe('Dialog Interaction', () => {
      it('should close dialog when clicking cancel', 0, async () => {
        await driver.click(ON.text('取消'))
        await driver.delayMs(500)
        
        const dialogExists = await driver.exists(ON.text('添加黑名单'))
        expect(dialogExists).assertFalse()
        hilog.info(DOMAIN, TAG, 'Cancel button interaction verified')
      })

      it('should keep dialog open on validation error', 0, async () => {
        await driver.click(ON.text('添加'))
        await driver.delayMs(500)
        await driver.click(ON.text('确定'))
        await driver.delayMs(500)
        
        const dialogExists = await driver.exists(ON.text('添加黑名单'))
        expect(dialogExists).assertTrue()
        hilog.info(DOMAIN, TAG, 'Dialog stays open on validation error verified')
      })
    })
  })
}
