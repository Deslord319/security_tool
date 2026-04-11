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
    if (theme === ThemeMode.DARK) {
      return {
        radius: isHovered ? (strong ? 34 : 28) : 10,
        color: isHovered ? (strong ? 'rgba(148,163,184,0.16)' : 'rgba(148,163,184,0.12)') : 'rgba(148,163,184,0.04)',
        offsetX: 0,
        offsetY: isHovered ? (strong ? 16 : 12) : 3
      }
    }

    return {
      radius: isHovered ? (strong ? 34 : 28) : 10,
      color: isHovered ? (strong ? 'rgba(15,23,42,0.20)' : 'rgba(15,23,42,0.15)') : 'rgba(15,23,42,0.06)',
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
