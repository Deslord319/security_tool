import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { LogEventResult, PeripheralType } from '../../main/ets/models/DataModels'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/PeripheralDevicePolicyRepository'
import { LogStorageService } from '../../main/ets/services/LogStorageService'
import { PeripheralPolicyViewModel } from '../../main/ets/viewmodels/PeripheralPolicyViewModel'

describe('PeripheralPolicyViewModel', () => {
  let viewModel: PeripheralPolicyViewModel
  let originalInit: (context: common.UIAbilityContext) => Promise<boolean>
  let originalExportToCsvFile: (payload: Object) => Promise<Object>

  beforeEach(() => {
    viewModel = new PeripheralPolicyViewModel()
    PeripheralDevicePolicyRepository.resetForTest()
    originalInit = LogStorageService.init
    originalExportToCsvFile = LogStorageService.exportToCsvFile
  })

  afterEach(() => {
    PeripheralDevicePolicyRepository.resetForTest()
    LogStorageService.init = originalInit
    LogStorageService.exportToCsvFile = originalExportToCsvFile
  })

  it('should rebuild policy records from connection records and explicit device policies', 0, async (done: Function) => {
    await PeripheralDevicePolicyRepository.set({
      deviceId: 'VID:1234 PID:5678',
      policy: 'deny',
      updatedAt: Date.now(),
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE
    })

    viewModel.reloadRecords([{
      id: 'record-1',
      timestamp: 200,
      deviceId: 'VID:1234 PID:5678',
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      source: 'runtime_event',
      action: 'connect',
      result: LogEventResult.SUCCESS,
      policyHit: 'allow',
      summary: 'connected'
    }])

    expect(viewModel.records.length).assertEqual(1)
    expect(viewModel.records[0].policyIndex).assertEqual(1)
    done()
  })

  it('should reject invalid device ids when changing policy', 0, async (done: Function) => {
    const reason = await viewModel.setDevicePolicy('', 'USB Device', PeripheralType.USB_STORAGE, 0)
    expect(reason).assertEqual('invalid_device_id')
    done()
  })

  it('should persist single-device deny policy', 0, async (done: Function) => {
    const reason = await viewModel.setDevicePolicy(
      'VID:1234 PID:5678',
      'USB Device',
      PeripheralType.USB_STORAGE,
      1
    )

    expect(reason).assertNull()
    expect(PeripheralDevicePolicyRepository.get('VID:1234 PID:5678')?.policy).assertEqual('deny')
    done()
  })

  it('should clear all explicit device policies', 0, async (done: Function) => {
    await PeripheralDevicePolicyRepository.set({
      deviceId: 'VID:1234 PID:5678',
      policy: 'deny',
      updatedAt: Date.now()
    })

    const success = await viewModel.clearAllPolicies()
    expect(success).assertTrue()
    expect(PeripheralDevicePolicyRepository.getAll().length).assertEqual(0)
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
    LogStorageService.init = async (_context: common.UIAbilityContext): Promise<boolean> => true
    LogStorageService.exportToCsvFile = async (_payload: Object): Promise<Object> => {
      return { success: true, fileName: 'mock.csv' }
    }

    const result = await viewModel.exportRecords({} as common.UIAbilityContext)
    expect(result.success).assertTrue()
    done()
  })
})
