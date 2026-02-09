import { AppColors, AppStyles } from '../constants/AppConstants'

@Component
export struct PlaceholderPage {
  @Prop title: string = ''

  build() {
    Column() {
      Column({ space: 16 }) {
        Text('...')
          .fontSize(48)
          .fontColor(AppColors.TEXT_PRIMARY)
          .opacity(0.15)
        Text(this.title || '该模块')
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontColor(AppColors.TEXT_PRIMARY)
          .opacity(AppColors.TEXT_SECONDARY_OPACITY)
        Text('正在开发中，敬请期待')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.TEXT_PRIMARY)
          .opacity(AppColors.TEXT_TERTIARY_OPACITY)
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppColors.BG_PAGE)
  }
}
