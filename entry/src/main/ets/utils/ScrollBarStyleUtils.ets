import { ThemeMode } from '../theme/ThemeColors'

export const SCROLL_BAR_WIDTH_DEFAULT: number = 4
export const SCROLL_BAR_WIDTH_HOVER: number = 6

export function getScrollBarColor(currentTheme: ThemeMode): ResourceColor {
  return currentTheme === ThemeMode.DARK ? '#6B7280' : '#9CA3AF'
}
