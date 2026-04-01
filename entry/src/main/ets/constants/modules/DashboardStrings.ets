import { CommonStrings } from '../CommonStrings'
import { AppColors } from '../AppConstants'
import { FirewallDialogStrings } from './DialogStrings'

export interface DashboardGradient {
  start: string
  end: string
}

export class DashboardStrings {
  static readonly pageTitle: string = CommonStrings.moduleDashboard
  static readonly pageSubtitle: string = '集中查看管理员、防火墙、日志和外设状态'
  static readonly quickActionsTitle: string = '快捷方式'

  static readonly adminTitle: string = '管理员'
  static readonly adminReady: string = '已激活'
  static readonly adminPending: string = '待激活'
  static readonly adminReadyDetail: string = '企业管理能力已就绪'
  static readonly adminPendingDetail: string = '完成激活后即可执行受控操作'

  static readonly firewallTitle: string = '防火墙'
  static readonly firewallEnabled: string = FirewallDialogStrings.SWITCH_ENABLED
  static readonly firewallDisabled: string = FirewallDialogStrings.SWITCH_DISABLED

  static readonly logTitle: string = '日志'
  static readonly logTodayDetailPrefix: string = '累计 '
  static readonly logTodayDetailSuffix: string = ' 条'

  static readonly peripheralTitle: string = '外设'
  static readonly peripheralDetailPrefix: string = '连接 '
  static readonly peripheralDetailMiddle: string = ' 次，断开 '
  static readonly peripheralDetailSuffix: string = ' 次'

  static readonly firewallGradient: DashboardGradient = { start: AppColors.BRAND_PRIMARY, end: AppColors.GRADIENT_FIREWALL_END }
  static readonly logManageGradient: DashboardGradient = { start: AppColors.SUCCESS, end: AppColors.GRADIENT_LOG_END }
  static readonly peripheralGradient: DashboardGradient = { start: AppColors.GRADIENT_PERIPHERAL_START, end: AppColors.GRADIENT_PERIPHERAL_END }
  static readonly identityGradient: DashboardGradient = { start: AppColors.WARNING, end: AppColors.GRADIENT_IDENTITY_END }
  static readonly toolSettingsGradient: DashboardGradient = { start: AppColors.GRADIENT_TOOL_START, end: AppColors.GRADIENT_TOOL_END }
  static readonly helpFeedbackGradient: DashboardGradient = { start: AppColors.GRADIENT_HELP_START, end: AppColors.GRADIENT_HELP_END }
}
