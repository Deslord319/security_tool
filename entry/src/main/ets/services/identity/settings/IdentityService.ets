import { LogUtils } from '../../../utils/LogUtils'
import { securityManager } from '@kit.MDMKit'
import { ADMIN_WANT } from '../../../constants/AppConstants'
import { OperationResult, PasswordComplexityConfig } from '../../../models/DataModels'
import { PeripheralService } from '../../peripheral/interface-control/PeripheralService'
import {
  IdentityActionStrings,
  IdentityRequirementStrings
} from '../../../constants/modules/IdentityStrings'

const TAG = 'IdentityService'

export class IdentityService {
  static readonly DAY_IN_MS: number = 24 * 60 * 60 * 1000

  static toConfig(policy?: securityManager.PasswordPolicy | null): PasswordComplexityConfig | null {
    if (!policy) {
      return null
    }

    return {
      minLength: IdentityService.resolveMinLength(policy.complexityRegex),
      requireUppercase: IdentityService.hasUppercaseRequirement(policy.complexityRegex),
      requireLowercase: IdentityService.hasLowercaseRequirement(policy.complexityRegex),
      requireDigit: IdentityService.hasDigitRequirement(policy.complexityRegex),
      requireSpecialChar: IdentityService.hasSpecialRequirement(policy.complexityRegex),
      validityPeriod: IdentityService.toDays(policy.validityPeriod)
    }
  }

  static toPasswordPolicy(config: PasswordComplexityConfig): securityManager.PasswordPolicy {
    let policy: securityManager.PasswordPolicy = {
      complexityRegex: IdentityService.buildComplexityRegex(config),
      additionalDescription: IdentityService.buildDescription(config)
    }
    if (typeof config.validityPeriod === 'number') {
      policy.validityPeriod = IdentityService.toMilliseconds(config.validityPeriod)
    }
    return policy
  }

  static buildComplexityRegex(config: PasswordComplexityConfig): string {
    let lookaheads: string[] = []
    let charSet = ''

    if (config.requireLowercase) {
      lookaheads.push('(?=.*[a-z])')
      charSet += 'a-z'
    }
    if (config.requireUppercase) {
      lookaheads.push('(?=.*[A-Z])')
      charSet += 'A-Z'
    }
    if (config.requireDigit) {
      lookaheads.push('(?=.*\\d)')
      charSet += '\\d'
    }
    if (config.requireSpecialChar) {
      lookaheads.push('(?=.*[!@#$%^&*])')
      charSet += '!@#$%^&*'
    }

    let charClass: string = charSet === '' ? '.' : `[${charSet}]`
    return `^${lookaheads.join('')}${charClass}{${config.minLength},}$`
  }

  static buildDescription(config: PasswordComplexityConfig): string {
    let parts: string[] = [IdentityService.buildMinLengthRequirement(config.minLength)]
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

  static setPasswordPolicyWithResult(config: PasswordComplexityConfig): OperationResult<void> {
    try {
      let policy = IdentityService.toPasswordPolicy(config)
      LogUtils.info(TAG,
        `setPasswordPolicy request | minLength=${config.minLength}, upper=${config.requireUppercase}, lower=${config.requireLowercase}, digit=${config.requireDigit}, special=${config.requireSpecialChar}, validity=${typeof config.validityPeriod === 'number' ? config.validityPeriod : -1}, regex=${policy.complexityRegex}`
      )
      securityManager.setPasswordPolicy(ADMIN_WANT, policy)
      LogUtils.info(TAG, `setPasswordPolicy success | regex=${policy.complexityRegex}, validity=${typeof policy.validityPeriod === 'number' ? policy.validityPeriod : -1}`)
      return { success: true } as OperationResult<void>
    } catch (err) {
      LogUtils.error(TAG, `setPasswordPolicy failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<void>(IdentityActionStrings.PASSWORD_POLICY, err as Object)
    }
  }

  static getPasswordPolicyWithResult(): OperationResult<securityManager.PasswordPolicy | null> {
    try {
      let result = securityManager.getPasswordPolicy(ADMIN_WANT)
      LogUtils.info(TAG,
        `getPasswordPolicy success | hasPolicy=${result !== null}, regex=${result?.complexityRegex ?? ''}, validity=${typeof result?.validityPeriod === 'number' ? result.validityPeriod : -1}`
      )
      return {
        success: true,
        data: result
      } as OperationResult<securityManager.PasswordPolicy | null>
    } catch (err) {
      LogUtils.error(TAG, `getPasswordPolicy failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<securityManager.PasswordPolicy | null>(
        IdentityActionStrings.READ_PASSWORD_POLICY,
        err as Object,
        null
      )
    }
  }

  private static buildMinLengthRequirement(minLength: number): string {
    return IdentityRequirementStrings.buildPasswordMinLengthRequirement(minLength)
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
    return days * IdentityService.DAY_IN_MS
  }

  private static toDays(milliseconds?: number): number | undefined {
    if (typeof milliseconds !== 'number') {
      return undefined
    }
    return Math.round(milliseconds / IdentityService.DAY_IN_MS)
  }
}
