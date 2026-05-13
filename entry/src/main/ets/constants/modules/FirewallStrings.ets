import { FirewallPresetMode, FirewallToggleRejectReason } from '../../services/firewall/FirewallModels'
import { AppColors } from '../AppConstants'
import { CommonSystemErrorCodes } from '../SystemErrorCodes'

export class FirewallPageStrings {
  static readonly SUBTITLE: string = '统一配置设备防火墙策略，支持按网络场景选择预置模式并维护自定义访问规则'
  static readonly RULES_PAGE: string = '规则页'
  static readonly USER_ID_CONTROL_BUTTON: string = '全局策略'
}

export class FirewallToggleStrings {
  static readonly TOGGLE_FAILED: string = '防火墙开关切换失败'
  static readonly MODE_APPLY_FAILED: string = '策略下发失败，当前模式未切换'
}

export class FirewallRuleStrings {
  static readonly ONLY_CUSTOM_MODE: string = '只有自定义模式支持维护规则'
  static readonly APPLY_FAILED: string = '自定义规则下发失败'
  static readonly APPLY_FAILED_PERMISSION: string = '规则添加失败，请检查权限和企业管理员状态'
  static readonly APPLY_FAILED_INVALID_PARAM: string = '规则参数不合法，请检查输入'
  static readonly APPLY_FAILED_DNS_UNSUPPORTED: string = '当前系统不支持该 DNS 规则参数，请联系厂家确认接口约束'
  static readonly DUPLICATE: string = '已存在完全相同的规则'
  static readonly CONFLICT_TITLE: string = '规则冲突'
  static readonly CONFLICT_REPLACE_MESSAGE: string = '发现与现有规则冲突的记录，是否使用新规则覆盖？'
  static readonly CONFLICT_REPLACE_AND_SAVE_MESSAGE: string = '修改后的规则与现有规则冲突，是否覆盖冲突规则并保存？'
  static readonly OVERLAP_TITLE: string = '规则重叠'
  static readonly OVERLAP_ADD_MESSAGE: string = '检测到规则范围存在重叠，仍要继续添加吗？'
  static readonly OVERLAP_EDIT_MESSAGE: string = '检测到规则范围存在重叠，仍要继续保存吗？'
  static readonly ADD_SUCCESS: string = '规则添加成功'
  static readonly UPDATE_SUCCESS: string = '规则更新成功'
  static readonly DELETE_TITLE: string = '删除规则'
  static readonly DELETE_MESSAGE: string = '确认删除这条规则吗？'
  static readonly DELETE_SUCCESS: string = '规则删除成功'
  static readonly WARNING_LABEL: string = '注意'
  static readonly CUSTOM_MODE_TITLE: string = '自定义模式'
  static readonly CUSTOM_RULES_SUBTITLE: string = '支持IP、域名和DNS规则自定义配置'
  static readonly ADD_BUTTON: string = '新增规则'
  static readonly INBOUND: string = '入站规则'
  static readonly OUTBOUND: string = '出站规则'
  static readonly INBOUND_DESCRIPTION: string = '自定义入站规则'
  static readonly OUTBOUND_DESCRIPTION: string = '自定义出站规则'
  static readonly DEFAULT_POLICY_ALLOWLIST_USERS: string = '白名单用户'
  static readonly DEFAULT_POLICY_DENYLIST_USERS: string = '黑名单用户'
  static readonly DEFAULT_POLICY_EMPTY_USERS: string = '无'
  static readonly DEFAULT_POLICY_CUSTOM: string = '方向自定义'
  static readonly DEFAULT_POLICY_UNKNOWN: string = '读取失败'
  static readonly DEFAULT_POLICY_DISABLED: string = '防火墙关闭，开启后生效'
}

export class FirewallUserStrings {
  static readonly NO_ACTIVATED_USERS: string = '未找到已激活用户'
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
      return '公共网络模式'
    case 'private':
      return '私有网络模式'
    case 'custom':
    default:
      return FirewallRuleStrings.CUSTOM_MODE_TITLE
  }
}

export function getFirewallModeDescription(mode: FirewallPresetMode): string {
  switch (mode) {
    case 'public':
      return '适用于开放网络环境，默认采用更严格的访问控制策略'
    case 'private':
      return '适用于可信网络环境，优先保证局域网互通与常规办公访问'
    case 'custom':
    default:
      return '根据业务需要自定义入站、出站与域名访问规则'
  }
}

export function buildFirewallToggleFailedMessage(
  reason: FirewallToggleRejectReason | undefined,
  lockRemainingSec: number | undefined
): string {
  switch (reason) {
    case 'lockout':
      return `PIN 校验失败次数过多，请在 ${lockRemainingSec ?? 60} 秒后重试`
    case 'pin_unavailable':
      return '当前设备未配置 PIN'
    case 'pin_failed':
      return 'PIN 校验失败'
    case 'no_available_users':
      return '未读取到可用系统用户'
    case 'policy_apply_failed':
      return '防火墙状态写入失败'
    default:
      return '防火墙状态切换失败'
  }
}

export function buildFirewallConflictNotice(duplicates: number, hardConflicts: number, overlapConflicts: number): string {
  let parts: string[] = []
  if (duplicates > 0) {
    parts.push(`重复 ${duplicates} 条`)
  }
  if (hardConflicts > 0) {
    parts.push(`硬冲突 ${hardConflicts} 条`)
  }
  if (overlapConflicts > 0) {
    parts.push(`范围重叠 ${overlapConflicts} 条`)
  }
  return parts.length > 0 ? `当前自定义规则集中存在：${parts.join('，')}` : ''
}

export function buildFirewallAddRuleFailedMessage(errorCode?: number): string {
  switch (errorCode) {
    case CommonSystemErrorCodes.PERMISSION_DENIED:
      return FirewallRuleStrings.APPLY_FAILED_PERMISSION
    case CommonSystemErrorCodes.INVALID_PARAMS:
    case 2100001:
      return FirewallRuleStrings.APPLY_FAILED_INVALID_PARAM
    case 29400007:
      return FirewallRuleStrings.APPLY_FAILED_DNS_UNSUPPORTED
    default:
      return FirewallRuleStrings.APPLY_FAILED
  }
}

export function buildFirewallRuleCountText(count: number): string {
  return `${count} 条`
}

export function buildFirewallUserCountText(count: number): string {
  return `${count} 个`
}

export class FirewallUserLabelStrings {
  static readonly FALLBACK_USER_LABEL_PREFIX: string = '用户'
  static readonly CURRENT_USER_SUFFIX: string = '（当前）'

  static buildFallbackUserLabel(userId: number): string {
    return `${FirewallUserLabelStrings.FALLBACK_USER_LABEL_PREFIX} ${userId}`
  }

  static buildCurrentUserLabel(label: string): string {
    return `${label}${FirewallUserLabelStrings.CURRENT_USER_SUFFIX}`
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
  static readonly PUBLIC_ALLOW_ICMPV4: string = '允许 ICMPv4'
  static readonly PUBLIC_ALLOW_SERVICE: string = '允许对外服务'
  static readonly PUBLIC_ALLOW_REMOTE_MANAGE: string = '允许远程管理'
  static readonly PUBLIC_DENY_SMB: string = '阻止 SMB 共享'
  static readonly PUBLIC_DENY_NETBIOS: string = '阻止 NetBIOS'
  static readonly PRIVATE_ALLOW_ICMP: string = '允许 ICMP'
  static readonly PRIVATE_ALLOW_REMOTE_MANAGE: string = '允许内网远程'
  static readonly PRIVATE_ALLOW_SHARE: string = '允许内网共享'
  static readonly PRIVATE_ALLOW_DISCOVERY: string = '允许内网发现'
  static readonly PRIVATE_ALLOW_TCP: string = '允许内网应用 TCP'
  static readonly PRIVATE_ALLOW_UDP: string = '允许内网应用 UDP'
}

export class FirewallRuleLabelStrings {
  static readonly ALL_RULES: string = '全部规则'
  static readonly IP_RULE: string = 'IP规则'
  static readonly DOMAIN_RULE: string = '域名规则'
  static readonly DNS_RULE: string = 'DNS规则'
}

export class FirewallDialogStrings {
  static readonly RULE_NAME: string = '规则名称'
  static readonly RULE_TYPE: string = '规则类型'
  static readonly RULE_DIRECTION: string = '方向'
  static readonly USER_SCOPE: string = '用户列表'
  static readonly LOCAL_ADDRESS: string = '本地地址'
  static readonly REMOTE_ADDRESS: string = '远端地址'
  static readonly LOCAL_PORT: string = '本地端口'
  static readonly REMOTE_PORT: string = '远端端口'
  static readonly PROTOCOL: string = '协议'
  static readonly ACTION: string = '动作'
  static readonly TARGET_USER: string = '目标用户'
  static readonly CURRENT_STATUS: string = '当前策略'
  static readonly TARGET_MODE: string = '目标模式'
  static readonly IP_PLACEHOLDER: string = '例如 110.110.110.110、8.8.8.0/24 或 110.110.110.1-110.110.110.254'
  static readonly DOMAIN_PLACEHOLDER: string = '例如 *.example.com'
  static readonly DNS_PLACEHOLDER: string = '例如 8.8.8.8'
  static readonly PORT_PLACEHOLDER: string = '例如 80,443,1000-2000'
  static readonly RULE_NAME_PLACEHOLDER: string = '请输入规则名称'
  static readonly DIRECTION_INBOUND: string = '入站'
  static readonly DIRECTION_OUTBOUND: string = '出站'
  static readonly PROTOCOL_TCP: string = 'TCP'
  static readonly PROTOCOL_UDP: string = 'UDP'
  static readonly PROTOCOL_ICMP: string = 'ICMP'
  static readonly ALL_VALUE: string = 'ALL'
  static readonly USER_SCOPE_PLACEHOLDER: string = '请选择用户'
  static readonly USER_SCOPE_EMPTY: string = '暂无可选用户'
  static readonly ACTION_ALLOW: string = '允许'
  static readonly ACTION_DENY: string = '阻止'
  static readonly APPLY_MODE_FAILED: string = '策略下发失败'
  static readonly MODE_ALLOWLIST: string = '白名单模式'
  static readonly MODE_DENYLIST: string = '黑名单模式'
  static readonly ERROR_DOMAIN_REQUIRED: string = '请输入域名'
  static readonly ERROR_DNS_REQUIRED: string = '请输入 DNS 地址'
  static readonly ERROR_INVALID_IP: string = 'IP 输入格式不正确'
  static readonly ERROR_INVALID_IP_RANGE: string = 'IP 段格式不正确'
  static readonly ERROR_INVALID_CIDR_MASK: string = 'CIDR mask 范围必须为 0-32'
  static readonly ERROR_INVALID_LOCAL_PORT: string = '本地端口格式不正确，请输入单端口、范围或逗号分隔组合'
  static readonly ERROR_INVALID_REMOTE_PORT: string = '远端端口格式不正确，请输入单端口、范围或逗号分隔组合'
  static readonly ERROR_INVALID_PORT_TOKEN: string = '端口格式不正确'
  static readonly ERROR_INVALID_PORT_RANGE: string = '端口范围格式不正确，请确保起始端口不大于结束端口'
  static readonly ERROR_PORT_ITEM_LIMIT: string = '端口项数量超过上限'
  static readonly ERROR_INVALID_DOMAIN: string = '域名格式不正确'
  static readonly ERROR_INVALID_DNS: string = 'DNS 地址格式不正确'
  static readonly ERROR_USER_SCOPE_REQUIRED: string = '请至少选择一个用户'
  static readonly ERROR_CANNOT_GET_STATUS: string = '无法获取该用户当前防火墙策略'

  static readonly APPLY_MODE_SUCCESS: string = '已为所选用户应用全局策略'

  static buildUserScopeSelectionSummary(userCount: number): string {
    return `已选择 ${userCount} 个用户`
  }
}
