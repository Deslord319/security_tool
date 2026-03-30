import { AppColors, AppStyles } from '../constants/AppConstants'
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

  build() {
    Column({ space: 0 }) {
      Row() {
        Text(this.title)
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        Blank()
        Button('关闭')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_COMPONENT)
          .borderRadius(AppStyles.RADIUS_SM)
          .height(30)
          .onClick(() => {
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
  }
}

@Component
export struct DetailDialogOverlay {
  @BuilderParam content: () => void

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')

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