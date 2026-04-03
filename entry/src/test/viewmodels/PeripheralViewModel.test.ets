import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import {
  AdminActivationState,
  LogEventResult,
  PeripheralConnectionRecord,
  PeripheralTraceRecord,
  PeripheralType
} from '../../main/ets/models/DataModels'
import { PeripheralStrings } from '../../main/ets/constants/modules/PeripheralStrings'
import { EnterpriseAdminService } from '../../main/ets/services/EnterpriseAdminService'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/PeripheralDevicePolicyRepository'
import { PeripheralTraceRepository } from '../../main/ets/services/PeripheralTraceRepository'
import { PeripheralViewModel } from '../../main/ets/viewmodels/PeripheralViewModel'
import { PeripheralConnectionRecordClearUsecase } from '../../main/ets/viewmodels/peripheral/connection-record/peripheral_connection_record_clear_usecase'

function createAdminState(activated: boolean): AdminActivationState {
  return {
    activated,
    enableCommand: 'mock enable-admin',
    adminType: EnterpriseAdminService.DEFAULT_ADMIN_TYPE
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
  let originalTraceInit: (context: common.UIAbilityContext) => Promise<boolean>
  let originalTraceClearAll: () => Promise<boolean>

  beforeEach(() => {
    usecase = new PeripheralConnectionRecordClearUsecase()
    originalTraceInit = PeripheralTraceRepository.init
    originalTraceClearAll = PeripheralTraceRepository.clearAll
    PeripheralTraceRepository.resetForTest()
  })

  afterEach(() => {
    PeripheralTraceRepository.init = originalTraceInit
    PeripheralTraceRepository.clearAll = originalTraceClearAll
    PeripheralTraceRepository.resetForTest()
  })

  it('U-CLEAR-001 should return false when context is null', 0, async (done: Function) => {
    const result = await usecase.execute(null)

    expect(result).assertFalse()
    done()
  })

  it('U-CLEAR-002 should return false when trace repository init fails', 0, async (done: Function) => {
    PeripheralTraceRepository.init = async (_context: common.UIAbilityContext): Promise<boolean> => false

    const result = await usecase.execute({} as common.UIAbilityContext)

    expect(result).assertFalse()
    done()
  })

  it('U-CLEAR-003 should return true when init and clearAll both succeed', 0, async (done: Function) => {
    let clearAllCalled = 0
    PeripheralTraceRepository.init = async (_context: common.UIAbilityContext): Promise<boolean> => true
    PeripheralTraceRepository.clearAll = async (): Promise<boolean> => {
      clearAllCalled++
      return true
    }

    const result = await usecase.execute({} as common.UIAbilityContext)

    expect(result).assertTrue()
    expect(clearAllCalled).assertEqual(1)
    done()
  })

  it('U-CLEAR-004 should return false when clearAll throws', 0, async (done: Function) => {
    PeripheralTraceRepository.init = async (_context: common.UIAbilityContext): Promise<boolean> => true
    PeripheralTraceRepository.clearAll = async (): Promise<boolean> => {
      throw new Error('clear failed')
    }

    const result = await usecase.execute({} as common.UIAbilityContext)

    expect(result).assertFalse()
    done()
  })
})

describe('PeripheralViewModel', () => {
  let viewModel: PeripheralViewModel
  let originalProbeActivation: (adminType?: any) => AdminActivationState
  let originalTraceAddChangeListener: (listener: (event: Object) => void) => number
  let originalTraceRemoveChangeListener: (listenerId: number) => void
  let originalTraceInit: (context: common.UIAbilityContext) => Promise<boolean>
  let originalTraceClearAll: () => Promise<boolean>
  let originalPolicyAddChangeListener: (listener: (event: Object) => void) => number
  let originalPolicyRemoveChangeListener: (listenerId: number) => void

  beforeEach(() => {
    viewModel = new PeripheralViewModel()
    originalProbeActivation = EnterpriseAdminService.probeActivation
    originalTraceAddChangeListener = PeripheralTraceRepository.addChangeListener
    originalTraceRemoveChangeListener = PeripheralTraceRepository.removeChangeListener
    originalTraceInit = PeripheralTraceRepository.init
    originalTraceClearAll = PeripheralTraceRepository.clearAll
    originalPolicyAddChangeListener = PeripheralDevicePolicyRepository.addChangeListener
    originalPolicyRemoveChangeListener = PeripheralDevicePolicyRepository.removeChangeListener
    PeripheralTraceRepository.resetForTest()
    PeripheralDevicePolicyRepository.resetForTest()
  })

  afterEach(() => {
    EnterpriseAdminService.probeActivation = originalProbeActivation
    PeripheralTraceRepository.addChangeListener = originalTraceAddChangeListener
    PeripheralTraceRepository.removeChangeListener = originalTraceRemoveChangeListener
    PeripheralTraceRepository.init = originalTraceInit
    PeripheralTraceRepository.clearAll = originalTraceClearAll
    PeripheralDevicePolicyRepository.addChangeListener = originalPolicyAddChangeListener
    PeripheralDevicePolicyRepository.removeChangeListener = originalPolicyRemoveChangeListener
    PeripheralTraceRepository.resetForTest()
    PeripheralDevicePolicyRepository.resetForTest()
  })

  it('U-PVM-001 should initialize successfully, reload child data and register listeners', 0, async (done: Function) => {
    let traceListener: ((event: Object) => void) | null = null
    let policyListener: ((event: Object) => void) | null = null
    let removedTraceId = -1
    let removedPolicyId = -1
    let policyInitializeCount = 0
    let interfaceReloadCount = 0
    let recordsReloadCount = 0
    let policyReloadCount = 0
    EnterpriseAdminService.probeActivation = (_adminType?: any): AdminActivationState => createAdminState(true)
    viewModel.policy.initialize = async (_context: common.UIAbilityContext): Promise<boolean> => {
      policyInitializeCount++
      return true
    }
    viewModel.interfaceControl.reloadState = (): void => {
      interfaceReloadCount++
    }
    viewModel.records.reloadRecords = (): void => {
      recordsReloadCount++
      viewModel.records.records = [createConnectionRecord('record-1', 1700000000000)]
    }
    viewModel.policy.reloadRecords = (records: PeripheralConnectionRecord[]): void => {
      policyReloadCount++
      expect(records.length).assertEqual(1)
    }
    PeripheralTraceRepository.addChangeListener = (listener: (event: Object) => void): number => {
      traceListener = listener
      return 101
    }
    PeripheralTraceRepository.removeChangeListener = (listenerId: number): void => {
      removedTraceId = listenerId
    }
    PeripheralDevicePolicyRepository.addChangeListener = (listener: (event: Object) => void): number => {
      policyListener = listener
      return 202
    }
    PeripheralDevicePolicyRepository.removeChangeListener = (listenerId: number): void => {
      removedPolicyId = listenerId
    }

    await viewModel.initialize({} as common.UIAbilityContext)

    expect(policyInitializeCount).assertEqual(1)
    expect(interfaceReloadCount).assertEqual(1)
    expect(recordsReloadCount).assertEqual(1)
    expect(policyReloadCount).assertEqual(1)
    expect(viewModel.reasonCode).assertNull()
    expect(viewModel.isLoading).assertFalse()
    expect(traceListener !== null).assertTrue()
    expect(policyListener !== null).assertTrue()

    viewModel.destroy()
    expect(removedTraceId).assertEqual(101)
    expect(removedPolicyId).assertEqual(202)
    done()
  })

  it('U-PVM-002 should expose init_failed when initialize throws', 0, async (done: Function) => {
    viewModel.policy.initialize = async (_context: common.UIAbilityContext): Promise<boolean> => {
      throw new Error('init failed')
    }

    await viewModel.initialize({} as common.UIAbilityContext)

    expect(viewModel.reasonCode).assertEqual(PeripheralStrings.initFailed)
    expect(viewModel.isLoading).assertFalse()
    done()
  })

  it('U-PVM-003 should reload device records, sync policy records and notify refresh', 0, () => {
    let recordsReloadCount = 0
    let policyReloadCount = 0
    let refreshCount = 0
    viewModel.onRefresh = () => {
      refreshCount++
    }
    viewModel.records.reloadRecords = (): void => {
      recordsReloadCount++
      viewModel.records.records = [createConnectionRecord('record-1', 1700000000000)]
    }
    viewModel.policy.reloadRecords = (records: PeripheralConnectionRecord[]): void => {
      policyReloadCount++
      expect(records.length).assertEqual(1)
    }

    viewModel.reloadDeviceRecords()

    expect(recordsReloadCount).assertEqual(1)
    expect(policyReloadCount).assertEqual(1)
    expect(refreshCount).assertEqual(1)
  })

  it('U-PVM-004 should open detail dialog and notify refresh', 0, () => {
    let refreshCount = 0
    const record = createConnectionRecord('record-1', 1700000000000)
    viewModel.records.records = [record]
    viewModel.onRefresh = () => {
      refreshCount++
    }

    viewModel.openConnectionDetailDialog(record)

    expect(viewModel.records.connectionDetailDialog.visible).assertTrue()
    expect(viewModel.records.connectionDetailDialog.record?.id ?? '').assertEqual('record-1')
    expect(refreshCount).assertEqual(1)
  })

  it('U-PVM-005 should close detail dialog and notify refresh', 0, () => {
    let refreshCount = 0
    const record = createConnectionRecord('record-1', 1700000000000)
    viewModel.records.records = [record]
    viewModel.records.openConnectionDetailDialog(record)
    viewModel.onRefresh = () => {
      refreshCount++
    }

    viewModel.closeConnectionDetailDialog()

    expect(viewModel.records.connectionDetailDialog.visible).assertFalse()
    expect(refreshCount).assertEqual(1)
  })

  it('U-PVM-006 should clear history successfully, close detail dialog and reload records', 0, async (done: Function) => {
    let recordsReloadCount = 0
    let policyReloadCount = 0
    viewModel.policy.initialize = async (_context: common.UIAbilityContext): Promise<boolean> => true
    viewModel.interfaceControl.reloadState = (): void => {}
    viewModel.records.reloadRecords = (): void => {}
    viewModel.policy.reloadRecords = (_records: PeripheralConnectionRecord[]): void => {}
    PeripheralTraceRepository.addChangeListener = (_listener: (event: Object) => void): number => 11
    PeripheralDevicePolicyRepository.addChangeListener = (_listener: (event: Object) => void): number => 22
    await viewModel.initialize({} as common.UIAbilityContext)

    viewModel.records.records = [createConnectionRecord('record-1', 1700000000000)]
    viewModel.openConnectionDetailDialog(viewModel.records.records[0])
    viewModel.records.reloadRecords = (): void => {
      recordsReloadCount++
      viewModel.records.records = []
    }
    viewModel.policy.reloadRecords = (_records: PeripheralConnectionRecord[]): void => {
      policyReloadCount++
    }
    PeripheralTraceRepository.init = async (_context: common.UIAbilityContext): Promise<boolean> => true
    PeripheralTraceRepository.clearAll = async (): Promise<boolean> => true

    const result = await viewModel.clearConnectionHistory()

    expect(result).assertTrue()
    expect(viewModel.records.connectionDetailDialog.visible).assertFalse()
    expect(viewModel.records.records.length).assertEqual(0)
    expect(recordsReloadCount).assertEqual(1)
    expect(policyReloadCount).assertEqual(1)
    done()
  })

  it('U-PVM-007 should keep current detail state when clear history fails', 0, async (done: Function) => {
    let recordsReloadCount = 0
    let policyReloadCount = 0
    viewModel.policy.initialize = async (_context: common.UIAbilityContext): Promise<boolean> => true
    viewModel.interfaceControl.reloadState = (): void => {}
    viewModel.records.reloadRecords = (): void => {}
    viewModel.policy.reloadRecords = (_records: PeripheralConnectionRecord[]): void => {}
    PeripheralTraceRepository.addChangeListener = (_listener: (event: Object) => void): number => 11
    PeripheralDevicePolicyRepository.addChangeListener = (_listener: (event: Object) => void): number => 22
    await viewModel.initialize({} as common.UIAbilityContext)

    viewModel.records.records = [createConnectionRecord('record-1', 1700000000000)]
    viewModel.openConnectionDetailDialog(viewModel.records.records[0])
    viewModel.records.reloadRecords = (): void => {
      recordsReloadCount++
    }
    viewModel.policy.reloadRecords = (_records: PeripheralConnectionRecord[]): void => {
      policyReloadCount++
    }
    PeripheralTraceRepository.init = async (_context: common.UIAbilityContext): Promise<boolean> => false

    const result = await viewModel.clearConnectionHistory()

    expect(result).assertFalse()
    expect(viewModel.records.connectionDetailDialog.visible).assertTrue()
    expect(viewModel.records.records.length).assertEqual(1)
    expect(recordsReloadCount).assertEqual(0)
    expect(policyReloadCount).assertEqual(0)
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
    let traceListener: ((event: Object) => void) | null = null
    let recordsReloadCount = 0
    let policyReloadCount = 0
    let refreshCount = 0
    viewModel.onRefresh = () => {
      refreshCount++
    }
    viewModel.policy.initialize = async (_context: common.UIAbilityContext): Promise<boolean> => true
    viewModel.interfaceControl.reloadState = (): void => {}
    viewModel.records.reloadRecords = (): void => {
      recordsReloadCount++
      viewModel.records.records = [createConnectionRecord('record-1', 1700000000000)]
    }
    viewModel.policy.reloadRecords = (_records: PeripheralConnectionRecord[]): void => {
      policyReloadCount++
    }
    PeripheralTraceRepository.addChangeListener = (listener: (event: Object) => void): number => {
      traceListener = listener
      return 11
    }
    PeripheralDevicePolicyRepository.addChangeListener = (_listener: (event: Object) => void): number => 22

    await viewModel.initialize({} as common.UIAbilityContext)
    recordsReloadCount = 0
    policyReloadCount = 0
    refreshCount = 0
    traceListener?.({ totalCount: 1, addedCount: 1, timestamp: Date.now() })

    expect(recordsReloadCount).assertEqual(1)
    expect(policyReloadCount).assertEqual(1)
    expect(refreshCount).assertEqual(1)
    done()
  })

  it('U-PVM-011 should refresh policy only when device policy listener fires', 0, async (done: Function) => {
    let policyListener: ((event: Object) => void) | null = null
    let recordsReloadCount = 0
    let policyReloadCount = 0
    let refreshCount = 0
    viewModel.onRefresh = () => {
      refreshCount++
    }
    viewModel.policy.initialize = async (_context: common.UIAbilityContext): Promise<boolean> => true
    viewModel.interfaceControl.reloadState = (): void => {}
    viewModel.records.reloadRecords = (): void => {
      recordsReloadCount++
      viewModel.records.records = [createConnectionRecord('record-1', 1700000000000)]
    }
    viewModel.policy.reloadRecords = (_records: PeripheralConnectionRecord[]): void => {
      policyReloadCount++
    }
    PeripheralTraceRepository.addChangeListener = (_listener: (event: Object) => void): number => 11
    PeripheralDevicePolicyRepository.addChangeListener = (listener: (event: Object) => void): number => {
      policyListener = listener
      return 22
    }

    await viewModel.initialize({} as common.UIAbilityContext)
    recordsReloadCount = 0
    policyReloadCount = 0
    refreshCount = 0
    policyListener?.({ totalCount: 1, timestamp: Date.now() })

    expect(recordsReloadCount).assertEqual(0)
    expect(policyReloadCount).assertEqual(1)
    expect(refreshCount).assertEqual(1)
    done()
  })

  it('should keep basic defaults and admin check behavior stable', 0, () => {
    EnterpriseAdminService.probeActivation = (_adminType?: any): AdminActivationState => createAdminState(false)
    PeripheralTraceRepository.setRecordsForTest([createTraceRecord('trace-1', 1700000000000)])
    PeripheralDevicePolicyRepository.setRecordsForTest([])

    const ready = viewModel.ensureAdminReady()

    expect(viewModel.records.connectionDetailDialog.visible).assertFalse()
    expect(ready).assertFalse()
    expect(viewModel.reasonCode).assertEqual(PeripheralStrings.adminRequired)
  })
})
