import { describe, expect, it } from '@ohos/hypium'
import {
  getHelpFeedbackFaqItems,
  getHelpFeedbackGuideItems,
  HelpFeedbackActionStrings,
  HelpFeedbackContactStrings,
  HelpFeedbackPageStrings
} from '../../main/ets/constants/modules/HelpFeedbackStrings'
import { ModuleText } from '../../main/ets/constants/StringCatalog'

export default function helpFeedbackStringsTest() {
  describe('HelpFeedbackStrings', () => {
    it('should keep commercial page subtitle and support contact stable', 0, () => {
      expect(HelpFeedbackPageStrings.SUBTITLE.length > 0).assertTrue()
      expect(HelpFeedbackContactStrings.EMAIL).assertEqual('consumer@huawei.com')
      expect(HelpFeedbackPageStrings.CONTACT_SECTION_TITLE.length > 0).assertTrue()
    })

    it('should provide guide items for each core module in a stable order', 0, () => {
      let guideItems = getHelpFeedbackGuideItems()
      expect(guideItems.length).assertEqual(5)
      expect(guideItems[0].title).assertEqual(ModuleText.FIREWALL)
      expect(guideItems[1].title).assertEqual(ModuleText.PERIPHERAL_MANAGE)
      expect(guideItems[2].title).assertEqual(ModuleText.IDENTITY)
      expect(guideItems[3].title).assertEqual(ModuleText.TOOL_SETTINGS)
      expect(guideItems[4].title.length > 0).assertTrue()
      expect(guideItems[0].description.length > 0).assertTrue()
    })

    it('should keep faq copy actionable instead of empty placeholders', 0, () => {
      let faqItems = getHelpFeedbackFaqItems()
      expect(faqItems.length >= 8).assertTrue()
      expect(faqItems[0].question.length > 0).assertTrue()
      expect(faqItems[0].answer.length > 0).assertTrue()
      expect(faqItems[3].question.length > 0).assertTrue()
      expect(faqItems[3].answer.length > 0).assertTrue()
    })

    it('should keep expandable actions and faq structure stable', 0, () => {
      expect(HelpFeedbackActionStrings.EXPAND.length > 0).assertTrue()
      expect(HelpFeedbackActionStrings.COLLAPSE.length > 0).assertTrue()
      expect(getHelpFeedbackFaqItems().every((item) => item.question.length > 0 && item.answer.length > 0)).assertTrue()
    })
  })
}
