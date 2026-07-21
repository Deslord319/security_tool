import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { SecurityEventResult } from '../../main/ets/models/CommonModels'
import {
  PeripheralConnectionRecord,
  PeripheralType
} from '../../main/ets/models/PeripheralModels'
import {
  getPeripheralRecordActionLabel,
  getPeripheralRecordSourceLabel,
  getPeripheralTypeLabel
} from '../../main/ets/presentation/peripheral/PeripheralRecordPresentationMapper'
import {
  PeripheralExportStrings,
  PeripheralReasonCodes
} from '../../main/ets/constants/modules/PeripheralStrings'
import {
  CsvFileExportService
} from '../../main/ets/services/common/export/CsvFileExportService'
import { createCsvFileExportResult } from '../common/CsvExportResultFactory'
import { PeripheralConnectionRecordService } from '../../main/ets/services/peripheral/connection-record/PeripheralConnectionRecordService'
import {
  formatPeripheralTimestamp,
  getPeripheralConnectionPolicyLabel,
  getPeripheralConnectionResultLabel
} from '../../main/ets/presentation/peripheral/PeripheralRecordPresentationMapper'
import { PeripheralRecordViewModel } from '../../main/ets/viewmodels/peripheral/connection-record/PeripheralRecordViewModel'

function createConnectionRecord(
  id: string,
  timestamp: number,
  deviceId: string = 'VID:1234 PID:5678',
  deviceName: string = 'USB Device'
): PeripheralConnectionRecord {
  return {
    id,
    timestamp,
    deviceId,
    deviceName,
    deviceType: PeripheralType.USB_STORAGE,
    source: 'runtime_event',
    action: 'connect',
    result: SecurityEventResult.SUCCESS,
    policyHit: 'allow',
    summary: 'connected',
    matchedPolicyKind: 'default_allow'
  }
}

export default function peripheralRecordViewModelTest() {
  describe('PeripheralRecordViewModel', () => {
    let viewModel: PeripheralRecordViewModel
    let mockKit: MockKit
    let queryRecordsMock: Object

    beforeEach(async () => {
      viewModel = new PeripheralRecordViewModel()
      mockKit = new MockKit()
      queryRecordsMock = mockKit.mockFunc(PeripheralConnectionRecordService, PeripheralConnectionRecordService.queryRecords)
      when(queryRecordsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve([]))
    })

    afterEach(async () => {
      mockKit.clearAll()
    })

    it('U-RVM-001 should reload records from record service', 0, async (done: Function) => {
      const base = Date.now()
      let records = [
        createConnectionRecord('peripheral_runtime_record-2', base + 1000, 'VID:1111 PID:2222', 'USB Camera'),
        createConnectionRecord('peripheral_runtime_record-1', base)
      ]
      when(queryRecordsMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(records))

      await viewModel.reloadRecords()

      expect(viewModel.state.records.length).assertEqual(2)
      expect(viewModel.state.records[0].id).assertEqual('peripheral_runtime_record-2')
      expect(viewModel.state.records[1].id).assertEqual('peripheral_runtime_record-1')
      done()
    })

    it('U-RVM-002 should fall back to empty list when query pipeline returns no records', 0, async (done: Function) => {
      viewModel.state.records = [createConnectionRecord('stale-record', 1700000000000)]

      await viewModel.reloadRecords()

      expect(viewModel.state.records.length).assertEqual(0)
      done()
    })

    it('U-RVM-003 should open detail dialog with selected record and same-device history only', 0, () => {
      const selectedRecord = createConnectionRecord('record-1', 1700000000000, 'VID:1234 PID:5678', 'USB Device')
      const sameDeviceLater = createConnectionRecord('record-2', 1700000003000, 'VID: 1234   PID:5678', 'USB Device')
      const differentDevice = createConnectionRecord('record-3', 1700000005000, 'VID:9999 PID:8888', 'Other Device')
      viewModel.state.records = [selectedRecord, sameDeviceLater, differentDevice]

      viewModel.openConnectionDetailDialog(selectedRecord)

      expect(viewModel.state.connectionDetailDialog.visible).assertTrue()
      expect(viewModel.state.connectionDetailDialog.record?.id ?? '').assertEqual('record-1')
      expect(viewModel.state.connectionDetailDialog.historyItems.length).assertEqual(2)
      expect(viewModel.state.connectionDetailDialog.historyItems[0].time).assertEqual(formatPeripheralTimestamp(1700000000000))
      expect(viewModel.state.connectionDetailDialog.historyItems[1].time).assertEqual(formatPeripheralTimestamp(1700000003000))
    })

    it('U-RVM-004 should close detail dialog and clear selected state', 0, () => {
      const record = createConnectionRecord('record-1', 1700000000000)
      viewModel.state.records = [record]
      viewModel.openConnectionDetailDialog(record)

      viewModel.closeConnectionDetailDialog()

      expect(viewModel.state.connectionDetailDialog.visible).assertFalse()
      expect(viewModel.state.connectionDetailDialog.record).assertNull()
      expect(viewModel.state.connectionDetailDialog.historyItems.length).assertEqual(0)
    })

    it('U-RVM-005 should export connection history and return generated file name', 0, async (done: Function) => {
      viewModel.state.records = [createConnectionRecord('record-1', 1700000000000)]
      let exportMock = mockKit.mockFunc(CsvFileExportService, CsvFileExportService.saveText)
      when(exportMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(createCsvFileExportResult(
        true,
        'ok',
        'peripheral_connection_history_20250115_083000.csv',
        '/mock/peripheral_connection_history_20250115_083000.csv'
      )))

      const result = await viewModel.exportConnectionHistory({} as common.UIAbilityContext)

      expect(result.success).assertTrue()
      expect(result.fileName ?? '').assertEqual('peripheral_connection_history_20250115_083000.csv')
      done()
    })

    it('U-RVM-006 should reject export when no connection history exists', 0, async (done: Function) => {
      viewModel.state.records = []

      const result = await viewModel.exportConnectionHistory({} as common.UIAbilityContext)

      expect(result.success).assertFalse()
      expect(result.reason ?? '').assertEqual(PeripheralReasonCodes.EMPTY_CONNECTION_HISTORY)
      done()
    })

    it('U-RVM-007 should reject export when context is missing', 0, async (done: Function) => {
      viewModel.state.records = [createConnectionRecord('record-1', 1700000000000)]

      const result = await viewModel.exportConnectionHistory(null)

      expect(result.success).assertFalse()
      expect(result.reason ?? '').assertEqual(PeripheralReasonCodes.EXPORT_ENV_NOT_READY)
      done()
    })

    it('U-RVM-008 should map export service failure and thrown errors to export failure reason', 0, async (done: Function) => {
      viewModel.state.records = [createConnectionRecord('record-1', 1700000000000)]
      let exportMock = mockKit.mockFunc(CsvFileExportService, CsvFileExportService.saveText)
      when(exportMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(createCsvFileExportResult(false, 'user_canceled')))

      const failedResult = await viewModel.exportConnectionHistory({} as common.UIAbilityContext)
      expect(failedResult.success).assertFalse()
      expect(failedResult.reason ?? '').assertEqual(PeripheralReasonCodes.EXPORT_CONNECTION_HISTORY_FAILED)

      when(exportMock)(ArgumentMatchers.any).afterAction(() => {
        throw new Error('picker failed')
      })
      const thrownResult = await viewModel.exportConnectionHistory({} as common.UIAbilityContext)
      expect(thrownResult.success).assertFalse()
      expect(thrownResult.reason ?? '').assertEqual(PeripheralReasonCodes.EXPORT_CONNECTION_HISTORY_FAILED)
      done()
    })

    it('U-RVM-009 should build csv with BOM, expected header order and mapped field values', 0, async (done: Function) => {
      const record = createConnectionRecord('record-1', 1700000000000, 'VID:1234 PID:5678', 'USB Device')
      viewModel.state.records = [record]
      let capturedCsv = ''
      let exportMock = mockKit.mockFunc(CsvFileExportService, CsvFileExportService.saveText)
      when(exportMock)(ArgumentMatchers.any).afterAction((
        _context: common.UIAbilityContext,
        content: string
      ) => {
        capturedCsv = content
        return Promise.resolve(createCsvFileExportResult(
          true,
          'ok',
          'peripheral_connection_history_mock.csv',
          '/mock/peripheral_connection_history_mock.csv'
        ))
      })

      const result = await viewModel.exportConnectionHistory({} as common.UIAbilityContext)

      expect(result.success).assertTrue()
      expect(capturedCsv.charCodeAt(0)).assertEqual(0xFEFF)
      const lines = capturedCsv.substring(1).split('\n')
      expect(lines[0]).assertEqual(PeripheralExportStrings.CONNECTION_HISTORY_CSV_HEADERS.join(','))
      const columns = lines[1].split(',')
      expect(columns.length).assertEqual(8)
      expect(columns[0]).assertEqual(formatPeripheralTimestamp(record.timestamp))
      expect(columns[1]).assertEqual(record.deviceName)
      expect(columns[2]).assertEqual(getPeripheralTypeLabel(record.deviceType))
      expect(columns[3]).assertEqual(record.deviceId)
      expect(columns[4]).assertEqual(getPeripheralRecordActionLabel(record.action))
      expect(columns[5]).assertEqual(getPeripheralConnectionPolicyLabel(record))
      expect(columns[6]).assertEqual(getPeripheralConnectionResultLabel(record))
      expect(columns[7]).assertEqual(getPeripheralRecordSourceLabel(record.source))
      done()
    })

    it('U-RVM-010 should escape csv values that contain commas quotes or newlines', 0, async (done: Function) => {
      const record = createConnectionRecord('record-1', 1700000000000, 'VID:1234 PID:5678', 'USB "Special", Device\nLine2')
      let capturedCsv = ''
      viewModel.state.records = [record]
      let exportMock = mockKit.mockFunc(CsvFileExportService, CsvFileExportService.saveText)
      when(exportMock)(ArgumentMatchers.any).afterAction((
        _context: common.UIAbilityContext,
        content: string
      ) => {
        capturedCsv = content
        return Promise.resolve(createCsvFileExportResult(
          true,
          'ok',
          'peripheral_connection_history_mock.csv',
          '/mock/peripheral_connection_history_mock.csv'
        ))
      })

      const result = await viewModel.exportConnectionHistory({} as common.UIAbilityContext)

      expect(result.success).assertTrue()
      expect(capturedCsv.indexOf('"USB ""Special"", Device\nLine2"') > -1).assertTrue()
      done()
    })
  })
}
