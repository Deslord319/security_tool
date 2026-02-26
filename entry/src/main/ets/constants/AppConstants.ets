import { ThemeMode, ThemeColorSet, getThemeColors } from '../theme/ThemeColors'

// 颜色常量
export class AppColors {
  // 获取当前主题颜色集合
  static getColors(theme: ThemeMode): ThemeColorSet {
    return getThemeColors(theme)
  }

  // 品牌色
  static readonly BRAND_PRIMARY: string = '#0A84FF'
  static readonly BRAND_LIGHT: string = '#5EA1FF'

  // 语义色
  static readonly SUCCESS: string = '#34C759'
  static readonly WARNING: string = '#FF9500'
  static readonly DANGER: string = '#FF3B30'

  // 文本色
  static readonly TEXT_PRIMARY: string = '#000000'
  static readonly TEXT_PRIMARY_OPACITY: number = 0.9
  static readonly TEXT_SECONDARY_OPACITY: number = 0.6
  static readonly TEXT_TERTIARY_OPACITY: number = 0.4

  // 背景色
  static readonly BG_PAGE: string = '#F5F5F5'
  static readonly BG_CARD: string = '#FFFFFF'
  static readonly BG_COMPONENT: string = '#F0F0F0'
  static readonly BG_HOVER: string = '#E5E5E5'

  // 边框色
  static readonly BORDER: string = '#000000'
  static readonly BORDER_OPACITY: number = 0.1

  // Tag 颜色
  static readonly TAG_BLUE_BG: string = '#E3F2FD'
  static readonly TAG_BLUE_TEXT: string = '#1565C0'
  static readonly TAG_GREEN_BG: string = '#E8F5E9'
  static readonly TAG_GREEN_TEXT: string = '#2E7D32'
  static readonly TAG_RED_BG: string = '#FFEBEE'
  static readonly TAG_RED_TEXT: string = '#C62828'
  static readonly TAG_PURPLE_BG: string = '#F3E5F5'
  static readonly TAG_PURPLE_TEXT: string = '#6A1B9A'
  static readonly TAG_ORANGE_BG: string = '#FFF3E0'
  static readonly TAG_ORANGE_TEXT: string = '#E65100'
  static readonly TAG_GRAY_BG: string = '#ECEFF1'
  static readonly TAG_GRAY_TEXT: string = '#546E7A'
}

// 样式常量
export class AppStyles {
  static readonly RADIUS_SM: number = 4
  static readonly RADIUS_MD: number = 8
  static readonly RADIUS_LG: number = 12
  static readonly RADIUS_XL: number = 16

  static readonly PADDING_XS: number = 4
  static readonly PADDING_SM: number = 8
  static readonly PADDING_MD: number = 16
  static readonly PADDING_LG: number = 24
  static readonly PADDING_XL: number = 32

  static readonly SIDEBAR_WIDTH: number = 200
  static readonly FONT_SIZE_TITLE: number = 24
  static readonly FONT_SIZE_SUBTITLE: number = 16
  static readonly FONT_SIZE_BODY: number = 14
  static readonly FONT_SIZE_SMALL: number = 13
  static readonly FONT_SIZE_CAPTION: number = 12
}

// 路由常量
export class Routes {
  static readonly DASHBOARD: string = 'dashboard'
  static readonly FIREWALL: string = 'firewall'
  static readonly FIREWALL_RULES: string = 'firewall-rules'
  static readonly LOG_MANAGE: string = 'log-manage'
  static readonly PERIPHERAL_MANAGE: string = 'peripheral-manage'
  static readonly IDENTITY: string = 'identity'
  static readonly TOOL_SETTINGS: string = 'tool-settings'
  static readonly HELP_FEEDBACK: string = 'help-feedback'
}

// 应用信息常量
export class AppInfo {
  static readonly APP_NAME: string = '安全管理中心'
  static readonly APP_VERSION: string = '1.0.0'
  static readonly BUNDLE_NAME: string = 'com.example.securitytool'
}

// 导航项
export interface NavItem {
  id: string
  label: string
  iconText: string
}

export const NAV_ITEMS: NavItem[] = [
  { id: Routes.DASHBOARD, label: '总览', iconText: '览' },
  { id: Routes.FIREWALL, label: '防火墙', iconText: '防' },
  { id: Routes.LOG_MANAGE, label: '日志管理', iconText: '日' },
  { id: Routes.PERIPHERAL_MANAGE, label: '外设管理', iconText: '外' },
  { id: Routes.IDENTITY, label: '身份鉴别', iconText: '身' },
  { id: Routes.TOOL_SETTINGS, label: '工具设置', iconText: '设' }
]
