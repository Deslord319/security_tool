import { ActionButtonStyles, AppColors, AppStyles } from '../constants/AppConstants'
import { DialogButtonStrings } from '../constants/modules/DialogStrings'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

@Component
export struct DetailDialogShell {
  title: string = ''
  dialogWidth: number = 560
  maxBodyHeight: number = 420
  @BuilderParam content: () => void
  onClose: () => void = () => {}
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @State private isCloseHovered: boolean = false
  @State private isClosePressed: boolean = false

  build() {
    Column({ space: 0 }) {
      Row() {
        Text(this.title)
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        Blank()
        Button(DialogButtonStrings.CLOSE)
          .type(ButtonType.Normal)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(ActionButtonStyles.getPrimaryForeground(this.currentTheme))
          .backgroundColor(ActionButtonStyles.getPrimaryBackground(this.currentTheme, this.isCloseHovered, this.isClosePressed))
          .borderRadius(AppStyles.RADIUS_SM)
          .height(ActionButtonStyles.CHIP_HEIGHT)
          .padding({
            left: ActionButtonStyles.CHIP_HORIZONTAL_PADDING,
            right: ActionButtonStyles.CHIP_HORIZONTAL_PADDING
          })
          .stateEffect(false)
          .onHover((isHover: boolean) => {
            this.isCloseHovered = isHover
          })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.isClosePressed = true
              return
            }
            if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.isClosePressed = false
            }
          })
          .onClick(() => {
            this.isClosePressed = false
            this.onClose()
          })
      }
      .width('100%')

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
        .margin({ top: 10, bottom: 10 })

      Scroll() {
        Column({ space: 12 }) {
          this.content()
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: this.maxBodyHeight })
      .scrollBar(BarState.Auto)
    }
    .width(this.dialogWidth)
    .padding(18)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
  }
}

@Component
export struct DetailDialogOverlay {
  onDismiss: () => void = () => {}
  @BuilderParam content: () => void

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(AppColors.OVERLAY_BACKGROUND)
        .onClick(() => {
          this.onDismiss()
        })

      Column() {
        this.content()
      }
      .width('100%')
      .height('100%')
      .padding(AppStyles.PADDING_LG)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}
