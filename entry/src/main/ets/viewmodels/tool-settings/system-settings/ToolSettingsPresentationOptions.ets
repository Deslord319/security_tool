import { IdentityAuthStrings } from '../../../constants/modules/IdentityStrings'
import { AuthMethod } from '../../../models/AuthModels'
import { SUPPORTED_TOOL_AUTH_METHODS } from '../../../models/ToolSettingsModels'
export interface AuthMethodOption {
  label: string
  value: AuthMethod
}

export const AUTH_METHOD_OPTIONS: AuthMethodOption[] = SUPPORTED_TOOL_AUTH_METHODS.map((value: AuthMethod): AuthMethodOption => ({
  label: resolveAuthMethodLabel(value),
  value: value
}))

function resolveAuthMethodLabel(value: AuthMethod): string {
  switch (value) {
    case AuthMethod.FINGERPRINT:
      return IdentityAuthStrings.METHOD_FINGERPRINT
    case AuthMethod.PIN:
    default:
      return IdentityAuthStrings.METHOD_PIN
  }
}
