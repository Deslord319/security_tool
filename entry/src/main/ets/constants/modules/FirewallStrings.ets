import { FirewallPresetMode, FirewallToggleRejectReason } from '../../models/firewall/FirewallModels'
import { AppColors } from '../AppConstants'
import { AppStrings } from '../AppStrings'
import { CommonSystemErrorCodes } from '../SystemErrorCodes'

/**
 * 防火墙模块文案资源门面
 *
 * 文案唯一来源为 resources/{base,en_US}/element/string.json 中的 firewall_* 资源，
 * 经 AppStrings 资源管理器按当前 locale 解析；锁屏重试、冲突通知、规则/用户
 * 计数和用户标签等动态文案由占位符资源构造。协议名 TCP/UDP/ICMP/ALL 为
 * locale 无关技术标识，保留字面量。
 *
 * 单元测试环境（AppStrings 未初始化）下门面返回资源名；相关断言必须经门面
 * 构造，不得断言中文或英文字面量。
 */
export class FirewallPageStrings {
  static get SUBTITLE(): string {
    return AppStrings.get('firewall_page_subtitle')
  }


}

export class FirewallToggleStrings {
  static get TOGGLE_FAILED(): string {
    return AppStrings.get('firewall_toggle_failed')
  }

  static get MODE_APPLY_FAILED(): string {
    return AppStrings.get('firewall_toggle_mode_apply_failed')
  }
}

export class FirewallRuleStrings {
  static get ONLY_CUSTOM_MODE(): string {
    return AppStrings.get('firewall_rule_only_custom_mode')
  }

  static get APPLY_FAILED(): string {
    return AppStrings.get('firewall_rule_apply_failed')
  }

  static get APPLY_FAILED_PERMISSION(): string {
    return AppStrings.get('firewall_rule_apply_failed_permission')
  }

  static get APPLY_FAILED_INVALID_PARAM(): string {
    return AppStrings.get('firewall_rule_apply_failed_invalid_param')
  }

  static get APPLY_FAILED_DNS_DUPLICATE(): string {
    return AppStrings.get('firewall_rule_apply_failed_dns_duplicate')
  }

  static get USER_SCOPE_CHANGED(): string {
    return AppStrings.get('firewall_rule_user_scope_changed')
  }

  static get DUPLICATE(): string {
    return AppStrings.get('firewall_rule_duplicate')
  }

  static get CONFLICT_TITLE(): string {
    return AppStrings.get('firewall_rule_conflict_title')
  }

  static get CONFLICT_REPLACE_MESSAGE(): string {
    return AppStrings.get('firewall_rule_conflict_replace_message')
  }

  static get CONFLICT_REPLACE_AND_SAVE_MESSAGE(): string {
    return AppStrings.get('firewall_rule_conflict_replace_and_save_message')
  }

  static get OVERLAP_TITLE(): string {
    return AppStrings.get('firewall_rule_overlap_title')
  }

  static get OVERLAP_ADD_MESSAGE(): string {
    return AppStrings.get('firewall_rule_overlap_add_message')
  }

  static get OVERLAP_EDIT_MESSAGE(): string {
    return AppStrings.get('firewall_rule_overlap_edit_message')
  }

  static get ADD_SUCCESS(): string {
    return AppStrings.get('firewall_rule_add_success')
  }

  static get UPDATE_SUCCESS(): string {
    return AppStrings.get('firewall_rule_update_success')
  }

  static get DELETE_TITLE(): string {
    return AppStrings.get('firewall_rule_delete_title')
  }

  static get DELETE_MESSAGE(): string {
    return AppStrings.get('firewall_rule_delete_message')
  }

  static get DELETE_SUCCESS(): string {
    return AppStrings.get('firewall_rule_delete_success')
  }


  static get CUSTOM_MODE_TITLE(): string {
    return AppStrings.get('firewall_rule_custom_mode_title')
  }

  static get CUSTOM_RULES_SUBTITLE(): string {
    return AppStrings.get('firewall_rule_custom_rules_subtitle')
  }


  static get INBOUND(): string {
    return AppStrings.get('firewall_rule_inbound')
  }

  static get OUTBOUND(): string {
    return AppStrings.get('firewall_rule_outbound')
  }

  static get INBOUND_DESCRIPTION(): string {
    return AppStrings.get('firewall_rule_inbound_description')
  }

  static get OUTBOUND_DESCRIPTION(): string {
    return AppStrings.get('firewall_rule_outbound_description')
  }

  static get DEFAULT_POLICY_ALLOWLIST_USERS(): string {
    return AppStrings.get('firewall_rule_default_policy_allowlist_users')
  }

  static get DEFAULT_POLICY_DENYLIST_USERS(): string {
    return AppStrings.get('firewall_rule_default_policy_denylist_users')
  }

  static get DEFAULT_POLICY_EMPTY_USERS(): string {
    return AppStrings.get('firewall_rule_default_policy_empty_users')
  }



}

export class FirewallUserStrings {
  static get NO_ACTIVATED_USERS(): string {
    return AppStrings.get('firewall_user_no_activated_users')
  }
}

export function getFirewallModeAccent(mode: FirewallPresetMode): string {
  switch (mode) {
    case 'public':
      return AppColors.BRAND_PRIMARY
    case 'private':
      return AppColors.SUCCESS
    case 'custom':
    default:
      return AppColors.WARNING
  }
}

export function getFirewallModeTitle(mode: FirewallPresetMode): string {
  switch (mode) {
    case 'public':
      return AppStrings.get('firewall_mode_public_title')
    case 'private':
      return AppStrings.get('firewall_mode_private_title')
    case 'custom':
    default:
      return FirewallRuleStrings.CUSTOM_MODE_TITLE
  }
}

export function getFirewallModeDescription(mode: FirewallPresetMode): string {
  switch (mode) {
    case 'public':
      return AppStrings.get('firewall_mode_public_description')
    case 'private':
      return AppStrings.get('firewall_mode_private_description')
    case 'custom':
    default:
      return AppStrings.get('firewall_mode_custom_description')
  }
}

export function buildFirewallToggleFailedMessage(
  reason: FirewallToggleRejectReason | undefined,
  lockRemainingSec: number | undefined
): string {
  switch (reason) {
    case 'lockout':
      return AppStrings.format('firewall_toggle_reason_lockout', lockRemainingSec ?? 60)
    case 'pin_unavailable':
      return AppStrings.get('firewall_toggle_reason_pin_unavailable')
    case 'pin_failed':
      return AppStrings.get('firewall_toggle_reason_pin_failed')
    case 'no_available_users':
      return AppStrings.get('firewall_toggle_reason_no_available_users')
    case 'policy_apply_failed':
      return AppStrings.get('firewall_toggle_reason_policy_apply_failed')
    default:
      return AppStrings.get('firewall_toggle_reason_default')
  }
}

export function buildFirewallConflictNotice(duplicates: number, hardConflicts: number, overlapConflicts: number): string {
  let parts: string[] = []
  if (duplicates > 0) {
    parts.push(AppStrings.format('firewall_conflict_duplicate', duplicates))
  }
  if (hardConflicts > 0) {
    parts.push(AppStrings.format('firewall_conflict_hard', hardConflicts))
  }
  if (overlapConflicts > 0) {
    parts.push(AppStrings.format('firewall_conflict_overlap', overlapConflicts))
  }
  return parts.length > 0 ?
    AppStrings.format('firewall_conflict_notice', parts.join(AppStrings.get('common_list_separator'))) :
    ''
}

export function buildFirewallAddRuleFailedMessage(errorCode?: number): string {
  switch (errorCode) {
    case CommonSystemErrorCodes.PERMISSION_DENIED:
      return FirewallRuleStrings.APPLY_FAILED_PERMISSION
    case CommonSystemErrorCodes.INVALID_PARAMS:
    case 2100001:
      return FirewallRuleStrings.APPLY_FAILED_INVALID_PARAM
    case 29400007:
      return FirewallRuleStrings.APPLY_FAILED_DNS_DUPLICATE
    default:
      return FirewallRuleStrings.APPLY_FAILED
  }
}

export function buildFirewallRuleCountText(count: number): string {
  return AppStrings.format('firewall_rule_count', count)
}

export function buildFirewallUserCountText(count: number): string {
  return AppStrings.format('firewall_user_count', count)
}

class FirewallUserLabelStrings {
  static buildFallbackUserLabel(userId: number): string {
    return AppStrings.format('firewall_user_fallback', userId)
  }

  static buildCurrentUserLabel(label: string): string {
    return AppStrings.format('firewall_user_current', label)
  }
}

export function buildFirewallUserLabel(userId: number, isForeground: boolean, userName?: string): string {
  let normalizedName = userName?.trim()
  let baseLabel = normalizedName && normalizedName.length > 0 ?
    normalizedName :
    FirewallUserLabelStrings.buildFallbackUserLabel(userId)
  return isForeground ? FirewallUserLabelStrings.buildCurrentUserLabel(baseLabel) : baseLabel
}

export class FirewallPresetRuleNameStrings {
  static get PUBLIC_ALLOW_ICMPV4(): string {
    return AppStrings.get('firewall_preset_public_allow_icmpv4')
  }

  static get PUBLIC_ALLOW_SERVICE(): string {
    return AppStrings.get('firewall_preset_public_allow_service')
  }

  static get PUBLIC_DENY_REMOTE_ACCESS(): string {
    return AppStrings.get('firewall_preset_public_deny_remote_access')
  }

  static get PUBLIC_DENY_SMB(): string {
    return AppStrings.get('firewall_preset_public_deny_smb')
  }

  static get PUBLIC_DENY_NETBIOS(): string {
    return AppStrings.get('firewall_preset_public_deny_netbios')
  }

  static get PRIVATE_ALLOW_ICMP(): string {
    return AppStrings.get('firewall_preset_private_allow_icmp')
  }

  static get PRIVATE_ALLOW_REMOTE_MANAGE(): string {
    return AppStrings.get('firewall_preset_private_allow_remote_manage')
  }

  static get PRIVATE_ALLOW_SHARE(): string {
    return AppStrings.get('firewall_preset_private_allow_share')
  }

  static get PRIVATE_ALLOW_DISCOVERY(): string {
    return AppStrings.get('firewall_preset_private_allow_discovery')
  }

  static get PRIVATE_ALLOW_TCP(): string {
    return AppStrings.get('firewall_preset_private_allow_tcp')
  }

  static get PRIVATE_ALLOW_UDP(): string {
    return AppStrings.get('firewall_preset_private_allow_udp')
  }
}

export class FirewallRuleLabelStrings {
  static get ALL_RULES(): string {
    return AppStrings.get('firewall_rule_label_all')
  }

  static get IP_RULE(): string {
    return AppStrings.get('firewall_rule_label_ip')
  }

  static get DOMAIN_RULE(): string {
    return AppStrings.get('firewall_rule_label_domain')
  }

  static get DNS_RULE(): string {
    return AppStrings.get('firewall_rule_label_dns')
  }
}

export class FirewallDialogStrings {



  static get USER_SCOPE(): string {
    return AppStrings.get('firewall_dialog_user_scope')
  }

  static get LOCAL_ADDRESS(): string {
    return AppStrings.get('firewall_dialog_local_address')
  }

  static get REMOTE_ADDRESS(): string {
    return AppStrings.get('firewall_dialog_remote_address')
  }

  static get LOCAL_PORT(): string {
    return AppStrings.get('firewall_dialog_local_port')
  }

  static get REMOTE_PORT(): string {
    return AppStrings.get('firewall_dialog_remote_port')
  }

  static get PRIMARY_DNS(): string {
    return AppStrings.get('firewall_dialog_primary_dns')
  }

  static get STANDBY_DNS(): string {
    return AppStrings.get('firewall_dialog_standby_dns')
  }

  static get PROTOCOL(): string {
    return AppStrings.get('firewall_dialog_protocol')
  }



  static get CURRENT_STATUS(): string {
    return AppStrings.get('firewall_dialog_current_status')
  }


  static get IP_PLACEHOLDER(): string {
    return AppStrings.get('firewall_dialog_ip_placeholder')
  }

  static get DOMAIN_PLACEHOLDER(): string {
    return AppStrings.get('firewall_dialog_domain_placeholder')
  }

  static get DNS_PLACEHOLDER(): string {
    return AppStrings.get('firewall_dialog_dns_placeholder')
  }


  static get PORT_PLACEHOLDER(): string {
    return AppStrings.get('firewall_dialog_port_placeholder')
  }

  static get RULE_NAME_PLACEHOLDER(): string {
    return AppStrings.get('firewall_dialog_rule_name_placeholder')
  }

  static get DIRECTION_INBOUND(): string {
    return AppStrings.get('firewall_dialog_direction_inbound')
  }

  static get DIRECTION_OUTBOUND(): string {
    return AppStrings.get('firewall_dialog_direction_outbound')
  }

  static readonly PROTOCOL_TCP: string = 'TCP'
  static readonly PROTOCOL_UDP: string = 'UDP'
  static readonly PROTOCOL_ICMP: string = 'ICMP'
  static readonly ALL_VALUE: string = 'ALL'

  static get USER_SCOPE_PLACEHOLDER(): string {
    return AppStrings.get('firewall_dialog_user_scope_placeholder')
  }

  static get USER_SCOPE_EMPTY(): string {
    return AppStrings.get('firewall_dialog_user_scope_empty')
  }

  static get ACTION_ALLOW(): string {
    return AppStrings.get('firewall_dialog_action_allow')
  }

  static get ACTION_DENY(): string {
    return AppStrings.get('firewall_dialog_action_deny')
  }

  static get APPLY_MODE_FAILED(): string {
    return AppStrings.get('firewall_dialog_apply_mode_failed')
  }

  static get MODE_ALLOWLIST(): string {
    return AppStrings.get('firewall_dialog_mode_allowlist')
  }

  static get MODE_DENYLIST(): string {
    return AppStrings.get('firewall_dialog_mode_denylist')
  }

  static get ERROR_DOMAIN_REQUIRED(): string {
    return AppStrings.get('firewall_dialog_error_domain_required')
  }

  static get ERROR_DNS_REQUIRED(): string {
    return AppStrings.get('firewall_dialog_error_dns_required')
  }

  static get ERROR_INVALID_IP(): string {
    return AppStrings.get('firewall_dialog_error_invalid_ip')
  }

  static get ERROR_INVALID_IP_RANGE(): string {
    return AppStrings.get('firewall_dialog_error_invalid_ip_range')
  }

  static get ERROR_INVALID_CIDR_MASK(): string {
    return AppStrings.get('firewall_dialog_error_invalid_cidr_mask')
  }

  static get ERROR_INVALID_LOCAL_PORT(): string {
    return AppStrings.get('firewall_dialog_error_invalid_local_port')
  }

  static get ERROR_INVALID_REMOTE_PORT(): string {
    return AppStrings.get('firewall_dialog_error_invalid_remote_port')
  }

  static get ERROR_INVALID_PORT_TOKEN(): string {
    return AppStrings.get('firewall_dialog_error_invalid_port_token')
  }

  static get ERROR_INVALID_PORT_RANGE(): string {
    return AppStrings.get('firewall_dialog_error_invalid_port_range')
  }

  static get ERROR_PORT_ITEM_LIMIT(): string {
    return AppStrings.get('firewall_dialog_error_port_item_limit')
  }

  static get ERROR_INVALID_DOMAIN(): string {
    return AppStrings.get('firewall_dialog_error_invalid_domain')
  }

  static get ERROR_INVALID_DNS(): string {
    return AppStrings.get('firewall_dialog_error_invalid_dns')
  }

  static get ERROR_INVALID_STANDBY_DNS(): string {
    return AppStrings.get('firewall_dialog_error_invalid_standby_dns')
  }

  static get ERROR_USER_SCOPE_REQUIRED(): string {
    return AppStrings.get('firewall_dialog_error_user_scope_required')
  }

  static get ERROR_CANNOT_GET_STATUS(): string {
    return AppStrings.get('firewall_dialog_error_cannot_get_status')
  }

  static get APPLY_MODE_SUCCESS(): string {
    return AppStrings.get('firewall_dialog_apply_mode_success')
  }

  static buildUserScopeSelectionSummary(userCount: number): string {
    return AppStrings.format('firewall_dialog_user_scope_summary', userCount)
  }
}
