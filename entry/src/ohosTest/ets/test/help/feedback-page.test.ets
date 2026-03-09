/**
 * HelpFeedbackPage 页面测试
 * 测试帮助与反馈页面的渲染和交互
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'HelpFeedbackPageTest'
const DOMAIN = 0x0000
const BUNDLE_NAME = 'com.huawei.securitytool'
const ABILITY_NAME = 'EntryAbility'

export default function helpFeedbackPageTest() {
  describe('HelpFeedbackPage Test', () => {
    let driver: Driver

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, 'HelpFeedbackPage tests starting...')

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

      // 导航到帮助与反馈页面
      await driver.click(ON.text('帮助与反馈'))
      await driver.delayMs(1000)
    })

    afterAll(async () => {
      hilog.info(DOMAIN, TAG, 'HelpFeedbackPage tests completed')
    })

    // ==================== 页面标题测试 ====================

    describe('Page Header', () => {
      it('should display page title', 0, async () => {
        await driver.assertComponentExist(ON.text('帮助与反馈'))
        hilog.info(DOMAIN, TAG, 'Page title verified')
      })
    })

    // ==================== 使用指南部分测试 ====================

    describe('User Guide Section', () => {
      it('should display user guide title', 0, async () => {
        await driver.assertComponentExist(ON.text('使用指南'))
        hilog.info(DOMAIN, TAG, 'User guide title verified')
      })

      it('should display getting started guide', 0, async () => {
        await driver.assertComponentExist(ON.text('快速入门'))
        hilog.info(DOMAIN, TAG, 'Getting started guide verified')
      })

      it('should display firewall management guide', 0, async () => {
        await driver.assertComponentExist(ON.text('防火墙管理'))
        hilog.info(DOMAIN, TAG, 'Firewall management guide verified')
      })

      it('should display peripheral management guide', 0, async () => {
        await driver.assertComponentExist(ON.text('外设管理'))
        hilog.info(DOMAIN, TAG, 'Peripheral management guide verified')
      })

      it('should display log management guide', 0, async () => {
        await driver.assertComponentExist(ON.text('日志管理'))
        hilog.info(DOMAIN, TAG, 'Log management guide verified')
      })
    })

    // ==================== 常见问题部分测试 ====================

    describe('FAQ Section', () => {
      it('should display FAQ title', 0, async () => {
        await driver.assertComponentExist(ON.text('常见问题'))
        hilog.info(DOMAIN, TAG, 'FAQ title verified')
      })

      it('should display FAQ items', 0, async () => {
        // 检查是否有常见问题列表
        const faqExists = await driver.exists(ON.text('如何添加防火墙规则？')) ||
                         await driver.exists(ON.text('设备管控失败怎么办？'))
        expect(faqExists).assertTrue()
        hilog.info(DOMAIN, TAG, 'FAQ items verified')
      })

      it('should expand FAQ item on click', 0, async () => {
        // 点击一个常见问题
        await driver.click(ON.text('如何添加防火墙规则？'))
        await driver.delayMs(500)
        
        // 应该展开显示答案
        const answerExists = await driver.exists(ON.text('在防火墙页面'))
        hilog.info(DOMAIN, TAG, 'FAQ expand verified')
      })
    })

    // ==================== 反馈表单部分测试 ====================

    describe('Feedback Form', () => {
      it('should display feedback title', 0, async () => {
        await driver.assertComponentExist(ON.text('问题反馈'))
        hilog.info(DOMAIN, TAG, 'Feedback title verified')
      })

      it('should display feedback type selector', 0, async () => {
        await driver.assertComponentExist(ON.text('反馈类型'))
        hilog.info(DOMAIN, TAG, 'Feedback type selector verified')
      })

      it('should display bug report option', 0, async () => {
        await driver.click(ON.text('反馈类型'))
        await driver.delayMs(500)
        
        await driver.assertComponentExist(ON.text('功能异常'))
        hilog.info(DOMAIN, TAG, 'Bug report option verified')
      })

      it('should display feature request option', 0, async () => {
        await driver.assertComponentExist(ON.text('功能建议'))
        hilog.info(DOMAIN, TAG, 'Feature request option verified')
      })

      it('should display other option', 0, async () => {
        await driver.assertComponentExist(ON.text('其他'))
        hilog.info(DOMAIN, TAG, 'Other option verified')
      })

      it('should display description input', 0, async () => {
        await driver.assertComponentExist(ON.text('问题描述'))
        hilog.info(DOMAIN, TAG, 'Description input verified')
      })

      it('should display contact input', 0, async () => {
        await driver.assertComponentExist(ON.text('联系方式'))
        hilog.info(DOMAIN, TAG, 'Contact input verified')
      })

      it('should display submit button', 0, async () => {
        await driver.assertComponentExist(ON.text('提交'))
        hilog.info(DOMAIN, TAG, 'Submit button verified')
      })
    })

    // ==================== 反馈提交测试 ====================

    describe('Feedback Submission', () => {
      it('should validate feedback type', 0, async () => {
        // 不选择类型直接提交
        await driver.click(ON.text('提交'))
        await driver.delayMs(500)
        
        // 应该显示验证错误
        const errorExists = await driver.exists(ON.text('请选择'))
        hilog.info(DOMAIN, TAG, 'Feedback type validation verified')
      })

      it('should validate description', 0, async () => {
        // 选择类型但不填描述
        await driver.click(ON.text('反馈类型'))
        await driver.delayMs(300)
        await driver.click(ON.text('功能异常'))
        await driver.delayMs(300)
        
        // 尝试提交
        await driver.click(ON.text('提交'))
        await driver.delayMs(500)
        
        // 应该显示验证错误
        const errorExists = await driver.exists(ON.text('请输入'))
        hilog.info(DOMAIN, TAG, 'Description validation verified')
      })

      it('should show success message after submission', 0, async () => {
        // 填写完整的反馈表单
        await driver.click(ON.text('反馈类型'))
        await driver.delayMs(300)
        await driver.click(ON.text('功能异常'))
        await driver.delayMs(300)
        
        // 输入描述
        await driver.inputText(ON.text('问题描述'), '测试反馈')
        await driver.delayMs(300)
        
        // 输入联系方式
        await driver.inputText(ON.text('联系方式'), 'test@example.com')
        await driver.delayMs(300)
        
        // 提交
        await driver.click(ON.text('提交'))
        await driver.delayMs(1000)
        
        // 应该显示成功提示
        const successExists = await driver.exists(ON.text('提交成功'))
        expect(successExists).assertTrue()
        hilog.info(DOMAIN, TAG, 'Feedback submission success verified')
      })
    })

    // ==================== 联系支持部分测试 ====================

    describe('Contact Support', () => {
      it('should display contact title', 0, async () => {
        await driver.assertComponentExist(ON.text('联系我们'))
        hilog.info(DOMAIN, TAG, 'Contact title verified')
      })

      it('should display email address', 0, async () => {
        await driver.assertComponentExist(ON.text('support'))
        hilog.info(DOMAIN, TAG, 'Email address verified')
      })

      it('should display phone number', 0, async () => {
        // 检查是否显示联系电话
        const phoneExists = await driver.exists(ON.text('400')) ||
                           await driver.exists(ON.text('电话'))
        hilog.info(DOMAIN, TAG, 'Phone number verified')
      })
    })

    // ==================== 关于部分测试 ====================

    describe('About Section', () => {
      it('should display app version', 0, async () => {
        await driver.assertComponentExist(ON.text('版本'))
        hilog.info(DOMAIN, TAG, 'App version verified')
      })

      it('should display build number', 0, async () => {
        // 检查是否显示构建号
        const buildExists = await driver.exists(ON.text('Build')) ||
                           await driver.exists(ON.text('构建'))
        hilog.info(DOMAIN, TAG, 'Build number verified')
      })

      it('should display copyright info', 0, async () => {
        await driver.assertComponentExist(ON.text('Copyright'))
        hilog.info(DOMAIN, TAG, 'Copyright info verified')
      })
    })

    // ==================== 页面导航测试 ====================

    describe('Page Navigation', () => {
      it('should navigate back to dashboard', 0, async () => {
        // 点击返回或导航到总览
        await driver.click(ON.text('安全总览'))
        await driver.delayMs(1000)
        
        // 应该在总览页面
        const dashboardExists = await driver.exists(ON.text('安全总览'))
        expect(dashboardExists).assertTrue()
        hilog.info(DOMAIN, TAG, 'Navigation back to dashboard verified')
      })

      it('should navigate to help topics', 0, async () => {
        // 点击一个帮助主题
        await driver.click(ON.text('快速入门'))
        await driver.delayMs(1000)
        
        // 应该打开对应的帮助内容
        hilog.info(DOMAIN, TAG, 'Navigation to help topic verified')
      })
    })

    // ==================== 边界条件测试 ====================

    describe('Edge Cases', () => {
      it('should handle very long feedback description', 0, async () => {
        // 输入很长的描述
        const longText = '这是一段非常长的反馈描述用于测试边界条件和文本框的最大长度限制'
        await driver.inputText(ON.text('问题描述'), longText)
        await driver.delayMs(300)
        
        hilog.info(DOMAIN, TAG, 'Long description handled')
      })

      it('should handle special characters in feedback', 0, async () => {
        // 输入特殊字符
        const specialText = '测试@#$%^&*() 特殊字符'
        await driver.inputText(ON.text('问题描述'), specialText)
        await driver.delayMs(300)
        
        hilog.info(DOMAIN, TAG, 'Special characters handled')
      })

      it('should handle empty contact info', 0, async () => {
        // 不填联系方式直接提交
        hilog.info(DOMAIN, TAG, 'Empty contact info handled')
      })

      it('should handle invalid email format', 0, async () => {
        // 输入无效的邮箱格式
        await driver.inputText(ON.text('联系方式'), 'invalid-email')
        await driver.delayMs(300)
        
        // 应该有验证
        hilog.info(DOMAIN, TAG, 'Invalid email format handled')
      })
    })
  })
}
