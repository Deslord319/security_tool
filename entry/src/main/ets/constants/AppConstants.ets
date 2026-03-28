import { ThemeMode, ThemeColorSet, getThemeColors } from '../theme/ThemeColors'
import { CommonStrings } from './CommonStrings'

export class AppColors {
  static getColors(theme: ThemeMode): ThemeColorSet {
    return getThemeColors(theme)
  }

  static readonly BRAND_PRIMARY: string = '#0A84FF'
  static readonly BRAND_LIGHT: string = '#5EA1FF'

  static readonly SUCCESS: string = '#34C759'
  static readonly WARNING: string = '#FF9500'
  static readonly DANGER: string = '#FF3B30'

  static readonly TEXT_PRIMARY: string = '#000000'
  static readonly TEXT_PRIMARY_OPACITY: number = 0.9
  static readonly TEXT_SECONDARY_OPACITY: number = 0.6
  static readonly TEXT_TERTIARY_OPACITY: number = 0.4

  static readonly BG_PAGE: string = '#F5F5F5'
  static readonly BG_CARD: string = '#FFFFFF'
  static readonly BG_COMPONENT: string = '#F0F0F0'
  static readonly BG_HOVER: string = '#E5E5E5'
  static readonly MENU_HOVER_LIGHT: string = 'rgba(229,229,234,0.9)'
  static readonly MENU_HOVER_DARK: string = 'rgba(72,72,74,0.9)'
  static readonly MENU_ICON_TILE_LIGHT: string = 'rgba(242,242,247,1)'
  static readonly MENU_ICON_TILE_DARK: string = 'rgba(58,58,60,1)'
  static readonly SIDEBAR_SELECTED_TILE: string = '#3B9BFF'
  static readonly SIDEBAR_SELECTED_ICON: string = '#EAF4FF'

  static readonly BORDER: string = '#000000'
  static readonly BORDER_OPACITY: number = 0.1

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
  static readonly TEXT_MUTED: string = '#9E9E9E'
}

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

export class ActionButtonStyles {
  static readonly HEIGHT: number = 36
  static readonly ICON_SIZE: number = 20
  static readonly FONT_SIZE: number = 14
  static readonly HORIZONTAL_PADDING_START: number = 10
  static readonly HORIZONTAL_PADDING_END: number = 14

  static readonly CHIP_HEIGHT: number = 32
  static readonly CHIP_HORIZONTAL_PADDING: number = 12

  static getPrimaryBackground(theme: ThemeMode, isHovered: boolean, isPressed: boolean = false): ResourceColor {
    if (theme === ThemeMode.DARK) {
      if (isPressed) {
        return 'rgba(94,161,255,0.24)'
      }
      return isHovered ? 'rgba(94,161,255,0.18)' : 'rgba(44,103,185,0.48)'
    }
    if (isPressed) {
      return 'rgba(10,132,255,0.20)'
    }
    return isHovered ? 'rgba(10,132,255,0.14)' : AppColors.getColors(theme).TAG_BLUE_BG
  }

  static getDangerBackground(theme: ThemeMode, isHovered: boolean, isPressed: boolean = false): ResourceColor {
    if (theme === ThemeMode.DARK) {
      if (isPressed) {
        return 'rgba(255,59,48,0.24)'
      }
      return isHovered ? 'rgba(255,59,48,0.18)' : 'rgba(185,54,47,0.67)'
    }
    if (isPressed) {
      return 'rgba(255,59,48,0.20)'
    }
    return isHovered ? 'rgba(255,59,48,0.14)' : AppColors.getColors(theme).TAG_RED_BG
  }

  static getPrimaryForeground(theme: ThemeMode): ResourceColor {
    if (theme === ThemeMode.DARK) {
      return Color.White
    }
    return AppColors.getColors(theme).TEXT_PRIMARY
  }

  static getDangerForeground(theme: ThemeMode): ResourceColor {
    if (theme === ThemeMode.DARK) {
      return Color.White
    }
    return AppColors.getColors(theme).TEXT_PRIMARY
  }
}

export class InteractiveItemStyles {
  static readonly ITEM_HEIGHT: number = 44
  static readonly ITEM_RADIUS: number = 12
  static readonly ITEM_HORIZONTAL_PADDING_START: number = 8
  static readonly ITEM_HORIZONTAL_PADDING_END: number = 10
  static readonly ICON_TILE_SIZE: number = 30
  static readonly ICON_TILE_RADIUS: number = 10
  static readonly ICON_SIZE: number = 18

  static getMenuItemBackground(theme: ThemeMode, isHovered: boolean, isPressed: boolean = false): string {
    if (!isHovered && !isPressed) {
      return 'rgba(0,0,0,0)'
    }
    if (theme === ThemeMode.DARK) {
      return isPressed ? 'rgba(94,94,98,0.92)' : 'rgba(84,84,88,0.78)'
    }
    return isPressed ? 'rgba(209,209,214,0.95)' : 'rgba(229,229,234,0.92)'
  }

  static getMenuIconColor(theme: ThemeMode): ResourceColor {
    return theme === ThemeMode.DARK ? '#A9C7FF' : AppColors.BRAND_PRIMARY
  }

  static getMenuIconTileBackground(theme: ThemeMode): string {
    return theme === ThemeMode.DARK ? AppColors.MENU_ICON_TILE_DARK : AppColors.MENU_ICON_TILE_LIGHT
  }

  static getBackButtonBackground(theme: ThemeMode, isHovered: boolean, isPressed: boolean = false): string {
    return InteractiveItemStyles.getMenuItemBackground(theme, isHovered, isPressed)
  }

  static getSidebarItemBackground(theme: ThemeMode, isSelected: boolean, isHovered: boolean, isPressed: boolean = false): string {
    if (isSelected) {
      if (theme === ThemeMode.DARK) {
        return isPressed ? 'rgba(94,161,255,0.90)' : (isHovered ? 'rgba(94,161,255,0.82)' : AppColors.BRAND_PRIMARY)
      }
      return isPressed ? 'rgba(10,132,255,0.92)' : (isHovered ? 'rgba(10,132,255,0.84)' : AppColors.BRAND_PRIMARY)
    }
    return InteractiveItemStyles.getMenuItemBackground(theme, isHovered, isPressed)
  }

  static getSidebarIconTileBackground(theme: ThemeMode, isSelected: boolean): string {
    if (isSelected) {
      return AppColors.SIDEBAR_SELECTED_TILE
    }
    return theme === ThemeMode.DARK ? 'rgba(10,132,255,0.14)' : 'rgba(10,132,255,0.08)'
  }

  static getSidebarIconColor(theme: ThemeMode, isSelected: boolean): ResourceColor {
    return isSelected ? AppColors.SIDEBAR_SELECTED_ICON : InteractiveItemStyles.getMenuIconColor(theme)
  }

  static getSidebarTextColor(theme: ThemeMode, isSelected: boolean): ResourceColor {
    return isSelected ? Color.White : AppColors.getColors(theme).TEXT_PRIMARY
  }

  static getThemeModeIconColor(theme: ThemeMode): string {
    return theme === ThemeMode.DARK ? '#8E8E93' : '#FFD60A'
  }

  static getThemeModeIconTileBackground(theme: ThemeMode): string {
    return theme === ThemeMode.DARK ? 'rgba(142,142,147,0.18)' : 'rgba(255,214,10,0.14)'
  }
}

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

export class AppInfo {
  static readonly APP_NAME: string = CommonStrings.appName
  static readonly APP_VERSION: string = '1.0.0'
  static readonly BUNDLE_NAME: string = 'com.huawei.securitytool'
}

export interface NavItem {
  id: string
  label: string
  icon: Resource
}

export const NAV_ITEMS: NavItem[] = [
  { id: Routes.DASHBOARD, label: CommonStrings.moduleDashboard, icon: $r('app.media.dashboard') },
  { id: Routes.FIREWALL, label: CommonStrings.moduleFirewall, icon: $r('app.media.firewall') },
  { id: Routes.LOG_MANAGE, label: CommonStrings.moduleLogManage, icon: $r('app.media.log') },
  { id: Routes.PERIPHERAL_MANAGE, label: CommonStrings.modulePeripheralManage, icon: $r('app.media.peripheral') },
  { id: Routes.IDENTITY, label: CommonStrings.moduleIdentity, icon: $r('app.media.identity') },
  { id: Routes.TOOL_SETTINGS, label: CommonStrings.moduleToolSettings, icon: $r('app.media.settings') }
]
