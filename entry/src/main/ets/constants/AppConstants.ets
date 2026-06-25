import { ThemeMode, ThemeColorSet, getThemeColors } from '../theme/ThemeColors'
import { AppResources } from './AppResources'
import { ModuleText } from './StringCatalog'
import { RouteIds } from './RouteIds'
import { Want } from '@kit.AbilityKit'

export class AppColors {
  static getColors(theme: ThemeMode): ThemeColorSet {
    return getThemeColors(theme)
  }

  static readonly BRAND_PRIMARY: string = '#0A84FF'
  static readonly MENU_ICON_COLOR_DARK: string = '#A9C7FF'
  static readonly THEME_MODE_ICON_COLOR_DARK: string = '#8E8E93'
  static readonly THEME_MODE_ICON_COLOR_LIGHT: string = '#FFD60A'
  static readonly OVERLAY_BACKGROUND: string = '#66000000'
  static readonly INTERACTIVE_BUTTON_HOVER_LIGHT: string = 'rgba(0,0,0,0.05)'
  static readonly INTERACTIVE_BUTTON_PRESSED_LIGHT: string = 'rgba(0,0,0,0.08)'
  static readonly INTERACTIVE_BUTTON_HOVER_DARK: string = 'rgba(255,255,255,0.10)'
  static readonly INTERACTIVE_BUTTON_PRESSED_DARK: string = 'rgba(255,255,255,0.14)'
  static readonly INTERACTIVE_SECONDARY_BG_DARK: string = 'rgba(255,255,255,0.08)'
  static readonly TRANSPARENT: string = 'rgba(0,0,0,0)'
  static readonly MODAL_SHADOW_LIGHT: string = 'rgba(0,0,0,0.14)'
  static readonly MODAL_SHADOW_DARK: string = 'rgba(0,0,0,0.32)'
  static readonly POPUP_SHADOW_LIGHT: string = 'rgba(0,0,0,0.15)'
  static readonly POPUP_SHADOW_DARK: string = 'rgba(0,0,0,0.4)'
  static readonly CARD_OVERLAY_START: string = 'rgba(255,255,255,0.03)'
  static readonly CARD_OVERLAY_HOVER_START: string = 'rgba(255,255,255,0.10)'
  static readonly CARD_OVERLAY_END: string = 'rgba(255,255,255,0.00)'
  static readonly HOVER_SHADOW_LIGHT: string = 'rgba(15,23,42,0.15)'
  static readonly HOVER_SHADOW_STRONG_LIGHT: string = 'rgba(15,23,42,0.20)'
  static readonly HOVER_SHADOW_REST_LIGHT: string = 'rgba(15,23,42,0.06)'
  static readonly HOVER_SHADOW_DARK: string = 'rgba(148,163,184,0.12)'
  static readonly HOVER_SHADOW_STRONG_DARK: string = 'rgba(148,163,184,0.16)'
  static readonly HOVER_SHADOW_REST_DARK: string = 'rgba(148,163,184,0.04)'
  static readonly SCROLL_BAR_LIGHT: string = '#9CA3AF'
  static readonly SCROLL_BAR_DARK: string = '#6B7280'
  static readonly ACTION_PRIMARY_BG_DARK: string = 'rgba(94,161,255,0.24)'
  static readonly ACTION_PRIMARY_HOVER_DARK: string = 'rgba(94,161,255,0.32)'
  static readonly ACTION_PRIMARY_PRESSED_DARK: string = 'rgba(94,161,255,0.42)'
  static readonly ACTION_PRIMARY_HOVER_LIGHT: string = 'rgba(10,132,255,0.14)'
  static readonly ACTION_PRIMARY_PRESSED_LIGHT: string = 'rgba(10,132,255,0.20)'
  static readonly ACTION_DANGER_BG_DARK: string = 'rgba(255,59,48,0.24)'
  static readonly ACTION_DANGER_HOVER_DARK: string = 'rgba(255,59,48,0.32)'
  static readonly ACTION_DANGER_PRESSED_DARK: string = 'rgba(255,59,48,0.42)'
  static readonly ACTION_DANGER_HOVER_LIGHT: string = 'rgba(255,59,48,0.14)'
  static readonly ACTION_DANGER_PRESSED_LIGHT: string = 'rgba(255,59,48,0.20)'
  static readonly SIDEBAR_SELECTED_HOVER_LIGHT: string = 'rgba(10,132,255,0.84)'
  static readonly SIDEBAR_SELECTED_PRESSED_LIGHT: string = 'rgba(10,132,255,0.92)'
  static readonly SIDEBAR_SELECTED_HOVER_DARK: string = 'rgba(94,161,255,0.82)'
  static readonly SIDEBAR_SELECTED_PRESSED_DARK: string = 'rgba(94,161,255,0.90)'
  static readonly SIDEBAR_ICON_TILE_BG_LIGHT: string = 'rgba(10,132,255,0.08)'
  static readonly SIDEBAR_ICON_TILE_BG_DARK: string = 'rgba(10,132,255,0.14)'
  static readonly THEME_MODE_ICON_TILE_BG_LIGHT: string = 'rgba(255,214,10,0.14)'
  static readonly THEME_MODE_ICON_TILE_BG_DARK: string = 'rgba(142,142,147,0.18)'

  static readonly SUCCESS: string = '#34C759'
  static readonly WARNING: string = '#FF9500'
  static readonly DANGER: string = '#FF3B30'
  static readonly MENU_ICON_TILE_LIGHT: string = 'rgba(242,242,247,1)'
  static readonly MENU_ICON_TILE_DARK: string = 'rgba(58,58,60,1)'
  static readonly SIDEBAR_SELECTED_TILE: string = '#3B9BFF'
  static readonly SIDEBAR_SELECTED_ICON: string = '#EAF4FF'

  // Dashboard 渐变色 end 值
  static readonly GRADIENT_FIREWALL_END: string = '#00C6FF'
  static readonly GRADIENT_LOG_END: string = '#30D158'
  static readonly GRADIENT_PERIPHERAL_START: string = '#5856D6'
  static readonly GRADIENT_PERIPHERAL_END: string = '#AF52DE'
  static readonly GRADIENT_PERMISSION_START: string = '#00A870'
  static readonly GRADIENT_PERMISSION_END: string = '#4CD4B0'
  static readonly GRADIENT_IDENTITY_END: string = '#FFCC00'
  static readonly GRADIENT_TOOL_START: string = '#9095A1'
  static readonly GRADIENT_TOOL_END: string = '#D8DCE3'
  static readonly GRADIENT_HELP_START: string = '#FF8A80'
  static readonly GRADIENT_HELP_END: string = '#FFB4A8'
  
  // Firewall 主题颜色
  static readonly FIREWALL_SELECTED_CARD_BG_DARK: string = '#243140'
  static readonly FIREWALL_SELECTED_CARD_BG_LIGHT: string = '#EEF6FF'
  static readonly FIREWALL_SELECTED_ICON_BORDER_DARK: string = '#0F1720'
  static readonly FIREWALL_SELECTED_ICON_BORDER_LIGHT: string = '#FFFFFF'
  static readonly FIREWALL_SELECTED_SHADOW_DARK: string = '#66000000'
  static readonly FIREWALL_SELECTED_SHADOW_LIGHT: string = '#22000000'
  
  // Firewall 规则冲突 UI 颜色
  static readonly FIREWALL_CONFLICT_BG: string = '#FFE8B3'
  static readonly FIREWALL_CONFLICT_PANEL_BG: string = '#FFF7E6'
  static readonly FIREWALL_CONFLICT_BORDER: string = '#FFD591'
}

export class AppStyles {
  static readonly RADIUS_SM: number = 4
  static readonly RADIUS_MD: number = 8
  static readonly RADIUS_LG: number = 12

  static readonly PADDING_XS: number = 4
  static readonly PADDING_SM: number = 8
  static readonly PADDING_12: number = 12
  static readonly PADDING_MD: number = 16
  static readonly PADDING_LG: number = 24
  static readonly PADDING_XL: number = 32

  static readonly SIDEBAR_WIDTH: number = 200
  static readonly FONT_SIZE_TITLE: number = 24
  static readonly FONT_SIZE_SUBTITLE: number = 16
  static readonly FONT_SIZE_BODY: number = 14
  static readonly FONT_SIZE_SMALL: number = 13
  static readonly FONT_SIZE_CAPTION: number = 12
  static readonly FONT_SIZE_MICRO: number = 11

  static readonly SELECT_WIDTH_DEFAULT: number = 140
  static readonly TOP_BAR_HEIGHT: number = 42
  static readonly TITLE_BAR_SYSTEM_BUTTON_COUNT: number = 3
  static readonly TITLE_BAR_CONTROL_BACKGROUND_SIZE: number = 28
  static readonly TITLE_BAR_CONTROL_BACKGROUND_RADIUS: number = 4
  static readonly TITLE_BAR_CONTROL_SPACING: number = 12
  static readonly TITLE_BAR_CLOSE_BUTTON_RIGHT_MARGIN: number = 20
  static readonly TITLE_BAR_CONTROL_VERTICAL_OFFSET: number = 8
  static readonly WINDOW_CONTROL_RESERVED_WIDTH: number =
    AppStyles.TITLE_BAR_CLOSE_BUTTON_RIGHT_MARGIN +
      AppStyles.TITLE_BAR_SYSTEM_BUTTON_COUNT * AppStyles.TITLE_BAR_CONTROL_BACKGROUND_SIZE +
      AppStyles.TITLE_BAR_SYSTEM_BUTTON_COUNT * AppStyles.TITLE_BAR_CONTROL_SPACING
  static readonly BUTTON_HEIGHT: number = 40
  static readonly INPUT_HEIGHT: number = 40
  static readonly LOADING_INDICATOR_SIZE: number = 42
  static readonly MODAL_LOADING_INDICATOR_SIZE: number = 44
  static readonly LOADING_INDICATOR_SIZE_LG: number = 48
  static readonly INLINE_LOADING_INDICATOR_SIZE: number = 18
  static readonly LOADING_DIALOG_WIDTH: number = 280
  static readonly LOADING_DIALOG_PADDING_HORIZONTAL: number = 24
  static readonly LOADING_DIALOG_PADDING_VERTICAL: number = 28
  static readonly LOADING_DIALOG_SHADOW_RADIUS: number = 18
  static readonly LOADING_DIALOG_SHADOW_OFFSET_Y: number = 8
  static readonly DIALOG_WIDTH_DEFAULT: number = 560
  static readonly DIALOG_WIDTH_MEDIUM: number = 620
  static readonly DIALOG_WIDTH_LARGE: number = 760
  static readonly DIALOG_BODY_MAX_HEIGHT_DEFAULT: number = 420
  static readonly DIALOG_BODY_MAX_HEIGHT_MEDIUM: number = 460
  static readonly DIALOG_BODY_MAX_HEIGHT_LARGE: number = 760
  static readonly ICON_SIZE_SM: number = 18
  static readonly ICON_SIZE_MD: number = 20
  static readonly ICON_SIZE_LG: number = 28
  static readonly ICON_TILE_SIZE_LG: number = 48
  static readonly RADIUS_PILL: number = 999
  static readonly CONTROL_ROW_ACTION_GAP: number = 10
  static readonly CONTROL_ROW_HORIZONTAL_PADDING: number = 20
  static readonly CONTROL_ROW_VERTICAL_PADDING: number = 16
  static readonly TABLE_HORIZONTAL_PADDING: number = 22
  static readonly TABLE_HEADER_VERTICAL_PADDING: number = 14
  static readonly TABLE_ROW_VERTICAL_PADDING: number = 18
  static readonly TABLE_DIVIDER_MARGIN: number = 20
  
  // 间距常量（按需定义）
  static readonly SPACING_TAB_BAR_ITEM_HORIZONTAL: number = 16
  static readonly SPACING_TAB_BAR_ITEM_VERTICAL: number = 10
  static readonly SPACING_CHIP: number = 4
  
  // 圆角常量
  static readonly RADIUS_CHIP: number = 10
  
  // 分隔线
  static readonly DIVIDER_HEIGHT: number = 1
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
        return AppColors.ACTION_PRIMARY_PRESSED_DARK
      }
      return isHovered ? AppColors.ACTION_PRIMARY_HOVER_DARK : AppColors.ACTION_PRIMARY_BG_DARK
    }
    if (isPressed) {
      return AppColors.ACTION_PRIMARY_PRESSED_LIGHT
    }
    return isHovered ? AppColors.ACTION_PRIMARY_HOVER_LIGHT : AppColors.getColors(theme).TAG_BLUE_BG
  }

  static getDangerBackground(theme: ThemeMode, isHovered: boolean, isPressed: boolean = false): ResourceColor {
    if (theme === ThemeMode.DARK) {
      if (isPressed) {
        return AppColors.ACTION_DANGER_PRESSED_DARK
      }
      return isHovered ? AppColors.ACTION_DANGER_HOVER_DARK : AppColors.ACTION_DANGER_BG_DARK
    }
    if (isPressed) {
      return AppColors.ACTION_DANGER_PRESSED_LIGHT
    }
    return isHovered ? AppColors.ACTION_DANGER_HOVER_LIGHT : AppColors.getColors(theme).TAG_RED_BG
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
    return AppColors.DANGER
  }

  static getPrimaryIconColor(theme: ThemeMode): ResourceColor {
    return InteractiveItemStyles.getMenuIconColor(theme)
  }

  static getDangerIconColor(theme: ThemeMode): ResourceColor {
    if (theme === ThemeMode.DARK) {
      return '#FFB4AE'
    }
    return AppColors.DANGER
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
      return AppColors.TRANSPARENT
    }
    if (theme === ThemeMode.DARK) {
      return isPressed ? AppColors.INTERACTIVE_BUTTON_PRESSED_DARK : AppColors.INTERACTIVE_BUTTON_HOVER_DARK
    }
    return isPressed ? AppColors.INTERACTIVE_BUTTON_PRESSED_LIGHT : AppColors.INTERACTIVE_BUTTON_HOVER_LIGHT
  }

  static getMenuIconColor(theme: ThemeMode): ResourceColor {
    return theme === ThemeMode.DARK ? AppColors.MENU_ICON_COLOR_DARK : AppColors.BRAND_PRIMARY
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
        return isPressed ? AppColors.SIDEBAR_SELECTED_PRESSED_DARK : (isHovered ? AppColors.SIDEBAR_SELECTED_HOVER_DARK : AppColors.BRAND_PRIMARY)
      }
      return isPressed ? AppColors.SIDEBAR_SELECTED_PRESSED_LIGHT : (isHovered ? AppColors.SIDEBAR_SELECTED_HOVER_LIGHT : AppColors.BRAND_PRIMARY)
    }
    return InteractiveItemStyles.getMenuItemBackground(theme, isHovered, isPressed)
  }

  static getSidebarIconTileBackground(theme: ThemeMode, isSelected: boolean): string {
    if (isSelected) {
      return AppColors.SIDEBAR_SELECTED_TILE
    }
    return theme === ThemeMode.DARK ? AppColors.SIDEBAR_ICON_TILE_BG_DARK : AppColors.SIDEBAR_ICON_TILE_BG_LIGHT
  }

  static getSidebarIconColor(theme: ThemeMode, isSelected: boolean): ResourceColor {
    return isSelected ? AppColors.SIDEBAR_SELECTED_ICON : InteractiveItemStyles.getMenuIconColor(theme)
  }

  static getSidebarTextColor(theme: ThemeMode, isSelected: boolean): ResourceColor {
    return isSelected ? Color.White : AppColors.getColors(theme).TEXT_PRIMARY
  }

  static getThemeModeIconColor(theme: ThemeMode): string {
    return theme === ThemeMode.DARK ? AppColors.THEME_MODE_ICON_COLOR_DARK : AppColors.THEME_MODE_ICON_COLOR_LIGHT
  }

  static getThemeModeIconTileBackground(theme: ThemeMode): string {
    return theme === ThemeMode.DARK ? AppColors.THEME_MODE_ICON_TILE_BG_DARK : AppColors.THEME_MODE_ICON_TILE_BG_LIGHT
  }
}

export class AppInfo {
  static readonly BUNDLE_NAME: string = 'com.huawei.securitytool'
  static readonly DEFAULT_USER_ID: number = 100
  static readonly ENTRY_MODULE_NAME: string = 'entry'
  static readonly ENTRY_ABILITY_NAME: string = 'EntryAbility'
  static readonly ADMIN_ABILITY_NAME: string = 'EnterpriseAdminAbility'
  static readonly BACKGROUND_ABILITY_NAME: string = 'BackGroundAbility'
  static readonly STATUS_BAR_TITLE: string = 'SecurityTool'
  static readonly BACKGROUND_ABILITY_TERMINATE_EVENT: string = 'security_tool_onPrepareToTerminate_event'
  static readonly DB_NAME: string = 'security_tool.db'
}

export const ADMIN_WANT: Want = {
  bundleName: AppInfo.BUNDLE_NAME,
  abilityName: AppInfo.ADMIN_ABILITY_NAME
}

export const ENTRY_WANT: Want = {
  bundleName: AppInfo.BUNDLE_NAME,
  abilityName: AppInfo.ENTRY_ABILITY_NAME
}

export interface NavItem {
  id: string
  label: string
  icon: Resource
}

export const NAV_ITEMS: NavItem[] = [
  { id: RouteIds.DASHBOARD, label: ModuleText.DASHBOARD, icon: AppResources.DASHBOARD_ICON },
  { id: RouteIds.FIREWALL, label: ModuleText.FIREWALL, icon: AppResources.FIREWALL_ICON },
  { id: RouteIds.LOG_MANAGE, label: ModuleText.LOG_MANAGE, icon: AppResources.LOG_ICON },
  { id: RouteIds.PERIPHERAL_MANAGE, label: ModuleText.PERIPHERAL_MANAGE, icon: AppResources.PERIPHERAL_ICON },
  { id: RouteIds.PERMISSION_MANAGE, label: ModuleText.PERMISSION_MANAGE, icon: AppResources.PERMISSION_ICON },
  { id: RouteIds.IDENTITY, label: ModuleText.IDENTITY, icon: AppResources.IDENTITY_ICON },
  // Help feedback is exposed from the top menu so the sidebar remains task-focused.
  { id: RouteIds.TOOL_SETTINGS, label: ModuleText.TOOL_SETTINGS, icon: AppResources.SETTINGS_ICON }
]
