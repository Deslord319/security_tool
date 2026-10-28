import { IdentityAuthStrings } from '../../../constants/modules/IdentityStrings'
import { AuthMethod } from '../../../models/AuthModels'
import { SUPPORTED_TOOL_AUTH_METHODS } from '../../../models/ToolSettingsModels'
export interface AuthMethodOption {
  label: string
  value: AuthMethod
}

/**
 * 认证方式下拉展示配置以惰性函数提供：认证方式标签经身份鉴别模块
 * identity_auth_method_* 资源解析，不得在模块顶层常量中读取文案门面。
 */
export function getAuthMethodOptions(): AuthMethodOption[] {
  return SUPPORTED_TOOL_AUTH_METHODS.map((value: AuthMethod): AuthMethodOption => ({
    label: resolveAuthMethodLabel(value),
    value: value
  }))
}

function resolveAuthMethodLabel(value: AuthMethod): string {
  switch (value) {
    case AuthMethod.FINGERPRINT:
      return IdentityAuthStrings.METHOD_FINGERPRINT
    case AuthMethod.PIN:
    default:
      return IdentityAuthStrings.METHOD_PIN
  }
}
