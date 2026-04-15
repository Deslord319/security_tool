import { describe, expect, it } from '@ohos/hypium'
import { LogUtils } from '../../main/ets/utils/LogUtils'

export default function logUtilsTest() {
  describe('LogUtils', () => {
    it('should call info without error', 0, () => {
      LogUtils.info('TestTag', 'test info message')

      expect(true).assertTrue()
    })

    it('should call warn without error', 0, () => {
      LogUtils.warn('TestTag', 'test warn message')

      expect(true).assertTrue()
    })

    it('should call error without error', 0, () => {
      LogUtils.error('TestTag', 'test error message')

      expect(true).assertTrue()
    })

    it('should call debug without error', 0, () => {
      LogUtils.debug('TestTag', 'test debug message')

      expect(true).assertTrue()
    })

    it('should handle format string with args', 0, () => {
      LogUtils.info('TestTag', 'value is %d', 42)

      expect(true).assertTrue()
    })

    it('should handle multiple format args', 0, () => {
      LogUtils.info('TestTag', 'name: %s, value: %d', 'test', 123)

      expect(true).assertTrue()
    })

    it('should handle empty tag', 0, () => {
      LogUtils.info('', 'empty tag test')

      expect(true).assertTrue()
    })

    it('should handle empty message', 0, () => {
      LogUtils.info('TestTag', '')

      expect(true).assertTrue()
    })
  })
}
