import { describe, expect, it } from '@ohos/hypium'

import { pickNumber, pickString } from '../../main/ets/services/log-manage/common/LogValuePicker'

interface StringSource {
  detail?: string
  message?: string
  summary?: string
}

interface NumberSource {
  pid?: string | number
  uid?: number
  detail?: string
}

export default function logValuePickerTest() {
  describe('LogValuePicker', () => {
    it('should pick trimmed string from a single source', 0, () => {
      let source: StringSource = {
        detail: '  audit detail  '
      }

      expect(pickString(source, ['detail'])).assertEqual('audit detail')
    })

    it('should pick string from the first matching source and key', 0, () => {
      let sources: StringSource[] = [
        { message: '' } as StringSource,
        { summary: ' crash summary ' } as StringSource
      ]

      expect(pickString(sources, ['message', 'summary'])).assertEqual('crash summary')
    })

    it('should pick finite number from numeric or string field', 0, () => {
      let sources: NumberSource[] = [
        { pid: '321' } as NumberSource,
        { uid: 100 } as NumberSource
      ]

      expect(pickNumber(sources, ['pid'])).assertEqual(321)
      expect(pickNumber(sources, ['uid'])).assertEqual(100)
    })

    it('should ignore empty and invalid values', 0, () => {
      let sources: NumberSource[] = [
        { pid: 'NaN', detail: '   ' } as NumberSource,
        { pid: Number.POSITIVE_INFINITY } as NumberSource
      ]

      expect(pickString(sources, ['detail'])).assertEqual(undefined)
      expect(pickNumber(sources, ['pid'])).assertEqual(undefined)
    })
  })
}
