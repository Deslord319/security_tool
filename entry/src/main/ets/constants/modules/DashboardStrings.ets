import { AppColors } from '../AppConstants'

export interface DashboardGradient {
  start: string
  end: string
}

export class DashboardPageStrings {
  static readonly SUBTITLE: string = 'HarmonyOS 安全管理中心，提供企业级设备安全管控能力'
  static readonly QUICK_ACTIONS_TITLE: string = '快捷方式'
}

export class DashboardAdminStrings {
  static readonly TITLE: string = '管理员状态'
  static readonly PENDING: string = '未激活'
  static readonly READY_DETAIL: string = '企业管理能力已激活'
  static readonly PENDING_DETAIL: string = '企业管理能力未激活'
}

export class DashboardFirewallCardStrings {
  static readonly TITLE: string = '防火墙模式'
}

export class DashboardLogCardStrings {
  static readonly TITLE: string = '日志记录'
  static readonly TODAY_DETAIL_PREFIX: string = '累计 '
  static readonly TODAY_DETAIL_SUFFIX: string = ' 条'
}

export class DashboardPeripheralCardStrings {
  static readonly TITLE: string = '外设连接记录'
  static readonly DETAIL_PREFIX: string = '连接 '
  static readonly DETAIL_MIDDLE: string = ' 次，断开 '
  static readonly DETAIL_SUFFIX: string = ' 次'
}

export class DashboardGradientPalette {
  static readonly firewallGradient: DashboardGradient = { start: AppColors.BRAND_PRIMARY, end: AppColors.GRADIENT_FIREWALL_END }
  static readonly logManageGradient: DashboardGradient = { start: AppColors.SUCCESS, end: AppColors.GRADIENT_LOG_END }
  static readonly peripheralGradient: DashboardGradient = { start: AppColors.GRADIENT_PERIPHERAL_START, end: AppColors.GRADIENT_PERIPHERAL_END }
  static readonly permissionGradient: DashboardGradient = { start: AppColors.GRADIENT_PERMISSION_START, end: AppColors.GRADIENT_PERMISSION_END }
  static readonly identityGradient: DashboardGradient = { start: AppColors.WARNING, end: AppColors.GRADIENT_IDENTITY_END }
  static readonly toolSettingsGradient: DashboardGradient = { start: AppColors.GRADIENT_TOOL_START, end: AppColors.GRADIENT_TOOL_END }
}
