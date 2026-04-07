import {
  FirewallPresetMode,
  FirewallToggleRejectReason,
  FirewallUserApplyMode,
  UserFirewallModeApplyResult,
  UserFirewallModeState,
  UserFirewallOption
} from '../DataModels'

export type { FirewallPresetMode, FirewallUserApplyMode, UserFirewallOption }

export interface FirewallOperationResult {
  success: boolean
  errorCode?: number
  errorMessage?: string
}

export interface FirewallOverviewState {
  enabled: boolean
  currentMode: FirewallPresetMode
}

export interface FirewallToggleOperationResult extends FirewallOperationResult {
  targetEnabled: boolean
  reason?: FirewallToggleRejectReason
  lockRemainingSec?: number
}

export interface FirewallRulesSaveResult extends FirewallOperationResult {
  appliedRuleCount?: number
  reapplyTotalUsers?: number
  reapplySuccessCount?: number
  reapplyFailedCount?: number
  failedUsers?: number[]
}

export type FirewallUserModeStateResult = UserFirewallModeState

export type FirewallUserApplyResult = UserFirewallModeApplyResult
