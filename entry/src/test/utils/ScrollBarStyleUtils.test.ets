import { describe, expect, it } from '@ohos/hypium'
import { ThemeMode } from '../../main/ets/theme/ThemeColors'
import {
  SCROLL_BAR_WIDTH_DEFAULT,
  SCROLL_BAR_WIDTH_HOVER,
  getScrollBarColor
} from '../../main/ets/utils/ScrollBarStyleUtils'

export default function scrollBarStyleUtilsTest() {
  describe('ScrollBarStyleUtils', () => {
    it('should have correct default width constant', 0, () => {
      expect(SCROLL_BAR_WIDTH_DEFAULT).assertEqual(4)
    })

    it('should have correct hover width constant', 0, () => {
      expect(SCROLL_BAR_WIDTH_HOVER).assertEqual(6)
    })

    it('should return correct color for light theme', 0, () => {
      let color = getScrollBarColor(ThemeMode.LIGHT)

      expect(color).assertEqual('#9CA3AF')
    })

    it('should return correct color for dark theme', 0, () => {
      let color = getScrollBarColor(ThemeMode.DARK)

      expect(color).assertEqual('#6B7280')
    })
  })
}
