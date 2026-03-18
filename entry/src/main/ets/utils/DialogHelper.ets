import { AppColors, AppStyles } from '../constants/AppConstants'
import { LogExportResult, formatLogTimestamp } from '../models/DataModels'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

export interface DetailDialogField {
  key: string
  label: string
  value: string
}

@Component
struct DetailTableRow {
  label: string = ''
  value: string = '-'
  labelWidth: number = 112
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @State expanded: boolean = false

  private shouldCollapse(): boolean {
    return this.value.length > 60 || this.value.indexOf('\n') >= 0
  }

  build() {
    Row({ space: 12 }) {
      Text(this.label)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .width(this.labelWidth)

      Column({ space: 6 }) {
        Text(this.value)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .maxLines(this.shouldCollapse() && !this.expanded ? 2 : 12)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.shouldCollapse()) {
          Text(this.expanded ? '收起' : '展开')
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.BRAND_PRIMARY)
            .onClick(() => {
              this.expanded = !this.expanded
            })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 10, bottom: 10 })
  }
}

@CustomDialog
export struct DetailTableDialog {
  controller: CustomDialogController
  title: string = ''
  fields: DetailDialogField[] = []
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  private readonly labelWidth: number = 112

  build() {
    Column({ space: 0 }) {
      Row() {
        Text(this.title)
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        Blank()
        Button('关闭')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_COMPONENT)
          .borderRadius(AppStyles.RADIUS_SM)
          .height(30)
          .onClick(() => {
            this.controller.close()
          })
      }
      .width('100%')

      Divider()
        .color(AppColors.getColors(this.currentTheme).BORDER)
        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
        .margin({ top: 10, bottom: 10 })

      Scroll() {
        Column({ space: 0 }) {
          ForEach(this.fields, (field: DetailDialogField, index: number) => {
            DetailTableRow({
              label: field.label,
              value: field.value,
              labelWidth: this.labelWidth
            })
            if (index < this.fields.length - 1) {
              Divider()
                .color(AppColors.getColors(this.currentTheme).BORDER)
                .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
            }
          }, (field: DetailDialogField) => field.key)
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: 420 })
      .scrollBar(BarState.Auto)
    }
    .width(580)
    .padding(18)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
  }
}

export class DialogHelper {
  static displayField(value: string | number | undefined): string {
    if (value === undefined || value === null) {
      return '-'
    }
    let text = value.toString().trim()
    if (text.length === 0) {
      return '-'
    }
    return text
  }

  static toDetailField(key: string, label: string, value: string | number | undefined): DetailDialogField {
    return {
      key: key,
      label: label,
      value: DialogHelper.displayField(value)
    } as DetailDialogField
  }

  static formatBytes(sizeBytes: number | undefined): string {
    if (sizeBytes === undefined || sizeBytes < 0) {
      return '未知'
    }
    if (sizeBytes < 1024) {
      return `${sizeBytes} B`
    }
    if (sizeBytes < 1024 * 1024) {
      return `${(sizeBytes / 1024).toFixed(2)} KB`
    }
    return `${(sizeBytes / (1024 * 1024)).toFixed(2)} MB`
  }

  static buildExportSuccessFields(result: LogExportResult): DetailDialogField[] {
    let fields: DetailDialogField[] = [
      DialogHelper.toDetailField('summary', '导出结果', `导出完成（${result.count} 条）`),
      DialogHelper.toDetailField('format', '导出格式', result.format.toUpperCase()),
      DialogHelper.toDetailField('count', '导出条数', result.count.toString()),
      DialogHelper.toDetailField('file_name', '文件名', result.fileName),
      DialogHelper.toDetailField('directory', '保存位置', result.directory),
      DialogHelper.toDetailField('full_path', '完整路径', result.fullPath),
      DialogHelper.toDetailField('size', '文件大小', DialogHelper.formatBytes(result.sizeBytes)),
      DialogHelper.toDetailField('exported_at', '导出时间', formatLogTimestamp(result.timestamp))
    ]
    if (result.errorMessage && result.errorMessage.trim().length > 0) {
      fields.push(DialogHelper.toDetailField('remark', '备注', result.errorMessage))
    }
    return fields
  }
}
