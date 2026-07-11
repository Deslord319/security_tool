import { securityManager } from '@kit.MDMKit'
import {
  PASSWORD_VALIDITY_DAY_IN_MS,
  PasswordComplexityConfig
} from '../../../models/IdentityModels'
import { IdentityRequirementStrings } from '../../../constants/modules/IdentityStrings'

export class IdentityPasswordPolicyMapper {
  static toConfig(policy?: securityManager.PasswordPolicy | null): PasswordComplexityConfig | null {
    if (!policy || IdentityPasswordPolicyMapper.isEmptyPolicy(policy)) {
      return null
    }

    return {
      minLength: IdentityPasswordPolicyMapper.resolveMinLength(policy.complexityRegex),
      requireUppercase: IdentityPasswordPolicyMapper.hasUppercaseRequirement(policy.complexityRegex),
      requireLowercase: IdentityPasswordPolicyMapper.hasLowercaseRequirement(policy.complexityRegex),
      requireDigit: IdentityPasswordPolicyMapper.hasDigitRequirement(policy.complexityRegex),
      requireSpecialChar: IdentityPasswordPolicyMapper.hasSpecialRequirement(policy.complexityRegex),
      validityPeriod: IdentityPasswordPolicyMapper.toDays(policy.validityPeriod)
    }
  }

  static toPasswordPolicy(config: PasswordComplexityConfig): securityManager.PasswordPolicy {
    let policy: securityManager.PasswordPolicy = {
      complexityRegex: IdentityPasswordPolicyMapper.buildComplexityRegex(config),
      additionalDescription: IdentityPasswordPolicyMapper.buildDescription(config)
    }
    if (typeof config.validityPeriod === 'number') {
      policy.validityPeriod = IdentityPasswordPolicyMapper.toMilliseconds(config.validityPeriod)
    }
    return policy
  }

  static buildComplexityRegex(config: PasswordComplexityConfig): string {
    let lookaheads: string[] = []

    if (config.requireLowercase) {
      lookaheads.push('(?=.*[a-z])')
    }
    if (config.requireUppercase) {
      lookaheads.push('(?=.*[A-Z])')
    }
    if (config.requireDigit) {
      lookaheads.push('(?=.*\\d)')
    }
    if (config.requireSpecialChar) {
      lookaheads.push('(?=.*[!@#$%^&*])')
    }

    return `^${lookaheads.join('')}.{${config.minLength},}$`
  }

  static buildDescription(config: PasswordComplexityConfig): string {
    let parts: string[] = [IdentityRequirementStrings.buildPasswordMinLengthRequirement(config.minLength)]
    if (config.requireUppercase) {
      parts.push(IdentityRequirementStrings.UPPERCASE)
    }
    if (config.requireLowercase) {
      parts.push(IdentityRequirementStrings.LOWERCASE)
    }
    if (config.requireDigit) {
      parts.push(IdentityRequirementStrings.DIGIT)
    }
    if (config.requireSpecialChar) {
      parts.push(IdentityRequirementStrings.SPECIAL)
    }
    return parts.join('，')
  }

  private static hasLowercaseRequirement(regex?: string): boolean {
    let source = regex ?? ''
    return source.indexOf('(?=.*[a-z])') >= 0
  }

  private static hasUppercaseRequirement(regex?: string): boolean {
    let source = regex ?? ''
    return source.indexOf('(?=.*[A-Z])') >= 0
  }

  private static hasDigitRequirement(regex?: string): boolean {
    let source = regex ?? ''
    return source.indexOf('(?=.*\\d)') >= 0 || source.indexOf('(?=.*[0-9])') >= 0
  }

  private static hasSpecialRequirement(regex?: string): boolean {
    let source = regex ?? ''
    return source.indexOf('(?=.*[!@#$%^&*])') >= 0 ||
      source.indexOf('(?=.*[^a-zA-Z0-9])') >= 0 ||
      source.indexOf('(?=.*[^A-Za-z0-9])') >= 0
  }

  private static resolveMinLength(regex?: string): number {
    let source = regex ?? ''
    let lenMatch = source.match(/\{(\d+),\}/)
    if (!lenMatch || !lenMatch[1]) {
      return 0
    }
    return parseInt(lenMatch[1])
  }

  private static toMilliseconds(days?: number): number | undefined {
    if (typeof days !== 'number') {
      return undefined
    }
    return days * PASSWORD_VALIDITY_DAY_IN_MS
  }

  private static toDays(milliseconds?: number): number | undefined {
    if (typeof milliseconds !== 'number') {
      return undefined
    }
    return Math.round(milliseconds / PASSWORD_VALIDITY_DAY_IN_MS)
  }

  private static isEmptyPolicy(policy: securityManager.PasswordPolicy): boolean {
    let complexityRegex = policy.complexityRegex?.trim() ?? ''
    let additionalDescription = policy.additionalDescription?.trim() ?? ''
    return complexityRegex.length === 0 &&
      additionalDescription.length === 0 &&
      IdentityPasswordPolicyMapper.isUnsetOrDefaultPolicyValidity(policy.validityPeriod)
  }

  private static isUnsetOrDefaultPolicyValidity(validityPeriod?: number): boolean {
    return typeof validityPeriod !== 'number' || validityPeriod === 0
  }
}
