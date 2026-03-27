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
