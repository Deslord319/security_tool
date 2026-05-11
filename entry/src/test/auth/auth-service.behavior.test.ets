import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { userAuth } from '@kit.UserAuthenticationKit'
import { LabelText } from '../../main/ets/constants/StringCatalog'
import { IdentityAuthStrings } from '../../main/ets/constants/modules/IdentityStrings'
import { AuthMethod } from '../../main/ets/models/AuthModels'
import { AuthService } from '../../main/ets/services/identity/auth/AuthService'
import { UserAuthAdapter } from '../../main/ets/services/identity/auth/UserAuthAdapter'

class FakeBusinessError extends Error {
  code: number

  constructor(code: number, message: string) {
    super(message)
    this.code = code
  }
}

interface AuthResultListener {
  onResult(result: userAuth.UserAuthResult): void
}

interface TestUserAuthInstance {
  on(event: string, listener: AuthResultListener): void
  off(event: string): void
  start(): void
}

class ControlledUserAuthInstance implements TestUserAuthInstance {
  listener: AuthResultListener | null = null
  startError: FakeBusinessError | null = null
  resultCode: number = userAuth.UserAuthResultCode.SUCCESS
  startCalls: number = 0
  offCalls: number = 0

  on(_event: string, listener: AuthResultListener): void {
    this.listener = listener
  }

  off(_event: string): void {
    this.offCalls++
  }

  start(): void {
    this.startCalls++
    if (this.startError) {
      throw this.startError
    }
    this.listener?.onResult({ result: this.resultCode } as userAuth.UserAuthResult)
  }
}

export default function authServiceBehaviorTest() {
  describe('AuthService behavior', () => {
    let mockKit: MockKit

    beforeEach(() => {
      mockKit = new MockKit()
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should report unsupported when auth method conversion fails', 0, () => {
      let result = AuthService.checkAuthMethodAvailability(999 as AuthMethod)

      expect(result.available).assertFalse()
      expect(result.message).assertEqual(IdentityAuthStrings.METHOD_UNSUPPORTED)
    })

    it('should map auth method labels correctly', 0, () => {
      expect(AuthService.getAuthMethodLabel(AuthMethod.PIN)).assertEqual('PIN')
      expect(AuthService.getAuthMethodLabel(AuthMethod.FINGERPRINT)).assertEqual(IdentityAuthStrings.METHOD_FINGERPRINT)
      expect(AuthService.getAuthMethodLabel(999 as AuthMethod)).assertEqual(LabelText.AUTH_METHOD)
    })

    it('should reject unsupported auth method during authenticate', 0, async () => {
      let result = await AuthService.authenticate(999 as AuthMethod)

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('unavailable')
      expect(result.message).assertEqual(IdentityAuthStrings.METHOD_UNSUPPORTED)
    })

    it('should reject unsupported auth method even when challenge is provided', 0, async () => {
      let result = await AuthService.authenticate(999 as AuthMethod, new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]))

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('unavailable')
      expect(result.message).assertEqual(IdentityAuthStrings.METHOD_UNSUPPORTED)
    })

    it('should report available when system auth status check succeeds', 0, () => {
      let statusMock = mockKit.mockFunc(UserAuthAdapter, UserAuthAdapter.getAvailableStatus)
      when(statusMock)(userAuth.UserAuthType.PIN).afterReturn(undefined)

      let result = AuthService.checkAuthMethodAvailability(AuthMethod.PIN)

      expect(result.available).assertTrue()
      expect(result.message).assertEqual(IdentityAuthStrings.SYSTEM_AVAILABLE)
    })

    it('should map availability errors from auth status check', 0, () => {
      let statusMock = mockKit.mockFunc(UserAuthAdapter, UserAuthAdapter.getAvailableStatus)
      when(statusMock)(userAuth.UserAuthType.FINGERPRINT).afterAction((): void => {
        throw new FakeBusinessError(12500010, 'not enrolled')
      })

      let result = AuthService.checkAuthMethodAvailability(AuthMethod.FINGERPRINT)

      expect(result.available).assertFalse()
      expect(result.errorCode).assertEqual(12500010)
      expect(result.message).assertEqual(IdentityAuthStrings.buildNotEnrolled(IdentityAuthStrings.METHOD_FINGERPRINT))
    })

    it('should resolve success when auth result callback returns success', 0, async () => {
      let instance = new ControlledUserAuthInstance()
      let instanceMock = mockKit.mockFunc(UserAuthAdapter, UserAuthAdapter.getUserAuthInstance)
      when(instanceMock)(ArgumentMatchers.anyObj).afterReturn(instance as never as userAuth.UserAuthInstance)

      let result = await AuthService.authenticate(AuthMethod.PIN, new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]))

      expect(result.success).assertTrue()
      expect(instance.startCalls).assertEqual(1)
      expect(instance.offCalls).assertEqual(1)
    })

    it('should map unavailable result callback codes to unavailable reason', 0, async () => {
      let instance = new ControlledUserAuthInstance()
      instance.resultCode = 12500006
      let instanceMock = mockKit.mockFunc(UserAuthAdapter, UserAuthAdapter.getUserAuthInstance)
      when(instanceMock)(ArgumentMatchers.anyObj).afterReturn(instance as never as userAuth.UserAuthInstance)

      let result = await AuthService.authenticate(AuthMethod.FINGERPRINT, new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]))

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('unavailable')
      expect(result.errorCode).assertEqual(12500006)
      expect(result.message).assertEqual(IdentityAuthStrings.TRUST_LEVEL_INSUFFICIENT)
    })

    it('should map non-availability result callback codes to failed reason', 0, async () => {
      let instance = new ControlledUserAuthInstance()
      instance.resultCode = 401
      let instanceMock = mockKit.mockFunc(UserAuthAdapter, UserAuthAdapter.getUserAuthInstance)
      when(instanceMock)(ArgumentMatchers.anyObj).afterReturn(instance as never as userAuth.UserAuthInstance)

      let result = await AuthService.authenticate(AuthMethod.PIN, new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]))

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('failed')
      expect(result.errorCode).assertEqual(401)
      expect(result.message).assertEqual(IdentityAuthStrings.FAILED_OR_CANCELED)
    })

    it('should map start exceptions from auth instance', 0, async () => {
      let instance = new ControlledUserAuthInstance()
      instance.startError = new FakeBusinessError(201, 'permission denied')
      let instanceMock = mockKit.mockFunc(UserAuthAdapter, UserAuthAdapter.getUserAuthInstance)
      when(instanceMock)(ArgumentMatchers.anyObj).afterReturn(instance as never as userAuth.UserAuthInstance)

      let result = await AuthService.authenticate(AuthMethod.PIN, new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]))

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('unavailable')
      expect(result.errorCode).assertEqual(201)
      expect(result.message).assertEqual(IdentityAuthStrings.PERMISSION_DENIED)
    })
  })
}
