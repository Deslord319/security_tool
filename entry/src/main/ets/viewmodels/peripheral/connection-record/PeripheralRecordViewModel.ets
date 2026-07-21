import { LogUtils } from '../../../utils/LogUtils'
import { common } from '@kit.AbilityKit'

import { PeripheralExportStrings, PeripheralReasonCodes } from '../../../constants/modules/PeripheralStrings'
import { ExportActionResult } from '../../../models/CommonModels'
import { PeripheralConnectionRecord } from '../../../models/PeripheralModels'
import { PeripheralConnectionRecordService } from '../../../services/peripheral/connection-record/PeripheralConnectionRecordService'
import {
  buildConnectionHistoryItems,
  formatPeripheralTimestamp,
  getPeripheralConnectionActionLabel,
  getPeripheralConnectionPolicyLabel,
  getPeripheralConnectionResultLabel,
  getPeripheralRecordSourceLabel,
  getPeripheralTypeLabel,
  PeripheralConnectionHistoryItem
} from '../../../presentation/peripheral/PeripheralRecordPresentationMapper'
import { CsvFileExportService } from '../../../services/common/export/CsvFileExportService'

const TAG = 'PeripheralRecordViewModel'

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

  async reloadRecords(): Promise<void> {
    try {
      this.state.records = await PeripheralConnectionRecordService.queryRecords()
      if (this.state.connectionDetailDialog.visible && this.state.connectionDetailDialog.record) {
        this.state.connectionDetailDialog.historyItems = buildConnectionHistoryItems(
          this.state.records,
          this.state.connectionDetailDialog.record
        )
      }
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
      return { success: false, reason: PeripheralReasonCodes.EMPTY_CONNECTION_HISTORY } as ExportActionResult
    }
    if (!context) {
      return { success: false, reason: PeripheralReasonCodes.EXPORT_ENV_NOT_READY } as ExportActionResult
    }

    try {
      const csvContent = this.buildConnectionHistoryCsv(this.state.records)
      const result = await CsvFileExportService.saveText(context, csvContent, PeripheralExportStrings.CONNECTION_HISTORY_FILE_PREFIX, 'csv')
      return result.success ?
        { success: true, fileName: result.fileName } as ExportActionResult :
          { success: false, reason: PeripheralReasonCodes.EXPORT_CONNECTION_HISTORY_FAILED } as ExportActionResult
    } catch (err) {
      LogUtils.error(TAG, `exportConnectionHistory failed: ${JSON.stringify(err)}`)
      return { success: false, reason: PeripheralReasonCodes.EXPORT_CONNECTION_HISTORY_FAILED } as ExportActionResult
    }
  }

  private buildConnectionHistoryCsv(records: PeripheralConnectionRecord[]): string {
    const headers: string[] = PeripheralExportStrings.CONNECTION_HISTORY_CSV_HEADERS
    const rows: string[][] = records.map((record: PeripheralConnectionRecord) => {
      return [
        formatPeripheralTimestamp(record.timestamp),
        record.deviceName,
        getPeripheralTypeLabel(record.deviceType),
        record.deviceId,
        getPeripheralConnectionActionLabel(record),
        getPeripheralConnectionPolicyLabel(record),
        getPeripheralConnectionResultLabel(record),
        getPeripheralRecordSourceLabel(record.source)
      ]
    })
    return CsvFileExportService.buildCsvContent(headers, rows)
  }
}
