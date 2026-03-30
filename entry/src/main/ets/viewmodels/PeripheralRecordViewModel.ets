import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { PeripheralReasons } from '../constants/modules/PeripheralReasons'
import {
  ExportActionResult,
  PeripheralConnectionRecord,
  PeripheralRecordAction,
  PeripheralRecordSource,
  PeripheralType
} from '../models/DataModels'
import { LogStorageService } from '../services/LogStorageService'
import { PeripheralConnectionRecordService } from '../services/PeripheralConnectionRecordService'
import {
  buildConnectionHistoryItems,
  formatPeripheralTimestamp,
  getPeripheralConnectionPolicyLabel,
  getPeripheralConnectionResultLabel,
  PeripheralConnectionHistoryItem
} from './PeripheralRecordPresentationMapper'

const TAG = 'PeripheralRecordViewModel'
const DOMAIN = 0x0013

export interface ConnectionDetailDialogState {
  visible: boolean
  record: PeripheralConnectionRecord | null
  historyItems: PeripheralConnectionHistoryItem[]
}

@Observed
export class PeripheralRecordViewModel {
  records: PeripheralConnectionRecord[] = []
  connectionDetailDialog: ConnectionDetailDialogState = {
    visible: false,
    record: null,
    historyItems: []
  }

  reloadRecords(): void {
    try {
      this.records = PeripheralConnectionRecordService.queryRecords()
    } catch (err) {
      hilog.error(DOMAIN, TAG, `reloadRecords failed: ${JSON.stringify(err)}`)
      this.records = []
    }
  }

  openConnectionDetailDialog(record: PeripheralConnectionRecord): void {
    this.connectionDetailDialog = {
      visible: true,
      record: record,
      historyItems: buildConnectionHistoryItems(this.records, record)
    }
  }

  closeConnectionDetailDialog(): void {
    this.connectionDetailDialog = {
      visible: false,
      record: null,
      historyItems: []
    }
  }

  async exportConnectionHistory(context: common.UIAbilityContext | null): Promise<ExportActionResult> {
    if (this.records.length === 0) {
      return { success: false, reason: PeripheralReasons.EMPTY_CONNECTION_HISTORY } as ExportActionResult
    }
    if (!context) {
      return { success: false, reason: PeripheralReasons.EXPORT_ENV_NOT_READY } as ExportActionResult
    }

    try {
      await LogStorageService.init(context)
      const csvContent = this.buildConnectionHistoryCsv(this.records)
      const result = await LogStorageService.exportToCsvFile({
        csvContent,
        fileNamePrefix: 'peripheral_connection_history'
      })
      return result.success ?
        { success: true, fileName: result.fileName } as ExportActionResult :
        { success: false, reason: PeripheralReasons.EXPORT_CONNECTION_HISTORY_FAILED } as ExportActionResult
    } catch (err) {
      hilog.error(DOMAIN, TAG, `exportConnectionHistory failed: ${JSON.stringify(err)}`)
      return { success: false, reason: PeripheralReasons.EXPORT_CONNECTION_HISTORY_FAILED } as ExportActionResult
    }
  }

  private buildConnectionHistoryCsv(records: PeripheralConnectionRecord[]): string {
    const headers: string[] = [
      '时间',
      '设备名称',
      '设备类型',
      '设备标识',
      '连接事件',
      '策略命中',
      '结果状态',
      '事件来源'
    ]
    const rows = records.map((record: PeripheralConnectionRecord) => {
      return [
        formatPeripheralTimestamp(record.timestamp),
        record.deviceName,
        this.getDeviceTypeLabel(record.deviceType),
        record.deviceId,
        this.getActionLabel(record.action),
        getPeripheralConnectionPolicyLabel(record),
        getPeripheralConnectionResultLabel(record),
        this.getSourceLabel(record.source)
      ].map((value: string) => this.escapeCsvValue(value)).join(',')
    })
    return `\uFEFF${headers.map((value: string) => this.escapeCsvValue(value)).join(',')}\n${rows.join('\n')}`
  }

  private getDeviceTypeLabel(deviceType: PeripheralType): string {
    switch (deviceType) {
      case PeripheralType.USB_STORAGE:
        return 'USB 存储设备'
      case PeripheralType.USB_CAMERA:
        return 'USB 摄像头'
      case PeripheralType.USB_PRINTER:
        return 'USB 打印机'
      case PeripheralType.USB_HID:
        return 'USB 人机输入设备'
      case PeripheralType.USB_OTHER:
        return 'USB 其他设备'
      case PeripheralType.BLUETOOTH:
        return '蓝牙设备'
      default:
        return '未知设备'
    }
  }

  private getActionLabel(action: PeripheralRecordAction): string {
    switch (action) {
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

  private getSourceLabel(source: PeripheralRecordSource): string {
    switch (source) {
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

  private escapeCsvValue(value: string): string {
    const normalized = value.replace(/"/g, '""')
    if (/[",\r\n]/.test(normalized)) {
      return `"${normalized}"`
    }
    return normalized
  }
}
