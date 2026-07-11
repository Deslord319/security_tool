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

      expect(policy.complexityRegex).assertEqual('^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[!@#$%^&*]).{10,}$')
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

    it('should treat empty zero-validity system policy as null config', 0, () => {
      let policy = new TestPasswordPolicy()
      policy.validityPeriod = 0

      let config = IdentityPasswordPolicyMapper.toConfig(policy)

      expect(config).assertEqual(null)
    })

    it('should keep zero validity from non-empty system policy as immediate-expiry config', 0, () => {
      let policy = new TestPasswordPolicy()
      policy.complexityRegex = '^.{6,}$'
      policy.validityPeriod = 0

      let config = IdentityPasswordPolicyMapper.toConfig(policy)

      expect(config !== null).assertTrue()
      if (config) {
        expect(config.validityPeriod).assertEqual(0)
      }
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

    it('should enforce every length option with all character requirement combinations', 0, () => {
      let lengths: number[] = [6, 8, 10, 12, 16, 20, 24]
      for (let lengthIndex: number = 0; lengthIndex < lengths.length; lengthIndex++) {
        let minLength: number = lengths[lengthIndex]
        for (let mask: number = 0; mask < 16; mask++) {
          let config = createConfig()
          config.minLength = minLength
          config.requireUppercase = (mask & 1) !== 0
          config.requireLowercase = (mask & 2) !== 0
          config.requireDigit = (mask & 4) !== 0
          config.requireSpecialChar = (mask & 8) !== 0

          let regex = new RegExp(IdentityPasswordPolicyMapper.buildComplexityRegex(config))
          let required: string = ''
          required += config.requireUppercase ? 'A' : ''
          required += config.requireLowercase ? 'a' : ''
          required += config.requireDigit ? '1' : ''
          required += config.requireSpecialChar ? '!' : ''
          let exactPassword: string = required.padEnd(minLength, '_')

          expect(regex.test(exactPassword)).assertTrue()
          expect(regex.test(`${exactPassword}_`)).assertTrue()
          expect(regex.test(exactPassword.substring(0, minLength - 1))).assertFalse()

          if (config.requireUppercase) {
            expect(regex.test(exactPassword.replace('A', '_'))).assertFalse()
          }
          if (config.requireLowercase) {
            expect(regex.test(exactPassword.replace('a', '_'))).assertFalse()
          }
          if (config.requireDigit) {
            expect(regex.test(exactPassword.replace('1', '_'))).assertFalse()
          }
          if (config.requireSpecialChar) {
            expect(regex.test(exactPassword.replace('!', '_'))).assertFalse()
          }
        }
      }
    })

    it('should allow character types that are not required', 0, () => {
      let config = createConfig()
      config.minLength = 8
      config.requireUppercase = true
      config.requireLowercase = false
      config.requireDigit = false
      config.requireSpecialChar = false
      let regex = new RegExp(IdentityPasswordPolicyMapper.buildComplexityRegex(config))

      expect(regex.test('Abcdef1!')).assertTrue()
      expect(regex.test('abcdefgh')).assertFalse()
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
