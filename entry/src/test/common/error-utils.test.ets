import { describe, expect, it } from '@ohos/hypium'
import { PermissionErrorStrings, SystemServiceErrorStrings } from '../../main/ets/constants/modules/ErrorStrings'
import { CommonErrorUtils } from '../../main/ets/utils/CommonErrorUtils'

class ErrorRecorderState {
  lastErrorCode: number | undefined = 1
  lastErrorMessage: string = 'boom'
}

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

    it('should resolve user-list action errors precisely', 0, () => {
      expect(CommonErrorUtils.resolveErrorMessage(PermissionErrorStrings.readUserListAction, 201))
        .assertEqual(PermissionErrorStrings.missingUserListPermission)
      expect(CommonErrorUtils.resolveErrorMessage(PermissionErrorStrings.readUserListAction, 12300001))
        .assertEqual(SystemServiceErrorStrings.accountServiceConnectionFailed)
      expect(CommonErrorUtils.resolveErrorMessage(PermissionErrorStrings.readUserListAction, undefined))
        .assertEqual(`${PermissionErrorStrings.readUserListAction}失败`)
    })

    it('should resolve generic system and permission errors', 0, () => {
      expect(CommonErrorUtils.resolveErrorMessage('更新策略', 201))
        .assertEqual(PermissionErrorStrings.missingAccountOrFirewallPermission)
      expect(CommonErrorUtils.resolveErrorMessage('更新策略', 2100001))
        .assertEqual(PermissionErrorStrings.invalidUserIdParam)
      expect(CommonErrorUtils.resolveErrorMessage('更新策略', 2100002))
        .assertEqual(SystemServiceErrorStrings.serviceConnectionFailed)
      expect(CommonErrorUtils.resolveErrorMessage('更新策略', 2100003))
        .assertEqual(SystemServiceErrorStrings.internalError)
      expect(CommonErrorUtils.resolveErrorMessage('更新策略', 29400000))
        .assertEqual(SystemServiceErrorStrings.userNotExistOrInvalid)
    })
  })
}
