import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { LogEventResult, PeripheralConnectionRecord, PeripheralType } from '../../main/ets/models/DataModels'
import { LogStorageService } from '../../main/ets/services/LogStorageService'
import { PeripheralRecordViewModel } from '../../main/ets/viewmodels/PeripheralRecordViewModel'

describe('PeripheralRecordViewModel', () => {
  let viewModel: PeripheralRecordViewModel
  let originalInit: (context: common.UIAbilityContext) => Promise<boolean>
  let originalExportToCsvFile: (payload: Object) => Promise<Object>

  beforeEach(() => {
    viewModel = new PeripheralRecordViewModel()
    originalInit = LogStorageService.init
    originalExportToCsvFile = LogStorageService.exportToCsvFile
  })

  afterEach(() => {
    LogStorageService.init = originalInit
    LogStorageService.exportToCsvFile = originalExportToCsvFile
  })

  it('should open and close connection detail dialog', 0, () => {
    const record: PeripheralConnectionRecord = {
      id: 'test-1',
      timestamp: Date.now(),
      deviceId: 'VID:1234 PID:5678',
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      source: 'runtime_event',
      action: 'connect',
      result: LogEventResult.SUCCESS,
      policyHit: 'allow',
      summary: 'connected'
    }
    viewModel.records = [record]

    viewModel.openConnectionDetailDialog(record)
    expect(viewModel.connectionDetailDialog.visible).assertTrue()
    expect(viewModel.connectionDetailDialog.historyItems.length).assertEqual(1)

    viewModel.closeConnectionDetailDialog()
    expect(viewModel.connectionDetailDialog.visible).assertFalse()
  })

  it('should export connection history successfully', 0, async (done: Function) => {
    viewModel.records = [{
      id: 'test-1',
      timestamp: Date.now(),
      deviceId: 'VID:1234 PID:5678',
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      source: 'runtime_event',
      action: 'connect',
      result: LogEventResult.SUCCESS,
      policyHit: 'allow',
      summary: 'connected'
    }]
    LogStorageService.init = async (_context: common.UIAbilityContext): Promise<boolean> => true
    LogStorageService.exportToCsvFile = async (_payload: Object): Promise<Object> => {
      return { success: true, fileName: 'mock.csv' }
    }

    const result = await viewModel.exportConnectionHistory({} as common.UIAbilityContext)
    expect(result.success).assertTrue()
    done()
  })

  it('should export discover label for bluetooth records', 0, async (done: Function) => {
    viewModel.records = [{
      id: 'bt-1',
      timestamp: Date.now(),
      deviceId: 'MAC: AA:BB:CC:DD:EE:FF',
      deviceName: 'Bluetooth Keyboard',
      deviceType: PeripheralType.BLUETOOTH,
      source: 'runtime_event',
      action: 'discover',
      result: LogEventResult.SUCCESS,
      policyHit: 'unknown',
      summary: '发现蓝牙设备'
    }]
    let exportedCsv = ''
    LogStorageService.init = async (_context: common.UIAbilityContext): Promise<boolean> => true
    LogStorageService.exportToCsvFile = async (payload: Object): Promise<Object> => {
      exportedCsv = (payload as Record<string, string>).csvContent ?? ''
      return { success: true, fileName: 'mock.csv' }
    }

    const result = await viewModel.exportConnectionHistory({} as common.UIAbilityContext)
    expect(result.success).assertTrue()
    expect(exportedCsv.indexOf('发现')).toBeGreaterThan(-1)
    done()
  })
})
