/**
 * 连接详情指标字段组件
 */
import { AppColors, AppStyles } from '../../constants/AppConstants'
import { ThemeMode } from '../../theme/ThemeColors'

interface ConnectionDetailMetricFieldProps {
  label: string
  value: string
  currentTheme: ThemeMode
}

@Component
export struct ConnectionDetailMetricField {
  @Prop label: string = ''
  @Prop value: string = ''
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Column({ space: 4 }) {
      Text(this.label)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      Text(this.value)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }
}
