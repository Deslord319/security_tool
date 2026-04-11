import { describe, expect, it } from '@ohos/hypium'

import { pickNumber, pickString } from '../../main/ets/services/log-manage/common/LogValuePicker'

export default function logValuePickerTest() {
  describe('LogValuePicker', () => {
    it('should pick trimmed string from a single source', 0, () => {
      let source = {
        detail: '  audit detail  '
      }

      expect(pickString(source, ['detail'])).assertEqual('audit detail')
    })

    it('should pick string from the first matching source and key', 0, () => {
      let sources = [
        { message: '' },
        { summary: ' crash summary ' }
      ]

      expect(pickString(sources, ['message', 'summary'])).assertEqual('crash summary')
    })

    it('should pick finite number from numeric or string field', 0, () => {
      let sources = [
        { pid: '321' },
        { uid: 100 }
      ]

      expect(pickNumber(sources, ['pid'])).assertEqual(321)
      expect(pickNumber(sources, ['uid'])).assertEqual(100)
    })

    it('should ignore empty and invalid values', 0, () => {
      let sources = [
        { pid: 'NaN', detail: '   ' },
        { pid: Number.POSITIVE_INFINITY }
      ]

      expect(pickString(sources, ['detail'])).assertEqual(undefined)
      expect(pickNumber(sources, ['pid'])).assertEqual(undefined)
    })
  })
}
