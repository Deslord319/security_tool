/**
 * 接口管控面板组件
 */
import { AppColors, AppStyles } from '../../constants/AppConstants'
import { ThemeMode } from '../../theme/ThemeColors'

interface InterfaceControlPanelProps {
  title: string
  description: string
  isDisabled: boolean
  isLoading: boolean
  currentTheme: ThemeMode
  onToggle: (disabled: boolean) => void
}

@Component
export struct InterfaceControlPanel {
  @Prop title: string = ''
  @Prop description: string = ''
  @Prop isDisabled: boolean = false
  @Prop isLoading: boolean = false
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT
  onToggle?: (disabled: boolean) => void

  build() {
    Column({ space: 12 }) {
      // 标题和状态
      Row() {
        Text(this.title)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

        Blank()

        // 状态标签
        Text(this.isDisabled ? '已禁用' : '已启用')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(this.isDisabled ? AppColors.ERROR : AppColors.SUCCESS)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.isDisabled ? AppColors.getColors(this.currentTheme).TAG_RED_BG : AppColors.getColors(this.currentTheme).TAG_GREEN_BG)
          .borderRadius(AppStyles.RADIUS_SM)
      }
      .width('100%')

      // 描述
      Text(this.description)
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .width('100%')

      // 开关控件
      Row() {
        Switch()
          .checked(this.isDisabled)
          .selectedColor(AppColors.BRAND_PRIMARY)
          .swtichControlSize(52, 32)
          .trackSize(52, 32)
          .onChange((isChecked: boolean) => {
            if (this.onToggle) {
              this.onToggle(isChecked)
            }
          })
          .disabled(this.isLoading)

        if (this.isLoading) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(AppColors.BRAND_PRIMARY)
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER,
      style: BorderStyle.Solid
    })
  }
}
