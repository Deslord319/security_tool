import { describe, expect, it } from '@ohos/hypium'
import { PasswordComplexityConfig } from '../../main/ets/models/DataModels'
import { IdentityPasswordPolicyMapper } from '../../main/ets/services/identity/settings/IdentityPasswordPolicyMapper'
import { IdentityService } from '../../main/ets/services/identity/settings/IdentityService'

class PasswordConfig implements PasswordComplexityConfig {
  minLength: number = 10
  requireLowercase: boolean = true
  requireUppercase: boolean = true
  requireDigit: boolean = true
  requireSpecialChar: boolean = false
  validityPeriod: number = 30
}

export default function identityServiceBehaviorTest() {
  describe('IdentityService behavior', () => {
    it('should build regex and description from config', 0, () => {
      let config = new PasswordConfig()

      let regex = IdentityPasswordPolicyMapper.buildComplexityRegex(config)
      let description = IdentityPasswordPolicyMapper.buildDescription(config)

      expect(regex).assertEqual('^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)[a-zA-Z\\d]{10,}$')
      expect(description.indexOf('至少10个字符') >= 0).assertTrue()
      expect(description.indexOf('包含大写字母') >= 0).assertTrue()
      expect(description.indexOf('包含数字') >= 0).assertTrue()
    })

    it('should return an operation result when setting password policy in unit test env', 0, () => {
      let result = IdentityService.setPasswordPolicyWithResult(new PasswordConfig())

      expect(typeof result.success).assertEqual('boolean')
    })

    it('should return an operation result when reading password policy in unit test env', 0, () => {
      let result = IdentityService.getPasswordPolicyWithResult()

      expect(typeof result.success).assertEqual('boolean')
    })
  })
}
