import { ThemeMode } from '../theme/ThemeColors'

export class HoverUtils {
  static readonly DURATION_MS: number = 280

  static animate(update: () => void): void {
    animateTo({
      duration: HoverUtils.DURATION_MS,
      curve: Curve.Friction
    }, update)
  }

  static getShadow(theme: ThemeMode, isHovered: boolean, strong: boolean = false): ShadowOptions {
    if (theme === ThemeMode.DARK) {
      return {
        radius: isHovered ? (strong ? 24 : 18) : 6,
        color: isHovered ? 'rgba(0,0,0,0.42)' : 'rgba(0,0,0,0.28)',
        offsetX: 0,
        offsetY: isHovered ? (strong ? 12 : 8) : 2
      }
    }

    return {
      radius: isHovered ? (strong ? 24 : 18) : 6,
      color: isHovered ? 'rgba(15,23,42,0.14)' : 'rgba(15,23,42,0.08)',
      offsetX: 0,
      offsetY: isHovered ? (strong ? 12 : 8) : 2
    }
  }

  static getTranslateY(isHovered: boolean, distance: number = 6): number {
    return isHovered ? -distance : 0
  }

  static getScale(isHovered: boolean, value: number = 1.01): number {
    return isHovered ? value : 1
  }
}
