export interface PasswordComplexityConfig {
  minLength: number
  requireUppercase: boolean
  requireLowercase: boolean
  requireDigit: boolean
  requireSpecialChar: boolean
  validityPeriod?: number
}

export const PASSWORD_LENGTH_OPTIONS: number[] = [6, 8, 10, 12, 16, 20, 24]
export type PasswordValidityPreset = 'halfYear' | 'oneYear' | 'permanent'
export const PASSWORD_VALIDITY_PRESETS: PasswordValidityPreset[] = ['halfYear', 'oneYear', 'permanent']
