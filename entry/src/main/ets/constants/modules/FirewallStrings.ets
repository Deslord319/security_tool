import { FirewallPresetMode, FirewallToggleRejectReason } from '../../models/DataModels'
import { AppColors } from '../AppConstants'

export class FirewallPageStrings {
  static readonly SUBTITLE: string = '统一配置设备防火墙策略，支持按网络场景选择预置模式并维护自定义访问规则'
  static readonly RULES_PAGE: string = '规则页'
  static readonly USER_ID_CONTROL_BUTTON: string = '按用户 ID 控制'
}

export class FirewallToggleStrings {
  static readonly TOGGLE_FAILED: string = '防火墙开关切换失败'
  static readonly MODE_APPLY_FAILED: string = '策略下发失败，当前模式未切换'
}

export class FirewallRuleStrings {
  static readonly ONLY_CUSTOM_MODE: string = '只有自定义模式支持维护规则'
  static readonly APPLY_FAILED: string = '自定义规则下发失败'
  static readonly LOCAL_SAVE_FAILED: string = '本地规则保存失败，且回滚远端规则失败'
  static readonly ROLLBACK_SUCCESS: string = '本地规则保存失败，已回滚远端规则'
  static readonly DUPLICATE: string = '已存在完全相同的规则'
  static readonly CONFLICT_TITLE: string = '规则冲突'
  static readonly CONFLICT_REPLACE_MESSAGE: string = '发现与现有规则冲突的记录，是否使用新规则覆盖？'
  static readonly CONFLICT_REPLACE_AND_SAVE_MESSAGE: string = '修改后的规则与现有规则冲突，是否覆盖冲突规则并保存？'
  static readonly OVERLAP_TITLE: string = '规则重叠'
  static readonly OVERLAP_ADD_MESSAGE: string = '检测到规则范围存在重叠，仍要继续添加吗？'
  static readonly OVERLAP_EDIT_MESSAGE: string = '检测到规则范围存在重叠，仍要继续保存吗？'
  static readonly ADD_SUCCESS: string = '规则添加成功'
  static readonly UPDATE_SUCCESS: string = '规则更新成功'
  static readonly REPLACE_SUCCESS: string = '冲突规则已替换并保存'
  static readonly OVERWRITE_SUCCESS: string = '冲突规则已覆盖'
  static readonly DELETE_TITLE: string = '删除规则'
  static readonly DELETE_MESSAGE: string = '确认删除这条规则吗？'
  static readonly DELETE_SUCCESS: string = '规则删除成功'
  static readonly WARNING_LABEL: string = '注意'
  static readonly CUSTOM_MODE_TITLE: string = '自定义模式'
  static readonly CUSTOM_RULES_SUBTITLE: string = '支持IP、域名和DNS规则自定义配置'
  static readonly ADD_BUTTON: string = '新增规则'
  static readonly REAPPLY_PARTIAL_FAILED: string = '共享规则已保存，但部分已绑定用户重下发失败'
  static readonly INBOUND: string = '入站规则'
  static readonly OUTBOUND: string = '出站规则'
  static readonly INBOUND_DESCRIPTION: string = '自定义入站规则'
  static readonly OUTBOUND_DESCRIPTION: string = '自定义出站规则'
}

export class FirewallModeStrings {
  static readonly PUBLIC_TITLE: string = '公共网络模式'
  static readonly PUBLIC_DESCRIPTION: string = '适用于开放网络环境，默认采用更严格的访问控制策略'
  static readonly PRIVATE_TITLE: string = '私有网络模式'
  static readonly PRIVATE_DESCRIPTION: string = '适用于可信网络环境，优先保证局域网互通与常规办公访问'
  static readonly CUSTOM_DESCRIPTION: string = '根据业务需要自定义入站、出站与域名访问规则'
}

export class FirewallOperationStrings {
  static readonly READ_POLICY: string = '读取防火墙策略'
  static readonly SET_STATUS: string = '设置防火墙状态'
  static readonly READ_RULES: string = '读取防火墙规则'
  static readonly ADD_RULE: string = '新增防火墙规则'
  static readonly DELETE_RULE: string = '删除防火墙规则'
  static readonly UPDATE_RULE: string = '更新防火墙规则'
  static readonly READ_USER_POLICY: string = '读取用户防火墙状态'
  static readonly READ_USER_MODE_BINDINGS: string = '读取用户模式绑定'
  static readonly SAVE_USER_MODE_BINDINGS: string = '保存用户模式绑定'
  static readonly READ_USER_RULES: string = '读取用户防火墙规则'
  static readonly DELETE_USER_RULES: string = '删除用户防火墙规则'
  static readonly WRITE_USER_POLICY: string = '写入用户防火墙策略'
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
      return FirewallModeStrings.PUBLIC_TITLE
    case 'private':
      return FirewallModeStrings.PRIVATE_TITLE
    case 'custom':
    default:
      return FirewallRuleStrings.CUSTOM_MODE_TITLE
  }
}

export function getFirewallModeDescription(mode: FirewallPresetMode): string {
  switch (mode) {
    case 'public':
      return FirewallModeStrings.PUBLIC_DESCRIPTION
    case 'private':
      return FirewallModeStrings.PRIVATE_DESCRIPTION
    case 'custom':
    default:
      return FirewallModeStrings.CUSTOM_DESCRIPTION
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

export function buildFirewallReapplyPartialFailedMessage(successCount: number, failedCount: number): string {
  return `${FirewallRuleStrings.REAPPLY_PARTIAL_FAILED}（成功 ${successCount} 个，失败 ${failedCount} 个）`
}

export function buildFirewallRuleCountText(count: number): string {
  return `${count} 条`
}

export function buildFirewallUserLabel(userId: number, isForeground: boolean): string {
  return isForeground ? `用户 ${userId}（当前）` : `用户 ${userId}`
}
