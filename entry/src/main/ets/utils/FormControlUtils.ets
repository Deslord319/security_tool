import { AppColors } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'

export class FormControlUtils {
  static background(theme: ThemeMode): ResourceColor {
    return AppColors.getColors(theme).FORM_BG
  }

  static border(theme: ThemeMode): ResourceColor {
    return AppColors.getColors(theme).FORM_BORDER
  }

  static text(theme: ThemeMode): ResourceColor {
    return AppColors.getColors(theme).FORM_TEXT
  }

  static selectArrow(theme: ThemeMode): ResourceColor {
    return AppColors.getColors(theme).FORM_TEXT
  }

  static placeholder(theme: ThemeMode): ResourceColor {
    return AppColors.getColors(theme).FORM_PLACEHOLDER
  }
}
