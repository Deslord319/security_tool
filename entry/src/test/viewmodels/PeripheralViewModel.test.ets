import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import {
  LogEventResult,
  PeripheralConnectionRecord,
  PeripheralTraceRecord,
  PeripheralType
} from '../../main/ets/models/DataModels'
import { PeripheralStrings } from '../../main/ets/constants/modules/PeripheralStrings'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/PeripheralDevicePolicyRepository'
import { PeripheralTraceRepository } from '../../main/ets/services/PeripheralTraceRepository'
import { InterfaceControlViewModel } from '../../main/ets/viewmodels/InterfaceControlViewModel'
import { PeripheralPolicyViewModel } from '../../main/ets/viewmodels/PeripheralPolicyViewModel'
import { PeripheralRecordViewModel } from '../../main/ets/viewmodels/PeripheralRecordViewModel'
import { PeripheralViewModel } from '../../main/ets/viewmodels/PeripheralViewModel'
import { PeripheralConnectionRecordClearUsecase } from '../../main/ets/viewmodels/peripheral/connection-record/peripheral_connection_record_clear_usecase'

class FakeInterfaceControlViewModel extends InterfaceControlViewModel {
  reloadCount: number = 0

  reloadState(): void {
    this.reloadCount++
  }
}

class FakeRecordViewModel extends PeripheralRecordViewModel {
  reloadCount: number = 0
  nextRecords: PeripheralConnectionRecord[] = []

  reloadRecords(): void {
    this.reloadCount++
    this.records = this.nextRecords.slice()
  }
}

class FakePolicyViewModel extends PeripheralPolicyViewModel {
  initializeCount: number = 0
  reloadCount: number = 0
  throwOnInitialize: boolean = false
  lastRecords: PeripheralConnectionRecord[] = []

  async initialize(_context: common.UIAbilityContext): Promise<boolean> {
    this.initializeCount++
    if (this.throwOnInitialize) {
      throw new Error('init failed')
    }
    return true
  }

  reloadRecords(connectionRecords: PeripheralConnectionRecord[]): void {
    this.reloadCount++
    this.lastRecords = connectionRecords.slice()
    this.records = []
  }
}

function createConnectionRecord(
  id: string,
  timestamp: number,
  deviceId: string = 'VID:1234 PID:5678'
): PeripheralConnectionRecord {
  return {
    id,
    timestamp,
    deviceId,
    deviceName: 'USB Device',
    deviceType: PeripheralType.USB_STORAGE,
    source: 'runtime_event',
    action: 'connect',
    result: LogEventResult.SUCCESS,
    policyHit: 'allow',
    summary: 'connected',
    matchedPolicyKind: 'default_allow'
  }
}

function createTraceRecord(recordId: string, occurAt: number, deviceId: string = 'VID:1234 PID:5678'): PeripheralTraceRecord {
  return {
    recordId,
    occurAt,
    collectAt: occurAt + 1,
    deviceName: 'USB Device',
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

describe('PeripheralConnectionRecordClearUsecase', () => {
  let usecase: PeripheralConnectionRecordClearUsecase

  beforeEach(() => {
    usecase = new PeripheralConnectionRecordClearUsecase()
    PeripheralTraceRepository.resetForTest()
  })

  afterEach(() => {
    PeripheralTraceRepository.resetForTest()
  })

  it('U-CLEAR-001 should return false when context is null', 0, async (done: Function) => {
    const result = await usecase.execute(null)

    expect(result).assertFalse()
    done()
  })

  it('U-CLEAR-002 should return false when trace repository init fails', 0, async (done: Function) => {
    const result = await usecase.execute({} as common.UIAbilityContext)

    expect(result).assertFalse()
    done()
  })
})

describe('PeripheralViewModel', () => {
  let viewModel: PeripheralViewModel
  let fakePolicy: FakePolicyViewModel
  let fakeRecords: FakeRecordViewModel
  let fakeInterface: FakeInterfaceControlViewModel

  beforeEach(() => {
    viewModel = new PeripheralViewModel()
    fakePolicy = new FakePolicyViewModel()
    fakeRecords = new FakeRecordViewModel()
    fakeInterface = new FakeInterfaceControlViewModel()
    viewModel.policy = fakePolicy
    viewModel.records = fakeRecords
    viewModel.interfaceControl = fakeInterface
    PeripheralTraceRepository.resetForTest()
    PeripheralDevicePolicyRepository.resetForTest()
  })

  afterEach(() => {
    viewModel.destroy()
    PeripheralTraceRepository.resetForTest()
    PeripheralDevicePolicyRepository.resetForTest()
  })

  it('U-PVM-001 should initialize successfully, reload child data and register listeners', 0, async (done: Function) => {
    fakeRecords.nextRecords = [createConnectionRecord('record-1', 1700000000000)]

    await viewModel.initialize({} as common.UIAbilityContext)

    expect(fakePolicy.initializeCount).assertEqual(1)
    expect(fakeInterface.reloadCount).assertEqual(1)
    expect(fakeRecords.reloadCount).assertEqual(1)
    expect(fakePolicy.reloadCount).assertEqual(1)
    expect(viewModel.reasonCode).assertNull()
    expect(viewModel.isLoading).assertFalse()

    await PeripheralTraceRepository.append(createTraceRecord('trace-1', 1700000000000))
    expect(fakeRecords.reloadCount).assertEqual(2)
    expect(fakePolicy.reloadCount).assertEqual(2)

    viewModel.destroy()
    await PeripheralTraceRepository.append(createTraceRecord('trace-2', 1700000001000))
    expect(fakeRecords.reloadCount).assertEqual(2)
    expect(fakePolicy.reloadCount).assertEqual(2)
    done()
  })

  it('U-PVM-002 should expose init_failed when initialize throws', 0, async (done: Function) => {
    fakePolicy.throwOnInitialize = true

    await viewModel.initialize({} as common.UIAbilityContext)

    expect(viewModel.reasonCode).assertEqual(PeripheralStrings.initFailed)
    expect(viewModel.isLoading).assertFalse()
    done()
  })

  it('U-PVM-003 should reload device records, sync policy records and notify refresh', 0, () => {
    let refreshCount = 0
    fakeRecords.nextRecords = [createConnectionRecord('record-1', 1700000000000)]
    viewModel.onRefresh = (): void => {
      refreshCount++
    }

    viewModel.reloadDeviceRecords()

    expect(fakeRecords.reloadCount).assertEqual(1)
    expect(fakePolicy.reloadCount).assertEqual(1)
    expect(fakePolicy.lastRecords.length).assertEqual(1)
    expect(refreshCount).assertEqual(1)
  })

  it('U-PVM-004 should open detail dialog and notify refresh', 0, () => {
    let refreshCount = 0
    const record = createConnectionRecord('record-1', 1700000000000)
    fakeRecords.records = [record]
    viewModel.onRefresh = (): void => {
      refreshCount++
    }

    viewModel.openConnectionDetailDialog(record)

    expect(fakeRecords.connectionDetailDialog.visible).assertTrue()
    expect(fakeRecords.connectionDetailDialog.record?.id ?? '').assertEqual('record-1')
    expect(refreshCount).assertEqual(1)
  })

  it('U-PVM-005 should close detail dialog and notify refresh', 0, () => {
    let refreshCount = 0
    const record = createConnectionRecord('record-1', 1700000000000)
    fakeRecords.records = [record]
    fakeRecords.openConnectionDetailDialog(record)
    viewModel.onRefresh = (): void => {
      refreshCount++
    }

    viewModel.closeConnectionDetailDialog()

    expect(fakeRecords.connectionDetailDialog.visible).assertFalse()
    expect(refreshCount).assertEqual(1)
  })

  it('U-PVM-007 should keep current detail state when clear history fails', 0, async (done: Function) => {
    fakeRecords.records = [createConnectionRecord('record-1', 1700000000000)]
    fakeRecords.nextRecords = []
    fakeRecords.openConnectionDetailDialog(fakeRecords.records[0])

    const result = await viewModel.clearConnectionHistory()

    expect(result).assertFalse()
    expect(fakeRecords.connectionDetailDialog.visible).assertTrue()
    expect(fakeRecords.reloadCount).assertEqual(0)
    expect(fakePolicy.reloadCount).assertEqual(0)
    expect(fakeRecords.records.length).assertEqual(1)
    done()
  })

  it('U-PVM-008 should ignore invalid tab indices', 0, () => {
    viewModel.currentTab = 1

    viewModel.switchToTab(-1)
    expect(viewModel.currentTab).assertEqual(1)

    viewModel.switchToTab(3)
    expect(viewModel.currentTab).assertEqual(1)
  })

  it('U-PVM-009 should ignore requests to switch to the current tab', 0, () => {
    viewModel.currentTab = 2

    viewModel.switchToTab(2)

    expect(viewModel.currentTab).assertEqual(2)
  })

  it('U-PVM-010 should refresh records and policy when trace listener fires', 0, async (done: Function) => {
    let refreshCount = 0
    fakeRecords.nextRecords = [createConnectionRecord('record-1', 1700000000000)]
    viewModel.onRefresh = (): void => {
      refreshCount++
    }

    await viewModel.initialize({} as common.UIAbilityContext)
    fakeRecords.reloadCount = 0
    fakePolicy.reloadCount = 0
    refreshCount = 0

    await PeripheralTraceRepository.append(createTraceRecord('trace-1', 1700000000000))

    expect(fakeRecords.reloadCount).assertEqual(1)
    expect(fakePolicy.reloadCount).assertEqual(1)
    expect(refreshCount).assertEqual(1)
    done()
  })

  it('U-PVM-011 should refresh policy only when device policy listener fires', 0, async (done: Function) => {
    let refreshCount = 0
    fakeRecords.nextRecords = [createConnectionRecord('record-1', 1700000000000)]
    viewModel.onRefresh = (): void => {
      refreshCount++
    }

    await viewModel.initialize({} as common.UIAbilityContext)
    fakeRecords.reloadCount = 0
    fakePolicy.reloadCount = 0
    refreshCount = 0

    await PeripheralDevicePolicyRepository.clearAll()

    expect(fakeRecords.reloadCount).assertEqual(0)
    expect(fakePolicy.reloadCount).assertEqual(1)
    expect(refreshCount).assertEqual(1)
    done()
  })

  it('should keep basic defaults and admin check behavior stable', 0, () => {
    PeripheralTraceRepository.setRecordsForTest([createTraceRecord('trace-1', 1700000000000)])
    PeripheralDevicePolicyRepository.setRecordsForTest([])

    const ready = viewModel.ensureAdminReady()

    expect(fakeRecords.connectionDetailDialog.visible).assertFalse()
    expect(ready).assertFalse()
    expect(viewModel.reasonCode).assertEqual(PeripheralStrings.adminRequired)
  })
})
