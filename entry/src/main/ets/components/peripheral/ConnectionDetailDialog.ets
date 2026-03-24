/**
 * 连接详情对话框组件
 */
import { AppColors, AppStyles } from '../../constants/AppConstants'
import { PeripheralConnectionRecord, PeripheralRecordAction, PeripheralType, getPeripheralRecordSourceLabel } from '../../models/DataModels'
import { ThemeMode } from '../../theme/ThemeColors'

interface ConnectionDetailDialogProps {
  selectedRecord: PeripheralConnectionRecord | null
  currentTheme: ThemeMode
  onClose: () => void
}

@Component
export struct ConnectionDetailDialog {
  @Prop selectedRecord: PeripheralConnectionRecord | null = null
  @Prop currentTheme: ThemeMode = ThemeMode.LIGHT
  onClose?: () => void

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#66000000')
      .onClick(() => {
        if (this.onClose) {
          this.onClose()
        }
      })

      Column({ space: 8 }) {
        Row() {
          Text('设备详情')
            .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          Blank()
          Button('关闭')
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
            .borderRadius(AppStyles.RADIUS_MD)
            .height(32)
            .onClick(() => {
              if (this.onClose) {
                this.onClose()
              }
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (!this.selectedRecord) {
          Column({ space: 8 }) {
            Text('当前没有可展示的连接记录。')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          }
          .width('100%')
        } else {
          this.detailContent(this.selectedRecord)
        }
      }
      .width('80%')
      .maxHeight('80%')
      .padding(20)
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
      .borderRadius(AppStyles.RADIUS_LG)
    }
  }

  @Builder
  private detailContent(record: PeripheralConnectionRecord) {
    Scroll() {
      Column({ space: 8 }) {
        this.keyInfoSection(record)
        this.historySection(record)
      }
      .width('100%')
    }
    .width('100%')
    .maxHeight('60vh')
  }

  @Builder
  private keyInfoSection(record: PeripheralConnectionRecord) {
    Column({ space: 8 }) {
      Text('关键信息')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

      Column({ space: 8 }) {
        Row({ space: 12 }) {
          this.metricField('设备标识', record.deviceId)
          this.metricField('最近时间', this.formatConnectionTime(record))
        }
        .width('100%')

        Row({ space: 12 }) {
          this.metricField('连接事件', this.getConnectionEventLabel(record.action))
          this.metricField('事件来源', getPeripheralRecordSourceLabel(record.source))
        }
        .width('100%')

        Row({ space: 12 }) {
          this.metricField('策略结论', record.policyHit)
          this.metricField('实际执行策略', record.executedPolicy || 'N/A')
        }
        .width('100%')

        Row({ space: 12 }) {
          this.metricField('命中类型', record.policyHit)
          this.metricField('结果状态', record.result === 'success' ? '成功' : '失败')
        }
        .width('100%')
      }
      .width('100%')
      .padding(12)
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
      .borderRadius(AppStyles.RADIUS_LG)
    }
    .width('100%')
  }

  @Builder
  private historySection(record: PeripheralConnectionRecord) {
    Column({ space: 8 }) {
      Row() {
        Text('历史连接记录')
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        Blank()
        Text('0 条')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .width('100%')

      Text('暂无历史连接记录')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
    .borderRadius(AppStyles.RADIUS_LG)
  }

  @Builder
  private metricField(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      Text(value)
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('50%')
    .padding(8)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_MD)
  }

  private formatConnectionTime(record: PeripheralConnectionRecord): string {
    const date = new Date(record.timestamp)
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
  }

  private getConnectionEventLabel(action: PeripheralRecordAction): string {
    const actionMap: Record<string, string> = {
      'connect': '连接',
      'disconnect': '断开',
      'blocked': '拦截'
    }
    return actionMap[action] || action
  }
}
