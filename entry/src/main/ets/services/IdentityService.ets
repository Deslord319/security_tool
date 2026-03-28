import { securityManager } from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Want } from '@kit.AbilityKit'
import { OperationResult, PasswordComplexityConfig } from '../models/DataModels'
import { AppInfo } from '../constants/AppConstants'
import { EnterpriseAdminService } from './EnterpriseAdminService'
import { CommonErrorUtils } from '../utils/CommonErrorUtils'

const TAG = 'IdentityService'
const DOMAIN = 0x0003

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
    let parts: string[] = [`至少${config.minLength}个字符`]
    if (config.requireUppercase) {
      parts.push('包含大写字母')
    }
    if (config.requireLowercase) {
      parts.push('包含小写字母')
    }
    if (config.requireDigit) {
      parts.push('包含数字')
    }
    if (config.requireSpecialChar) {
      parts.push('包含特殊字符(!@#$%^&*)')
    }
    return parts.join('，')
  }

  static setPasswordPolicyWithResult(config: PasswordComplexityConfig): OperationResult<void> {
    try {
      let regex = IdentityService.buildComplexityRegex(config)
      let description = IdentityService.buildDescription(config)
      let policy: securityManager.PasswordPolicy = {
        complexityRegex: regex,
        validityPeriod: config.validityPeriod,
        additionalDescription: description
      }
      securityManager.setPasswordPolicy(ADMIN_WANT, policy)
      hilog.info(DOMAIN, TAG, `setPasswordPolicy success, regex=${regex}, validityPeriod=${config.validityPeriod}`)
      return { success: true } as OperationResult<void>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `setPasswordPolicy failed: ${JSON.stringify(err)}`)
      return IdentityService.buildFailureResult<void>('设置口令策略', err as Object)
    }
  }

  static getPasswordPolicyWithResult(): OperationResult<securityManager.PasswordPolicy | null> {
    try {
      let result = securityManager.getPasswordPolicy(ADMIN_WANT)
      hilog.info(DOMAIN, TAG, `getPasswordPolicy: ${JSON.stringify(result)}`)
      return {
        success: true,
        data: result
      } as OperationResult<securityManager.PasswordPolicy | null>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getPasswordPolicy failed: ${JSON.stringify(err)}`)
      return IdentityService.buildFailureResult<securityManager.PasswordPolicy | null>('读取口令策略', err as Object, null)
    }
  }

  private static buildFailureResult<T>(action: string, err: Object, fallbackData?: T): OperationResult<T> {
    let code = CommonErrorUtils.extractErrorCode(err)
    let isAdminMissing = EnterpriseAdminService.isAdminMissingError(err)
    let message = isAdminMissing ? '企业管理员未激活，无法执行身份策略操作。' : `${action}失败`
    let suggestion = isAdminMissing ?
      `请先在设备执行：${EnterpriseAdminService.buildEnableCommand()}` :
      '请检查权限声明、签名模板和设备策略状态后重试。'
    return {
      success: false,
      data: fallbackData,
      errorCode: code,
      errorMessage: message,
      isAdminMissing: isAdminMissing,
      suggestion: suggestion
    } as OperationResult<T>
  }
}
