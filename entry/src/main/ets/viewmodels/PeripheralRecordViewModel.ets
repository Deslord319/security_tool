import { LogUtils } from '../utils/LogUtils'
﻿import { common } from '@kit.AbilityKit'

import { PeripheralStrings } from '../constants/modules/PeripheralStrings'
import {
  ExportActionResult,
  PeripheralConnectionRecord,
  getPeripheralRecordActionLabel,
  getPeripheralRecordSourceLabel,
  getPeripheralTypeLabel
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
      LogUtils.error(TAG, `reloadRecords failed: ${JSON.stringify(err)}`)
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
      return { success: false, reason: PeripheralStrings.EMPTY_CONNECTION_HISTORY } as ExportActionResult
    }
    if (!context) {
      return { success: false, reason: PeripheralStrings.EXPORT_ENV_NOT_READY } as ExportActionResult
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
        { success: false, reason: PeripheralStrings.EXPORT_CONNECTION_HISTORY_FAILED } as ExportActionResult
    } catch (err) {
      LogUtils.error(TAG, `exportConnectionHistory failed: ${JSON.stringify(err)}`)
      return { success: false, reason: PeripheralStrings.EXPORT_CONNECTION_HISTORY_FAILED } as ExportActionResult
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
