import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

export type ResultMessageStatus = 'success' | 'failure'

@CustomDialog
export struct ResultMessageBox {
  controller: CustomDialogController
  status: ResultMessageStatus = 'success'
  message: string = ''
  buttonText: string = '我知道了'
  onConfirm: () => void = () => {}
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  private confirmDialog(): void {
    this.onConfirm()
    this.controller.close()
  }

  private getStatusTitle(): string {
    return this.status === 'success' ? '操作成功 ✅' : '操作失败 ❌'
  }

  build() {
    Column({ space: 0 }) {
      Column({ space: 8 }) {
        Text(this.getStatusTitle())
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .textAlign(TextAlign.Center)
          .width('100%')

        Text(this.message)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .textAlign(TextAlign.Center)
          .lineHeight(22)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .width('100%')
      .padding({ top: 8, bottom: 24 })

      Row() {
        Blank()

        Button(this.buttonText)
          .type(ButtonType.Normal)
          .width(96)
          .height(36)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(Color.White)
          .backgroundColor(AppColors.BRAND_PRIMARY)
          .borderRadius(AppStyles.RADIUS_SM)
          .padding({ left: 18, right: 18 })
          .onClick(() => {
            this.confirmDialog()
          })

        Blank()
      }
      .width('100%')
    }
    .width(392)
    .padding({ left: 20, right: 20, top: 18, bottom: 20 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow({
      radius: 20,
      color: this.currentTheme === ThemeMode.DARK ? 'rgba(0,0,0,0.36)' : 'rgba(0,0,0,0.14)',
      offsetX: 0,
      offsetY: 10
    })
  }
}
