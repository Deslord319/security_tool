import { AppColors, AppStyles } from '../../constants/AppConstants'
import { ThemeMode } from '../../theme/ThemeColors'

@Component
export struct PageHeaderActions {
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT
  @Prop exportLabel: string = '导出历史记录'
  @Prop clearLabel: string = '清理历史记录'
  @Prop showClear: boolean = true
  onExport?: () => void
  onClear?: () => void

  build() {
    Row({ space: 8 }) {
      Button(this.exportLabel)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
        .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
        .borderRadius(AppStyles.RADIUS_SM)
        .height(32)
        .padding({ left: 10, right: 10 })
        .onClick(() => this.onExport && this.onExport())

      if (this.showClear) {
        Button(this.clearLabel)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_RED_TEXT)
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_RED_BG)
          .borderRadius(AppStyles.RADIUS_SM)
          .height(32)
          .padding({ left: 10, right: 10 })
          .onClick(() => this.onClear && this.onClear())
      }
    }
  }
}
