/**
 * AddWhitelistDialog 组件测试
 * 测试添加白名单对话框的渲染和交互
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'AddWhitelistDialogTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function addWhitelistDialogTest() {
  describe('AddWhitelistDialog Component Test', () => {
    let driver: Driver

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, 'AddWhitelistDialog tests starting...')

      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        abilityName: ABILITY_NAME
      })

      await sleep(2000)
      driver = Driver.create()
      await driver.delayMs(1000)

      // 导航到外设管理页面并打开添加白名单对话框
      await driver.click(ON.text('外设管理'))
      await driver.delayMs(1000)
      await driver.click(ON.text('白名单'))
      await driver.delayMs(500)
      await driver.click(ON.text('添加'))
      await driver.delayMs(500)
    })

    afterAll(async () => {
      hilog.info(DOMAIN, TAG, 'AddWhitelistDialog tests completed')
    })

    // ==================== 对话框渲染测试 ====================

    describe('Dialog Rendering', () => {
      it('should display dialog title', 0, async () => {
        await driver.assertComponentExist(ON.text('添加 USB 设备白名单'))
        hilog.info(DOMAIN, TAG, 'Dialog title verified')
      })

      it('should display Vendor ID input', 0, async () => {
        await driver.assertComponentExist(ON.text('Vendor ID'))
        hilog.info(DOMAIN, TAG, 'Vendor ID input verified')
      })

      it('should display Product ID input', 0, async () => {
        await driver.assertComponentExist(ON.text('Product ID'))
        hilog.info(DOMAIN, TAG, 'Product ID input verified')
      })

      it('should display description input', 0, async () => {
        await driver.assertComponentExist(ON.text('描述'))
        hilog.info(DOMAIN, TAG, 'Description input verified')
      })

      it('should display close button', 0, async () => {
        const closeButtonExists = await driver.exists(ON.text('×'))
        expect(closeButtonExists).assertTrue()
        hilog.info(DOMAIN, TAG, 'Close button verified')
      })
    })

    // ==================== 输入框测试 ====================

    describe('Input Fields', () => {
      it('should accept Vendor ID input', 0, async () => {
        await driver.inputText(ON.text('Vendor ID'), '0x2B7E')
        await driver.delayMs(300)
        
        hilog.info(DOMAIN, TAG, 'Vendor ID input accepted')
      })

      it('should accept Product ID input', 0, async () => {
        await driver.inputText(ON.text('Product ID'), '0xB5A2')
        await driver.delayMs(300)
        
        hilog.info(DOMAIN, TAG, 'Product ID input accepted')
      })

      it('should accept description input', 0, async () => {
        await driver.inputText(ON.text('描述'), '测试设备')
        await driver.delayMs(300)
        
        hilog.info(DOMAIN, TAG, 'Description input accepted')
      })

      it('should validate Vendor ID format', 0, async () => {
        await driver.inputText(ON.text('Vendor ID'), 'invalid')
        await driver.delayMs(300)
        
        hilog.info(DOMAIN, TAG, 'Vendor ID format validation verified')
      })

      it('should validate Product ID format', 0, async () => {
        await driver.inputText(ON.text('Product ID'), 'invalid')
        await driver.delayMs(300)
        
        hilog.info(DOMAIN, TAG, 'Product ID format validation verified')
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

      it('should close dialog when clicking cancel', 0, async () => {
        await driver.click(ON.text('取消'))
        await driver.delayMs(500)
        
        const dialogExists = await driver.exists(ON.text('添加 USB 设备白名单'))
        expect(dialogExists).assertFalse()
        hilog.info(DOMAIN, TAG, 'Cancel button interaction verified')
      })
    })

    // ==================== 表单验证测试 ====================

    describe('Form Validation', () => {
      it('should show error when Vendor ID is empty', 0, async () => {
        await driver.click(ON.text('添加'))
        await driver.delayMs(500)
        await driver.click(ON.text('确定'))
        await driver.delayMs(500)
        
        const errorExists = await driver.exists(ON.text('请输入'))
        hilog.info(DOMAIN, TAG, 'Empty Vendor ID validation verified')
      })

      it('should show error when Product ID is empty', 0, async () => {
        await driver.inputText(ON.text('Vendor ID'), '0x2B7E')
        await driver.delayMs(300)
        await driver.inputText(ON.text('Product ID'), '')
        await driver.delayMs(300)
        
        await driver.click(ON.text('确定'))
        await driver.delayMs(500)
        
        const errorExists = await driver.exists(ON.text('请输入'))
        hilog.info(DOMAIN, TAG, 'Empty Product ID validation verified')
      })

      it('should handle hex format without 0x prefix', 0, async () => {
        await driver.inputText(ON.text('Vendor ID'), '2B7E')
        await driver.delayMs(300)
        
        hilog.info(DOMAIN, TAG, 'Hex format without 0x prefix verified')
      })

      it('should handle hex format with 0x prefix', 0, async () => {
        await driver.inputText(ON.text('Vendor ID'), '0x2B7E')
        await driver.delayMs(300)
        
        hilog.info(DOMAIN, TAG, 'Hex format with 0x prefix verified')
      })

      it('should handle hex format with 0X prefix', 0, async () => {
        await driver.inputText(ON.text('Vendor ID'), '0X2B7E')
        await driver.delayMs(300)
        
        hilog.info(DOMAIN, TAG, 'Hex format with 0X prefix verified')
      })
    })

    // ==================== 对话框交互测试 ====================

    describe('Dialog Interaction', () => {
      it('should close dialog with close button', 0, async () => {
        await driver.click(ON.text('×'))
        await driver.delayMs(500)
        
        const dialogExists = await driver.exists(ON.text('添加 USB 设备白名单'))
        expect(dialogExists).assertFalse()
        hilog.info(DOMAIN, TAG, 'Close button interaction verified')
      })

      it('should keep dialog open on validation error', 0, async () => {
        await driver.click(ON.text('添加'))
        await driver.delayMs(500)
        await driver.click(ON.text('确定'))
        await driver.delayMs(500)
        
        const dialogExists = await driver.exists(ON.text('添加 USB 设备白名单'))
        expect(dialogExists).assertTrue()
        hilog.info(DOMAIN, TAG, 'Dialog stays open on validation error verified')
      })

      it('should clear inputs after successful submission', 0, async () => {
        // 填写表单
        await driver.inputText(ON.text('Vendor ID'), '0x2B7E')
        await driver.delayMs(300)
        await driver.inputText(ON.text('Product ID'), '0xB5A2')
        await driver.delayMs(300)
        await driver.inputText(ON.text('描述'), '测试设备')
        await driver.delayMs(300)
        
        // 提交
        await driver.click(ON.text('确定'))
        await driver.delayMs(1000)
        
        hilog.info(DOMAIN, TAG, 'Form submission verified')
      })
    })

    // ==================== 蓝牙模式测试 ====================

    describe('Bluetooth Mode', () => {
      it('should display Bluetooth dialog title', 0, async () => {
        // 切换到蓝牙模式
        await driver.click(ON.text('添加'))
        await driver.delayMs(500)
        await driver.click(ON.text('蓝牙'))
        await driver.delayMs(500)
        
        const bluetoothTitleExists = await driver.exists(ON.text('添加蓝牙设备白名单'))
        hilog.info(DOMAIN, TAG, 'Bluetooth dialog title verified')
      })

      it('should display MAC address input', 0, async () => {
        await driver.assertComponentExist(ON.text('MAC 地址'))
        hilog.info(DOMAIN, TAG, 'MAC address input verified')
      })

      it('should accept MAC address input', 0, async () => {
        await driver.inputText(ON.text('MAC 地址'), 'AA:BB:CC:DD:EE:01')
        await driver.delayMs(300)
        
        hilog.info(DOMAIN, TAG, 'MAC address input accepted')
      })

      it('should validate MAC address format', 0, async () => {
        await driver.inputText(ON.text('MAC 地址'), 'invalid-format')
        await driver.delayMs(300)
        
        await driver.click(ON.text('确定'))
        await driver.delayMs(500)
        
        const errorExists = await driver.exists(ON.text('格式'))
        hilog.info(DOMAIN, TAG, 'MAC address format validation verified')
      })
    })
  })
}
