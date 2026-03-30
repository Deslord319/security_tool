import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'

@Component
export struct CompactSummaryCard {
  @Prop title: string = ''
  @Prop valueText: string = ''
  @Prop description: string = ''
  @Prop icon?: Resource
  @Prop iconText: string = ''
  @Prop accentStart: string = AppColors.BRAND_PRIMARY
  @Prop accentEnd: string = AppColors.GRADIENT_FIREWALL_END
  @Prop clickable: boolean = false
  @Prop disabled: boolean = false
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onPress: () => void = () => {}
  @State isHovered: boolean = false

  private canInteract(): boolean {
    return this.clickable && !this.disabled
  }

  private setHoverState(isHovered: boolean): void {
    if (!this.canInteract()) {
      if (this.isHovered) {
        this.isHovered = false
      }
      return
    }
    HoverUtils.animate(() => {
      this.isHovered = isHovered
    })
  }

  build() {
    Row({ space: 12 }) {
      Column() {
        if (this.icon !== undefined) {
          Image(this.icon)
            .width(18)
            .height(18)
            .fillColor(Color.White)
            .draggable(false)
        } else {
          Text(this.iconText)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
      }
      .width(36)
      .height(36)
      .borderRadius(12)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .linearGradient({
        angle: 135,
        colors: [
          [this.accentStart, 0],
          [this.accentEnd, 1]
        ]
      })

      Column({ space: 4 }) {
        Text(this.title)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

        Text(this.valueText)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

        if (this.description.length > 0) {
          Text(this.description)
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height(92)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow(HoverUtils.getShadow(this.currentTheme, this.isHovered, true))
    .translate({ y: HoverUtils.getTranslateY(this.isHovered, 4) })
    .scale({
      x: HoverUtils.getScale(this.isHovered),
      y: HoverUtils.getScale(this.isHovered)
    })
    .opacity(this.disabled ? 0.6 : 1)
    .clip(true)
    .onHover((isHover: boolean) => {
      this.setHoverState(isHover)
    })
    .onClick(() => {
      if (this.canInteract()) {
        this.onPress()
      }
    })
  }
}
