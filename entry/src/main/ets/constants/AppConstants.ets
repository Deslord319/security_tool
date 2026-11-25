import { ThemeMode, ThemeColorSet, getThemeColors } from '../theme/ThemeColors'
import { AppResources } from './AppResources'
import { ModuleText } from './StringCatalog'
import { RouteIds } from './RouteIds'
import { Want } from '@kit.AbilityKit'

export class AppColors {
  static getColors(theme: ThemeMode): ThemeColorSet {
    return getThemeColors(theme)
  }

  static readonly BRAND_PRIMARY: ResourceColor = $r('app.color.app_brand_primary')
  static readonly MENU_ICON_COLOR_DARK: ResourceColor = $r('app.color.app_menu_icon_color_dark')
  static readonly THEME_MODE_ICON_COLOR_DARK: ResourceColor = $r('app.color.app_theme_mode_icon_color_dark')
  static readonly THEME_MODE_ICON_COLOR_LIGHT: ResourceColor = $r('app.color.app_theme_mode_icon_color_light')
  static readonly OVERLAY_BACKGROUND: ResourceColor = $r('app.color.app_overlay_background')
  static readonly INTERACTIVE_BUTTON_HOVER_LIGHT: ResourceColor = $r('app.color.app_interactive_button_hover_light')
  static readonly INTERACTIVE_BUTTON_PRESSED_LIGHT: ResourceColor = $r('app.color.app_interactive_button_pressed_light')
  static readonly INTERACTIVE_BUTTON_HOVER_DARK: ResourceColor = $r('app.color.app_interactive_button_hover_dark')
  static readonly INTERACTIVE_BUTTON_PRESSED_DARK: ResourceColor = $r('app.color.app_interactive_button_pressed_dark')
  static readonly INTERACTIVE_SECONDARY_BG_DARK: ResourceColor = $r('app.color.app_interactive_secondary_bg_dark')
  static readonly TRANSPARENT: ResourceColor = $r('app.color.app_transparent')
  static readonly MODAL_SHADOW_LIGHT: ResourceColor = $r('app.color.app_modal_shadow_light')
  static readonly MODAL_SHADOW_DARK: ResourceColor = $r('app.color.app_modal_shadow_dark')
  static readonly POPUP_SHADOW_LIGHT: ResourceColor = $r('app.color.app_popup_shadow_light')
  static readonly POPUP_SHADOW_DARK: ResourceColor = $r('app.color.app_popup_shadow_dark')
  static readonly CARD_OVERLAY_START: ResourceColor = $r('app.color.app_card_overlay_start')
  static readonly CARD_OVERLAY_HOVER_START: ResourceColor = $r('app.color.app_card_overlay_hover_start')
  static readonly CARD_OVERLAY_END: ResourceColor = $r('app.color.app_card_overlay_end')
  static readonly HOVER_SHADOW_LIGHT: ResourceColor = $r('app.color.app_hover_shadow_light')
  static readonly HOVER_SHADOW_STRONG_LIGHT: ResourceColor = $r('app.color.app_hover_shadow_strong_light')
  static readonly HOVER_SHADOW_REST_LIGHT: ResourceColor = $r('app.color.app_hover_shadow_rest_light')
  static readonly HOVER_SHADOW_DARK: ResourceColor = $r('app.color.app_hover_shadow_dark')
  static readonly HOVER_SHADOW_STRONG_DARK: ResourceColor = $r('app.color.app_hover_shadow_strong_dark')
  static readonly HOVER_SHADOW_REST_DARK: ResourceColor = $r('app.color.app_hover_shadow_rest_dark')
  static readonly SCROLL_BAR_LIGHT: ResourceColor = $r('app.color.app_scroll_bar_light')
  static readonly SCROLL_BAR_DARK: ResourceColor = $r('app.color.app_scroll_bar_dark')
  static readonly ACTION_PRIMARY_BG_DARK: ResourceColor = $r('app.color.app_action_primary_bg_dark')
  static readonly ACTION_PRIMARY_HOVER_DARK: ResourceColor = $r('app.color.app_action_primary_hover_dark')
  static readonly ACTION_PRIMARY_PRESSED_DARK: ResourceColor = $r('app.color.app_action_primary_pressed_dark')
  static readonly ACTION_PRIMARY_HOVER_LIGHT: ResourceColor = $r('app.color.app_action_primary_hover_light')
  static readonly ACTION_PRIMARY_PRESSED_LIGHT: ResourceColor = $r('app.color.app_action_primary_pressed_light')
  static readonly ACTION_DANGER_BG_DARK: ResourceColor = $r('app.color.app_action_danger_bg_dark')
  static readonly ACTION_DANGER_HOVER_DARK: ResourceColor = $r('app.color.app_action_danger_hover_dark')
  static readonly ACTION_DANGER_PRESSED_DARK: ResourceColor = $r('app.color.app_action_danger_pressed_dark')
  static readonly ACTION_DANGER_HOVER_LIGHT: ResourceColor = $r('app.color.app_action_danger_hover_light')
  static readonly ACTION_DANGER_PRESSED_LIGHT: ResourceColor = $r('app.color.app_action_danger_pressed_light')
  static readonly SIDEBAR_SELECTED_HOVER_LIGHT: ResourceColor = $r('app.color.app_sidebar_selected_hover_light')
  static readonly SIDEBAR_SELECTED_PRESSED_LIGHT: ResourceColor = $r('app.color.app_sidebar_selected_pressed_light')
  static readonly SIDEBAR_SELECTED_HOVER_DARK: ResourceColor = $r('app.color.app_sidebar_selected_hover_dark')
  static readonly SIDEBAR_SELECTED_PRESSED_DARK: ResourceColor = $r('app.color.app_sidebar_selected_pressed_dark')
  static readonly SIDEBAR_ICON_TILE_BG_LIGHT: ResourceColor = $r('app.color.app_sidebar_icon_tile_bg_light')
  static readonly SIDEBAR_ICON_TILE_BG_DARK: ResourceColor = $r('app.color.app_sidebar_icon_tile_bg_dark')
  static readonly THEME_MODE_ICON_TILE_BG_LIGHT: ResourceColor = $r('app.color.app_theme_mode_icon_tile_bg_light')
  static readonly THEME_MODE_ICON_TILE_BG_DARK: ResourceColor = $r('app.color.app_theme_mode_icon_tile_bg_dark')

  static readonly SUCCESS: ResourceColor = $r('app.color.app_success')
  static readonly WARNING: ResourceColor = $r('app.color.app_warning')
  static readonly DANGER: ResourceColor = $r('app.color.app_danger')
  static readonly MENU_ICON_TILE_LIGHT: ResourceColor = $r('app.color.app_menu_icon_tile_light')
  static readonly MENU_ICON_TILE_DARK: ResourceColor = $r('app.color.app_menu_icon_tile_dark')
  static readonly SIDEBAR_SELECTED_TILE: ResourceColor = $r('app.color.app_sidebar_selected_tile')
  static readonly SIDEBAR_SELECTED_ICON: ResourceColor = $r('app.color.app_sidebar_selected_icon')

  // Dashboard 渐变色 end 值
  static readonly GRADIENT_FIREWALL_END: ResourceColor = $r('app.color.app_gradient_firewall_end')
  static readonly GRADIENT_LOG_END: ResourceColor = $r('app.color.app_gradient_log_end')
  static readonly GRADIENT_PERIPHERAL_START: ResourceColor = $r('app.color.app_gradient_peripheral_start')
  static readonly GRADIENT_PERIPHERAL_END: ResourceColor = $r('app.color.app_gradient_peripheral_end')
  static readonly GRADIENT_PERMISSION_START: ResourceColor = $r('app.color.app_gradient_permission_start')
  static readonly GRADIENT_PERMISSION_END: ResourceColor = $r('app.color.app_gradient_permission_end')
  static readonly GRADIENT_IDENTITY_END: ResourceColor = $r('app.color.app_gradient_identity_end')
  static readonly GRADIENT_TOOL_START: ResourceColor = $r('app.color.app_gradient_tool_start')
  static readonly GRADIENT_TOOL_END: ResourceColor = $r('app.color.app_gradient_tool_end')
  
  // Firewall 主题颜色
  static readonly FIREWALL_SELECTED_CARD_BG_DARK: ResourceColor = $r('app.color.app_firewall_selected_card_bg_dark')
  static readonly FIREWALL_SELECTED_CARD_BG_LIGHT: ResourceColor = $r('app.color.app_firewall_selected_card_bg_light')
  static readonly FIREWALL_SELECTED_ICON_BORDER_DARK: ResourceColor = $r('app.color.app_firewall_selected_icon_border_dark')
  static readonly FIREWALL_SELECTED_ICON_BORDER_LIGHT: ResourceColor = $r('app.color.app_firewall_selected_icon_border_light')
  static readonly FIREWALL_SELECTED_SHADOW_DARK: ResourceColor = $r('app.color.app_firewall_selected_shadow_dark')
  static readonly FIREWALL_SELECTED_SHADOW_LIGHT: ResourceColor = $r('app.color.app_firewall_selected_shadow_light')
  
  // Firewall 规则冲突 UI 颜色
  static readonly FIREWALL_CONFLICT_BG: ResourceColor = $r('app.color.app_firewall_conflict_bg')
  static readonly FIREWALL_CONFLICT_PANEL_BG: ResourceColor = $r('app.color.app_firewall_conflict_panel_bg')
  static readonly FIREWALL_CONFLICT_BORDER: ResourceColor = $r('app.color.app_firewall_conflict_border')
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
      return $r('app.color.app_danger_icon_dark')
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

  static getMenuItemBackground(theme: ThemeMode, isHovered: boolean, isPressed: boolean = false): ResourceColor {
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

  static getMenuIconTileBackground(theme: ThemeMode): ResourceColor {
    return theme === ThemeMode.DARK ? AppColors.MENU_ICON_TILE_DARK : AppColors.MENU_ICON_TILE_LIGHT
  }

  static getBackButtonBackground(theme: ThemeMode, isHovered: boolean, isPressed: boolean = false): ResourceColor {
    return InteractiveItemStyles.getMenuItemBackground(theme, isHovered, isPressed)
  }

  static getSidebarItemBackground(theme: ThemeMode, isSelected: boolean, isHovered: boolean, isPressed: boolean = false): ResourceColor {
    if (isSelected) {
      if (theme === ThemeMode.DARK) {
        return isPressed ? AppColors.SIDEBAR_SELECTED_PRESSED_DARK : (isHovered ? AppColors.SIDEBAR_SELECTED_HOVER_DARK : AppColors.BRAND_PRIMARY)
      }
      return isPressed ? AppColors.SIDEBAR_SELECTED_PRESSED_LIGHT : (isHovered ? AppColors.SIDEBAR_SELECTED_HOVER_LIGHT : AppColors.BRAND_PRIMARY)
    }
    return InteractiveItemStyles.getMenuItemBackground(theme, isHovered, isPressed)
  }

  static getSidebarIconTileBackground(theme: ThemeMode, isSelected: boolean): ResourceColor {
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

  static getThemeModeIconColor(theme: ThemeMode): ResourceColor {
    return theme === ThemeMode.DARK ? AppColors.THEME_MODE_ICON_COLOR_DARK : AppColors.THEME_MODE_ICON_COLOR_LIGHT
  }

  static getThemeModeIconTileBackground(theme: ThemeMode): ResourceColor {
    return theme === ThemeMode.DARK ? AppColors.THEME_MODE_ICON_TILE_BG_DARK : AppColors.THEME_MODE_ICON_TILE_BG_LIGHT
  }
}

export class AppInfo {
  static readonly BUNDLE_NAME: string = 'com.huawei.securitytool'
  static readonly DEFAULT_USER_ID: number = 100
  static readonly ENTRY_MODULE_NAME: string = 'entry'
  static readonly ENTRY_ABILITY_NAME: string = 'EntryAbility'
  static readonly ADMIN_ABILITY_NAME: string = 'EnterpriseAdminAbility'
  static readonly STATUS_BAR_TITLE: string = 'SecurityTool'
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

export function getNavItems(): NavItem[] {
  return [
  { id: RouteIds.DASHBOARD, label: ModuleText.DASHBOARD, icon: AppResources.DASHBOARD_ICON },
  { id: RouteIds.FIREWALL, label: ModuleText.FIREWALL, icon: AppResources.FIREWALL_ICON },
  { id: RouteIds.LOG_MANAGE, label: ModuleText.LOG_MANAGE, icon: AppResources.LOG_ICON },
  { id: RouteIds.PERIPHERAL_MANAGE, label: ModuleText.PERIPHERAL_MANAGE, icon: AppResources.PERIPHERAL_ICON },
  { id: RouteIds.PERMISSION_MANAGE, label: ModuleText.PERMISSION_MANAGE, icon: AppResources.PERMISSION_ICON },
  { id: RouteIds.IDENTITY, label: ModuleText.IDENTITY, icon: AppResources.IDENTITY_ICON },
  // Help feedback is exposed from the top menu so the sidebar remains task-focused.
  { id: RouteIds.TOOL_SETTINGS, label: ModuleText.TOOL_SETTINGS, icon: AppResources.SETTINGS_ICON }
  ]
}
