import { CommonStrings } from '../CommonStrings'
import { AppColors } from '../AppConstants'

export interface DashboardGradient {
  start: string
  end: string
}

export class DashboardStrings {
  static readonly pageTitle: string = CommonStrings.moduleDashboard
  static readonly pageSubtitle: string = 'HarmonyOS 安全管理中心，提供企业级设备安全管控能力。'
  static readonly quickActionsTitle: string = '快捷功能'

  static readonly healthAdminLabel: string = '管理员'

  static readonly statFirewallStatus: string = '防火墙状态'
  static readonly statFirewallEnabled: string = '已开启'
  static readonly statFirewallDisabled: string = '已关闭'
  static readonly statTodayAuditEvents: string = '今日审计事件'
  static readonly statBlockedEvents: string = '已阻止事件'
  static readonly statTotalLogs: string = '日志总量'

  static readonly firewallGradient: DashboardGradient = { start: AppColors.BRAND_PRIMARY, end: '#00C6FF' }
  static readonly logManageGradient: DashboardGradient = { start: AppColors.SUCCESS, end: '#30D158' }
  static readonly peripheralGradient: DashboardGradient = { start: '#5856D6', end: '#AF52DE' }
  static readonly identityGradient: DashboardGradient = { start: AppColors.WARNING, end: '#FFCC00' }
  static readonly toolSettingsGradient: DashboardGradient = { start: '#9095A1', end: '#D8DCE3' }
  static readonly helpFeedbackGradient: DashboardGradient = { start: '#FF8A80', end: '#FFB4A8' }
}
