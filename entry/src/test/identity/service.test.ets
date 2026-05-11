import { describe, expect, it } from '@ohos/hypium'
import { securityManager } from '@kit.MDMKit'
import { PasswordComplexityConfig } from '../../main/ets/models/IdentityModels'
import { IdentityPasswordPolicyMapper } from '../../main/ets/services/identity/settings/IdentityPasswordPolicyMapper'

const DAY_IN_MS: number = 24 * 60 * 60 * 1000

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
  describe('IdentityPasswordPolicyMapper', () => {
    it('should convert config to password policy', 0, () => {
      let config = createConfig()
      config.minLength = 10
      config.requireSpecialChar = true
      config.validityPeriod = 365

      let policy = IdentityPasswordPolicyMapper.toPasswordPolicy(config)

      expect(policy.complexityRegex).assertEqual('^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[!@#$%^&*])[a-zA-Z\\d!@#$%^&*]{10,}$')
      expect(policy.additionalDescription).assertEqual('至少10个字符，包含大写字母，包含小写字母，包含数字，包含特殊字符(!@#$%^&*)')
      expect(policy.validityPeriod).assertEqual(365 * DAY_IN_MS)
    })

    it('should omit validityPeriod when config does not set one', 0, () => {
      let config = createConfig()
      config.validityPeriod = undefined

      let policy = IdentityPasswordPolicyMapper.toPasswordPolicy(config)

      expect(policy.validityPeriod === undefined).assertTrue()
    })

    it('should preserve zero validityPeriod for immediate-expiry password policy', 0, () => {
      let config = createConfig()
      config.validityPeriod = 0

      let policy = IdentityPasswordPolicyMapper.toPasswordPolicy(config)

      expect(policy.validityPeriod).assertEqual(0)
    })

    it('should convert password policy to config', 0, () => {
      let policy = new TestPasswordPolicy()
      policy.complexityRegex = '^(?=.*[A-Z])(?=.*[0-9])(?=.*[^a-zA-Z0-9]).{12,}$'
      policy.validityPeriod = 184 * DAY_IN_MS

      let config = IdentityPasswordPolicyMapper.toConfig(policy)

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
      let config = IdentityPasswordPolicyMapper.toConfig(null)

      expect(config).assertEqual(null)
    })

    it('should return null config for system empty zero-validity policy', 0, () => {
      let policy = new TestPasswordPolicy()
      policy.validityPeriod = 0

      let config = IdentityPasswordPolicyMapper.toConfig(policy)

      expect(config).assertEqual(null)
    })

    it('should fall back to minLength zero when regex does not contain length marker', 0, () => {
      let policy = new TestPasswordPolicy()
      policy.complexityRegex = '^(?=.*[a-z])(?=.*[A-Z]).*$'
      let config = IdentityPasswordPolicyMapper.toConfig(policy)

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
      let regex = IdentityPasswordPolicyMapper.buildComplexityRegex(config)

      expect(regex).assertEqual('^.{6,}$')
    })

    it('should build description in stable order', 0, () => {
      let config = createConfig()
      config.minLength = 12
      config.requireUppercase = false
      config.requireSpecialChar = true
      let description = IdentityPasswordPolicyMapper.buildDescription(config)

      expect(description).assertEqual('至少12个字符，包含小写字母，包含数字，包含特殊字符(!@#$%^&*)')
    })
  })
}
