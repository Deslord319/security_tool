import { CommonStrings } from '../CommonStrings'

export class IdentityStrings {
  static readonly pageTitle: string = CommonStrings.moduleIdentity
  static readonly pageSubtitle: string = '配置账户口令复杂度和密码有效期，保障系统访问安全。'

  static readonly saveButton: string = CommonStrings.actionSaveConfig
  static readonly saveAction: string = '保存身份鉴别配置'
  static readonly passwordPolicyAction: string = '设置口令策略'
  static readonly saveSuccess: string = '身份鉴别配置已保存'
  static readonly adminRequired: string = '企业管理员未激活'
  static readonly adminRequiredWithActionSuffix: string = '未完成，请先激活企业管理员'
  static readonly actionRetrySuffix: string = '未完成，请稍后重试'
  static readonly invalidValidityDays: string = '请输入非负整数天数，0 表示永久有效'

  static readonly sectionPasswordComplexity: string = '口令复杂度策略'
  static readonly minPasswordLength: string = '最小密码长度'
  static readonly minPasswordLengthDesc: string = '设置用户密码的最少字符数要求。'
  static readonly requireUppercase: string = '要求包含大写字母'
  static readonly requireUppercaseDesc: string = '密码中必须包含至少一个大写英文字母 (A-Z)。'
  static readonly requireLowercase: string = '要求包含小写字母'
  static readonly requireLowercaseDesc: string = '密码中必须包含至少一个小写英文字母 (a-z)。'
  static readonly requireDigit: string = '要求包含数字'
  static readonly requireDigitDesc: string = '密码中必须包含至少一个数字 (0-9)。'
  static readonly requireSpecialChar: string = '要求包含特殊字符'
  static readonly requireSpecialCharDesc: string = '密码中必须包含至少一个特殊字符 (!@#$%^&*)。'
  static readonly passwordValidityPeriod: string = '密码有效期'
  static readonly passwordValidityPeriodDesc: string =
    '设置密码需要变更的周期。固定选项保持不变，也支持自定义输入，0 表示永久有效。'
  static readonly customDaysPlaceholder: string = '输入天数'
  static readonly dayUnit: string = '天'
  static readonly permanentOption: string = '永久'
  static readonly customOption: string = '自定义'
  static readonly byteUnitSuffix: string = '位'
}
