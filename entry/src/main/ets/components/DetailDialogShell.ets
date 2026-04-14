import { AppColors, AppStyles } from '../constants/AppConstants'
import { ActionText } from '../constants/StringCatalog'
import { ThemeMode } from '../theme/ThemeColors'
import { getScrollBarColor, SCROLL_BAR_WIDTH_DEFAULT, SCROLL_BAR_WIDTH_HOVER } from '../utils/ScrollBarStyleUtils'
import { IconTextActionButton } from './IconTextActionButton'

@ComponentV2
export struct DetailDialogShell {
  @Param title: string = ''
  @Param dialogWidth: number = 560
  @Param maxBodyHeight: number = 420
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param showHeader: boolean = true
  @Param showCloseAction: boolean = true
  @Param bodyRightPaddingExtra: number = DetailDialogShell.SCROLL_CONTENT_RIGHT_PADDING
  @BuilderParam content?: () => void
  @Event onClose: () => void = () => {}
  private static readonly DIALOG_PADDING: number = 18
  private static readonly SCROLL_CONTENT_RIGHT_PADDING: number = 24
  @Local private scrollBarWidth: number = SCROLL_BAR_WIDTH_DEFAULT

  private getBodyTopPadding(): number {
    return this.showHeader || this.showCloseAction ? 0 : DetailDialogShell.DIALOG_PADDING
  }

  build() {
    Column({ space: 0 }) {
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
      }
      .width('100%')
      .padding({
        left: DetailDialogShell.DIALOG_PADDING,
        right: DetailDialogShell.DIALOG_PADDING,
        top: DetailDialogShell.DIALOG_PADDING,
        bottom: 0
      })

      Scroll() {
        Column({ space: 12 }) {
          if (this.content) {
            this.content()
          }
        }
        .width('100%')
        .padding({
          left: DetailDialogShell.DIALOG_PADDING,
          right: DetailDialogShell.DIALOG_PADDING + this.bodyRightPaddingExtra,
          top: this.getBodyTopPadding(),
          bottom: DetailDialogShell.DIALOG_PADDING
        })
      }
      .width('100%')
      .constraintSize({ maxHeight: this.maxBodyHeight })
      .scrollBar(BarState.Auto)
      .scrollBarColor(getScrollBarColor(this.currentTheme))
      .scrollBarWidth(this.scrollBarWidth)
      .onHover((isHover: boolean) => {
        this.scrollBarWidth = isHover ? SCROLL_BAR_WIDTH_HOVER : SCROLL_BAR_WIDTH_DEFAULT
      })
    }
    .width(this.dialogWidth)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
  }
}
