import { describe, expect, it } from '@ohos/hypium'
import { CommonErrorUtils } from '../../main/ets/utils/CommonErrorUtils'

class NumericCodeError {
  code: number = 201
  message: string = 'permission denied'
}

class StringCodeError {
  code: string = '2100002'
  data: string = 'service disconnected'
}

export default function errorUtilsTest() {
  describe('CommonErrorUtils', () => {
    it('should extract numeric and string error metadata', 0, () => {
      expect(CommonErrorUtils.extractErrorCode(new NumericCodeError())).assertEqual(201)
      expect(CommonErrorUtils.extractErrorCode(new StringCodeError())).assertEqual(2100002)
      expect(CommonErrorUtils.extractErrorMessage(new NumericCodeError())).assertEqual('permission denied')
      expect(CommonErrorUtils.extractErrorMessage(new StringCodeError())).assertEqual('service disconnected')
    })

  })
}
