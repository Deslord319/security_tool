import { CommonStrings } from '../CommonStrings'

export class IdentityStrings {
  static readonly pageSubtitle: string = '配置账户口令复杂度和密码有效期，保障系统访问安全'

  static readonly saveAction: string = '保存身份鉴别配置'
  static readonly passwordPolicyAction: string = '设置口令策略'
  static readonly readPasswordPolicyAction: string = '读取口令策略'
  static readonly saveSuccess: string = '身份鉴别配置已保存'
  static readonly adminRequired: string = '企业管理员未激活'
  static readonly adminRequiredWithActionSuffix: string = '未完成，请先激活企业管理员'
  static readonly actionRetrySuffix: string = '未完成，请稍后重试'
  static readonly invalidValidityDays: string = '请输入非负整数天数，0 表示永久有效'

  static readonly sectionPasswordComplexity: string = '口令复杂度策略'
  static readonly minPasswordLength: string = '最小密码长度'
  static readonly minPasswordLengthDesc: string = '设置用户密码的最少字符数要求。'
  static readonly requireUppercase: string = '要求包含大写字母'
  static readonly requireUppercaseDesc: string = '密码中必须包含至少一个大写英文字母 (A-Z)'
  static readonly requireLowercase: string = '要求包含小写字母'
  static readonly requireLowercaseDesc: string = '密码中必须包含至少一个小写英文字母 (a-z)'
  static readonly requireDigit: string = '要求包含数字'
  static readonly requireDigitDesc: string = '密码中必须包含至少一个数字 (0-9)'
  static readonly requireSpecialChar: string = '要求包含特殊字符'
  static readonly requireSpecialCharDesc: string = '密码中必须包含至少一个特殊字符 (!@#$%^&*)'
  static readonly passwordValidityPeriod: string = '密码有效期'
  static readonly passwordValidityPeriodDesc: string =
    '设置密码需要变更的周期。固定选项保持不变，也支持自定义输入，0 表示永久有效。'
  static readonly customDaysPlaceholder: string = '输入天数'
  static readonly dayUnit: string = '天'
  static readonly permanentOption: string = '永久'
  static readonly customOption: string = '自定义'
  static readonly byteUnitSuffix: string = '位'
  static readonly authMethodFingerprint: string = '指纹'
  static readonly authMethodGeneric: string = '认证方式'
  static readonly authMethodUnsupported: string = '当前设备不支持该认证方式'
  static readonly authSystemAvailable: string = '系统认证可用'
  static readonly authDialogTitle: string = '身份验证'
  static readonly authFailedOrCanceled: string = '验证失败或已取消'
  static readonly authTrustLevelInsufficient: string = '当前系统认证等级不满足要求'
  static readonly authPinExpired: string = '系统 PIN 已过期，请先在系统设置中更新'
  static readonly authPermissionDenied: string = '认证权限不足，无法调用系统认证'
  static readonly authInvalidParams: string = '认证参数错误'
  static readonly passwordRequirementUppercase: string = '包含大写字母'
  static readonly passwordRequirementLowercase: string = '包含小写字母'
  static readonly passwordRequirementDigit: string = '包含数字'
  static readonly passwordRequirementSpecial: string = '包含特殊字符(!@#$%^&*)'

  static buildPasswordMinLengthRequirement(minLength: number): string {
    return `至少${minLength}个字符`
  }

  static buildAuthNotEnrolled(authLabel: string): string {
    return `系统未录入${authLabel}或凭据不满足要求`
  }

  static buildAuthUnavailable(authLabel: string): string {
    return `系统${authLabel}认证暂不可用`
  }
}
