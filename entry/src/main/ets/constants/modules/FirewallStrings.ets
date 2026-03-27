import { CommonStrings } from '../CommonStrings'
import { FirewallPresetMode, FirewallToggleRejectReason } from '../../models/DataModels'

export class FirewallStrings {
  static readonly pageTitle: string = CommonStrings.moduleFirewall
  static readonly pageSubtitle: string = '统一配置网络访问规则，精准控制应用与设备的通信行为，降低未授权连接带来的安全风险。'

  static readonly modeLoadingMessage: string = '正在切换防火墙模式，请稍候'
  static readonly modeSectionTitle: string = '模式切换'
  static readonly currentMode: string = CommonStrings.statusCurrentMode
  static readonly rulesPage: string = '规则页'
  static readonly effective: string = CommonStrings.statusEffective
  static readonly userIdControlButton: string = '按用户ID控制'
  static readonly toggleFailed: string = '防火墙开关切换失败'
  static readonly modeApplyFailed: string = '策略下发失败，当前模式未切换'

  static readonly publicModeTitle: string = '公用网络'
  static readonly privateModeTitle: string = '专用网络'
  static readonly customModeTitle: string = '自定义规则'

  static readonly publicModeDescription: string = '下发公用网络预置策略，成功后仅保留公用模式规则。'
  static readonly privateModeDescription: string = '下发专用网络预置策略，成功后仅保留专用模式规则。'
  static readonly customModeDescription: string = '切换为自定义模式并进入规则页，重新下发已保存的自定义策略。'

  static readonly rulesOnlyCustomMode: string = '仅自定义模式可进入规则页'
  static readonly customRulesApplyFailed: string = '自定义规则下发失败'
  static readonly customRulesLocalSaveFailed: string = '规则已下发，但本地保存失败，请重新进入页面确认'
  static readonly customRulesRollbackSuccess: string = '自定义规则保存失败，已恢复原策略'
  static readonly duplicateRule: string = '存在重复规则'
  static readonly conflictRuleTitle: string = '存在冲突规则'
  static readonly conflictRuleReplaceMessage: string = '发现动作相反的同类规则，是否用新规则覆盖旧规则？'
  static readonly conflictRuleReplaceAndSaveMessage: string = '发现动作相反的同类规则，是否删除旧规则并保存本次修改？'
  static readonly overlapRuleTitle: string = '规则范围重叠'
  static readonly overlapRuleAddMessage: string = '新规则与现有规则有重叠，仍然继续保存并重新下发吗？'
  static readonly overlapRuleEditMessage: string = '修改后的规则与现有规则有重叠，是否继续保存？'
  static readonly addRuleSuccess: string = '自定义规则已新增'
  static readonly updateRuleSuccess: string = '自定义规则已更新'
  static readonly replaceRuleSuccess: string = '冲突规则已替换并保存'
  static readonly overwriteRuleSuccess: string = '冲突规则已覆盖'
  static readonly deleteRuleTitle: string = '删除规则'
  static readonly deleteRuleMessage: string = '删除后会立即重新下发当前自定义策略，是否继续？'
  static readonly deleteRuleSuccess: string = '自定义规则已删除'
  static readonly conflictWarningLabel: string = '注意'
  static readonly customRulesTitle: string = FirewallStrings.customModeTitle
  static readonly customRulesSubtitle: string = '当前页面只维护自定义模式规则。保存后会重新下发整套自定义策略。'
  static readonly addRuleButton: string = '+ 新增规则'
  static readonly inboundRules: string = '入站规则'
  static readonly outboundRules: string = '出站规则'
  static readonly tabAllRules: string = '全部规则'
  static readonly tabIpRules: string = 'IP规则'
  static readonly tabDomainRules: string = '域名规则'
  static readonly tabDnsRules: string = 'DNS规则'
  static readonly loadingRules: string = '正在加载自定义规则...'
  static readonly emptyRules: string = '当前没有自定义规则'
  static readonly detailRemoteAddress: string = '远端地址'
  static readonly detailLocalPort: string = '本地端口'
  static readonly detailRemotePort: string = '远端端口'
  static readonly detailProtocol: string = '协议'
  static readonly typeDomain: string = '域名'
  static readonly typeUnknown: string = '未知'
  static readonly directionInbound: string = '入站'
  static readonly directionOutbound: string = '出站'
  static readonly actionAllow: string = '允许'
  static readonly actionDeny: string = '阻止'

  static getModeTitle(mode: FirewallPresetMode): string {
    switch (mode) {
      case 'public':
        return FirewallStrings.publicModeTitle
      case 'private':
        return FirewallStrings.privateModeTitle
      case 'custom':
      default:
        return FirewallStrings.customModeTitle
    }
  }

  static getModeDescription(mode: FirewallPresetMode): string {
    switch (mode) {
      case 'public':
        return FirewallStrings.publicModeDescription
      case 'private':
        return FirewallStrings.privateModeDescription
      case 'custom':
      default:
        return FirewallStrings.customModeDescription
    }
  }

  static buildToggleFailedMessage(reason: FirewallToggleRejectReason | undefined, lockRemainingSec: number | undefined): string {
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
}
