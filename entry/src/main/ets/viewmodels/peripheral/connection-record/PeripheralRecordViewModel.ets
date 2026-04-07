import { LogUtils } from '../../../utils/LogUtils'
import { common } from '@kit.AbilityKit'

import { PeripheralStrings } from '../../../constants/modules/PeripheralStrings'
import {
  ExportActionResult,
  PeripheralConnectionRecord,
  getPeripheralRecordActionLabel,
  getPeripheralRecordSourceLabel,
  getPeripheralTypeLabel
} from '../../../models/DataModels'
import { PeripheralConnectionRecordService } from '../../../services/peripheral/connection-record/PeripheralConnectionRecordService'
import { LogExportService } from '../../../services/log-manage/export/LogExportService'
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

@ObservedV2
export class ConnectionDetailDialogStateModel {
  @Trace visible: boolean = false
  @Trace record: PeripheralConnectionRecord | null = null
  @Trace historyItems: PeripheralConnectionHistoryItem[] = []
}

@ObservedV2
export class PeripheralRecordState {
  @Trace records: PeripheralConnectionRecord[] = []
  @Trace connectionDetailDialog: ConnectionDetailDialogStateModel = new ConnectionDetailDialogStateModel()
}

@ObservedV2
export class PeripheralRecordViewModel {
  @Trace state: PeripheralRecordState = new PeripheralRecordState()

  reloadRecords(): void {
    try {
      this.state.records = PeripheralConnectionRecordService.queryRecords()
    } catch (err) {
      LogUtils.error(TAG, `reloadRecords failed: ${JSON.stringify(err)}`)
      this.state.records = []
    }
  }

  openConnectionDetailDialog(record: PeripheralConnectionRecord): void {
    this.state.connectionDetailDialog.visible = true
    this.state.connectionDetailDialog.record = record
    this.state.connectionDetailDialog.historyItems = buildConnectionHistoryItems(this.state.records, record)
  }

  closeConnectionDetailDialog(): void {
    this.state.connectionDetailDialog.visible = false
    this.state.connectionDetailDialog.record = null
    this.state.connectionDetailDialog.historyItems = []
  }

  async exportConnectionHistory(context: common.UIAbilityContext | null): Promise<ExportActionResult> {
    if (this.state.records.length === 0) {
      return { success: false, reason: PeripheralStrings.emptyConnectionHistory } as ExportActionResult
    }
    if (!context) {
      return { success: false, reason: PeripheralStrings.exportEnvNotReady } as ExportActionResult
    }

    try {
      const csvContent = this.buildConnectionHistoryCsv(this.state.records)
      const result = await LogExportService.saveCsvContent(context, csvContent, PeripheralStrings.csvConnectionHistoryFilePrefix)
      return result.success ?
        { success: true, fileName: result.fileName } as ExportActionResult :
          { success: false, reason: PeripheralStrings.exportConnectionHistoryFailed } as ExportActionResult
    } catch (err) {
      LogUtils.error(TAG, `exportConnectionHistory failed: ${JSON.stringify(err)}`)
      return { success: false, reason: PeripheralStrings.exportConnectionHistoryFailed } as ExportActionResult
    }
  }

  private buildConnectionHistoryCsv(records: PeripheralConnectionRecord[]): string {
    const headers: string[] = PeripheralStrings.connectionHistoryCsvHeaders
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
