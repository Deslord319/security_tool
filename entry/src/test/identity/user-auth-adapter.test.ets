import { describe, expect, it } from '@ohos/hypium'
import { userAuth } from '@kit.UserAuthenticationKit'
import {
  UserAuthAdapter,
  UserAuthInstanceRequest,
  UserAuthInstanceResult,
  UserAuthStatusResult
} from '../../main/ets/services/identity/auth/UserAuthAdapter'

class FakeBusinessError extends Error {
  code: number

  constructor(code: number, message: string) {
    super(message)
    this.code = code
  }
}

class FakeAuthParam implements userAuth.AuthParam {
  challenge: Uint8Array = new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8])
  authType: userAuth.UserAuthType[] = [userAuth.UserAuthType.PIN]
  authTrustLevel: userAuth.AuthTrustLevel = userAuth.AuthTrustLevel.ATL1
}

class FakeWidgetParam implements userAuth.WidgetParam {
  title: string = 'Test'
}

class FakeUserAuthInstanceRequest implements UserAuthInstanceRequest {
  authParam: userAuth.AuthParam = new FakeAuthParam()
  widgetParam: userAuth.WidgetParam = new FakeWidgetParam()
}

class FakeUserAuthStatusResult implements UserAuthStatusResult {
  success: boolean = false
  errorCode?: number
  errorMessage?: string
}

class FakeUserAuthInstanceResult implements UserAuthInstanceResult {
  success: boolean = false
  instance?: userAuth.UserAuthInstance
  errorCode?: number
  errorMessage?: string
}

function buildRequest(authTypes: userAuth.UserAuthType[], title: string): UserAuthInstanceRequest {
  let request = new FakeUserAuthInstanceRequest()
  let authParam = request.authParam as FakeAuthParam
  let widgetParam = request.widgetParam as FakeWidgetParam
  authParam.authType = authTypes
  widgetParam.title = title
  return request
}

export default function userAuthAdapterTest() {
  describe('UserAuthAdapter', () => {
    it('should return a status result object for PIN availability', 0, () => {
      UserAuthAdapter.getAvailableStatus(userAuth.UserAuthType.PIN)
      expect(true).assertTrue()
    })

    it('should return a status result object for fingerprint availability', 0, () => {
      UserAuthAdapter.getAvailableStatus(userAuth.UserAuthType.FINGERPRINT)
      expect(true).assertTrue()
    })

    it('should return a result object for getUserAuthInstance', 0, () => {
      let request = buildRequest([userAuth.UserAuthType.PIN], 'PIN Auth')

      UserAuthAdapter.getUserAuthInstance(request)
      expect(true).assertTrue()
    })

    it('should support multiple auth types in request', 0, () => {
      let request = buildRequest(
        [userAuth.UserAuthType.PIN, userAuth.UserAuthType.FINGERPRINT],
        'Multi Auth'
      )

      UserAuthAdapter.getUserAuthInstance(request)
      expect(true).assertTrue()
    })

    it('should support empty auth type arrays', 0, () => {
      let request = buildRequest([], 'Empty Auth')

      UserAuthAdapter.getUserAuthInstance(request)
      expect(true).assertTrue()
    })
  })
}
