import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

@Component
export struct StatCard {
  @Prop label: string = ''
  @Prop value: string = ''
  @Prop gradientStart: string = '#0A84FF'
  @Prop gradientEnd: string = '#00C6FF'
  @Prop iconText: string = ''
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Row({ space: 16 }) {
      // 渐变图标区域
      Column() {
        Text(this.iconText)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(52)
      .height(52)
      .borderRadius(AppStyles.RADIUS_LG)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .linearGradient({
        angle: 135,
        colors: [
          [this.gradientStart, 0],
          [this.gradientEnd, 1]
        ]
      })

      // 数值和标签
      Column({ space: 4 }) {
        Text(this.value)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.label)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .shadow({
      radius: 4,
      color: this.currentTheme === ThemeMode.DARK ? 'rgba(0,0,0,0.3)' : 'rgba(0,0,0,0.06)',
      offsetX: 0,
      offsetY: 2
    })
  }
}
