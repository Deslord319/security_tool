import { describe, expect, it } from '@ohos/hypium'
import {
  HELP_FEEDBACK_FAQ_ITEMS,
  HELP_FEEDBACK_GUIDE_ITEMS,
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
      expect(HELP_FEEDBACK_GUIDE_ITEMS.length).assertEqual(5)
      expect(HELP_FEEDBACK_GUIDE_ITEMS[0].title).assertEqual(ModuleText.FIREWALL)
      expect(HELP_FEEDBACK_GUIDE_ITEMS[1].title).assertEqual(ModuleText.PERIPHERAL_MANAGE)
      expect(HELP_FEEDBACK_GUIDE_ITEMS[2].title).assertEqual(ModuleText.IDENTITY)
      expect(HELP_FEEDBACK_GUIDE_ITEMS[3].title).assertEqual(ModuleText.TOOL_SETTINGS)
      expect(HELP_FEEDBACK_GUIDE_ITEMS[4].title).assertEqual('主题模式')
      expect(HELP_FEEDBACK_GUIDE_ITEMS[0].description.length > 0).assertTrue()
    })

    it('should keep faq copy actionable instead of empty placeholders', 0, () => {
      expect(HELP_FEEDBACK_FAQ_ITEMS.length >= 8).assertTrue()
      expect(HELP_FEEDBACK_FAQ_ITEMS[0].question.length > 0).assertTrue()
      expect(HELP_FEEDBACK_FAQ_ITEMS[0].answer.length > 0).assertTrue()
      expect(HELP_FEEDBACK_FAQ_ITEMS[3].question.length > 0).assertTrue()
      expect(HELP_FEEDBACK_FAQ_ITEMS[3].answer.length > 0).assertTrue()
    })

    it('should keep expandable actions and faq structure stable', 0, () => {
      expect(HelpFeedbackActionStrings.EXPAND).assertEqual('展开')
      expect(HelpFeedbackActionStrings.COLLAPSE).assertEqual('收起')
      expect(HELP_FEEDBACK_FAQ_ITEMS.every((item) => item.question.length > 0 && item.answer.length > 0)).assertTrue()
    })
  })
}
