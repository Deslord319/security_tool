import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { LogEventResult, PeripheralConnectionRecord, PeripheralType } from '../../main/ets/models/DataModels'
import { LogExportResult, LogStorageService } from '../../main/ets/services/LogStorageService'
import { PeripheralRecordViewModel } from '../../main/ets/viewmodels/PeripheralRecordViewModel'

describe('PeripheralRecordViewModel', () => {
  let viewModel: PeripheralRecordViewModel
  let originalInit: (context: common.UIAbilityContext) => Promise<void>
  let originalExport: (content: string, format: Object, trigger: Object, options?: Object) => Promise<LogExportResult>

  beforeEach(() => {
    viewModel = new PeripheralRecordViewModel()
    originalInit = LogStorageService.init
    originalExport = LogStorageService.exportContentToFile
  })

  afterEach(() => {
    LogStorageService.init = originalInit
    LogStorageService.exportContentToFile = originalExport
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

    viewModel.closeConnectionDetailDialog()
    expect(viewModel.connectionDetailDialog.visible).assertFalse()
  })

  it('should reject export when there are no records', 0, async (done: Function) => {
    const reason = await viewModel.exportConnectionHistory(null)
    expect(reason).assertEqual('empty_connection_history')
    done()
  })

  it('should reject export when context is missing', 0, async (done: Function) => {
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

    const reason = await viewModel.exportConnectionHistory(null)
    expect(reason).assertEqual('export_env_not_ready')
    done()
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
    LogStorageService.init = async (_context: common.UIAbilityContext): Promise<void> => {}
    LogStorageService.exportContentToFile = async (
      _content: string,
      _format: Object,
      _trigger: Object,
      _options?: Object
    ): Promise<LogExportResult> => {
      return { success: true, filePath: 'mock.csv' }
    }

    const reason = await viewModel.exportConnectionHistory({} as common.UIAbilityContext)

    expect(reason).assertNull()
    done()
  })
})
