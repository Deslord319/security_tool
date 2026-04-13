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
export interface ThemeColorSet {
  // 背景色
  BG_PAGE: string
  BG_CARD: string
  BG_COMPONENT: string
  BG_HOVER: string

  // 文本色
  TEXT_PRIMARY: string
  TEXT_PRIMARY_OPACITY: number
  TEXT_SECONDARY_OPACITY: number
  TEXT_TERTIARY_OPACITY: number

  // 边框色
  BORDER: string
  BORDER_OPACITY: number

  FORM_BG: string
  FORM_BORDER: string
  FORM_TEXT: string
  FORM_PLACEHOLDER: string
  FORM_ICON: string
  FORM_FOCUS_BORDER: string

  // Tag 颜色
  TAG_BLUE_BG: string
  TAG_BLUE_TEXT: string
  TAG_GREEN_BG: string
  TAG_GREEN_TEXT: string
  TAG_RED_BG: string
  TAG_RED_TEXT: string
  TAG_PURPLE_BG: string
  TAG_PURPLE_TEXT: string
  TAG_ORANGE_BG: string
  TAG_ORANGE_TEXT: string
  TAG_GRAY_BG: string
  TAG_GRAY_TEXT: string
  TAG_TEAL_BG: string
  TAG_TEAL_TEXT: string
}

// 浅色主题颜色
export const LightThemeColors: ThemeColorSet = {
  // 背景色
  BG_PAGE: '#F5F5F5',
  BG_CARD: '#FFFFFF',
  BG_COMPONENT: '#F0F0F0',
  BG_HOVER: '#E5E5E5',

  // 文本色
  TEXT_PRIMARY: '#000000',
  TEXT_PRIMARY_OPACITY: 0.9,
  TEXT_SECONDARY_OPACITY: 0.6,
  TEXT_TERTIARY_OPACITY: 0.4,

  // 边框色
  BORDER: '#000000',
  BORDER_OPACITY: 0.1,

  FORM_BG: '#FFFFFF',
  FORM_BORDER: '#D0D7DE',
  FORM_TEXT: '#111827',
  FORM_PLACEHOLDER: '#6B7280',
  FORM_ICON: '#475467',
  FORM_FOCUS_BORDER: '#0A84FF',

  // Tag 颜色
  TAG_BLUE_BG: '#E3F2FD',
  TAG_BLUE_TEXT: '#1565C0',
  TAG_GREEN_BG: '#E8F5E9',
  TAG_GREEN_TEXT: '#2E7D32',
  TAG_RED_BG: '#FFEBEE',
  TAG_RED_TEXT: '#C62828',
  TAG_PURPLE_BG: '#F3E5F5',
  TAG_PURPLE_TEXT: '#6A1B9A',
  TAG_ORANGE_BG: '#FFF3E0',
  TAG_ORANGE_TEXT: '#E65100',
  TAG_GRAY_BG: '#ECEFF1',
  TAG_GRAY_TEXT: '#546E7A',
  TAG_TEAL_BG: '#E0F2F1',
  TAG_TEAL_TEXT: '#00695C'
}

// 深色主题颜色
const DarkThemeColors: ThemeColorSet = {
  // 背景色
  BG_PAGE: '#121212',
  BG_CARD: '#1E1E1E',
  BG_COMPONENT: '#2C2C2C',
  BG_HOVER: '#3A3A3A',

  // 文本色
  TEXT_PRIMARY: '#FFFFFF',
  TEXT_PRIMARY_OPACITY: 0.9,
  TEXT_SECONDARY_OPACITY: 0.8,
  TEXT_TERTIARY_OPACITY: 0.62,

  // 边框色
  BORDER: '#FFFFFF',
  BORDER_OPACITY: 0.1,

  FORM_BG: '#2A2A2C',
  FORM_BORDER: '#5A5A5E',
  FORM_TEXT: '#F4F4F5',
  FORM_PLACEHOLDER: '#A1A1AA',
  FORM_ICON: '#D4D4D8',
  FORM_FOCUS_BORDER: '#4AA3FF',

  // Tag 颜色 (深色模式下调整为更柔和的色调)
  TAG_BLUE_BG: '#1E3A5F',
  TAG_BLUE_TEXT: '#64B5F6',
  TAG_GREEN_BG: '#1B3D2F',
  TAG_GREEN_TEXT: '#81C784',
  TAG_RED_BG: '#3D1F1F',
  TAG_RED_TEXT: '#EF9A9A',
  TAG_PURPLE_BG: '#2D1F3D',
  TAG_PURPLE_TEXT: '#CE93D8',
  TAG_ORANGE_BG: '#3D2D1F',
  TAG_ORANGE_TEXT: '#FFB74D',
  TAG_GRAY_BG: '#2D2D2D',
  TAG_GRAY_TEXT: '#B0BEC5',
  TAG_TEAL_BG: '#1B3D3D',
  TAG_TEAL_TEXT: '#80CBC4'
}

// 获取主题颜色
export function getThemeColors(theme: ThemeMode): ThemeColorSet {
  return theme === ThemeMode.DARK ? DarkThemeColors : LightThemeColors
}
