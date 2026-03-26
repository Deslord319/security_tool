import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { usbManager as edmUsbManager } from '@kit.MDMKit'
import {
  LogEventResult,
  OperationResult,
  PeripheralConnectionRecord,
  PeripheralType
} from '../../main/ets/models/DataModels'
import { LogExportResult, LogStorageService } from '../../main/ets/services/LogStorageService'
import { PeripheralService } from '../../main/ets/services/PeripheralService'
import { PeripheralPolicyViewModel } from '../../main/ets/viewmodels/PeripheralPolicyViewModel'

describe('PeripheralPolicyViewModel', () => {
  let viewModel: PeripheralPolicyViewModel
  let originalSwitchPolicy: (device: edmUsbManager.UsbDeviceId, peripheralType: PeripheralType, targetPolicy: string) => OperationResult<void>
  let originalInit: (context: common.UIAbilityContext) => Promise<void>
  let originalExport: (content: string, format: Object, trigger: Object, options?: Object) => Promise<LogExportResult>

  beforeEach(() => {
    viewModel = new PeripheralPolicyViewModel()
    originalSwitchPolicy = PeripheralService.switchUsbDevicePolicyWithResult
    originalInit = LogStorageService.init
    originalExport = LogStorageService.exportContentToFile
  })

  afterEach(() => {
    PeripheralService.switchUsbDevicePolicyWithResult = originalSwitchPolicy
    LogStorageService.init = originalInit
    LogStorageService.exportContentToFile = originalExport
  })

  it('should rebuild policy records from connection records', 0, () => {
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

    viewModel.rebuildRecords([record])
    expect(viewModel.records.length).assertEqual(1)
  })

  it('should reject invalid device ids when changing policy', 0, async (done: Function) => {
    const reason = await viewModel.changePolicy('invalid-id', PeripheralType.USB_STORAGE, 0)
    expect(reason).assertEqual('invalid_device_id')
    done()
  })

  it('should change policy successfully', 0, async (done: Function) => {
    PeripheralService.switchUsbDevicePolicyWithResult = (
      _device: edmUsbManager.UsbDeviceId,
      _peripheralType: PeripheralType,
      _targetPolicy: string
    ): OperationResult<void> => {
      return { success: true }
    }

    const reason = await viewModel.changePolicy('VID:1234 PID:5678', PeripheralType.USB_STORAGE, 0)

    expect(reason).assertNull()
    done()
  })

  it('should surface failure stage when changing policy fails', 0, async (done: Function) => {
    PeripheralService.switchUsbDevicePolicyWithResult = (
      _device: edmUsbManager.UsbDeviceId,
      _peripheralType: PeripheralType,
      _targetPolicy: string
    ): OperationResult<void> => {
      return { success: false, stage: 'precheck_blacklist_conflict' }
    }

    const reason = await viewModel.changePolicy('VID:1234 PID:5678', PeripheralType.USB_STORAGE, 0)

    expect(reason).assertEqual('precheck_blacklist_conflict')
    done()
  })

  it('should reject export when there are no policy records', 0, async (done: Function) => {
    const reason = await viewModel.exportRecords(null)
    expect(reason).assertEqual('empty_policy_records')
    done()
  })

  it('should export policy records successfully', 0, async (done: Function) => {
    viewModel.records = [{
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      deviceId: 'VID:1234 PID:5678',
      lastSeenAt: Date.now(),
      lastSeenLabel: '2026-03-26 12:00:00',
      policyIndex: 0
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

    const reason = await viewModel.exportRecords({} as common.UIAbilityContext)

    expect(reason).assertNull()
    done()
  })
})
