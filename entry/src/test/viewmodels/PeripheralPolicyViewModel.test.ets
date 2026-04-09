import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { LogEventResult, PeripheralType } from '../../main/ets/models/DataModels'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/peripheral/device-policy/PeripheralDevicePolicyRepository'
import { LogExportService } from '../../main/ets/services/log-manage/export/LogExportService'
import { PeripheralPolicyViewModel } from '../../main/ets/viewmodels/peripheral/device-policy/PeripheralPolicyViewModel'

class FixedSavePicker {
  private readonly paths: string[]

  constructor(paths: string[]) {
    this.paths = paths
  }

  async save(_options: Object): Promise<string[]> {
    return this.paths.slice()
  }
}

export default function peripheralPolicyViewModelTest() {
  describe('PeripheralPolicyViewModel', () => {
    let viewModel: PeripheralPolicyViewModel

  beforeEach(() => {
    viewModel = new PeripheralPolicyViewModel()
    PeripheralDevicePolicyRepository.setRecordsForTest([])
    LogExportService.setTestDeps({})
  })

  afterEach(() => {
    PeripheralDevicePolicyRepository.setRecordsForTest([])
    LogExportService.setTestDeps({})
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

    expect(viewModel.state.records.length).assertEqual(1)
    expect(viewModel.state.records[0].policyIndex).assertEqual(1)
    done()
  })

  it('should expose connected devices as default allow when no explicit policy exists', 0, () => {
    viewModel.reloadRecords([{
      id: 'record-2',
      timestamp: 300,
      deviceId: 'VID:1234 PID:5678',
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      source: 'runtime_event',
      action: 'connect',
      result: LogEventResult.SUCCESS,
      policyHit: 'allow',
      summary: 'connected'
    }])

    expect(viewModel.state.records.length).assertEqual(1)
    expect(viewModel.state.records[0].policyIndex).assertEqual(0)
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

  it('should normalize bluetooth device ids when persisting policy', 0, async (done: Function) => {
    const reason = await viewModel.setDevicePolicy(
      'aa-bb-cc-dd-ee-ff',
      'Bluetooth Device',
      PeripheralType.BLUETOOTH,
      1
    )

    expect(reason).assertNull()
    expect(PeripheralDevicePolicyRepository.get('MAC: AA:BB:CC:DD:EE:FF')?.policy).assertEqual('deny')
    done()
  })

  it('should rebuild bluetooth policy records with normalized ids', 0, async (done: Function) => {
    await PeripheralDevicePolicyRepository.set({
      deviceId: 'aa-bb-cc-dd-ee-ff',
      policy: 'deny',
      updatedAt: Date.now(),
      deviceName: 'Bluetooth Device',
      deviceType: PeripheralType.BLUETOOTH
    })

    viewModel.reloadRecords([{
      id: 'record-bt-1',
      timestamp: 400,
      deviceId: 'MAC: AA:BB:CC:DD:EE:FF',
      deviceName: 'Bluetooth Device',
      deviceType: PeripheralType.BLUETOOTH,
      source: 'runtime_event',
      action: 'connect',
      result: LogEventResult.SUCCESS,
      policyHit: 'allow',
      summary: 'connected'
    }])

    expect(viewModel.state.records.length).assertEqual(1)
    expect(viewModel.state.records[0].deviceId).assertEqual('MAC: AA:BB:CC:DD:EE:FF')
    expect(viewModel.state.records[0].policyIndex).assertEqual(1)
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
    viewModel.state.records = [{
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      deviceId: 'VID:1234 PID:5678',
      lastSeenAt: Date.now(),
      lastSeenLabel: '2026-03-26 12:00:00',
      policyIndex: 0
    }]
    LogExportService.setTestDeps({
      pickerFactory: (_context: common.UIAbilityContext) => new FixedSavePicker(['file://mock-dir']),
      buildPathFn: (_directoryUri: string, fileName: string): string => `/mock/${fileName}`,
      openFileFn: (_path: string) => {
        return { fd: 1 }
      },
      writeFileFn: (_fd: number, _content: string): void => {},
      closeFileFn: (_fd: number): void => {}
    })

    const result = await viewModel.exportRecords({} as common.UIAbilityContext)
    expect(result.success).assertTrue()
    done()
  })
  })
}
