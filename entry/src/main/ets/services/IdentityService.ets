import { securityManager } from '@kit.MDMKit'
import { accountManager } from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Want } from '@kit.AbilityKit'
import { osAccount } from '@kit.BasicServicesKit'
import { OperationResult, PasswordComplexityConfig } from '../models/DataModels'
import { AppInfo } from '../constants/AppConstants'
import { EnterpriseAdminService } from './EnterpriseAdminService'

const TAG = 'IdentityService'
const DOMAIN = 0x0003

// 企业管理员 Want 对象
const ADMIN_WANT: Want = {
  bundleName: AppInfo.BUNDLE_NAME,
  abilityName: 'EnterpriseAdminAbility'
}

export class IdentityService {

  // ========== 正则生成器 ==========

  /**
   * 根据 UI 配置项动态生成密码复杂度正则表达式
   * 示例输出: ^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*])[a-zA-Z\d!@#$%^&*]{8,}$
   */
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

    // 如果没有任何字符类型要求，匹配任意字符
    let charClass: string
    if (charSet === '') {
      charClass = '.'
    } else {
      charClass = `[${charSet}]`
    }

    return `^${lookaheads.join('')}${charClass}{${config.minLength},}$`
  }

  /**
   * 根据配置生成人可读的描述文本
   */
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

  // ========== 口令策略 (securityManager) ==========

  static setPasswordPolicyWithResult(config: PasswordComplexityConfig): OperationResult<void> {
    try {
      let regex = IdentityService.buildComplexityRegex(config)
      let description = IdentityService.buildDescription(config)
      let policy: securityManager.PasswordPolicy = {
        complexityRegex: regex,
        validityPeriod: 0,
        additionalDescription: description
      }
      securityManager.setPasswordPolicy(ADMIN_WANT, policy)
      hilog.info(DOMAIN, TAG, `setPasswordPolicy success, regex=${regex}`)
      return { success: true } as OperationResult<void>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `setPasswordPolicy failed: ${JSON.stringify(err)}`)
      return IdentityService.buildFailureResult<void>('设置口令策略', err as Object)
    }
  }

  // 设置口令策略
  static setPasswordPolicy(config: PasswordComplexityConfig): boolean {
    return IdentityService.setPasswordPolicyWithResult(config).success
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

  // 获取口令策略
  static getPasswordPolicy(): securityManager.PasswordPolicy | null {
    return IdentityService.getPasswordPolicyWithResult().data ?? null
  }

  // ========== 域账号策略 (accountManager) ==========

  static setDomainAccountPolicyWithResult(passwordMaxAgeDays: number, expirationNotifyDays: number,
    authTokenValidityMinutes: number): OperationResult<void> {
    try {
      let policy: accountManager.DomainAccountPolicy = {
        authenticationValidityPeriod:
          authTokenValidityMinutes === -1 ? -1 : authTokenValidityMinutes * 60,
        passwordValidityPeriod:
          passwordMaxAgeDays === -1 ? -1 : passwordMaxAgeDays * 86400,
        passwordExpirationNotification:
          expirationNotifyDays * 86400
      }
      let emptyInfo: osAccount.DomainAccountInfo = {
        domain: '',
        accountName: '',
        serverConfigId: ''
      }
      accountManager.setDomainAccountPolicy(ADMIN_WANT, emptyInfo, policy)
      hilog.info(DOMAIN, TAG, `setDomainAccountPolicy success: ${JSON.stringify(policy)}`)
      return { success: true } as OperationResult<void>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `setDomainAccountPolicy failed: ${JSON.stringify(err)}`)
      return IdentityService.buildFailureResult<void>('设置域账号策略', err as Object)
    }
  }

  // 设置域账号策略（全局）
  static setDomainAccountPolicy(passwordMaxAgeDays: number, expirationNotifyDays: number,
    authTokenValidityMinutes: number): boolean {
    return IdentityService.setDomainAccountPolicyWithResult(
      passwordMaxAgeDays,
      expirationNotifyDays,
      authTokenValidityMinutes
    ).success
  }

  static getDomainAccountPolicyWithResult(): OperationResult<accountManager.DomainAccountPolicy | null> {
    try {
      let emptyInfo: osAccount.DomainAccountInfo = {
        domain: '',
        accountName: '',
        serverConfigId: ''
      }
      let result = accountManager.getDomainAccountPolicy(ADMIN_WANT, emptyInfo)
      hilog.info(DOMAIN, TAG, `getDomainAccountPolicy: ${JSON.stringify(result)}`)
      return {
        success: true,
        data: result
      } as OperationResult<accountManager.DomainAccountPolicy | null>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getDomainAccountPolicy failed: ${JSON.stringify(err)}`)
      return IdentityService.buildFailureResult<accountManager.DomainAccountPolicy | null>('读取域账号策略', err as Object, null)
    }
  }

  // 获取域账号策略（全局）
  static getDomainAccountPolicy(): accountManager.DomainAccountPolicy | null {
    return IdentityService.getDomainAccountPolicyWithResult().data ?? null
  }

  private static buildFailureResult<T>(action: string, err: Object, fallbackData?: T): OperationResult<T> {
    let code = EnterpriseAdminService.extractErrorCode(err)
    let isAdminMissing = EnterpriseAdminService.isAdminMissingError(err)
    let message = isAdminMissing ?
      '企业管理员未激活，无法执行身份策略操作。' :
      `${action}失败`
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
