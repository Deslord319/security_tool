import { netFirewall } from '@kit.NetworkKit'
import { OperationResult } from '../../models/CommonModels'

export type FirewallPresetMode = 'public' | 'private' | 'custom'
export type FirewallUserPolicyMode = 'allowlist' | 'denylist'
export type FirewallDefaultPolicyMode = FirewallUserPolicyMode | 'custom' | 'unknown'

export const FIREWALL_USER_POLICY_MODE_OPTIONS: FirewallUserPolicyMode[] = ['allowlist', 'denylist']

export const FIREWALL_PROTOCOL_TCP = 6
export const FIREWALL_PROTOCOL_UDP = 17
export const FIREWALL_PROTOCOL_ICMP = 1
export const FIREWALL_RULE_PROTOCOL_OPTIONS: number[] = [
  FIREWALL_PROTOCOL_TCP,
  FIREWALL_PROTOCOL_UDP,
  FIREWALL_PROTOCOL_ICMP
]
export const FIREWALL_IPV4_PARAM_TYPE = 1
export const FIREWALL_IPV4_RANGE_PARAM_TYPE = 2
export const FIREWALL_IPV4_FAMILY = 1
export const FIREWALL_IPV4_MASK_MIN = 0
export const FIREWALL_IPV4_MASK_MAX = 32
export const FIREWALL_PORT_MIN = 1
export const FIREWALL_PORT_MAX = 65535
export const FIREWALL_MAX_PORT_ITEM_COUNT = 10
export const FIREWALL_RULE_TYPE_OPTIONS: number[] = [
  netFirewall.NetFirewallRuleType.RULE_IP,
  netFirewall.NetFirewallRuleType.RULE_DOMAIN,
  netFirewall.NetFirewallRuleType.RULE_DNS
]
export const FIREWALL_RULE_TAB_TYPES: Array<number | undefined> = [
  undefined,
  netFirewall.NetFirewallRuleType.RULE_IP,
  netFirewall.NetFirewallRuleType.RULE_DOMAIN,
  netFirewall.NetFirewallRuleType.RULE_DNS
]

export interface FirewallPresetConfig {
  fixedPublicIp: string
  privateCidrs: string[]
  privateTcpPorts: number[]
  privateUdpPorts: number[]
}

export type FirewallToggleRejectReason =
  'lockout' |
  'pin_unavailable' |
  'pin_failed' |
  'no_available_users' |
  'policy_apply_failed'

export interface UserFirewallOption {
  userId: number
  label: string
  isForeground?: boolean
}

export interface UserFirewallListResult {
  users: UserFirewallOption[]
  selectedUserId?: number
  errorCode?: number
  message?: string
}

export interface FirewallScopedRule extends netFirewall.NetFirewallRule {
  userIds?: number[]
  targetUserIds?: number[]
  localRuleId?: string
  deployments?: FirewallRuleDeployment[]
  createdAt?: number
  updatedAt?: number
  id?: number
  ruleId?: number
}

export function normalizeFirewallRuleUserIds(userIds: number[]): number[] {
  let uniqueValues = new Set<number>()
  userIds.forEach((value: number) => {
    if (Number.isInteger(value) && value >= 0) {
      uniqueValues.add(value)
    }
  })
  return Array.from(uniqueValues).sort((left: number, right: number) => left - right)
}

export function getFirewallRuleUserIds(rule: netFirewall.NetFirewallRule): number[] {
  let scopedRule = rule as FirewallScopedRule
  if (Array.isArray(scopedRule.targetUserIds)) {
    return normalizeFirewallRuleUserIds(scopedRule.targetUserIds)
  }
  return Array.isArray(scopedRule.userIds) ? normalizeFirewallRuleUserIds(scopedRule.userIds) : []
}

export function attachFirewallRuleUserIds(
  rule: netFirewall.NetFirewallRule,
  userIds: number[]
): FirewallScopedRule {
  let scopedRule = rule as FirewallScopedRule
  let normalizedUserIds = normalizeFirewallRuleUserIds(userIds)
  scopedRule.userIds = normalizedUserIds
  scopedRule.targetUserIds = normalizedUserIds
  return scopedRule
}

export interface FirewallOverviewState {
  enabled: boolean
  currentMode: FirewallPresetMode
}

export interface FirewallFailedItem {
  userId?: number
  localRuleId?: string
  systemRuleId?: number
  errorCode?: number
  errorMessage?: string
}

export interface FirewallOperationResult extends OperationResult<void> {
  failedItems?: FirewallFailedItem[]
}

export interface FirewallBatchOperationResult extends FirewallOperationResult {
  failedItems: FirewallFailedItem[]
}

export interface FirewallToggleOperationResult extends FirewallOperationResult {
  targetEnabled: boolean
  reason?: FirewallToggleRejectReason
  lockRemainingSec?: number
}

export interface FirewallRuleIntentMappingData {
  version: number
  ruleIntents: FirewallRuleIntent[]
  ruleDeployments: FirewallRuleDeployment[]
}

export interface FirewallRuleIntent {
  localRuleId: string
  name: string
  type: number
  direction: number
  action: number
  isEnabled: boolean
  targetUserIds: number[]
  protocol?: number
  remoteIps?: netFirewall.NetFirewallIpParams[]
  localIps?: netFirewall.NetFirewallIpParams[]
  localPorts?: netFirewall.NetFirewallPortParams[]
  remotePorts?: netFirewall.NetFirewallPortParams[]
  domains?: netFirewall.NetFirewallDomainParams[]
  dns?: netFirewall.NetFirewallDnsParams
  createdAt: number
  updatedAt: number
}

export interface FirewallRuleDeployment {
  localRuleId: string
  userId: number
  systemRuleId: number
}

export interface FirewallPreparedRule {
  localRuleId?: string
  userId: number
  rule: netFirewall.NetFirewallRule
}

export interface FirewallRuleIntentInput {
  localRuleId?: string
  name: string
  type: number
  direction: number
  action: number
  isEnabled?: boolean
  targetUserIds: number[]
  protocol?: number
  remoteIps?: netFirewall.NetFirewallIpParams[]
  localIps?: netFirewall.NetFirewallIpParams[]
  localPorts?: netFirewall.NetFirewallPortParams[]
  remotePorts?: netFirewall.NetFirewallPortParams[]
  domains?: netFirewall.NetFirewallDomainParams[]
  dns?: netFirewall.NetFirewallDnsParams
}

export interface FirewallRuleValidationResult {
  success: boolean
  errorMessage?: string
}

export type FirewallRuleConflictKind = 'none' | 'duplicate' | 'hard_conflict' | 'overlap_conflict'

export interface FirewallRuleConflictMatch {
  kind: FirewallRuleConflictKind
  existingRule: FirewallRuleIntent
}

export interface FirewallConflictSummary {
  duplicates: number
  hardConflicts: number
  overlapConflicts: number
}

export interface FirewallRuleDisplayItem extends netFirewall.NetFirewallRule {
  localRuleId: string
  targetUserIds: number[]
  deployments: FirewallRuleDeployment[]
  createdAt: number
  updatedAt: number
}

export interface FirewallRuleMutationResult extends FirewallOperationResult {
  localRuleId?: string
  successDeployments?: FirewallRuleDeployment[]
}

export interface FirewallUserPolicyModeRecord {
  userId: number
  mode: FirewallUserPolicyMode
}

export interface FirewallUserPolicyStateResult {
  userId: number
  bindingMode?: FirewallUserPolicyMode
  isManaged: boolean
  isOpen: boolean
  inAction: number
  outAction: number
  errorCode?: number
  message?: string
}

export interface FirewallDefaultPolicyDisplayItem {
  userId: number
  label: string
  mode: FirewallDefaultPolicyMode
  isOpen: boolean
  inAction: number
  outAction: number
}

export interface FirewallUserPolicyApplyResult extends FirewallOperationResult {
  userId: number
  mode: FirewallUserPolicyMode
}

export function resolveFirewallUserPolicyModeFromActions(
  inAction: number,
  outAction: number
): FirewallUserPolicyMode | undefined {
  if (
    inAction === netFirewall.FirewallRuleAction.RULE_DENY &&
      outAction === netFirewall.FirewallRuleAction.RULE_DENY
  ) {
    return 'allowlist'
  }
  if (
    inAction === netFirewall.FirewallRuleAction.RULE_ALLOW &&
      outAction === netFirewall.FirewallRuleAction.RULE_ALLOW
  ) {
    return 'denylist'
  }
  return undefined
}

export const FIREWALL_RULE_MAPPING_VERSION = 1
export const PREF_STORE_NAME_FIREWALL_MODE = 'firewall_mode'
export const PREF_KEY_FIREWALL_ACTIVE_MODE = 'firewall_active_mode'
export const PREF_STORE_NAME_FIREWALL_RULE_MAPPING = 'firewall_rule_mapping'
export const PREF_KEY_FIREWALL_RULE_MAPPING = 'firewall_rule_intent_mapping_payload'
export const PREF_STORE_NAME_FIREWALL_USER_POLICY = 'firewall_user_policy'
export const PREF_KEY_FIREWALL_USER_POLICY = 'firewall_user_policy_payload'
