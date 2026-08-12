import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { LogManageDetailStrings } from '../../../constants/modules/LogManageStrings'
import { LogDetailSection, LogDisplayField } from '../../../presentation/log-manage/LogEntryPresentationModels'
import { ThemeMode } from '../../../theme/ThemeColors'

@ComponentV2
export struct LogDetailTable {
  @Param sections: LogDetailSection[] = []
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT

  @Builder
  private rowCard(field: LogDisplayField) {
    Row({ space: 12 }) {
      Text(field.label)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .width(120)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(field.value)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .layoutWeight(1)
        .copyOption(CopyOptions.LocalDevice)
    }
    .width('100%')
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

      ForEach(section.fields, (field: LogDisplayField) => {
        this.rowCard(field)
      }, (field: LogDisplayField) => field.key)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 12 }) {
      if (this.sections.length === 0) {
        Text(LogManageDetailStrings.EMPTY)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      } else {
        ForEach(this.sections, (section: LogDetailSection) => {
          this.sectionView(section)
        }, (section: LogDetailSection) => section.id)
      }
    }
    .width('100%')
  }
}
