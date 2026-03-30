import { describe, expect, it } from '@ohos/hypium'
import { HelpFeedbackStrings } from '../../main/ets/constants/modules/HelpFeedbackStrings'

export default function helpFeedbackStringsTest() {
  describe('HelpFeedbackStrings', () => {
    it('should provide guide items for each module', 0, () => {
      expect(HelpFeedbackStrings.guideItems.length > 0).assertTrue()
      expect(HelpFeedbackStrings.guideItems[0].title.length > 0).assertTrue()
      expect(HelpFeedbackStrings.guideItems[0].description.length > 0).assertTrue()
    })

    it('should provide faq items and contact entry', 0, () => {
      expect(HelpFeedbackStrings.faqItems.length > 0).assertTrue()
      expect(HelpFeedbackStrings.faqItems[0].question.length > 0).assertTrue()
      expect(HelpFeedbackStrings.faqItems[0].answer.length > 0).assertTrue()
      expect(HelpFeedbackStrings.feedbackEmail.indexOf('@') >= 0).assertTrue()
    })
  })
}
