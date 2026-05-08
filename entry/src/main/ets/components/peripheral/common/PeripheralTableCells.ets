import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { ThemeMode } from '../../../theme/ThemeColors'

@ComponentV2
export struct PeripheralDeviceIdentityCell {
  @Param deviceName: string = ''
  @Param deviceId: string = ''
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param weight: number = 2.6

  build() {
    Column({ space: 6 }) {
      Text(this.deviceName)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.deviceId.length > 0) {
        Text(this.deviceId)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(this.weight)
  }
}

@ComponentV2
export struct PeripheralHeaderCell {
  @Param label: string = ''
  @Param weight: number = 1
  @Param textAlign: TextAlign = TextAlign.Center
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Text(this.label)
      .fontSize(AppStyles.FONT_SIZE_SMALL)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .layoutWeight(this.weight)
      .textAlign(this.textAlign)
  }
}

@ComponentV2
export struct PeripheralTypeTag {
  @Param label: string = ''
  @Param weight: number = 1
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Row() {
      Row() {
        Text(this.label)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .borderRadius(6)
      .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
    }
    .layoutWeight(this.weight)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }
}
