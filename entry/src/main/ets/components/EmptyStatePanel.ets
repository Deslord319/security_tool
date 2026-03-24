import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'

@Component
export struct EmptyStatePanel {
  @Prop title: string = ''
  @Prop description: string = ''
  @Prop radius: number = AppStyles.RADIUS_LG
  @Prop horizontalPadding: number = AppStyles.PADDING_LG
  @Prop verticalPadding: number = 32
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @State isHovered: boolean = false

  build() {
    Column({ space: 10 }) {
      Text(this.title)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .textAlign(TextAlign.Center)

      if (this.description.length > 0) {
        Text(this.description)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding({
      left: this.horizontalPadding,
      right: this.horizontalPadding,
      top: this.verticalPadding,
      bottom: this.verticalPadding
    })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(this.radius)
    .clip(true)
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow(HoverUtils.getShadow(this.currentTheme, this.isHovered, true))
    .translate({ y: HoverUtils.getTranslateY(this.isHovered, 4) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.isHovered = isHover
      })
    })
  }
}

@Component
export struct EmptyStateCard {
  @Prop title: string = ''
  @Prop description: string = ''
  @Prop radius: number = AppStyles.RADIUS_MD
  @Prop bottomOnly: boolean = false
  @Prop horizontalPadding: number = 20
  @Prop verticalPadding: number = 32
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Column({ space: 10 }) {
      Text(this.title)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .textAlign(TextAlign.Center)

      if (this.description.length > 0) {
        Text(this.description)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding({
      left: this.horizontalPadding,
      right: this.horizontalPadding,
      top: this.verticalPadding,
      bottom: this.verticalPadding
    })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(this.bottomOnly ? {
      bottomLeft: this.radius,
      bottomRight: this.radius
    } : this.radius)
  }
}

