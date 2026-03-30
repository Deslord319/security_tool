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
})
