import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import {
  getPeripheralRecordActionLabel,
  getPeripheralRecordSourceLabel,
  getPeripheralTypeLabel,
  LogEventResult,
  PeripheralConnectionRecord,
  PeripheralType
} from '../../main/ets/models/DataModels'
import { PeripheralStrings } from '../../main/ets/constants/modules/PeripheralStrings'
import { PeripheralConnectionRecordService } from '../../main/ets/services/PeripheralConnectionRecordService'
import { LogExportService } from '../../main/ets/services/log-manage/export/LogExportService'
import {
  formatPeripheralTimestamp,
  getPeripheralConnectionPolicyLabel,
  getPeripheralConnectionResultLabel
} from '../../main/ets/viewmodels/PeripheralRecordPresentationMapper'
import { PeripheralRecordViewModel } from '../../main/ets/viewmodels/PeripheralRecordViewModel'

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

describe('PeripheralRecordViewModel', () => {
  let viewModel: PeripheralRecordViewModel
  let originalQueryRecords: (filter?: Object) => PeripheralConnectionRecord[]
  let originalSaveCsvContent: (
    context: common.UIAbilityContext | null,
    csvContent: string,
    fileNamePrefix?: string
  ) => Promise<Object>

  beforeEach(() => {
    viewModel = new PeripheralRecordViewModel()
    originalQueryRecords = PeripheralConnectionRecordService.queryRecords
    originalSaveCsvContent = LogExportService.saveCsvContent
    LogExportService.resetForTest()
  })

  afterEach(() => {
    PeripheralConnectionRecordService.queryRecords = originalQueryRecords
    LogExportService.saveCsvContent = originalSaveCsvContent
    LogExportService.resetForTest()
  })

  it('U-RVM-001 should reload records from record service', 0, () => {
    const records: PeripheralConnectionRecord[] = [
      createConnectionRecord('record-1', 1700000000000),
      createConnectionRecord('record-2', 1700000001000, 'VID:1111 PID:2222', 'USB Camera')
    ]
    PeripheralConnectionRecordService.queryRecords = (_filter?: Object): PeripheralConnectionRecord[] => records

    viewModel.reloadRecords()

    expect(viewModel.records.length).assertEqual(2)
    expect(viewModel.records[0].id).assertEqual('record-1')
    expect(viewModel.records[1].id).assertEqual('record-2')
  })

  it('U-RVM-002 should fall back to empty list when record service throws', 0, () => {
    PeripheralConnectionRecordService.queryRecords = (_filter?: Object): PeripheralConnectionRecord[] => {
      throw new Error('query failed')
    }
    viewModel.records = [createConnectionRecord('stale-record', 1700000000000)]

    viewModel.reloadRecords()

    expect(viewModel.records.length).assertEqual(0)
  })

  it('U-RVM-003 should open detail dialog with selected record and same-device history only', 0, () => {
    const selectedRecord = createConnectionRecord('record-1', 1700000000000, 'VID:1234 PID:5678', 'USB Device')
    const sameDeviceLater = createConnectionRecord('record-2', 1700000003000, 'VID: 1234   PID:5678', 'USB Device')
    const differentDevice = createConnectionRecord('record-3', 1700000005000, 'VID:9999 PID:8888', 'Other Device')
    viewModel.records = [selectedRecord, sameDeviceLater, differentDevice]

    viewModel.openConnectionDetailDialog(selectedRecord)

    expect(viewModel.connectionDetailDialog.visible).assertTrue()
    expect(viewModel.connectionDetailDialog.record?.id ?? '').assertEqual('record-1')
    expect(viewModel.connectionDetailDialog.historyItems.length).assertEqual(2)
    expect(viewModel.connectionDetailDialog.historyItems[0].time).assertEqual(formatPeripheralTimestamp(1700000000000))
    expect(viewModel.connectionDetailDialog.historyItems[1].time).assertEqual(formatPeripheralTimestamp(1700000003000))
  })

  it('U-RVM-004 should close detail dialog and clear selected state', 0, () => {
    const record = createConnectionRecord('record-1', 1700000000000)
    viewModel.records = [record]
    viewModel.openConnectionDetailDialog(record)

    viewModel.closeConnectionDetailDialog()

    expect(viewModel.connectionDetailDialog.visible).assertFalse()
    expect(viewModel.connectionDetailDialog.record).assertNull()
    expect(viewModel.connectionDetailDialog.historyItems.length).assertEqual(0)
  })

  it('U-RVM-005 should export connection history and return generated file name', 0, async (done: Function) => {
    viewModel.records = [createConnectionRecord('record-1', 1700000000000)]
    LogExportService.saveCsvContent = async (
      _context: common.UIAbilityContext | null,
      _csvContent: string,
      _fileNamePrefix?: string
    ): Promise<Object> => ({ success: true, fileName: 'mock.csv' })

    const result = await viewModel.exportConnectionHistory({} as common.UIAbilityContext)

    expect(result.success).assertTrue()
    expect(result.fileName ?? '').assertEqual('mock.csv')
    done()
  })

  it('U-RVM-006 should reject export when no connection history exists', 0, async (done: Function) => {
    viewModel.records = []

    const result = await viewModel.exportConnectionHistory({} as common.UIAbilityContext)

    expect(result.success).assertFalse()
    expect(result.reason ?? '').assertEqual(PeripheralStrings.emptyConnectionHistory)
    done()
  })

  it('U-RVM-007 should reject export when context is missing', 0, async (done: Function) => {
    viewModel.records = [createConnectionRecord('record-1', 1700000000000)]

    const result = await viewModel.exportConnectionHistory(null)

    expect(result.success).assertFalse()
    expect(result.reason ?? '').assertEqual(PeripheralStrings.exportEnvNotReady)
    done()
  })

  it('U-RVM-008 should map export service failure and thrown errors to export failure reason', 0, async (done: Function) => {
    viewModel.records = [createConnectionRecord('record-1', 1700000000000)]
    LogExportService.saveCsvContent = async (
      _context: common.UIAbilityContext | null,
      _csvContent: string,
      _fileNamePrefix?: string
    ): Promise<Object> => ({ success: false })

    const failedResult = await viewModel.exportConnectionHistory({} as common.UIAbilityContext)
    expect(failedResult.success).assertFalse()
    expect(failedResult.reason ?? '').assertEqual(PeripheralStrings.exportConnectionHistoryFailed)

    LogExportService.saveCsvContent = async (
      _context: common.UIAbilityContext | null,
      _csvContent: string,
      _fileNamePrefix?: string
    ): Promise<Object> => {
      throw new Error('io failed')
    }
    const thrownResult = await viewModel.exportConnectionHistory({} as common.UIAbilityContext)
    expect(thrownResult.success).assertFalse()
    expect(thrownResult.reason ?? '').assertEqual(PeripheralStrings.exportConnectionHistoryFailed)
    done()
  })

  it('U-RVM-009 should build csv with BOM, expected header order and mapped field values', 0, async (done: Function) => {
    const record = createConnectionRecord('record-1', 1700000000000, 'VID:1234 PID:5678', 'USB Device')
    let capturedCsv = ''
    let capturedPrefix = ''
    viewModel.records = [record]
    LogExportService.saveCsvContent = async (
      _context: common.UIAbilityContext | null,
      csvContent: string,
      fileNamePrefix?: string
    ): Promise<Object> => {
      capturedCsv = csvContent
      capturedPrefix = fileNamePrefix ?? ''
      return { success: true, fileName: 'history.csv' }
    }

    const result = await viewModel.exportConnectionHistory({} as common.UIAbilityContext)

    expect(result.success).assertTrue()
    expect(capturedPrefix).assertEqual(PeripheralStrings.csvConnectionHistoryFilePrefix)
    expect(capturedCsv.charCodeAt(0)).assertEqual(0xFEFF)
    const lines = capturedCsv.substring(1).split('\n')
    expect(lines[0]).assertEqual(PeripheralStrings.connectionHistoryCsvHeaders.join(','))
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
    viewModel.records = [record]
    LogExportService.saveCsvContent = async (
      _context: common.UIAbilityContext | null,
      csvContent: string,
      _fileNamePrefix?: string
    ): Promise<Object> => {
      capturedCsv = csvContent
      return { success: true, fileName: 'history.csv' }
    }

    const result = await viewModel.exportConnectionHistory({} as common.UIAbilityContext)

    expect(result.success).assertTrue()
    expect(capturedCsv.indexOf('"USB ""Special"", Device\nLine2"') > -1).assertTrue()
    done()
  })
})
