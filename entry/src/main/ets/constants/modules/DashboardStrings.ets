import { AppColors } from '../AppConstants'

export interface DashboardGradient {
  start: string
  end: string
}

export class DashboardStrings {
  static readonly pageTitle: string = '安全总览'
  static readonly pageSubtitle: string = 'HarmonyOS安全管理中心，提供企业级安全管控能力'
  static readonly quickActionsTitle: string = '快捷方式'

  static readonly adminTitle: string = '管理员'
  static readonly adminReady: string = '已激活'
  static readonly adminPending: string = '待激活'
  static readonly adminReadyDetail: string = '企业管理员能力已就绪'
  static readonly adminPendingDetail: string = '完成激活后才能执行受控操作'

  static readonly firewallTitle: string = '防火墙管理'
  static readonly firewallEnabled: string = '已开启'
  static readonly firewallDisabled: string = '已关闭'

  static readonly logTitle: string = '日志管理'
  static readonly logTodayDetailPrefix: string = '今日新增，累计 '
  static readonly logTodayDetailSuffix: string = ' 条'

  static readonly peripheralTitle: string = '外设管理'
  static readonly peripheralDetailPrefix: string = '连接 '
  static readonly peripheralDetailMiddle: string = ' 次，断开 '
  static readonly peripheralDetailSuffix: string = ' 次'

  static readonly identityTitle: string = '身份鉴别'
  static readonly toolSettingsTitle: string = '工具设置'
  static readonly helpFeedbackTitle: string = '帮助与反馈'

  static readonly firewallGradient: DashboardGradient = { start: AppColors.BRAND_PRIMARY, end: AppColors.GRADIENT_FIREWALL_END }
  static readonly logManageGradient: DashboardGradient = { start: AppColors.SUCCESS, end: AppColors.GRADIENT_LOG_END }
  static readonly peripheralGradient: DashboardGradient = { start: AppColors.GRADIENT_PERIPHERAL_START, end: AppColors.GRADIENT_PERIPHERAL_END }
  static readonly identityGradient: DashboardGradient = { start: AppColors.WARNING, end: AppColors.GRADIENT_IDENTITY_END }
  static readonly toolSettingsGradient: DashboardGradient = { start: AppColors.GRADIENT_TOOL_START, end: AppColors.GRADIENT_TOOL_END }
  static readonly helpFeedbackGradient: DashboardGradient = { start: AppColors.GRADIENT_HELP_START, end: AppColors.GRADIENT_HELP_END }
}
