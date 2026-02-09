import { AppColors, AppStyles } from '../constants/AppConstants'

@Component
export struct DirectionCard {
  @Prop label: string = ''
  @Prop count: number = 0
  @Prop gradientStart: string = '#0A84FF'
  @Prop gradientEnd: string = '#00C6FF'
  @Prop iconText: string = ''

  build() {
    Row({ space: 16 }) {
      // 渐变图标
      Column() {
        Text(this.iconText)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(48)
      .height(48)
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

      // 文字
      Column({ space: 4 }) {
        Text(this.label)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .opacity(AppColors.TEXT_PRIMARY_OPACITY)
        Text(`${this.count} 条规则`)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.TEXT_PRIMARY)
          .opacity(AppColors.TEXT_TERTIARY_OPACITY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(AppColors.BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .shadow({
      radius: 4,
      color: 'rgba(0,0,0,0.06)',
      offsetX: 0,
      offsetY: 2
    })
  }
}
