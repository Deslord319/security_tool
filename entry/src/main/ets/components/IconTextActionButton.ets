import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

export type IconTextActionButtonKind = 'primary' | 'info' | 'danger'

@Component
export struct IconTextActionButton {
  label: string = ''
  icon: Resource = $r('app.media.save')
  kind: IconTextActionButtonKind = 'primary'
  isEnabled: boolean = true
  onTap: () => void = () => {}
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @State private isHovered: boolean = false

  private getBackgroundColor(): ResourceColor {
    let colors = AppColors.getColors(this.currentTheme)
    switch (this.kind) {
      case 'danger':
        return this.isHovered ? colors.BG_HOVER : colors.TAG_RED_BG
      default:
        return this.isHovered ? colors.BG_HOVER : colors.TAG_BLUE_BG
    }
  }

  private getForegroundColor(): ResourceColor {
    let colors = AppColors.getColors(this.currentTheme)
    switch (this.kind) {
      case 'danger':
        return colors.TAG_RED_TEXT
      default:
        return colors.TAG_BLUE_TEXT
    }
  }

  private getIconTileColor(): ResourceColor {
    let colors = AppColors.getColors(this.currentTheme)
    switch (this.kind) {
      case 'danger':
        return this.isHovered ? colors.TAG_RED_BG : colors.BG_COMPONENT
      default:
        return this.isHovered ? colors.TAG_BLUE_BG : colors.BG_COMPONENT
    }
  }

  build() {
    Button() {
      Row({ space: 8 }) {
        Row() {
          Image(this.icon)
            .width(18)
            .height(18)
            .draggable(false)
        }
        .width(26)
        .height(26)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.getIconTileColor())
        .borderRadius(AppStyles.RADIUS_SM)

        Text(this.label)
          .fontSize(15)
          .fontColor(this.getForegroundColor())
          .fontWeight(FontWeight.Bold)
      }
      .alignItems(VerticalAlign.Center)
    }
    .type(ButtonType.Normal)
    .enabled(this.isEnabled)
    .opacity(this.isEnabled ? 1 : 0.5)
    .backgroundColor(this.getBackgroundColor())
    .borderRadius(AppStyles.RADIUS_SM)
    .height(40)
    .padding({ left: 12, right: 16 })
    .stateEffect(false)
    .onHover((isHover: boolean) => {
      this.isHovered = this.isEnabled && isHover
    })
    .onClick(() => {
      if (this.isEnabled) {
        this.onTap()
      }
    })
  }
}
