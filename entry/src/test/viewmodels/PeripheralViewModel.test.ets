import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import {
  AdminActivationState,
  ExportActionResult,
  SecurityEventResult
} from '../../main/ets/models/CommonModels'
import {
  PeripheralConnectionRecord,
  PeripheralPolicyRecord,
  PeripheralType
} from '../../main/ets/models/PeripheralModels'
import {
  PeripheralPolicyOptionIndexes,
  PeripheralReasonCodes
} from '../../main/ets/constants/modules/PeripheralStrings'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/peripheral/device-policy/PeripheralDevicePolicyRepository'
import { EnterpriseAdminService } from '../../main/ets/services/admin/activation/EnterpriseAdminService'
import { PeripheralTraceEntryRepository } from '../../main/ets/services/peripheral/connection-record/PeripheralTraceEntryRepository'
import {
  PeripheralTraceClearResult,
  PeripheralTraceInitializeResult,
  PeripheralTraceMaintenanceService
} from '../../main/ets/services/peripheral/connection-record/PeripheralTraceMaintenanceService'
import { InterfaceControlViewModel } from '../../main/ets/viewmodels/peripheral/interface-control/InterfaceControlViewModel'
import { PeripheralPolicyViewModel } from '../../main/ets/viewmodels/peripheral/device-policy/PeripheralPolicyViewModel'
import { PeripheralRecordViewModel } from '../../main/ets/viewmodels/peripheral/connection-record/PeripheralRecordViewModel'
import { PeripheralViewModel } from '../../main/ets/viewmodels/peripheral/overview/PeripheralViewModel'
import { PeripheralConnectionRecordClearUsecase } from '../../main/ets/viewmodels/peripheral/connection-record/PeripheralConnectionRecordClearUsecase'

class FakeInterfaceControlViewModel extends InterfaceControlViewModel {
  reloadCount: number = 0

  async reloadState(): Promise<void> {
    this.reloadCount++
  }
}

class FakeExportResult implements ExportActionResult {
  success: boolean
  fileName?: string
  reason?: string

  constructor(success: boolean, fileName?: string, reason?: string) {
    this.success = success
    this.fileName = fileName
    this.reason = reason
  }
}

class FakeRecordViewModel extends PeripheralRecordViewModel {
  reloadCount: number = 0
  nextRecords: PeripheralConnectionRecord[] = []
  exportResult: ExportActionResult = new FakeExportResult(true, 'peripheral_connection_history.csv')

  async reloadRecords(): Promise<void> {
    this.reloadCount++
    this.state.records = this.nextRecords.slice()
  }

  async exportConnectionHistory(_context: common.UIAbilityContext | null): Promise<ExportActionResult> {
    return this.exportResult
  }
}

class FakePolicyViewModel extends PeripheralPolicyViewModel {
  initializeCount: number = 0
  reloadCount: number = 0
  clearCount: number = 0
  throwOnInitialize: boolean = false
  clearResult: boolean = true
  nextHasRestorableRecords: boolean = false
  exportResult: ExportActionResult = new FakeExportResult(true, 'peripheral_policy_records.csv')

  async initialize(_context: common.UIAbilityContext): Promise<boolean> {
    this.initializeCount++
    if (this.throwOnInitialize) {
      throw new Error('init failed')
    }
    return true
  }

  async reloadRecords(): Promise<void> {
    this.reloadCount++
    this.state.records = []
    this.state.hasRestorableRecords = this.nextHasRestorableRecords
  }

  async exportRecords(_context: common.UIAbilityContext | null): Promise<ExportActionResult> {
    return this.exportResult
  }

  async clearAllPolicies(): Promise<boolean> {
    this.clearCount++
    return this.clearResult
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
    result: SecurityEventResult.SUCCESS,
    policyHit: 'allow',
    summary: 'connected',
    matchedPolicyKind: 'default_allow'
  }
}

function createPolicyRecord(policyIndex: number): PeripheralPolicyRecord {
  return {
    deviceName: 'USB Device',
    deviceType: PeripheralType.USB_STORAGE,
    deviceId: 'USB-WEAK:1234:5678:ABCDEF01',
    lastSeenAt: 1700000000000,
    lastSeenLabel: '2026-07-09 11:00:00',
    policyIndex: policyIndex,
    present: true,
    editable: true
  }
}

async function flushAsyncWork(): Promise<void> {
  await Promise.resolve()
  await Promise.resolve()
}

export default function peripheralViewModelTest() {
  describe('PeripheralConnectionRecordClearUsecase', () => {
    let usecase: PeripheralConnectionRecordClearUsecase
    let mockKit: MockKit

  beforeEach(() => {
    usecase = new PeripheralConnectionRecordClearUsecase()
    mockKit = new MockKit()
    let initMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.initialize)
    let clearMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.clearAll)
    let initResult: PeripheralTraceInitializeResult = { success: true, code: 'ok' }
    let clearResult: PeripheralTraceClearResult = { success: true, code: 'ok' }
    when(initMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(initResult))
    when(clearMock)().afterReturn(Promise.resolve(clearResult))
  })

  afterEach(() => {
    mockKit.clearAll()
  })

  it('U-CLEAR-001 should return false when context is null', 0, async (done: Function) => {
    const result = await usecase.execute(null)

    expect(result).assertFalse()
    done()
  })

  it('U-CLEAR-002 should return true when trace repository initializes and clear succeeds', 0, async (done: Function) => {
    const result = await usecase.execute({} as common.UIAbilityContext)

    expect(result).assertTrue()
    done()
  })
  })

  describe('PeripheralViewModel', () => {
    let viewModel: PeripheralViewModel
    let fakePolicy: FakePolicyViewModel
    let fakeRecords: FakeRecordViewModel
    let fakeInterface: FakeInterfaceControlViewModel
    let mockKit: MockKit
    let traceListener: (() => void) | null
    let devicePolicyListener: (() => void) | null

  beforeEach(() => {
    mockKit = new MockKit()
    traceListener = null
    devicePolicyListener = null
    viewModel = new PeripheralViewModel()
    fakePolicy = new FakePolicyViewModel()
    fakeRecords = new FakeRecordViewModel()
    fakeInterface = new FakeInterfaceControlViewModel()
    viewModel.policy = fakePolicy
    viewModel.records = fakeRecords
    viewModel.interfaceControl = fakeInterface
    const inactiveAdminState: AdminActivationState = {
      activated: false,
      enableCommand: 'mock-enable',
      adminType: 'super'
    }
    let probeActivationMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
    let traceInitMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.initialize)
    let traceAddListenerMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.addChangeListener)
    let traceRemoveListenerMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.removeChangeListener)
    let deviceAddListenerMock = mockKit.mockFunc(PeripheralDevicePolicyRepository, PeripheralDevicePolicyRepository.addChangeListener)
    let deviceRemoveListenerMock = mockKit.mockFunc(PeripheralDevicePolicyRepository, PeripheralDevicePolicyRepository.removeChangeListener)
    when(probeActivationMock)().afterReturn(inactiveAdminState)
    let traceInitResult: PeripheralTraceInitializeResult = { success: true, code: 'ok' }
    when(traceInitMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(traceInitResult))
    when(traceAddListenerMock)(ArgumentMatchers.any).afterAction((listener: () => void) => {
      traceListener = listener
      return 1
    })
    when(traceRemoveListenerMock)(ArgumentMatchers.any).afterAction(() => {
      traceListener = null
    })
    when(deviceAddListenerMock)(ArgumentMatchers.any).afterAction((listener: () => void) => {
      devicePolicyListener = listener
      return 1
    })
    when(deviceRemoveListenerMock)(ArgumentMatchers.any).afterAction(() => {
      devicePolicyListener = null
    })
  })

  afterEach(() => {
    mockKit.clearAll()
    viewModel.destroy()
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

    if (traceListener) {
      traceListener()
    }
    await flushAsyncWork()
    expect(fakeRecords.reloadCount).assertEqual(2)
    expect(fakePolicy.reloadCount).assertEqual(1)

    viewModel.destroy()
    if (traceListener) {
      traceListener()
    }
    await flushAsyncWork()
    expect(fakeRecords.reloadCount).assertEqual(2)
    expect(fakePolicy.reloadCount).assertEqual(1)
    done()
  })

  it('U-PVM-002 should expose init_failed when initialize throws', 0, async (done: Function) => {
    fakePolicy.throwOnInitialize = true

    await viewModel.initialize({} as common.UIAbilityContext)

    expect(viewModel.reasonCode).assertEqual(PeripheralReasonCodes.INIT_FAILED)
    expect(viewModel.isLoading).assertFalse()
    done()
  })

  it('U-PVM-003 should reload device records without rebuilding policy records', 0, async () => {
    fakeRecords.nextRecords = [createConnectionRecord('record-1', 1700000000000)]

    await viewModel.reloadDeviceRecords()

    expect(fakeRecords.reloadCount).assertEqual(1)
    expect(fakePolicy.reloadCount).assertEqual(0)
  })

  it('U-PVM-004 should open detail dialog and notify refresh', 0, () => {
    const record = createConnectionRecord('record-1', 1700000000000)
    fakeRecords.state.records = [record]

    viewModel.openConnectionDetailDialog(record)

    expect(fakeRecords.state.connectionDetailDialog.visible).assertTrue()
    expect(fakeRecords.state.connectionDetailDialog.record?.id ?? '').assertEqual('record-1')
  })

  it('U-PVM-005 should close detail dialog and notify refresh', 0, () => {
    const record = createConnectionRecord('record-1', 1700000000000)
    fakeRecords.state.records = [record]
    fakeRecords.openConnectionDetailDialog(record)

    viewModel.closeConnectionDetailDialog()

    expect(fakeRecords.state.connectionDetailDialog.visible).assertFalse()
  })

  it('U-PVM-007 should keep current detail state when clear history fails', 0, async (done: Function) => {
    fakeRecords.state.records = [createConnectionRecord('record-1', 1700000000000)]
    fakeRecords.nextRecords = []
    fakeRecords.openConnectionDetailDialog(fakeRecords.state.records[0])

    const result = await viewModel.clearConnectionHistory()

    expect(result).assertFalse()
    expect(fakeRecords.state.connectionDetailDialog.visible).assertTrue()
    expect(fakeRecords.reloadCount).assertEqual(0)
    expect(fakePolicy.reloadCount).assertEqual(0)
    expect(fakeRecords.state.records.length).assertEqual(1)
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

  it('U-PVM-010 should refresh records only when trace listener fires', 0, async (done: Function) => {
    fakeRecords.nextRecords = [createConnectionRecord('record-1', 1700000000000)]

    await viewModel.initialize({} as common.UIAbilityContext)
    fakeRecords.reloadCount = 0
    fakePolicy.reloadCount = 0

    if (traceListener) {
      traceListener()
    }
    await flushAsyncWork()

    expect(fakeRecords.reloadCount).assertEqual(1)
    expect(fakePolicy.reloadCount).assertEqual(0)
    done()
  })

  it('U-PVM-011 should refresh policy only when device policy listener fires', 0, async (done: Function) => {
    fakeRecords.nextRecords = [createConnectionRecord('record-1', 1700000000000)]
    fakePolicy.nextHasRestorableRecords = true

    await viewModel.initialize({} as common.UIAbilityContext)
    fakeRecords.reloadCount = 0
    fakePolicy.reloadCount = 0
    fakePolicy.nextHasRestorableRecords = false

    if (devicePolicyListener) {
      devicePolicyListener()
    }
    await flushAsyncWork()

    expect(fakeRecords.reloadCount).assertEqual(0)
    expect(fakePolicy.reloadCount).assertEqual(1)
    expect(viewModel.hasRestorablePolicyRecords()).assertFalse()
    done()
  })

  it('should keep basic defaults and admin check behavior stable', 0, async (done: Function) => {
    const ready = viewModel.ensureAdminReady()

    expect(fakeRecords.state.connectionDetailDialog.visible).assertFalse()
    expect(ready).assertFalse()
    expect(viewModel.reasonCode).assertEqual(PeripheralReasonCodes.ADMIN_REQUIRED)
    done()
  })

  it('should map connection history export result into page reason state', 0, async (done: Function) => {
    fakeRecords.exportResult = new FakeExportResult(false, undefined, PeripheralReasonCodes.EXPORT_CONNECTION_HISTORY_FAILED)

    let result = await viewModel.exportConnectionHistory()

    expect(result.success).assertFalse()
    expect(viewModel.reasonCode).assertEqual(PeripheralReasonCodes.EXPORT_CONNECTION_HISTORY_FAILED)
    done()
  })

  it('should map policy export success without polluting failure reason', 0, async (done: Function) => {
    viewModel.reasonCode = PeripheralReasonCodes.EXPORT_POLICY_RECORDS_FAILED
    fakePolicy.exportResult = new FakeExportResult(true, 'peripheral_policy_records.csv')

    let result = await viewModel.exportPeripheralPolicyRecords()

    expect(result.success).assertTrue()
    expect(result.fileName).assertEqual('peripheral_policy_records.csv')
    expect(viewModel.reasonCode).assertNull()
    done()
  })

  it('should disable policy restore when records are all allow', 0, async () => {
    fakePolicy.state.records = [
      createPolicyRecord(PeripheralPolicyOptionIndexes.ALLOW)
    ]
    fakePolicy.state.hasRestorableRecords = false

    expect(viewModel.hasRestorablePolicyRecords()).assertFalse()

    let result = await viewModel.clearPeripheralPolicyRecords()

    expect(result).assertTrue()
    expect(fakePolicy.clearCount).assertEqual(0)
  })

  it('should enable policy restore when any record is denied', 0, async () => {
    fakePolicy.state.records = [
      createPolicyRecord(PeripheralPolicyOptionIndexes.ALLOW),
      createPolicyRecord(PeripheralPolicyOptionIndexes.DENY)
    ]
    fakePolicy.state.hasRestorableRecords = true
    fakePolicy.nextHasRestorableRecords = false

    expect(viewModel.hasRestorablePolicyRecords()).assertTrue()

    let result = await viewModel.clearPeripheralPolicyRecords()

    expect(result).assertTrue()
    expect(fakePolicy.clearCount).assertEqual(1)
    expect(fakePolicy.reloadCount).assertEqual(1)
    expect(viewModel.hasRestorablePolicyRecords()).assertFalse()
  })
  })
}
