export class IdentityPageStrings {
  static readonly SUBTITLE: string = '配置账户口令复杂度和密码有效期，保障系统访问安全'
}

export class IdentityActionStrings {
  static readonly SAVE: string = '保存身份鉴别配置'
  static readonly PASSWORD_POLICY: string = '设置口令策略'
  static readonly READ_PASSWORD_POLICY: string = '读取口令策略'
}

export class IdentityMessageStrings {
  static readonly SAVE_SUCCESS: string = '身份鉴别配置已保存'
  static readonly ADMIN_REQUIRED_WITH_ACTION_SUFFIX: string = '未完成，请先激活企业管理员'
  static readonly ACTION_RETRY_SUFFIX: string = '未完成，请稍后重试'
  static readonly INVALID_VALIDITY_DAYS: string = '请输入非负整数天数，0 表示永久有效'
}

export class IdentitySectionStrings {
  static readonly PASSWORD_COMPLEXITY: string = '口令复杂度策略'
  static readonly MIN_PASSWORD_LENGTH: string = '最小密码长度'
  static readonly MIN_PASSWORD_LENGTH_DESC: string = '设置用户密码的最少字符数要求'
  static readonly REQUIRE_UPPERCASE: string = '要求包含大写字母'
  static readonly REQUIRE_UPPERCASE_DESC: string = '密码中必须包含至少一个大写英文字母 (A-Z)'
  static readonly REQUIRE_LOWERCASE: string = '要求包含小写字母'
  static readonly REQUIRE_LOWERCASE_DESC: string = '密码中必须包含至少一个小写英文字母 (a-z)'
  static readonly REQUIRE_DIGIT: string = '要求包含数字'
  static readonly REQUIRE_DIGIT_DESC: string = '密码中必须包含至少一个数字 (0-9)'
  static readonly REQUIRE_SPECIAL_CHAR: string = '要求包含特殊字符'
  static readonly REQUIRE_SPECIAL_CHAR_DESC: string = '密码中必须包含至少一个特殊字符 (!@#$%^&*)'
  static readonly PASSWORD_VALIDITY_PERIOD: string = '密码有效期'
  static readonly PASSWORD_VALIDITY_PERIOD_DESC: string = '设置密码需要变更的周期'
}

export class IdentityFormStrings {
  static readonly CUSTOM_DAYS_PLACEHOLDER: string = '输入天数'
  static readonly DAY_UNIT: string = '天'
  static readonly PERMANENT_OPTION: string = '永久'
  static readonly CUSTOM_OPTION: string = '自定义'
  static readonly BYTE_UNIT_SUFFIX: string = '位'
}

export class IdentityAuthStrings {
  static readonly METHOD_FINGERPRINT: string = '指纹'
  static readonly METHOD_UNSUPPORTED: string = '当前设备不支持该认证方式'
  static readonly SYSTEM_AVAILABLE: string = '系统认证可用'
  static readonly DIALOG_TITLE: string = '身份验证'
  static readonly FAILED_OR_CANCELED: string = '验证失败或已取消'
  static readonly TRUST_LEVEL_INSUFFICIENT: string = '当前系统认证等级不满足要求'
  static readonly PIN_EXPIRED: string = '系统 PIN 已过期，请先在系统设置中更新'
  static readonly PERMISSION_DENIED: string = '认证权限不足，无法调用系统认证'
  static readonly INVALID_PARAMS: string = '认证参数错误'

  static buildNotEnrolled(authLabel: string): string {
    return `系统未录入${authLabel}或凭据不满足要求`
  }

  static buildUnavailable(authLabel: string): string {
    return `系统${authLabel}认证暂不可用`
  }
}

export class IdentityRequirementStrings {
  static readonly UPPERCASE: string = '包含大写字母'
  static readonly LOWERCASE: string = '包含小写字母'
  static readonly DIGIT: string = '包含数字'
  static readonly SPECIAL: string = '包含特殊字符(!@#$%^&*)'

  static buildPasswordMinLengthRequirement(minLength: number): string {
    return `至少${minLength}个字符`
  }
}
