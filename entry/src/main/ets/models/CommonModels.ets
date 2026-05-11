export type EnterpriseAdminType = 'super' | 'byod'

export interface AdminActivationState {
  activated: boolean
  errorCode?: number
  errorMessage?: string
  enableCommand: string
  adminType: EnterpriseAdminType
}

export interface OperationResult<T = void> {
  success: boolean
  data?: T
  errorCode?: number
  errorMessage?: string
  userMessage?: string
  isAdminMissing?: boolean
  stage?: string
  suggestion?: string
}

export interface ExportActionResult {
  success: boolean
  fileName?: string
  reason?: string
}

export enum SecurityEventResult {
  SUCCESS = 0,
  BLOCKED = 1,
  FAILED = 2
}

export function normalizeSecurityEventResult(
  value: SecurityEventResult,
  fallback: SecurityEventResult = SecurityEventResult.FAILED
): SecurityEventResult {
  if (value === SecurityEventResult.SUCCESS ||
    value === SecurityEventResult.BLOCKED ||
    value === SecurityEventResult.FAILED) {
    return value
  }
  return fallback
}

export function parseSecurityEventResult(
  rawValue: string,
  fallback: SecurityEventResult = SecurityEventResult.FAILED
): SecurityEventResult {
  let numeric = Number(rawValue)
  if (numeric === SecurityEventResult.SUCCESS ||
    numeric === SecurityEventResult.BLOCKED ||
    numeric === SecurityEventResult.FAILED) {
    return numeric as SecurityEventResult
  }
  return fallback
}
