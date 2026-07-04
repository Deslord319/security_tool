import { LIGHT_COLORS, ThemeColorSet } from '../theme/ThemeColors'

export class AppColors {
  static readonly BRAND_PRIMARY: string = '#0A84FF'
  static readonly ACTION_PRIMARY_HOVER_LIGHT: string = 'rgba(10,132,255,0.14)'
  static readonly ACTION_PRIMARY_PRESSED_LIGHT: string = 'rgba(10,132,255,0.20)'
  static readonly HOVER_SHADOW_LIGHT: string = 'rgba(15,23,42,0.15)'
  static readonly HOVER_SHADOW_STRONG_LIGHT: string = 'rgba(15,23,42,0.20)'
  static readonly HOVER_SHADOW_REST_LIGHT: string = 'rgba(15,23,42,0.06)'

  static getColors(): ThemeColorSet {
    return LIGHT_COLORS
  }
}

export class AppStyles {
  static readonly RADIUS_SM: number = 4
  static readonly RADIUS_MD: number = 8
  static readonly RADIUS_LG: number = 12
  static readonly PADDING_MD: number = 16
  static readonly PADDING_LG: number = 24
  static readonly FONT_SIZE_TITLE: number = 24
  static readonly FONT_SIZE_SUBTITLE: number = 16
  static readonly FONT_SIZE_BODY: number = 14
  static readonly FONT_SIZE_CAPTION: number = 12
  static readonly INLINE_LOADING_INDICATOR_SIZE: number = 18
  static readonly DIVIDER_HEIGHT: number = 1
}

export class ActionButtonStyles {
  static readonly CHIP_HEIGHT: number = 32
  static readonly CHIP_HORIZONTAL_PADDING: number = 12

  static getPrimaryBackground(isHovered: boolean, isPressed: boolean = false): ResourceColor {
    if (isPressed) {
      return AppColors.ACTION_PRIMARY_PRESSED_LIGHT
    }
    return isHovered ? AppColors.ACTION_PRIMARY_HOVER_LIGHT : AppColors.getColors().TAG_BLUE_BG
  }

  static getPrimaryForeground(): ResourceColor {
    return AppColors.getColors().TEXT_PRIMARY
  }
}

export class AppInfo {
  static readonly BUNDLE_NAME: string = 'com.ukey.pin'
  static readonly ENTRY_MODULE_NAME: string = 'entry'
  static readonly BACKGROUND_ABILITY_NAME: string = 'BackGroundAbility'
  static readonly STATUS_BAR_TITLE: string = 'ukey解锁工具'
  static readonly BACKGROUND_ABILITY_TERMINATE_EVENT: string = 'ukey_pin_onPrepareToTerminate_event'
}
