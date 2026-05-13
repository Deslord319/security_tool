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
export const PASSWORD_VALIDITY_DAY_IN_MS: number = 24 * 60 * 60 * 1000
export const PASSWORD_PERMANENT_VALIDITY_YEARS: number = 100
export const PASSWORD_PERMANENT_VALIDITY_DAY_OPTIONS: number[] = [36524, 36525, 36526]
export const PASSWORD_HALF_YEAR_VALIDITY_DAY_OPTIONS: number[] = [181, 182, 183, 184]
export const PASSWORD_ONE_YEAR_VALIDITY_DAY_OPTIONS: number[] = [365, 366]
