import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  getPeripheralRecordActionLabel,
  getPeripheralRecordSourceLabel,
  getPeripheralTypeLabel,
  LogExportFormat,
  PeripheralConnectionRecord
} from '../models/DataModels'
import { LogContentExportOptions, LogStorageService } from '../services/LogStorageService'
import { PeripheralConnectionRecordService } from '../services/PeripheralConnectionRecordService'
import {
  buildConnectionHistoryItems,
  formatPeripheralTimestamp,
  PeripheralConnectionHistoryItem
} from '../utils/PeripheralRecordViewDataUtils'
import {
  getPeripheralConnectionPolicyLabel,
  getPeripheralConnectionResultLabel
} from '../utils/PeripheralRecordDisplayUtils'
import {
  REASON_EMPTY_CONNECTION_HISTORY,
  REASON_EXPORT_CONNECTION_HISTORY_FAILED,
  REASON_EXPORT_ENV_NOT_READY
} from './PeripheralViewModelReasons'

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

  async exportConnectionHistory(context: common.UIAbilityContext | null): Promise<string | null> {
    if (this.records.length === 0) {
      return REASON_EMPTY_CONNECTION_HISTORY
    }
    if (!context) {
      return REASON_EXPORT_ENV_NOT_READY
    }

    try {
      await LogStorageService.init(context)
      const exportOptions: LogContentExportOptions = {
        fileNamePrefix: 'peripheral_connection_history',
        count: this.records.length,
        emptyErrorMessage: '无可导出的设备连接记录'
      }
      const result = await LogStorageService.exportContentToFile(
        this.buildConnectionHistoryCsv(this.records),
        LogExportFormat.CSV,
        'manual',
        exportOptions
      )
      return result.success ? null : REASON_EXPORT_CONNECTION_HISTORY_FAILED
    } catch (err) {
      hilog.error(DOMAIN, TAG, `exportConnectionHistory failed: ${JSON.stringify(err)}`)
      return REASON_EXPORT_CONNECTION_HISTORY_FAILED
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
        getPeripheralTypeLabel(record.deviceType),
        record.deviceId,
        getPeripheralRecordActionLabel(record.action),
        getPeripheralConnectionPolicyLabel(record),
        getPeripheralConnectionResultLabel(record),
        getPeripheralRecordSourceLabel(record.source)
      ].map((value: string) => this.escapeCsvValue(value)).join(',')
    })
    return `\uFEFF${headers.map((value: string) => this.escapeCsvValue(value)).join(',')}\n${rows.join('\n')}`
  }

  private escapeCsvValue(value: string): string {
    const normalized = value.replace(/"/g, '""')
    if (/[",\r\n]/.test(normalized)) {
      return `"${normalized}"`
    }
    return normalized
  }
}
