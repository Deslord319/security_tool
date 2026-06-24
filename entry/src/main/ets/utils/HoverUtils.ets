import { AppColors } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'

export class HoverUtils {
  static readonly DURATION_MS: number = 220

  static animate(uiContext: UIContext, update: () => void): void {
    uiContext.animateTo({
      duration: HoverUtils.DURATION_MS,
      curve: Curve.EaseOut
    }, update)
  }

  static getShadow(theme: ThemeMode, isHovered: boolean, strong: boolean = false): ShadowOptions {
    let color: ResourceColor = theme === ThemeMode.DARK
      ? (isHovered
        ? (strong ? AppColors.HOVER_SHADOW_STRONG_DARK : AppColors.HOVER_SHADOW_DARK)
        : AppColors.HOVER_SHADOW_REST_DARK)
      : (isHovered
        ? (strong ? AppColors.HOVER_SHADOW_STRONG_LIGHT : AppColors.HOVER_SHADOW_LIGHT)
        : AppColors.HOVER_SHADOW_REST_LIGHT)
    return {
      radius: isHovered ? (strong ? 34 : 28) : 10,
      color: color,
      offsetX: 0,
      offsetY: isHovered ? (strong ? 16 : 12) : 3
    }
  }

  static getTranslateY(isHovered: boolean, distance: number = 6): number {
    return isHovered ? -distance : 0
  }

  static getScale(isHovered: boolean, value: number = 1.01): number {
    return isHovered ? value : 1
  }
}
