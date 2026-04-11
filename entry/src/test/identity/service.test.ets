import { describe, expect, it } from '@ohos/hypium'
import { securityManager } from '@kit.MDMKit'
import { PasswordComplexityConfig } from '../../main/ets/models/DataModels'
import { IdentityService } from '../../main/ets/services/identity/settings/IdentityService'

class TestPasswordConfig implements PasswordComplexityConfig {
  minLength: number = 8
  requireLowercase: boolean = true
  requireUppercase: boolean = true
  requireDigit: boolean = true
  requireSpecialChar: boolean = false
  validityPeriod?: number = 181
}

class TestPasswordPolicy implements securityManager.PasswordPolicy {
  complexityRegex?: string
  validityPeriod?: number
  additionalDescription?: string
}

function createConfig(): PasswordComplexityConfig {
  let config = new TestPasswordConfig()
  return config
}

export default function identityServiceTest() {
  describe('IdentityService', () => {
    it('should convert config to password policy', 0, () => {
      let config = createConfig()
      config.minLength = 10
      config.requireSpecialChar = true
      config.validityPeriod = 365

      let policy = IdentityService.toPasswordPolicy(config)

      expect(policy.complexityRegex).assertEqual('^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[!@#$%^&*])[a-zA-Z\\d!@#$%^&*]{10,}$')
      expect(policy.additionalDescription).assertEqual('至少10个字符，包含大写字母，包含小写字母，包含数字，包含特殊字符(!@#$%^&*)')
      expect(policy.validityPeriod).assertEqual(365)
    })

    it('should omit validityPeriod when config does not set one', 0, () => {
      let config = createConfig()
      config.validityPeriod = undefined

      let policy = IdentityService.toPasswordPolicy(config)

      expect(policy.validityPeriod === undefined).assertTrue()
    })

    it('should convert password policy to config', 0, () => {
      let policy = new TestPasswordPolicy()
      policy.complexityRegex = '^(?=.*[A-Z])(?=.*[0-9])(?=.*[^a-zA-Z0-9]).{12,}$'
      policy.validityPeriod = 184

      let config = IdentityService.toConfig(policy)

      expect(config !== null).assertTrue()
      if (config) {
        expect(config.minLength).assertEqual(12)
        expect(config.requireLowercase).assertFalse()
        expect(config.requireUppercase).assertTrue()
        expect(config.requireDigit).assertTrue()
        expect(config.requireSpecialChar).assertTrue()
        expect(config.validityPeriod).assertEqual(184)
      }
    })

    it('should return null config for empty policy', 0, () => {
      let config = IdentityService.toConfig(null)

      expect(config).assertEqual(null)
    })

    it('should fall back to minLength zero when regex does not contain length marker', 0, () => {
      let policy = new TestPasswordPolicy()
      policy.complexityRegex = '^(?=.*[a-z])(?=.*[A-Z]).*$'
      let config = IdentityService.toConfig(policy)

      expect(config !== null).assertTrue()
      if (config) {
        expect(config.minLength).assertEqual(0)
        expect(config.requireLowercase).assertTrue()
        expect(config.requireUppercase).assertTrue()
      }
    })

    it('should build regex for config without character requirements', 0, () => {
      let config = createConfig()
      config.minLength = 6
      config.requireLowercase = false
      config.requireUppercase = false
      config.requireDigit = false
      config.requireSpecialChar = false
      let regex = IdentityService.buildComplexityRegex(config)

      expect(regex).assertEqual('^.{6,}$')
    })

    it('should build description in stable order', 0, () => {
      let config = createConfig()
      config.minLength = 12
      config.requireUppercase = false
      config.requireSpecialChar = true
      let description = IdentityService.buildDescription(config)

      expect(description).assertEqual('至少12个字符，包含小写字母，包含数字，包含特殊字符(!@#$%^&*)')
    })
  })
}
