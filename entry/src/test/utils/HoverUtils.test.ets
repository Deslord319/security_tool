import { describe, expect, it } from '@ohos/hypium'
import { ThemeMode } from '../../main/ets/theme/ThemeColors'
import { HoverUtils } from '../../main/ets/utils/HoverUtils'

export default function hoverUtilsTest() {
  describe('HoverUtils', () => {
    it('should expose duration constant', 0, () => {
      expect(HoverUtils.DURATION_MS).assertEqual(220)
    })

    it('should return shadow options for light theme when hovered', 0, () => {
      let shadow = HoverUtils.getShadow(ThemeMode.LIGHT, true)

      expect(shadow.radius).assertEqual(28)
      expect(shadow.offsetY).assertEqual(12)
    })

    it('should return shadow options for light theme when not hovered', 0, () => {
      let shadow = HoverUtils.getShadow(ThemeMode.LIGHT, false)

      expect(shadow.radius).assertEqual(10)
      expect(shadow.offsetY).assertEqual(3)
    })

    it('should return shadow options for dark theme when hovered', 0, () => {
      let shadow = HoverUtils.getShadow(ThemeMode.DARK, true)

      expect(shadow.radius).assertEqual(28)
      expect(shadow.offsetY).assertEqual(12)
    })

    it('should return shadow options for dark theme when not hovered', 0, () => {
      let shadow = HoverUtils.getShadow(ThemeMode.DARK, false)

      expect(shadow.radius).assertEqual(10)
      expect(shadow.offsetY).assertEqual(3)
    })

    it('should return strong shadow when strong flag is true', 0, () => {
      let shadow = HoverUtils.getShadow(ThemeMode.LIGHT, true, true)

      expect(shadow.radius).assertEqual(34)
      expect(shadow.offsetY).assertEqual(16)
    })

    it('should return negative translate Y when hovered', 0, () => {
      let translateY = HoverUtils.getTranslateY(true)

      expect(translateY).assertEqual(-6)
    })

    it('should return zero translate Y when not hovered', 0, () => {
      let translateY = HoverUtils.getTranslateY(false)

      expect(translateY).assertEqual(0)
    })

    it('should return custom translate Y distance', 0, () => {
      let translateY = HoverUtils.getTranslateY(true, 10)

      expect(translateY).assertEqual(-10)
    })

    it('should return scale value when hovered', 0, () => {
      let scale = HoverUtils.getScale(true)

      expect(scale).assertEqual(1.01)
    })

    it('should return scale 1 when not hovered', 0, () => {
      let scale = HoverUtils.getScale(false)

      expect(scale).assertEqual(1)
    })

    it('should return custom scale value when hovered', 0, () => {
      let scale = HoverUtils.getScale(true, 1.05)

      expect(scale).assertEqual(1.05)
    })
  })
}
