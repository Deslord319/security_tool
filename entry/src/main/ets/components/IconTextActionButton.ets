import { ActionButtonStyles, AppStyles } from '../constants/AppConstants'
import { AppResources } from '../constants/AppResources'
import { ThemeMode } from '../theme/ThemeColors'

type IconTextActionButtonKind = 'primary' | 'info' | 'danger'

@ComponentV2
export struct IconTextActionButton {
  @Param label: string = ''
  @Param icon: Resource = AppResources.SAVE_ICON
  @Param showIcon: boolean = true
  @Param kind: IconTextActionButtonKind = 'primary'
  @Param isEnabled: boolean = true
  @Param isLoading: boolean = false
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onTap: () => void = () => {}
  @Local private isHovered: boolean = false
  @Local private isPressed: boolean = false

  private getBackgroundColor(): ResourceColor {
    switch (this.kind) {
      case 'danger':
        return ActionButtonStyles.getDangerBackground(this.currentTheme, this.isHovered, this.isPressed)
      default:
        return ActionButtonStyles.getPrimaryBackground(this.currentTheme, this.isHovered, this.isPressed)
    }
  }

  private getForegroundColor(): ResourceColor {
    switch (this.kind) {
      case 'danger':
        return ActionButtonStyles.getDangerForeground(this.currentTheme)
      default:
        return ActionButtonStyles.getPrimaryForeground(this.currentTheme)
    }
  }

  private getIconColor(): ResourceColor {
    switch (this.kind) {
      case 'danger':
        return ActionButtonStyles.getDangerIconColor(this.currentTheme)
      default:
        return ActionButtonStyles.getPrimaryIconColor(this.currentTheme)
    }
  }

  build() {
    Button() {
      Row({ space: 8 }) {
        if (this.isLoading) {
          LoadingProgress()
            .width(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
            .height(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
            .color(this.getForegroundColor())
        } else if (this.showIcon) {
          Image(this.icon)
            .width(ActionButtonStyles.ICON_SIZE)
            .height(ActionButtonStyles.ICON_SIZE)
            .fillColor(this.getIconColor())
            .draggable(false)
        }

        Text(this.label)
          .fontSize(ActionButtonStyles.FONT_SIZE)
          .fontColor(this.getForegroundColor())
          .fontWeight(FontWeight.Regular)
      }
      .alignItems(VerticalAlign.Center)
    }
    .type(ButtonType.Normal)
    .opacity(this.isEnabled || this.isLoading ? 1 : 0.5)
    .backgroundColor(this.getBackgroundColor())
    .borderRadius(AppStyles.RADIUS_SM)
    .height(ActionButtonStyles.HEIGHT)
    .padding({
      left: ActionButtonStyles.HORIZONTAL_PADDING_START,
      right: ActionButtonStyles.HORIZONTAL_PADDING_END
    })
    .stateEffect(false)
    .onHover((isHover: boolean) => {
      this.isHovered = this.isEnabled && !this.isLoading && isHover
    })
    .onTouch((event: TouchEvent) => {
      if (!this.isEnabled || this.isLoading) {
        return
      }
      if (event.type === TouchType.Down) {
        this.isPressed = true
        return
      }
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false
      }
    })
    .onClick(() => {
      this.isPressed = false
      if (this.isEnabled && !this.isLoading) {
        this.onTap()
      }
    })
  }
}
