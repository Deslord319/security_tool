export enum ThemeMode {
  LIGHT = 'light',
  DARK = 'dark'
}

export interface ThemeColorSet {
  BG_PAGE: string
  BG_CARD: string
  BG_COMPONENT: string
  BG_HOVER: string
  TEXT_PRIMARY: string
  TEXT_PRIMARY_OPACITY: number
  TEXT_SECONDARY_OPACITY: number
  TEXT_TERTIARY_OPACITY: number
  BORDER: string
  BORDER_OPACITY: number
  TAG_BLUE_BG: string
  TAG_BLUE_TEXT: string
  TAG_GREEN_BG: string
  TAG_GREEN_TEXT: string
  TAG_RED_BG: string
  TAG_RED_TEXT: string
}

const LightThemeColors: ThemeColorSet = {
  BG_PAGE: '#F5F5F5',
  BG_CARD: '#FFFFFF',
  BG_COMPONENT: '#F0F0F0',
  BG_HOVER: '#E5E5E5',
  TEXT_PRIMARY: '#000000',
  TEXT_PRIMARY_OPACITY: 0.9,
  TEXT_SECONDARY_OPACITY: 0.6,
  TEXT_TERTIARY_OPACITY: 0.4,
  BORDER: '#000000',
  BORDER_OPACITY: 0.1,
  TAG_BLUE_BG: '#E3F2FD',
  TAG_BLUE_TEXT: '#1565C0',
  TAG_GREEN_BG: '#E8F5E9',
  TAG_GREEN_TEXT: '#2E7D32',
  TAG_RED_BG: '#FFEBEE',
  TAG_RED_TEXT: '#C62828'
}

const DarkThemeColors: ThemeColorSet = {
  BG_PAGE: '#121212',
  BG_CARD: '#1E1E1E',
  BG_COMPONENT: '#2C2C2C',
  BG_HOVER: '#3A3A3A',
  TEXT_PRIMARY: '#FFFFFF',
  TEXT_PRIMARY_OPACITY: 0.9,
  TEXT_SECONDARY_OPACITY: 0.8,
  TEXT_TERTIARY_OPACITY: 0.62,
  BORDER: '#FFFFFF',
  BORDER_OPACITY: 0.1,
  TAG_BLUE_BG: '#1E3A5F',
  TAG_BLUE_TEXT: '#64B5F6',
  TAG_GREEN_BG: '#1B3D2F',
  TAG_GREEN_TEXT: '#81C784',
  TAG_RED_BG: '#3D1F1F',
  TAG_RED_TEXT: '#EF9A9A'
}

export function getThemeColors(theme: ThemeMode): ThemeColorSet {
  return theme === ThemeMode.DARK ? DarkThemeColors : LightThemeColors
}
