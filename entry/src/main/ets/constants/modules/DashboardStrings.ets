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

  static readonly firewallGradient: DashboardGradient = { start: AppColors.BRAND_PRIMARY, end: AppColors.GRADIENT_FIREWALL_END }
  static readonly logManageGradient: DashboardGradient = { start: AppColors.SUCCESS, end: AppColors.GRADIENT_LOG_END }
  static readonly peripheralGradient: DashboardGradient = { start: AppColors.GRADIENT_PERIPHERAL_START, end: AppColors.GRADIENT_PERIPHERAL_END }
  static readonly identityGradient: DashboardGradient = { start: AppColors.WARNING, end: AppColors.GRADIENT_IDENTITY_END }
  static readonly toolSettingsGradient: DashboardGradient = { start: AppColors.GRADIENT_TOOL_START, end: AppColors.GRADIENT_TOOL_END }
  static readonly helpFeedbackGradient: DashboardGradient = { start: AppColors.GRADIENT_HELP_START, end: AppColors.GRADIENT_HELP_END }
}
