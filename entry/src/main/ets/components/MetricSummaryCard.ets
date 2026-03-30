import { AppColors, AppStyles } from '../constants/AppConstants'
import { DashboardStatusKind } from '../models/DashboardModels'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'

@Component
export struct MetricSummaryCard {
  @Prop title: string = ''
  @Prop primaryText: string = ''
  @Prop secondaryText: string = ''
  @Prop statusText: string = ''
  @Prop statusKind: DashboardStatusKind = 'neutral'
  @Prop icon: Resource = $r('app.media.shield')
  @Prop accentStart: string = AppColors.BRAND_PRIMARY
  @Prop accentEnd: string = AppColors.GRADIENT_FIREWALL_END
  @Prop clickable: boolean = true
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

  private getStatusTextColor(): string {
    switch (this.statusKind) {
      case 'success':
        return AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT
      case 'warning':
        return AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT
      case 'neutral':
      default:
        return AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT
    }
  }

  private getStatusBackground(): ResourceColor {
    switch (this.statusKind) {
      case 'success':
        return AppColors.getColors(this.currentTheme).TAG_GREEN_BG
      case 'warning':
        return AppColors.getColors(this.currentTheme).TAG_ORANGE_BG
      case 'neutral':
      default:
        return AppColors.getColors(this.currentTheme).TAG_BLUE_BG
    }
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 24,
          colors: [
            [this.isHovered ? 'rgba(255,255,255,0.10)' : 'rgba(255,255,255,0.03)', 0],
            ['rgba(255,255,255,0.00)', 1]
          ]
        })

      Column({ space: 18 }) {
        Row() {
          Text(this.title)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

          Blank()

          Column() {
            Image(this.icon)
              .width(22)
              .height(22)
              .fillColor(Color.White)
              .draggable(false)
          }
          .width(42)
          .height(42)
          .borderRadius(14)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .linearGradient({
            angle: 135,
            colors: [
              [this.accentStart, 0],
              [this.accentEnd, 1]
            ]
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Column({ space: 6 }) {
          Text(this.primaryText)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.secondaryText)
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Row() {
          Text(this.statusText)
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getStatusTextColor())
            .backgroundColor(this.getStatusBackground())
            .padding({ left: 8, right: 8, top: 5, bottom: 5 })
            .borderRadius(999)
            .maxLines(1)

          Blank()

          if (this.clickable && !this.disabled) {
            Image($r('app.media.chevron_right'))
              .width(16)
              .height(16)
              .fillColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .padding(20)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(172)
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
