import { describe, expect, it } from '@ohos/hypium'
import { ThemeMode } from '../../main/ets/theme/ThemeColors'
import { FormControlUtils } from '../../main/ets/utils/FormControlUtils'

export default function formControlUtilsTest() {
  describe('FormControlUtils', () => {
    it('should return background color for light theme', 0, () => {
      let color = FormControlUtils.background(ThemeMode.LIGHT)

      expect(color !== undefined).assertTrue()
      expect(typeof color === 'string').assertTrue()
    })

    it('should return background color for dark theme', 0, () => {
      let color = FormControlUtils.background(ThemeMode.DARK)

      expect(color !== undefined).assertTrue()
      expect(typeof color === 'string').assertTrue()
    })

    it('should return border color for light theme', 0, () => {
      let color = FormControlUtils.border(ThemeMode.LIGHT)

      expect(color !== undefined).assertTrue()
      expect(typeof color === 'string').assertTrue()
    })

    it('should return border color for dark theme', 0, () => {
      let color = FormControlUtils.border(ThemeMode.DARK)

      expect(color !== undefined).assertTrue()
      expect(typeof color === 'string').assertTrue()
    })

    it('should return text color for light theme', 0, () => {
      let color = FormControlUtils.text(ThemeMode.LIGHT)

      expect(color !== undefined).assertTrue()
      expect(typeof color === 'string').assertTrue()
    })

    it('should return text color for dark theme', 0, () => {
      let color = FormControlUtils.text(ThemeMode.DARK)

      expect(color !== undefined).assertTrue()
      expect(typeof color === 'string').assertTrue()
    })

    it('should return select arrow color same as text color', 0, () => {
      let arrowColor = FormControlUtils.selectArrow(ThemeMode.LIGHT)
      let textColor = FormControlUtils.text(ThemeMode.LIGHT)

      expect(arrowColor).assertEqual(textColor)
    })

    it('should return placeholder color for light theme', 0, () => {
      let color = FormControlUtils.placeholder(ThemeMode.LIGHT)

      expect(color !== undefined).assertTrue()
      expect(typeof color === 'string').assertTrue()
    })

    it('should return placeholder color for dark theme', 0, () => {
      let color = FormControlUtils.placeholder(ThemeMode.DARK)

      expect(color !== undefined).assertTrue()
      expect(typeof color === 'string').assertTrue()
    })
  })
}
