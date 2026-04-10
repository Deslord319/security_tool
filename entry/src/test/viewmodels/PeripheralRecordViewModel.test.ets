import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { MockKit, when } from '@ohos/hamock'
import {
  getPeripheralRecordActionLabel,
  getPeripheralRecordSourceLabel,
  getPeripheralTypeLabel,
  LogEventResult,
  PeripheralConnectionRecord,
  PeripheralTraceRecord,
  PeripheralType
} from '../../main/ets/models/DataModels'
import {
  PeripheralExportStrings,
  PeripheralReasonCodes
} from '../../main/ets/constants/modules/PeripheralStrings'
import { PeripheralTraceRepository } from '../../main/ets/services/peripheral/connection-record/PeripheralTraceRepository'
import {
  CsvFileExportResult,
  CsvFileExportService
} from '../../main/ets/services/common/export/CsvFileExportService'
import {
  formatPeripheralTimestamp,
  getPeripheralConnectionPolicyLabel,
  getPeripheralConnectionResultLabel
} from '../../main/ets/viewmodels/peripheral/connection-record/PeripheralRecordPresentationMapper'
import { PeripheralRecordViewModel } from '../../main/ets/viewmodels/peripheral/connection-record/PeripheralRecordViewModel'

const DEFAULT_RETENTION_DAYS = 180
const DEFAULT_MAX_ENTRIES = 200000

function createExportResult(
  success: boolean,
  code: 'ok' | 'empty' | 'user_canceled' | 'io_failed' | 'context_missing',
  fileName?: string,
  fullPath?: string
): CsvFileExportResult {
  let result: CsvFileExportResult = {
    success,
    code,
    fileName,
    fullPath
  }
  return result
}

function createTraceRecord(
  recordId: string,
  occurAt: number,
  deviceId: string = 'VID:1234 PID:5678',
  deviceName: string = 'USB Device'
): PeripheralTraceRecord {
  return {
    recordId,
    occurAt,
    collectAt: occurAt + 1,
    deviceName,
    deviceType: PeripheralType.USB_STORAGE,
    deviceId,
    action: 'connect',
    decision: 'allow',
    result: LogEventResult.SUCCESS,
    source: 'runtime_event',
    summary: 'connected',
    matchedPolicyKind: 'default_allow'
  }
}

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
    result: LogEventResult.SUCCESS,
    policyHit: 'allow',
    summary: 'connected',
    matchedPolicyKind: 'default_allow'
  }
}

async function resetTraceRepository(): Promise<void> {
  await PeripheralTraceRepository.configure(DEFAULT_RETENTION_DAYS, DEFAULT_MAX_ENTRIES)
  await PeripheralTraceRepository.clearAll()
}

async function seedTraceRecords(records: PeripheralTraceRecord[]): Promise<void> {
  await resetTraceRepository()
  if (records.length <= 0) {
    return
  }
  const sorted = records.slice().sort((left: PeripheralTraceRecord, right: PeripheralTraceRecord) => right.occurAt - left.occurAt)
  await PeripheralTraceRepository.appendBatch(sorted)
}

export default function peripheralRecordViewModelTest() {
  describe('PeripheralRecordViewModel', () => {
    let viewModel: PeripheralRecordViewModel
    let mockKit: MockKit

    beforeEach(async () => {
      viewModel = new PeripheralRecordViewModel()
      mockKit = new MockKit()
      await resetTraceRepository()
    })

    afterEach(async () => {
      await resetTraceRepository()
      mockKit.clearAll()
    })

    it('U-RVM-001 should reload records from record service', 0, async (done: Function) => {
      const base = Date.now()
      await seedTraceRecords([
        createTraceRecord('record-1', base),
        createTraceRecord('record-2', base + 1000, 'VID:1111 PID:2222', 'USB Camera')
      ])

      await viewModel.reloadRecords()

      expect(viewModel.state.records.length).assertEqual(2)
      expect(viewModel.state.records[0].id).assertEqual('peripheral_runtime_record-2')
      expect(viewModel.state.records[1].id).assertEqual('peripheral_runtime_record-1')
      done()
    })

    it('U-RVM-002 should fall back to empty list when query pipeline returns no records', 0, async (done: Function) => {
      await resetTraceRepository()
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
      when(exportMock)().afterReturn(Promise.resolve(createExportResult(
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
      when(exportMock)().afterReturn(Promise.resolve(createExportResult(false, 'user_canceled')))

      const failedResult = await viewModel.exportConnectionHistory({} as common.UIAbilityContext)
      expect(failedResult.success).assertFalse()
      expect(failedResult.reason ?? '').assertEqual(PeripheralReasonCodes.EXPORT_CONNECTION_HISTORY_FAILED)

      when(exportMock)().afterAction(() => {
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
      when(exportMock)().afterAction((
        _context: common.UIAbilityContext,
        content: string
      ) => {
        capturedCsv = content
        return Promise.resolve(createExportResult(
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
      when(exportMock)().afterAction((
        _context: common.UIAbilityContext,
        content: string
      ) => {
        capturedCsv = content
        return Promise.resolve(createExportResult(
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
