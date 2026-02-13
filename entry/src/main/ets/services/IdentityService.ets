import { securityManager } from '@kit.MDMKit'
import { accountManager } from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Want } from '@kit.AbilityKit'
import { osAccount } from '@kit.BasicServicesKit'
import { PasswordComplexityConfig } from '../models/DataModels'

const TAG = 'IdentityService'
const DOMAIN = 0x0003

// 企业管理员 Want 对象
const ADMIN_WANT: Want = {
  bundleName: 'com.example.securitytool',
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

  // 设置口令策略
  static setPasswordPolicy(config: PasswordComplexityConfig): boolean {
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
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `setPasswordPolicy failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 获取口令策略
  static getPasswordPolicy(): securityManager.PasswordPolicy | null {
    try {
      let result = securityManager.getPasswordPolicy(ADMIN_WANT)
      hilog.info(DOMAIN, TAG, `getPasswordPolicy: ${JSON.stringify(result)}`)
      return result
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getPasswordPolicy failed: ${JSON.stringify(err)}`)
      return null
    }
  }

  // ========== 域账号策略 (accountManager) ==========

  // 设置域账号策略（全局）
  static setDomainAccountPolicy(passwordMaxAgeDays: number, expirationNotifyDays: number,
    authTokenValidityMinutes: number): boolean {
    try {
      let policy: accountManager.DomainAccountPolicy = {
        authenticationValidityPeriod:
          authTokenValidityMinutes === -1 ? -1 : authTokenValidityMinutes * 60,
        passwordValidityPeriod:
          passwordMaxAgeDays === -1 ? -1 : passwordMaxAgeDays * 86400,
        passwordExpirationNotification:
          expirationNotifyDays * 86400
      }
      // 全局策略: domainAccountInfo 内部属性均为空
      let emptyInfo: osAccount.DomainAccountInfo = {
        domain: '',
        accountName: '',
        serverConfigId: ''
      }
      accountManager.setDomainAccountPolicy(ADMIN_WANT, emptyInfo, policy)
      hilog.info(DOMAIN, TAG, `setDomainAccountPolicy success: ${JSON.stringify(policy)}`)
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `setDomainAccountPolicy failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 获取域账号策略（全局）
  static getDomainAccountPolicy(): accountManager.DomainAccountPolicy | null {
    try {
      let emptyInfo: osAccount.DomainAccountInfo = {
        domain: '',
        accountName: '',
        serverConfigId: ''
      }
      let result = accountManager.getDomainAccountPolicy(ADMIN_WANT, emptyInfo)
      hilog.info(DOMAIN, TAG, `getDomainAccountPolicy: ${JSON.stringify(result)}`)
      return result
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getDomainAccountPolicy failed: ${JSON.stringify(err)}`)
      return null
    }
  }
}
