import { AppColors } from '../AppConstants'
import { AppStrings } from '../AppStrings'

export interface DashboardGradient {
  start: string
  end: string
}

/**
 * 安全总览模块文案资源门面
 *
 * 文案唯一来源为 resources/{base,en_US}/element/string.json 中的 dashboard_* 资源。
 * 门面保持与旧常量一致的访问方式，内部经 AppStrings 资源管理器按当前 locale 解析；
 * 摘要卡次数类副文案由占位符资源构造，不再做前后缀字符串拼接。
 *
 * 单元测试环境（AppStrings 未初始化）下门面返回资源名；相关断言必须经门面构造，
 * 不得断言中文或英文字面量。
 */

export class DashboardAdminStrings {
  static get TITLE(): string {
    return AppStrings.get('dashboard_admin_title')
  }

  static get PENDING(): string {
    return AppStrings.get('dashboard_admin_pending')
  }

  static get READY_DETAIL(): string {
    return AppStrings.get('dashboard_admin_ready_detail')
  }

  static get PENDING_DETAIL(): string {
    return AppStrings.get('dashboard_admin_pending_detail')
  }
}

export class DashboardFirewallCardStrings {
  static get TITLE(): string {
    return AppStrings.get('dashboard_firewall_card_title')
  }
}

export class DashboardLogCardStrings {
  static get TITLE(): string {
    return AppStrings.get('dashboard_log_card_title')
  }

  static buildTodayDetail(totalCount: number): string {
    return AppStrings.format('dashboard_log_card_today_detail', totalCount)
  }
}

export class DashboardPeripheralCardStrings {
  static get TITLE(): string {
    return AppStrings.get('dashboard_peripheral_card_title')
  }

  static buildDetail(connects: number, disconnects: number, policyChanges: number): string {
    return AppStrings.format('dashboard_peripheral_card_detail', connects, disconnects, policyChanges)
  }
}

export class DashboardGradientPalette {
  static readonly firewallGradient: DashboardGradient = { start: AppColors.BRAND_PRIMARY, end: AppColors.GRADIENT_FIREWALL_END }
  static readonly logManageGradient: DashboardGradient = { start: AppColors.SUCCESS, end: AppColors.GRADIENT_LOG_END }
  static readonly peripheralGradient: DashboardGradient = { start: AppColors.GRADIENT_PERIPHERAL_START, end: AppColors.GRADIENT_PERIPHERAL_END }
  static readonly permissionGradient: DashboardGradient = { start: AppColors.GRADIENT_PERMISSION_START, end: AppColors.GRADIENT_PERMISSION_END }
  static readonly identityGradient: DashboardGradient = { start: AppColors.WARNING, end: AppColors.GRADIENT_IDENTITY_END }
  static readonly toolSettingsGradient: DashboardGradient = { start: AppColors.GRADIENT_TOOL_START, end: AppColors.GRADIENT_TOOL_END }
}
