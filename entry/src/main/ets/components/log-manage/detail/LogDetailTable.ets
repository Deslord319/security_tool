import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { LogManageDetailStrings } from '../../../constants/modules/LogManageStrings'
import { LogDetailTableRow } from '../../../models/LogModels'
import { ThemeMode } from '../../../theme/ThemeColors'

@ComponentV2
export struct LogDetailTable {
  @Param rows: LogDetailTableRow[] = []
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT

  private getVisibleRows(): LogDetailTableRow[] {
    let visibleRows: LogDetailTableRow[] = []
    for (let row of this.rows) {
      if (!row) {
        continue
      }
      let key = row.key.trim()
      let label = row.label.trim()
      let value = row.value.trim()
      if (key.length === 0 || label.length === 0 || value.length === 0) {
        continue
      }
      visibleRows.push({
        key,
        label,
        value
      })
    }
    return visibleRows
  }

  @Builder
  private rowCard(row: LogDetailTableRow) {
    Row({ space: 12 }) {
      Text(row.label)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .width(120)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(row.value)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .layoutWeight(1)
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_MD)
  }

  build() {
    Column({ space: 8 }) {
      if (this.getVisibleRows().length === 0) {
        Text(LogManageDetailStrings.EMPTY)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      } else {
        ForEach(this.getVisibleRows(), (row: LogDetailTableRow) => {
          this.rowCard(row)
        }, (row: LogDetailTableRow) => row.key)
      }
    }
    .width('100%')
  }
}
