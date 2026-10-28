/**
 * 身份鉴别模块文案资源门面
 *
 * 文案唯一来源为 resources/{base,en_US}/element/string.json 中的 identity_* 资源。
 * 门面保持与旧常量一致的访问方式（IdentityStrings.ets 类名与属性名不变），
 * 内部经 AppStrings 资源管理器取值，设备语言切换后按当前 locale 解析。
 *
 * 单元测试环境（AppStrings 未初始化）下门面返回资源名；相关断言必须经门面构造，
 * 不得断言中文或英文字面量。@Concurrent 任务不得直接读取本门面，动作文案由主线程
 * 解析后作为参数传入任务（见 IdentityPasswordPolicyTasks）。
 */
import { AppStrings } from '../AppStrings'

export class IdentityActionStrings {

  static get PASSWORD_POLICY(): string {
    return AppStrings.get('identity_action_password_policy')
  }

  static get READ_PASSWORD_POLICY(): string {
    return AppStrings.get('identity_action_read_password_policy')
  }
}

export class IdentityMessageStrings {
  static get SAVE_SUCCESS(): string {
    return AppStrings.get('identity_message_save_success')
  }

  static get SAVE_ADMIN_REQUIRED(): string {
    return AppStrings.get('identity_message_save_admin_required')
  }

  static get PASSWORD_POLICY_RETRY(): string {
    return AppStrings.get('identity_message_password_policy_retry')
  }

  static get INVALID_VALIDITY_DAYS(): string {
    return AppStrings.get('identity_message_invalid_validity_days')
  }

  static get IMMEDIATE_EXPIRY_RISK_TITLE(): string {
    return AppStrings.get('identity_message_immediate_expiry_risk_title')
  }

  static get IMMEDIATE_EXPIRY_RISK_MESSAGE(): string {
    return AppStrings.get('identity_message_immediate_expiry_risk_message')
  }
}

export class IdentityFormStrings {

  static buildLengthOption(value: number): string {
    return AppStrings.format('identity_form_length_option', value)
  }
}

export class IdentityAuthStrings {
  static get METHOD_PIN(): string {
    return AppStrings.get('identity_auth_method_pin')
  }

  static get METHOD_FINGERPRINT(): string {
    return AppStrings.get('identity_auth_method_fingerprint')
  }

  static get METHOD_UNSUPPORTED(): string {
    return AppStrings.get('identity_auth_method_unsupported')
  }

  static get SYSTEM_AVAILABLE(): string {
    return AppStrings.get('identity_auth_system_available')
  }

  static get DIALOG_TITLE(): string {
    return AppStrings.get('identity_auth_dialog_title')
  }

  static get FAILED_OR_CANCELED(): string {
    return AppStrings.get('identity_auth_failed_or_canceled')
  }

  static get TRUST_LEVEL_INSUFFICIENT(): string {
    return AppStrings.get('identity_auth_trust_level_insufficient')
  }

  static get PIN_EXPIRED(): string {
    return AppStrings.get('identity_auth_pin_expired')
  }

  static get PERMISSION_DENIED(): string {
    return AppStrings.get('identity_auth_permission_denied')
  }

  static get INVALID_PARAMS(): string {
    return AppStrings.get('identity_auth_invalid_params')
  }

  static buildNotEnrolled(authLabel: string): string {
    return AppStrings.format('identity_auth_not_enrolled', authLabel)
  }

  static buildUnavailable(authLabel: string): string {
    return AppStrings.format('identity_auth_unavailable', authLabel)
  }
}

export class IdentityRequirementStrings {
  static get UPPERCASE(): string {
    return AppStrings.get('identity_requirement_uppercase')
  }

  static get LOWERCASE(): string {
    return AppStrings.get('identity_requirement_lowercase')
  }

  static get DIGIT(): string {
    return AppStrings.get('identity_requirement_digit')
  }

  static get SPECIAL(): string {
    return AppStrings.get('identity_requirement_special')
  }

  static buildPasswordMinLengthRequirement(minLength: number): string {
    return AppStrings.format('identity_requirement_min_length', minLength)
  }
}
