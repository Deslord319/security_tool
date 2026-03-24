/**
 * Tab 标题构建器组件
 */
import { AppColors, AppStyles } from '../../constants/AppConstants'
import { ThemeMode } from '../../theme/ThemeColors'

interface TabBuilderProps {
  title: string
  index: number
  currentTab: number
  currentTheme: ThemeMode
}

@Component
export struct TabBuilder {
  @Prop title: string = ''
  @Prop index: number = 0
  @Prop currentTab: number = 0
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Column() {
      Text(this.title)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(this.currentTab === this.index ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(this.currentTab === this.index ? 1 : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
    }
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }
}
