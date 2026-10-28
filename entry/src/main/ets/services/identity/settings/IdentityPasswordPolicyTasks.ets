import { LogUtils } from '../../../utils/LogUtils'
import { securityManager } from '@kit.MDMKit'
import { ADMIN_WANT } from '../../../constants/AppConstants'
import { OperationResult } from '../../../models/CommonModels'
import { PasswordComplexityConfig } from '../../../models/IdentityModels'
import { CommonErrorUtils } from '../../../utils/CommonErrorUtils'
import { ErrorLike } from '../../../types/LooseValueTypes'
import { EnterpriseAdminService } from '../../admin/activation/EnterpriseAdminService'
import { IdentityPasswordPolicyMapper } from './IdentityPasswordPolicyMapper'

@Concurrent
export function setPasswordPolicyWithResultTask(config: PasswordComplexityConfig): OperationResult<void> {
  try {
    let policy: securityManager.PasswordPolicy = IdentityPasswordPolicyMapper.toPasswordPolicy(config)
    LogUtils.info('IdentityService',
      `setPasswordPolicy request | minLength=${config.minLength}, upper=${config.requireUppercase}, lower=${config.requireLowercase}, digit=${config.requireDigit}, special=${config.requireSpecialChar}, validity=${typeof config.validityPeriod === 'number' ? config.validityPeriod : -1}, regex=${policy.complexityRegex}`
    )
    securityManager.setPasswordPolicy(ADMIN_WANT, policy)
    LogUtils.info('IdentityService', `setPasswordPolicy success | regex=${policy.complexityRegex}, validity=${typeof policy.validityPeriod === 'number' ? policy.validityPeriod : -1}`)
    return { success: true } as OperationResult<void>
  } catch (err) {
    LogUtils.error('IdentityService', `setPasswordPolicy failed: ${JSON.stringify(err)}`)
    // 任务线程内文案门面不可见：返回空 errorMessage，由页面 displayReason 走本地化兜底
    return {
      success: false,
      errorCode: CommonErrorUtils.extractErrorCode(err as ErrorLike),
      errorMessage: '',
      isAdminMissing: EnterpriseAdminService.isAdminMissingError(err as ErrorLike)
    } as OperationResult<void>
  }
}

@Concurrent
export function getPasswordPolicyWithResultTask(): OperationResult<securityManager.PasswordPolicy | null> {
  try {
    let result = securityManager.getPasswordPolicy(ADMIN_WANT)
    LogUtils.info('IdentityService',
      `getPasswordPolicy success | hasPolicy=${result !== null}, regex=${result?.complexityRegex ?? ''}, validity=${typeof result?.validityPeriod === 'number' ? result.validityPeriod : -1}`
    )
    return {
      success: true,
      data: result
    } as OperationResult<securityManager.PasswordPolicy | null>
  } catch (err) {
    LogUtils.error('IdentityService', `getPasswordPolicy failed: ${JSON.stringify(err)}`)
    return {
      success: false,
      data: null,
      errorCode: CommonErrorUtils.extractErrorCode(err as ErrorLike),
      errorMessage: '',
      isAdminMissing: EnterpriseAdminService.isAdminMissingError(err as ErrorLike)
    } as OperationResult<securityManager.PasswordPolicy | null>
  }
}
