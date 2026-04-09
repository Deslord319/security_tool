import { AppColors, AppStyles } from '../constants/AppConstants'
import { ActionText } from '../constants/StringCatalog'
import { ThemeMode } from '../theme/ThemeColors'
import { IconTextActionButton } from './IconTextActionButton'

@ComponentV2
export struct DetailDialogShell {
  @Param title: string = ''
  @Param dialogWidth: number = 560
  @Param maxBodyHeight: number = 420
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param showHeader: boolean = true
  @Param showCloseAction: boolean = true
  @BuilderParam content?: () => void
  @Event onClose: () => void = () => {}

  build() {
    Column({ space: 0 }) {
      if (this.showHeader || this.showCloseAction) {
        Row() {
          if (this.showHeader) {
            Text(this.title)
              .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          }
          Blank()
          if (this.showCloseAction) {
            IconTextActionButton({
              label: ActionText.CLOSE,
              showIcon: false,
              currentTheme: this.currentTheme,
              onTap: this.onClose
            })
          }
        }
        .width('100%')

        if (this.showHeader) {
          Divider()
            .color(AppColors.getColors(this.currentTheme).BORDER)
            .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
            .margin({ top: 10, bottom: 10 })
        }
      }

      Scroll() {
        Column({ space: 12 }) {
          if (this.content) {
            this.content()
          }
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

@ComponentV2
export struct DetailDialogOverlay {
  @Event onDismiss: () => void = () => {}
  @BuilderParam content?: () => void

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
        if (this.content) {
          this.content()
        }
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
