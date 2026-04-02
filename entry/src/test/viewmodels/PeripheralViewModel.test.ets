import { beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { LogEventResult, PeripheralType } from '../../main/ets/models/DataModels'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/PeripheralDevicePolicyRepository'
import { PeripheralTraceRepository } from '../../main/ets/services/PeripheralTraceRepository'
import { PeripheralViewModel } from '../../main/ets/viewmodels/PeripheralViewModel'
import { PeripheralConnectionRecordClearUsecase } from '../../main/ets/viewmodels/peripheral/connection-record/peripheral_connection_record_clear_usecase'

class SuccessClearUsecase extends PeripheralConnectionRecordClearUsecase {
  executeCount: number = 0

  async execute(_context: common.UIAbilityContext | null): Promise<boolean> {
    this.executeCount++
    PeripheralTraceRepository.setRecordsForTest([])
    return true
  }
}

class FailedClearUsecase extends PeripheralConnectionRecordClearUsecase {
  executeCount: number = 0

  async execute(_context: common.UIAbilityContext | null): Promise<boolean> {
    this.executeCount++
    return false
  }
}

describe('PeripheralViewModel', () => {
  let viewModel: PeripheralViewModel

  beforeEach(() => {
    viewModel = new PeripheralViewModel()
    PeripheralTraceRepository.resetForTest()
    PeripheralDevicePolicyRepository.resetForTest()
  })

  it('should initialize nested view models with expected defaults', 0, () => {
    expect(viewModel.adminState.activated).assertFalse()
    expect(viewModel.interfaceControl.state.usbDisabled).assertFalse()
    expect(viewModel.interfaceControl.state.usbStoragePolicyIndex).assertEqual(1)
    expect(viewModel.records.records.length).assertEqual(0)
    expect(viewModel.policy.records.length).assertEqual(0)
    expect(viewModel.records.connectionDetailDialog.visible).assertFalse()
  })

  it('should switch tabs and ignore invalid indices', 0, () => {
    viewModel.switchToTab(1)
    expect(viewModel.currentTab).assertEqual(1)

    viewModel.switchToTab(3)
    expect(viewModel.currentTab).assertEqual(1)
  })

  it('should expose admin required reason when admin is not ready', 0, () => {
    const ready = viewModel.ensureAdminReady()
    expect(ready).assertFalse()
    expect(viewModel.reasonCode).assertEqual('admin_required')
  })

  it('should notify refresh when opening and closing connection detail dialog', 0, () => {
    let refreshCount = 0
    viewModel.onRefresh = () => {
      refreshCount++
    }

    viewModel.records.records = [{
      id: 'record-1',
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

    viewModel.openConnectionDetailDialog(viewModel.records.records[0])
    expect(viewModel.records.connectionDetailDialog.visible).assertTrue()

    viewModel.closeConnectionDetailDialog()
    expect(viewModel.records.connectionDetailDialog.visible).assertFalse()
    expect(refreshCount).assertEqual(2)
  })

  it('should clear explicit policies without deleting connection records', 0, async (done: Function) => {
    PeripheralTraceRepository.setRecordsForTest([{
      recordId: 'runtime_1',
      occurAt: 200,
      collectAt: 201,
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      deviceId: 'VID:1234 PID:5678',
      action: 'connect',
      decision: 'allow',
      result: LogEventResult.SUCCESS,
      source: 'runtime_event',
      summary: 'connected'
    }])
    await PeripheralDevicePolicyRepository.set({
      deviceId: 'VID:1234 PID:5678',
      policy: 'deny',
      updatedAt: Date.now()
    })

    viewModel.reloadDeviceRecords()
    expect(viewModel.policy.records[0].policyIndex).assertEqual(1)

    const success = await viewModel.clearPeripheralPolicyRecords()
    expect(success).assertTrue()
    expect(viewModel.records.records.length).assertEqual(1)
    expect(viewModel.policy.records[0].policyIndex).assertEqual(0)
    done()
  })

  it('should clear policy candidates when connection records are removed', 0, async (done: Function) => {
    PeripheralTraceRepository.setRecordsForTest([{
      recordId: 'runtime_2',
      occurAt: 300,
      collectAt: 301,
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      deviceId: 'VID:1234 PID:5678',
      action: 'connect',
      decision: 'allow',
      result: LogEventResult.SUCCESS,
      source: 'runtime_event',
      summary: 'connected'
    }])
    await PeripheralDevicePolicyRepository.set({
      deviceId: 'VID:1234 PID:5678',
      policy: 'deny',
      updatedAt: Date.now()
    })

    viewModel.reloadDeviceRecords()
    expect(viewModel.records.records.length).assertEqual(1)
    expect(viewModel.policy.records.length).assertEqual(1)
    expect(viewModel.policy.records[0].policyIndex).assertEqual(1)

    PeripheralTraceRepository.setRecordsForTest([])
    viewModel.reloadDeviceRecords()

    expect(viewModel.records.records.length).assertEqual(0)
    expect(viewModel.policy.records.length).assertEqual(0)
    done()
  })

  it('should clear connection history successfully and trigger refresh chain', 0, async (done: Function) => {
    const usecase = new SuccessClearUsecase()
    let refreshCount = 0
    viewModel.setConnectionRecordClearUsecaseForTest(usecase)
    viewModel.onRefresh = () => {
      refreshCount++
    }
    PeripheralTraceRepository.setRecordsForTest([{
      recordId: 'runtime_3',
      occurAt: 400,
      collectAt: 401,
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      deviceId: 'VID:1111 PID:2222',
      action: 'connect',
      decision: 'allow',
      result: LogEventResult.SUCCESS,
      source: 'runtime_event',
      summary: 'connected'
    }])
    viewModel.reloadDeviceRecords()
    expect(viewModel.records.records.length).assertEqual(1)
    viewModel.openConnectionDetailDialog(viewModel.records.records[0])
    expect(viewModel.records.connectionDetailDialog.visible).assertTrue()

    const success = await viewModel.clearConnectionHistory()
    expect(success).assertTrue()
    expect(usecase.executeCount).assertEqual(1)
    expect(viewModel.records.connectionDetailDialog.visible).assertFalse()
    expect(viewModel.records.records.length).assertEqual(0)
    expect(refreshCount > 0).assertTrue()
    done()
  })

  it('should return false when clear connection history usecase fails', 0, async (done: Function) => {
    const usecase = new FailedClearUsecase()
    let refreshCount = 0
    viewModel.setConnectionRecordClearUsecaseForTest(usecase)
    viewModel.onRefresh = () => {
      refreshCount++
    }
    PeripheralTraceRepository.setRecordsForTest([{
      recordId: 'runtime_4',
      occurAt: 500,
      collectAt: 501,
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      deviceId: 'VID:3333 PID:4444',
      action: 'connect',
      decision: 'allow',
      result: LogEventResult.SUCCESS,
      source: 'runtime_event',
      summary: 'connected'
    }])
    viewModel.reloadDeviceRecords()
    viewModel.openConnectionDetailDialog(viewModel.records.records[0])
    expect(viewModel.records.connectionDetailDialog.visible).assertTrue()
    const refreshBeforeClear = refreshCount

    const success = await viewModel.clearConnectionHistory()
    expect(success).assertFalse()
    expect(usecase.executeCount).assertEqual(1)
    expect(viewModel.records.connectionDetailDialog.visible).assertTrue()
    expect(viewModel.records.records.length).assertEqual(1)
    expect(refreshCount).assertEqual(refreshBeforeClear)
    done()
  })
})
