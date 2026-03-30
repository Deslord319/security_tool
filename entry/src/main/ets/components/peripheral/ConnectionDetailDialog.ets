import { DetailDialogShell } from '../DetailDialogShell'
import { AppColors, AppStyles } from '../../constants/AppConstants'
import { PeripheralConnectionRecord } from '../../models/DataModels'
import { ThemeMode } from '../../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../../theme/ThemeManager'
import {
  getPeripheralConnectionPolicyLabel,
  getPeripheralConnectionResultLabel,
  getPeripheralMatchedPolicyKindLabel
} from '../../viewmodels/PeripheralRecordPresentationMapper'

const DEVICE_DETAIL_TITLE = '设备详情'
const DEVICE_DETAIL_EMPTY = '当前没有可展示的连接记录。'
const DEVICE_DETAIL_KEY_INFO = '关键信息'
const DEVICE_DETAIL_HISTORY_TITLE = '历史连接记录'
const DEVICE_DETAIL_HISTORY_EMPTY = '暂无历史连接记录'
const DEVICE_DETAIL_HISTORY_SUFFIX = '条'
const DEVICE_DETAIL_DEVICE_ID = '设备标识'
const DEVICE_DETAIL_RECENT_TIME = '最近时间'
const DEVICE_DETAIL_CONNECTION_EVENT = '连接事件'
const DEVICE_DETAIL_EVENT_SOURCE = '事件来源'
const DEVICE_DETAIL_POLICY_RESULT = '策略结论'
const DEVICE_DETAIL_EFFECTIVE_POLICY = '执行策略'
const DEVICE_DETAIL_MATCH_TYPE = '命中类型'
const DEVICE_DETAIL_RESULT_STATUS = '结果状态'

export interface ConnectionHistoryItem {
  time: string
  policy: string
  result: string
}

@Component
export struct ConnectionDetailDialog {
  selectedRecord: PeripheralConnectionRecord | null = null
  historyItems: ConnectionHistoryItem[] = []
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onClose: () => void = () => {}

  @Builder
  private shellContent() {
    if (this.selectedRecord) {
      Column({ space: 12 }) {
        this.metricCard(this.selectedRecord)
        this.historyCard()
      }
      .width('100%')
    } else {
      Text(DEVICE_DETAIL_EMPTY)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
    }
  }

  @Builder
  private metricCard(record: PeripheralConnectionRecord) {
    Column({ space: 10 }) {
      Text(DEVICE_DETAIL_KEY_INFO)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)

      Row({ space: 10 }) {
        this.metricField(DEVICE_DETAIL_DEVICE_ID, record.deviceId)
        this.metricField(DEVICE_DETAIL_RECENT_TIME, this.formatConnectionTime(record))
      }
      .width('100%')

      Row({ space: 10 }) {
        this.metricField(DEVICE_DETAIL_CONNECTION_EVENT, this.getActionLabel(record))
        this.metricField(DEVICE_DETAIL_EVENT_SOURCE, this.getSourceLabel(record))
      }
      .width('100%')

      Row({ space: 10 }) {
        this.metricField(DEVICE_DETAIL_POLICY_RESULT, getPeripheralConnectionPolicyLabel(record))
        this.metricField(DEVICE_DETAIL_EFFECTIVE_POLICY, record.effectivePolicyLabel ?? '--')
      }
      .width('100%')

      Row({ space: 10 }) {
        this.metricField(DEVICE_DETAIL_MATCH_TYPE, getPeripheralMatchedPolicyKindLabel(record.matchedPolicyKind))
        this.metricField(DEVICE_DETAIL_RESULT_STATUS, getPeripheralConnectionResultLabel(record))
      }
      .width('100%')
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
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private historyCard() {
    Column({ space: AppStyles.PADDING_SM }) {
      Row() {
        Text(DEVICE_DETAIL_HISTORY_TITLE)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(`${this.historyItems.length} ${DEVICE_DETAIL_HISTORY_SUFFIX}`)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .width('100%')

      if (this.historyItems.length === 0) {
        Text(DEVICE_DETAIL_HISTORY_EMPTY)
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      } else {
        Column({ space: AppStyles.PADDING_SM }) {
          ForEach(this.historyItems, (item: ConnectionHistoryItem, index: number) => {
            Row({ space: AppStyles.PADDING_SM }) {
              Text(`${index + 1}`)
                .fontSize(AppStyles.FONT_SIZE_CAPTION)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.BRAND_PRIMARY)
                .width(24)
                .textAlign(TextAlign.Center)
              Column({ space: 4 }) {
                Text(item.time)
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontWeight(FontWeight.Medium)
                Text(`${item.policy} / ${item.result}`)
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(10)
            .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
            .borderRadius(AppStyles.RADIUS_MD)
          })
        }
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
    .borderRadius(AppStyles.RADIUS_LG)
  }

  private getActionLabel(record: PeripheralConnectionRecord): string {
    switch (record.action) {
      case 'connect':
        return '连接'
      case 'disconnect':
        return '断开'
      case 'intercept':
        return '拦截'
      default:
        return '未知动作'
    }
  }

  private getSourceLabel(record: PeripheralConnectionRecord): string {
    switch (record.source) {
      case 'runtime_event':
        return '运行时事件'
      case 'audit_event':
        return '审计事件'
      case 'policy_snapshot':
        return '策略快照'
      default:
        return '未知来源'
    }
  }

  private formatConnectionTime(record: PeripheralConnectionRecord): string {
    const date = new Date(record.timestamp)
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
  }

  build() {
    DetailDialogShell({
      title: DEVICE_DETAIL_TITLE,
      dialogWidth: 760,
      maxBodyHeight: 460,
      onClose: this.onClose,
      content: this.shellContent
    })
  }
}
