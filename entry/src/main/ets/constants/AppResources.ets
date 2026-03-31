/**
 * 应用资源常量
 * 统一管理所有资源引用 ($r('app.media.*'))
 * 
 * 使用示例:
 * ```ets
 * import { AppResources } from '../constants/AppResources'
 * Image(AppResources.SHIELD_ICON)
 * ```
 */
export class AppResources {
  // ==================== 导航图标 ====================
  static readonly DASHBOARD_ICON = $r('app.media.dashboard')
  static readonly FIREWALL_ICON = $r('app.media.firewall')
  static readonly LOG_ICON = $r('app.media.log')
  static readonly PERIPHERAL_ICON = $r('app.media.peripheral')
  static readonly IDENTITY_ICON = $r('app.media.identity')
  static readonly SETTINGS_ICON = $r('app.media.settings')
  static readonly HELP_ICON = $r('app.media.help')
  static readonly HELP_MENU_ICON = $r('app.media.help_menu')
  
  // ==================== 通用图标 ====================
  static readonly SHIELD_ICON = $r('app.media.shield')
  static readonly SAVE_ICON = $r('app.media.save')
  static readonly ARROW_LEFT_ICON = $r('app.media.arrow_left')
  static readonly ARROW_UP_ICON = $r('app.media.arrow_up')
  static readonly ARROW_DOWN_ICON = $r('app.media.arrow_down')
  static readonly CHEVRON_RIGHT_ICON = $r('app.media.chevron_right')
  
  // ==================== 主题图标 ====================
  static readonly SUN_ICON = $r('app.media.sun')
  static readonly MOON_ICON = $r('app.media.moon')
  static readonly START_ICON_ABOUT = $r('app.media.startIcon_about')
  
  // ==================== 其他图标 ====================
  static readonly INFO_MENU_ICON = $r('app.media.info_menu')
  static readonly START_ICON = $r('app.media.startIcon')
}
