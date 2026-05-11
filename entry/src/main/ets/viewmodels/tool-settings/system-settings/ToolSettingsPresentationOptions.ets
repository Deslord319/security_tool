import { IdentityAuthStrings } from '../../../constants/modules/IdentityStrings'
import { AuthMethod } from '../../../models/DataModels'

export interface AuthMethodOption {
  label: string
  value: AuthMethod
}

export const AUTH_METHOD_OPTIONS: AuthMethodOption[] = [
  { label: IdentityAuthStrings.METHOD_PIN, value: AuthMethod.PIN },
  { label: IdentityAuthStrings.METHOD_FINGERPRINT, value: AuthMethod.FINGERPRINT }
]
