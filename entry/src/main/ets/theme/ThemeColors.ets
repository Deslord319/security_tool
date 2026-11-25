// 主题模式枚举
export enum ThemeMode {
  LIGHT = 'light',
  DARK = 'dark'
}

// 用户偏好枚举
export enum ThemePreference {
  SYSTEM = 'system',  // 跟随系统
  MANUAL = 'manual'   // 手动设置
}

// 主题选项枚举（用于菜单三选一）
export enum ThemeOption {
  SYSTEM = 'system',  // 跟随系统
  LIGHT = 'light',    // 强制浅色
  DARK = 'dark'       // 强制深色
}

// 颜色集合接口
// 颜色值唯一来源为 resources/base/element/color.json（theme_light_* / theme_dark_* 双套显式资源名）。
// 不使用资源目录深色限定词：应用内主题为手动切换，不随系统深浅色变化。
// ThemeColorSet 颜色字段类型为 ResourceColor，可直接用于 ArkUI 颜色属性。
export interface ThemeColorSet {
  // 背景色
  BG_PAGE: ResourceColor
  BG_CARD: ResourceColor
  BG_COMPONENT: ResourceColor
  BG_HOVER: ResourceColor

  // 文本色
  TEXT_PRIMARY: ResourceColor
  TEXT_PRIMARY_OPACITY: number
  TEXT_SECONDARY_OPACITY: number
  TEXT_TERTIARY_OPACITY: number

  // 边框色
  BORDER: ResourceColor
  BORDER_OPACITY: number

  FORM_BG: ResourceColor
  FORM_BORDER: ResourceColor
  FORM_TEXT: ResourceColor
  FORM_PLACEHOLDER: ResourceColor
  FORM_ICON: ResourceColor
  FORM_FOCUS_BORDER: ResourceColor

  // Tag 颜色
  TAG_BLUE_BG: ResourceColor
  TAG_BLUE_TEXT: ResourceColor
  TAG_GREEN_BG: ResourceColor
  TAG_GREEN_TEXT: ResourceColor
  TAG_RED_BG: ResourceColor
  TAG_RED_TEXT: ResourceColor
  TAG_PURPLE_BG: ResourceColor
  TAG_PURPLE_TEXT: ResourceColor
  TAG_ORANGE_BG: ResourceColor
  TAG_ORANGE_TEXT: ResourceColor
  TAG_GRAY_BG: ResourceColor
  TAG_GRAY_TEXT: ResourceColor
  TAG_TEAL_BG: ResourceColor
  TAG_TEAL_TEXT: ResourceColor
}

// 浅色主题颜色
const LightThemeColors: ThemeColorSet = {
  // 背景色
  BG_PAGE: $r('app.color.theme_light_bg_page'),
  BG_CARD: $r('app.color.theme_light_bg_card'),
  BG_COMPONENT: $r('app.color.theme_light_bg_component'),
  BG_HOVER: $r('app.color.theme_light_bg_hover'),

  // 文本色
  TEXT_PRIMARY: $r('app.color.theme_light_text_primary'),
  TEXT_PRIMARY_OPACITY: 0.9,
  TEXT_SECONDARY_OPACITY: 0.6,
  TEXT_TERTIARY_OPACITY: 0.4,

  // 边框色
  BORDER: $r('app.color.theme_light_border'),
  BORDER_OPACITY: 0.1,

  FORM_BG: $r('app.color.theme_light_form_bg'),
  FORM_BORDER: $r('app.color.theme_light_form_border'),
  FORM_TEXT: $r('app.color.theme_light_form_text'),
  FORM_PLACEHOLDER: $r('app.color.theme_light_form_placeholder'),
  FORM_ICON: $r('app.color.theme_light_form_icon'),
  FORM_FOCUS_BORDER: $r('app.color.theme_light_form_focus_border'),

  // Tag 颜色
  TAG_BLUE_BG: $r('app.color.theme_light_tag_blue_bg'),
  TAG_BLUE_TEXT: $r('app.color.theme_light_tag_blue_text'),
  TAG_GREEN_BG: $r('app.color.theme_light_tag_green_bg'),
  TAG_GREEN_TEXT: $r('app.color.theme_light_tag_green_text'),
  TAG_RED_BG: $r('app.color.theme_light_tag_red_bg'),
  TAG_RED_TEXT: $r('app.color.theme_light_tag_red_text'),
  TAG_PURPLE_BG: $r('app.color.theme_light_tag_purple_bg'),
  TAG_PURPLE_TEXT: $r('app.color.theme_light_tag_purple_text'),
  TAG_ORANGE_BG: $r('app.color.theme_light_tag_orange_bg'),
  TAG_ORANGE_TEXT: $r('app.color.theme_light_tag_orange_text'),
  TAG_GRAY_BG: $r('app.color.theme_light_tag_gray_bg'),
  TAG_GRAY_TEXT: $r('app.color.theme_light_tag_gray_text'),
  TAG_TEAL_BG: $r('app.color.theme_light_tag_teal_bg'),
  TAG_TEAL_TEXT: $r('app.color.theme_light_tag_teal_text')
}

// 深色主题颜色
const DarkThemeColors: ThemeColorSet = {
  // 背景色
  BG_PAGE: $r('app.color.theme_dark_bg_page'),
  BG_CARD: $r('app.color.theme_dark_bg_card'),
  BG_COMPONENT: $r('app.color.theme_dark_bg_component'),
  BG_HOVER: $r('app.color.theme_dark_bg_hover'),

  // 文本色
  TEXT_PRIMARY: $r('app.color.theme_dark_text_primary'),
  TEXT_PRIMARY_OPACITY: 0.9,
  TEXT_SECONDARY_OPACITY: 0.8,
  TEXT_TERTIARY_OPACITY: 0.62,

  // 边框色
  BORDER: $r('app.color.theme_dark_border'),
  BORDER_OPACITY: 0.1,

  FORM_BG: $r('app.color.theme_dark_form_bg'),
  FORM_BORDER: $r('app.color.theme_dark_form_border'),
  FORM_TEXT: $r('app.color.theme_dark_form_text'),
  FORM_PLACEHOLDER: $r('app.color.theme_dark_form_placeholder'),
  FORM_ICON: $r('app.color.theme_dark_form_icon'),
  FORM_FOCUS_BORDER: $r('app.color.theme_dark_form_focus_border'),

  // Tag 颜色 (深色模式下调整为更柔和的色调)
  TAG_BLUE_BG: $r('app.color.theme_dark_tag_blue_bg'),
  TAG_BLUE_TEXT: $r('app.color.theme_dark_tag_blue_text'),
  TAG_GREEN_BG: $r('app.color.theme_dark_tag_green_bg'),
  TAG_GREEN_TEXT: $r('app.color.theme_dark_tag_green_text'),
  TAG_RED_BG: $r('app.color.theme_dark_tag_red_bg'),
  TAG_RED_TEXT: $r('app.color.theme_dark_tag_red_text'),
  TAG_PURPLE_BG: $r('app.color.theme_dark_tag_purple_bg'),
  TAG_PURPLE_TEXT: $r('app.color.theme_dark_tag_purple_text'),
  TAG_ORANGE_BG: $r('app.color.theme_dark_tag_orange_bg'),
  TAG_ORANGE_TEXT: $r('app.color.theme_dark_tag_orange_text'),
  TAG_GRAY_BG: $r('app.color.theme_dark_tag_gray_bg'),
  TAG_GRAY_TEXT: $r('app.color.theme_dark_tag_gray_text'),
  TAG_TEAL_BG: $r('app.color.theme_dark_tag_teal_bg'),
  TAG_TEAL_TEXT: $r('app.color.theme_dark_tag_teal_text')
}

// 获取主题颜色
export function getThemeColors(theme: ThemeMode): ThemeColorSet {
  return theme === ThemeMode.DARK ? DarkThemeColors : LightThemeColors
}
