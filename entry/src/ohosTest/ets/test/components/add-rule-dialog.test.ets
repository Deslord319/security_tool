/**
 * AddRuleDialog 组件测试
 * 测试防火墙规则添加对话框的渲染和交互
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'AddRuleDialogTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function addRuleDialogTest() {
  describe('AddRuleDialog Component Test', () => {
    let driver: Driver

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, 'AddRuleDialog tests starting...')

      // 启动主应用
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        abilityName: ABILITY_NAME
      })

      // 等待应用启动完成
      await sleep(2000)

      // 创建 UI 驱动
      driver = Driver.create()
      await driver.delayMs(1000)
    })

    afterAll(async () => {
      hilog.info(DOMAIN, TAG, 'AddRuleDialog tests completed')
    })

    // ==================== 对话框渲染测试 ====================

    describe('Dialog Rendering', () => {
      it('should display dialog title', 0, async () => {
        await driver.assertComponentExist(ON.text('添加规则'))
        hilog.info(DOMAIN, TAG, 'Dialog title verified')
      })

      it('should display rule type selector', 0, async () => {
        await driver.assertComponentExist(ON.text('规则类型'))
        hilog.info(DOMAIN, TAG, 'Rule type selector verified')
      })

      it('should display rule name input', 0, async () => {
        await driver.assertComponentExist(ON.text('规则名称'))
        hilog.info(DOMAIN, TAG, 'Rule name input verified')
      })

      it('should display address input', 0, async () => {
        await driver.assertComponentExist(ON.text('地址'))
        hilog.info(DOMAIN, TAG, 'Address input verified')
      })

      it('should display port input', 0, async () => {
        await driver.assertComponentExist(ON.text('端口'))
        hilog.info(DOMAIN, TAG, 'Port input verified')
      })

      it('should display protocol selector', 0, async () => {
        await driver.assertComponentExist(ON.text('协议'))
        hilog.info(DOMAIN, TAG, 'Protocol selector verified')
      })

      it('should display action selector', 0, async () => {
        await driver.assertComponentExist(ON.text('动作'))
        hilog.info(DOMAIN, TAG, 'Action selector verified')
      })

      it('should display direction selector', 0, async () => {
        await driver.assertComponentExist(ON.text('方向'))
        hilog.info(DOMAIN, TAG, 'Direction selector verified')
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

    // ==================== 规则类型选项测试 ====================

    describe('Rule Type Options', () => {
      it('should display IP option', 0, async () => {
        // 打开规则类型选择器
        await driver.click(ON.text('规则类型'))
        await driver.delayMs(500)
        
        await driver.assertComponentExist(ON.text('IP'))
        hilog.info(DOMAIN, TAG, 'IP option verified')
      })

      it('should display Domain option', 0, async () => {
        await driver.assertComponentExist(ON.text('域名'))
        hilog.info(DOMAIN, TAG, 'Domain option verified')
      })

      it('should display DNS option', 0, async () => {
        await driver.assertComponentExist(ON.text('DNS'))
        hilog.info(DOMAIN, TAG, 'DNS option verified')
      })
    })

    // ==================== 协议选项测试 ====================

    describe('Protocol Options', () => {
      it('should display ALL option', 0, async () => {
        await driver.click(ON.text('协议'))
        await driver.delayMs(500)
        
        await driver.assertComponentExist(ON.text('ALL'))
        hilog.info(DOMAIN, TAG, 'ALL protocol option verified')
      })

      it('should display TCP option', 0, async () => {
        await driver.assertComponentExist(ON.text('TCP'))
        hilog.info(DOMAIN, TAG, 'TCP protocol option verified')
      })

      it('should display UDP option', 0, async () => {
        await driver.assertComponentExist(ON.text('UDP'))
        hilog.info(DOMAIN, TAG, 'UDP protocol option verified')
      })
    })

    // ==================== 动作选项测试 ====================

    describe('Action Options', () => {
      it('should display Allow option', 0, async () => {
        await driver.click(ON.text('动作'))
        await driver.delayMs(500)
        
        await driver.assertComponentExist(ON.text('允许'))
        hilog.info(DOMAIN, TAG, 'Allow action verified')
      })

      it('should display Deny option', 0, async () => {
        await driver.assertComponentExist(ON.text('拒绝'))
        hilog.info(DOMAIN, TAG, 'Deny action verified')
      })
    })

    // ==================== 方向选项测试 ====================

    describe('Direction Options', () => {
      it('should display Inbound option', 0, async () => {
        await driver.click(ON.text('方向'))
        await driver.delayMs(500)
        
        await driver.assertComponentExist(ON.text('入站'))
        hilog.info(DOMAIN, TAG, 'Inbound direction verified')
      })

      it('should display Outbound option', 0, async () => {
        await driver.assertComponentExist(ON.text('出站'))
        hilog.info(DOMAIN, TAG, 'Outbound direction verified')
      })
    })

    // ==================== 表单验证测试 ====================

    describe('Form Validation', () => {
      it('should show error when rule name is empty', 0, async () => {
        // 清空规则名称
        await driver.clearText(ON.text('规则名称'))
        await driver.delayMs(300)
        
        // 点击确定
        await driver.click(ON.text('确定'))
        await driver.delayMs(500)
        
        // 应该显示错误提示
        await driver.assertComponentExist(ON.text('请输入规则名称'))
        hilog.info(DOMAIN, TAG, 'Empty rule name validation verified')
      })

      it('should show error when address is empty', 0, async () => {
        // 输入规则名称
        await driver.inputText(ON.text('规则名称'), 'Test Rule')
        await driver.delayMs(300)
        
        // 清空地址
        await driver.clearText(ON.text('地址'))
        await driver.delayMs(300)
        
        // 点击确定
        await driver.click(ON.text('确定'))
        await driver.delayMs(500)
        
        // 应该显示错误提示
        await driver.assertComponentExist(ON.text('请输入地址'))
        hilog.info(DOMAIN, TAG, 'Empty address validation verified')
      })

      it('should show error when port is invalid', 0, async () => {
        // 输入规则名称和地址
        await driver.inputText(ON.text('规则名称'), 'Test Rule')
        await driver.inputText(ON.text('地址'), '192.168.1.1')
        await driver.delayMs(300)
        
        // 输入无效端口
        await driver.inputText(ON.text('端口'), '99999')
        await driver.delayMs(300)
        
        // 点击确定
        await driver.click(ON.text('确定'))
        await driver.delayMs(500)
        
        // 应该显示错误提示
        await driver.assertComponentExist(ON.text('端口范围'))
        hilog.info(DOMAIN, TAG, 'Invalid port validation verified')
      })
    })

    // ==================== 对话框交互测试 ====================

    describe('Dialog Interaction', () => {
      it('should close dialog when clicking cancel', 0, async () => {
        // 点击取消
        await driver.click(ON.text('取消'))
        await driver.delayMs(500)
        
        // 对话框应该关闭
        const dialogExists = await driver.exists(ON.text('添加规则'))
        expect(dialogExists).assertFalse()
        hilog.info(DOMAIN, TAG, 'Cancel button interaction verified')
      })

      it('should keep dialog open on validation error', 0, async () => {
        // 打开对话框（通过导航到防火墙页面并点击添加按钮）
        await driver.click(ON.text('防火墙'))
        await driver.delayMs(1000)
        await driver.click(ON.text('添加'))
        await driver.delayMs(500)
        
        // 点击确定（不填任何内容）
        await driver.click(ON.text('确定'))
        await driver.delayMs(500)
        
        // 对话框应该仍然打开
        const dialogExists = await driver.exists(ON.text('添加规则'))
        expect(dialogExists).assertTrue()
        hilog.info(DOMAIN, TAG, 'Dialog stays open on validation error verified')
      })
    })
  })
}
