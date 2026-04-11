import { LogUtils } from '../../../utils/LogUtils'
import { securityManager } from '@kit.MDMKit'

import { Want } from '@kit.AbilityKit'
import { OperationResult, PasswordComplexityConfig } from '../../../models/DataModels'
import { AppInfo } from '../../../constants/AppConstants'
import { EnterpriseAdminService } from '../../admin/activation/EnterpriseAdminService'
import { PeripheralService } from '../../peripheral/interface-control/PeripheralService'
import { CommonErrorUtils } from '../../../utils/CommonErrorUtils'
import {
  IdentityActionStrings,
  IdentityRequirementStrings
} from '../../../constants/modules/IdentityStrings'

const TAG = 'IdentityService'

const ADMIN_WANT: Want = {
  bundleName: AppInfo.BUNDLE_NAME,
  abilityName: 'EnterpriseAdminAbility'
}

export class IdentityService {
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
      let regex = IdentityService.buildComplexityRegex(config)
      let description = IdentityService.buildDescription(config)
      let policy: securityManager.PasswordPolicy = {
        complexityRegex: regex,
        additionalDescription: description
      }
      if (typeof config.validityPeriod === 'number') {
        policy.validityPeriod = config.validityPeriod
      }
      securityManager.setPasswordPolicy(ADMIN_WANT, policy)
      return { success: true } as OperationResult<void>
    } catch (err) {
      LogUtils.error(TAG, `setPasswordPolicy failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<void>(IdentityActionStrings.PASSWORD_POLICY, err as Object)
    }
  }

  static getPasswordPolicyWithResult(): OperationResult<securityManager.PasswordPolicy | null> {
    try {
      let result = securityManager.getPasswordPolicy(ADMIN_WANT)
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
}
