import { AppColors } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'

export class FormControlUtils {
  static background(theme: ThemeMode): string {
    return AppColors.getColors(theme).FORM_BG
  }

  static border(theme: ThemeMode): string {
    return AppColors.getColors(theme).FORM_BORDER
  }

  static text(theme: ThemeMode): string {
    return AppColors.getColors(theme).FORM_TEXT
  }

  static selectArrow(theme: ThemeMode): string {
    return AppColors.getColors(theme).FORM_TEXT
  }

  static placeholder(theme: ThemeMode): string {
    return AppColors.getColors(theme).FORM_PLACEHOLDER
  }

  static focusBorder(theme: ThemeMode): string {
    return AppColors.getColors(theme).FORM_FOCUS_BORDER
  }
}
