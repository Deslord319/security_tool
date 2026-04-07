import { describe, expect, it } from '@ohos/hypium'
import { HelpFeedbackStrings } from '../../main/ets/constants/modules/HelpFeedbackStrings'

export default function helpFeedbackStringsTest() {
  describe('HelpFeedbackStrings', () => {
    it('should keep commercial page subtitle and support contact stable', 0, () => {
      expect(HelpFeedbackStrings.pageSubtitle).assertEqual('产品指南、常见问题与客户支持')
      expect(HelpFeedbackStrings.feedbackEmail).assertEqual('consumer@huawei.com')
      expect(HelpFeedbackStrings.contactSectionTitle).assertEqual('联系与反馈')
    })

    it('should provide guide items for each core module in a stable order', 0, () => {
      expect(HelpFeedbackStrings.guideItems.length).assertEqual(5)
      expect(HelpFeedbackStrings.guideItems[0].title).assertEqual('防火墙管理')
      expect(HelpFeedbackStrings.guideItems[1].title).assertEqual('外设管理')
      expect(HelpFeedbackStrings.guideItems[2].title).assertEqual('身份鉴别')
      expect(HelpFeedbackStrings.guideItems[3].title).assertEqual('工具设置')
      expect(HelpFeedbackStrings.guideItems[4].title).assertEqual('主题模式')
      expect(HelpFeedbackStrings.guideItems[0].description.indexOf('黑白名单规则') >= 0).assertTrue()
    })

    it('should keep faq copy actionable instead of empty placeholders', 0, () => {
      expect(HelpFeedbackStrings.faqItems.length >= 8).assertTrue()
      expect(HelpFeedbackStrings.faqItems[0].question).assertEqual('审计诊断中的不同事件类型如何触发？')
      expect(HelpFeedbackStrings.faqItems[0].answer.indexOf('系统安全操作') >= 0).assertTrue()
      expect(HelpFeedbackStrings.faqItems[3].question).assertEqual('防火墙规则不生效怎么办？')
      expect(HelpFeedbackStrings.faqItems[3].answer.indexOf('企业管理权限') >= 0).assertTrue()
    })
  })
}
