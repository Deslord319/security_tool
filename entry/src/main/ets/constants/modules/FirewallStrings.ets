import { FirewallPresetMode, FirewallToggleRejectReason } from '../../models/DataModels'
import { CommonStrings } from '../CommonStrings'
import { AppColors } from '../AppConstants'
import { EmptyStateStrings, FirewallDialogStrings } from './DialogStrings'

export class FirewallStrings {
  static readonly pageSubtitle: string = '统一配置设备防火墙策略，支持按网络场景选择预置模式并维护自定义访问规则'

  static readonly rulesPage: string = '规则页'
  static readonly userIdControlButton: string = '按用户 ID 控制'
  static readonly toggleFailed: string = '防火墙开关切换失败'
  static readonly modeApplyFailed: string = '策略下发失败，当前模式未切换'

  static readonly rulesOnlyCustomMode: string = '只有自定义模式支持维护规则'
  static readonly customRulesApplyFailed: string = '自定义规则下发失败'
  static readonly customRulesLocalSaveFailed: string = '本地规则保存失败，且回滚远端规则失败'
  static readonly customRulesRollbackSuccess: string = '本地规则保存失败，已回滚远端规则'
  static readonly duplicateRule: string = '已存在完全相同的规则'
  static readonly conflictRuleTitle: string = '规则冲突'
  static readonly conflictRuleReplaceMessage: string = '发现与现有规则冲突的记录，是否使用新规则覆盖？'
  static readonly conflictRuleReplaceAndSaveMessage: string = '修改后的规则与现有规则冲突，是否覆盖冲突规则并保存？'
  static readonly overlapRuleTitle: string = '规则重叠'
  static readonly overlapRuleAddMessage: string = '检测到规则范围存在重叠，仍要继续添加吗？'
  static readonly overlapRuleEditMessage: string = '检测到规则范围存在重叠，仍要继续保存吗？'
  static readonly addRuleSuccess: string = '规则添加成功'
  static readonly updateRuleSuccess: string = '规则更新成功'
  static readonly replaceRuleSuccess: string = '冲突规则已替换并保存'
  static readonly overwriteRuleSuccess: string = '冲突规则已覆盖'
  static readonly deleteRuleTitle: string = '删除规则'
  static readonly deleteRuleMessage: string = '确认删除这条规则吗？'
  static readonly deleteRuleSuccess: string = '规则删除成功'
  static readonly conflictWarningLabel: string = '注意'

  static readonly customModeTitle: string = '自定义模式'
  static readonly customRulesSubtitle: string = '当前页面只维护自定义模式规则，保存后会重新下发整套自定义策略'
  static readonly addRuleButton: string = '+ 新增规则'
  static readonly rulesReapplyPartialFailed: string = '共享规则已保存，但部分已绑定用户重下发失败'
  static readonly inboundRules: string = '入站规则'
  static readonly outboundRules: string = '出站规则'
  static readonly inboundCustomRulesDescription: string = '自定义入站规则'
  static readonly outboundCustomRulesDescription: string = '自定义出站规则'
  static getModeAccent(mode: FirewallPresetMode): string {
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

  static getModeTitle(mode: FirewallPresetMode): string {
    switch (mode) {
      case 'public':
        return '公共网络模式'
      case 'private':
        return '私有网络模式'
      case 'custom':
      default:
        return FirewallStrings.customModeTitle
    }
  }

  static getModeDescription(mode: FirewallPresetMode): string {
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

  static buildToggleFailedMessage(
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

  static buildConflictNotice(duplicates: number, hardConflicts: number, overlapConflicts: number): string {
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

  static buildReapplyPartialFailedMessage(successCount: number, failedCount: number): string {
    return `${FirewallStrings.rulesReapplyPartialFailed}（成功 ${successCount} 个，失败 ${failedCount} 个）`
  }

  static buildRuleCountText(count: number): string {
    return `${count} 条`
  }
  static readonly readPolicyAction: string = '读取防火墙策略'
  static readonly setStatusAction: string = '设置防火墙状态'
  static readonly readRulesAction: string = '读取防火墙规则'
  static readonly addRuleAction: string = '新增防火墙规则'
  static readonly deleteRuleAction: string = '删除防火墙规则'
  static readonly updateRuleAction: string = '更新防火墙规则'
  static readonly readUserListAction: string = '读取用户列表'
  static readonly readUserPolicyAction: string = '读取用户防火墙状态'
  static readonly readUserModeBindingsAction: string = '读取用户模式绑定'
  static readonly saveUserModeBindingsAction: string = '保存用户模式绑定'
  static readonly readUserRulesAction: string = '读取用户防火墙规则'
  static readonly deleteUserRulesAction: string = '删除用户防火墙规则'
  static readonly writeUserPolicyAction: string = '写入用户防火墙策略'
  static readonly noActivatedUsers: string = '未找到已激活用户'

  static buildUserLabel(userId: number, isForeground: boolean): string {
    return isForeground ? `用户 ${userId}（当前）` : `用户 ${userId}`
  }
}
