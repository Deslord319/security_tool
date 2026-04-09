import { describe, expect, it } from '@ohos/hypium'
import { IdentityStrings } from '../../main/ets/constants/modules/IdentityStrings'
import { AuthMethod } from '../../main/ets/models/DataModels'
import { AuthService } from '../../main/ets/services/identity/auth/AuthService'

export default function authServiceBehaviorTest() {
  describe('AuthService behavior', () => {
    it('should report unsupported when auth method conversion fails', 0, () => {
      let result = AuthService.checkAuthMethodAvailability(999 as AuthMethod)

      expect(result.available).assertFalse()
      expect(result.message).assertEqual(IdentityStrings.authMethodUnsupported)
    })

    it('should map auth method labels correctly', 0, () => {
      expect(AuthService.getAuthMethodLabel(AuthMethod.PIN)).assertEqual('PIN')
      expect(AuthService.getAuthMethodLabel(AuthMethod.FINGERPRINT)).assertEqual(IdentityStrings.authMethodFingerprint)
      expect(AuthService.getAuthMethodLabel(999 as AuthMethod)).assertEqual(IdentityStrings.authMethodGeneric)
    })

    it('should reject unsupported auth method during authenticate', 0, async () => {
      let result = await AuthService.authenticate(999 as AuthMethod)

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('unavailable')
      expect(result.message).assertEqual(IdentityStrings.authMethodUnsupported)
    })

    it('should reject unsupported auth method even when challenge is provided', 0, async () => {
      let result = await AuthService.authenticate(999 as AuthMethod, new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]))

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('unavailable')
      expect(result.message).assertEqual(IdentityStrings.authMethodUnsupported)
    })
  })
}
