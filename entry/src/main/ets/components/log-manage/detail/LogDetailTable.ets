import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { LogDetailSection, LogDisplayField } from '../../../presentation/log-manage/LogEntryPresentationModels'
import { ThemeMode } from '../../../theme/ThemeColors'

@ComponentV2
export struct LogDetailTable {
  @Param sections: LogDetailSection[] = []
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT

  @Builder
  private fieldCard(field: LogDisplayField) {
    Column({ space: 5 }) {
      Text(field.label)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)

      Text(field.value)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .copyOption(CopyOptions.LocalDevice)
    }
    .width(field.fullWidth ? '100%' : '49%')
    .alignItems(HorizontalAlign.Start)
    .padding(AppStyles.PADDING_12)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_MD)
  }

  @Builder
  private sectionView(section: LogDetailSection) {
    Column({ space: 8 }) {
      Text(section.title)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(section.fields, (field: LogDisplayField) => {
          this.fieldCard(field)
        }, (field: LogDisplayField) => field.key)
      }
      .width('100%')
    }
    .width('100%')
  }

  build() {
    Column({ space: 14 }) {
      ForEach(this.sections, (section: LogDetailSection) => {
        this.sectionView(section)
      }, (section: LogDetailSection) => section.id)
    }
    .width('100%')
  }
}
