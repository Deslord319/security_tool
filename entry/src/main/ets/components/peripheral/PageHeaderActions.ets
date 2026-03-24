/**
 * 页面头部操作按钮组件
 */
import { AppColors, AppStyles } from '../../constants/AppConstants'
import { ThemeMode } from '../../theme/ThemeColors'

interface PageHeaderActionsProps {
  currentTheme: ThemeMode
  onExport: () => void
  onClear: () => void
  showClear?: boolean
}

@Component
export struct PageHeaderActions {
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT
  onExport?: () => void
  onClear?: () => void
  @Prop showClear: boolean = true

  build() {
    Row({ space: 8 }) {
      Button() {
        Row({ space: 6 }) {
          Image($r('app.media.save'))
            .width(14)
            .height(14)
            .fillColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)

          Text('导出历史记录')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
        }
        .alignItems(VerticalAlign.Center)
      }
      .type(ButtonType.Normal)
      .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
      .borderRadius(AppStyles.RADIUS_SM)
      .height(32)
      .padding({ left: 10, right: 10 })
      .onClick(() => {
        if (this.onExport) {
          this.onExport()
        }
      })

      if (this.showClear) {
        Button() {
          Row({ space: 6 }) {
            Image($r('app.media.trash'))
              .width(14)
              .height(14)
              .fillColor(AppColors.getColors(this.currentTheme).TAG_RED_TEXT)

            Text('清理历史记录')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TAG_RED_TEXT)
          }
          .alignItems(VerticalAlign.Center)
        }
        .type(ButtonType.Normal)
        .backgroundColor(AppColors.getColors(this.currentTheme).TAG_RED_BG)
        .borderRadius(AppStyles.RADIUS_SM)
        .height(32)
        .padding({ left: 10, right: 10 })
        .onClick(() => {
          if (this.onClear) {
            this.onClear()
          }
        })
      }
    }
  }
}
