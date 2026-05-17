import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'

@CustomDialog
export struct CommonLoadingDialog {
  controller?: CustomDialogController
  message: string = ''
  currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Column({ space: 14 }) {
      LoadingProgress()
        .width(AppStyles.MODAL_LOADING_INDICATOR_SIZE)
        .height(AppStyles.MODAL_LOADING_INDICATOR_SIZE)

      Text(this.message)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .textAlign(TextAlign.Center)
    }
    .width(AppStyles.LOADING_DIALOG_WIDTH)
    .padding({
      left: AppStyles.LOADING_DIALOG_PADDING_HORIZONTAL,
      right: AppStyles.LOADING_DIALOG_PADDING_HORIZONTAL,
      top: AppStyles.LOADING_DIALOG_PADDING_VERTICAL,
      bottom: AppStyles.LOADING_DIALOG_PADDING_VERTICAL
    })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .shadow({
      radius: AppStyles.LOADING_DIALOG_SHADOW_RADIUS,
      color: this.currentTheme === ThemeMode.DARK ? AppColors.MODAL_SHADOW_DARK : AppColors.MODAL_SHADOW_LIGHT,
      offsetX: 0,
      offsetY: AppStyles.LOADING_DIALOG_SHADOW_OFFSET_Y
    })
  }
}
