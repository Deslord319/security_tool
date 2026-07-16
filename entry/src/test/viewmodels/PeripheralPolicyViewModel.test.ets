import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { usbManager } from '@kit.MDMKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import {
  PeripheralType,
  UsbDevicePolicyStateRecord
} from '../../main/ets/models/PeripheralModels'
import {
  PeripheralDevicePolicyDispatchService,
  PeripheralPolicyDispatchRequest,
  PeripheralPolicyDispatchResult
} from '../../main/ets/services/peripheral/device-policy/PeripheralDevicePolicyDispatchService'
import {
  CsvFileExportService
} from '../../main/ets/services/common/export/CsvFileExportService'
import { createSuccessfulCsvFileExportResult } from '../common/CsvExportResultFactory'
import { PeripheralPolicyViewModel } from '../../main/ets/viewmodels/peripheral/device-policy/PeripheralPolicyViewModel'
import { PeripheralPolicySnapshotTraceService } from '../../main/ets/services/peripheral/connection-record/PeripheralPolicySnapshotTraceService'
import { PeripheralTraceMutationResult } from '../../main/ets/services/peripheral/connection-record/PeripheralTraceMaintenanceService'
import { UsbDevicePolicyStateRepository } from '../../main/ets/services/peripheral/device-policy/UsbDevicePolicyStateRepository'
import { UsbDevicePolicyStateService } from '../../main/ets/services/peripheral/device-policy/UsbDevicePolicyStateService'
import { PeripheralService } from '../../main/ets/services/peripheral/interface-control/PeripheralService'
import { OperationResult } from '../../main/ets/models/CommonModels'

function cloneUsbState(record: UsbDevicePolicyStateRecord): UsbDevicePolicyStateRecord {
  return {
    fingerprintKey: record.fingerprintKey,
    fingerprintType: record.fingerprintType,
    serialNumber: record.serialNumber,
    vendorId: record.vendorId,
    productId: record.productId,
    description: record.description,
    baseClass: record.baseClass,
    deviceName: record.deviceName,
    desiredPolicy: record.desiredPolicy,
    present: record.present,
    activePolicy: record.activePolicy,
    lastSeenAt: record.lastSeenAt,
    updatedAt: record.updatedAt
  }
}

function createDispatchResult(success: boolean, reason?: string): PeripheralPolicyDispatchResult {
  let result: PeripheralPolicyDispatchResult = {
    success: success
  }
  if (reason !== undefined) {
    result.reason = reason as never
  }
  return result
}

function createTraceMutationResult(): PeripheralTraceMutationResult {
  return { success: true, code: 'ok' } as PeripheralTraceMutationResult
}

export default function peripheralPolicyViewModelTest() {
  describe('PeripheralPolicyViewModel', () => {
    let viewModel: PeripheralPolicyViewModel
    let mockKit: MockKit
    let usbStates: UsbDevicePolicyStateRecord[]
    let usbStoragePolicy: usbManager.UsbPolicy
    let clearPolicyCalls: number

    beforeEach(async () => {
      viewModel = new PeripheralPolicyViewModel()
      mockKit = new MockKit()
      usbStates = []
      usbStoragePolicy = usbManager.UsbPolicy.READ_WRITE
      clearPolicyCalls = 0
      let listUsbStateMock = mockKit.mockFunc(UsbDevicePolicyStateRepository, UsbDevicePolicyStateRepository.listAll)
      let getUsbStateMock = mockKit.mockFunc(UsbDevicePolicyStateRepository, UsbDevicePolicyStateRepository.get)
      let setUsbStatePolicyMock = mockKit.mockFunc(UsbDevicePolicyStateService, UsbDevicePolicyStateService.setPolicy)
      let clearUsbStatePoliciesMock = mockKit.mockFunc(UsbDevicePolicyStateService, UsbDevicePolicyStateService.clearAllPolicies)
      let dispatchMock = mockKit.mockFunc(PeripheralDevicePolicyDispatchService, PeripheralDevicePolicyDispatchService.dispatch)
      let hasDisallowedUsbTypesMock = mockKit.mockFunc(
        PeripheralDevicePolicyDispatchService,
        PeripheralDevicePolicyDispatchService.hasDisallowedUsbDeviceTypePolicies
      )
      let getUsbStoragePolicyMock = mockKit.mockFunc(
        PeripheralService,
        PeripheralService.getUsbStoragePolicyWithResult
      )
      let getUsbGlobalPolicyMock = mockKit.mockFunc(
        PeripheralService,
        PeripheralService.getInterfaceDisabledWithResult
      )
      let appendSnapshotMock = mockKit.mockFunc(
        PeripheralPolicySnapshotTraceService,
        PeripheralPolicySnapshotTraceService.appendDevicePolicySnapshot
      )

      when(listUsbStateMock)().afterAction(() => Promise.resolve(
        usbStates.map((item: UsbDevicePolicyStateRecord) => cloneUsbState(item))
      ))
      when(getUsbStateMock)(ArgumentMatchers.any).afterAction((fingerprintKey: string) => {
        let found = usbStates.find((item: UsbDevicePolicyStateRecord) => item.fingerprintKey === fingerprintKey)
        return Promise.resolve(found ? cloneUsbState(found) : null)
      })
      when(setUsbStatePolicyMock)(ArgumentMatchers.any).afterAction((fingerprintKey: string, policy: 'allow' | 'deny') => {
        let index = usbStates.findIndex((item: UsbDevicePolicyStateRecord) => item.fingerprintKey === fingerprintKey)
        if (index >= 0) {
          usbStates[index].desiredPolicy = policy
          usbStates[index].activePolicy = policy === 'deny' ? 'deny' : 'none'
        }
        return Promise.resolve(createDispatchResult(index >= 0, index >= 0 ? undefined : 'usb_dispatch_failed'))
      })
      when(clearUsbStatePoliciesMock)().afterAction(() => {
        clearPolicyCalls += 1
        usbStates = usbStates.map((item: UsbDevicePolicyStateRecord) => {
          let next = cloneUsbState(item)
          next.desiredPolicy = 'allow'
          next.activePolicy = 'none'
          return next
        })
        return Promise.resolve(true)
      })
      when(dispatchMock)(ArgumentMatchers.any).afterReturn(createDispatchResult(true))
      when(hasDisallowedUsbTypesMock)().afterReturn(false)
      when(getUsbStoragePolicyMock)().afterAction(() => {
        return { success: true, data: usbStoragePolicy } as OperationResult<usbManager.UsbPolicy>
      })
      when(getUsbGlobalPolicyMock)(ArgumentMatchers.any).afterReturn({
        success: true,
        data: false
      } as OperationResult<boolean>)
      when(appendSnapshotMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(createTraceMutationResult()))
    })

    afterEach(async () => {
      mockKit.clearAll()
    })

    it('should rebuild usb policy records from usb policy state records', 0, async () => {
      usbStates = [{
        fingerprintKey: 'USB-WEAK:1234:5678:ABCDEF01',
        fingerprintType: 'weak',
        vendorId: 0x1234,
        productId: 0x5678,
        description: 'storage',
        baseClass: 0x08,
        deviceName: 'USB Device',
        desiredPolicy: 'deny',
        present: true,
        activePolicy: 'deny',
        lastSeenAt: 200,
        updatedAt: 201
      }]

      await viewModel.reloadRecords()

      expect(viewModel.state.records.length).assertEqual(1)
      expect(viewModel.state.records[0].policyIndex).assertEqual(1)
      expect(viewModel.state.records[0].deviceId).assertEqual('USB-WEAK:1234:5678:ABCDEF01')
      expect(viewModel.state.hasRestorableRecords).assertTrue()

      usbStates = []
      await viewModel.reloadRecords()

      expect(viewModel.state.hasRestorableRecords).assertFalse()
      expect(viewModel.state.records.length).assertEqual(0)
    })

    it('should not expose connection records as policy candidates', 0, async () => {
      await viewModel.reloadRecords()

      expect(viewModel.state.records.length).assertEqual(0)
    })

    it('should expose usb policy state as default allow', 0, async () => {
      usbStates = [{
        fingerprintKey: 'USB-WEAK:1234:5678:ABCDEF01',
        fingerprintType: 'weak',
        vendorId: 0x1234,
        productId: 0x5678,
        description: 'storage',
        baseClass: 0x08,
        deviceName: 'USB Device',
        desiredPolicy: 'allow',
        present: true,
        activePolicy: 'none',
        lastSeenAt: 300,
        updatedAt: 301
      }]
      await viewModel.reloadRecords()

      expect(viewModel.state.records.length).assertEqual(1)
      expect(viewModel.state.records[0].policyIndex).assertEqual(0)
      expect(viewModel.state.hasRestorableRecords).assertFalse()
    })

    it('should keep desired policy visible and disable editing when storage access is disabled', 0, async () => {
      usbStoragePolicy = usbManager.UsbPolicy.DISABLED
      usbStates = [{
        fingerprintKey: 'USB-WEAK:1234:5678:ABCDEF01',
        fingerprintType: 'weak',
        vendorId: 0x1234,
        productId: 0x5678,
        description: 'storage',
        baseClass: 0x08,
        deviceName: 'USB Device',
        desiredPolicy: 'allow',
        present: true,
        activePolicy: 'none',
        lastSeenAt: 300,
        updatedAt: 301
      }]

      await viewModel.reloadRecords()

      expect(viewModel.state.records[0].editable).assertFalse()
      expect(viewModel.state.records[0].policyIndex).assertEqual(0)
    })

    it('should prefer the confirmed storage target state over an immediate stale system read', 0, async () => {
      usbStoragePolicy = usbManager.UsbPolicy.DISABLED
      usbStates = [{
        fingerprintKey: 'USB-WEAK:1234:5678:ABCDEF01',
        fingerprintType: 'weak',
        vendorId: 0x1234,
        productId: 0x5678,
        description: 'storage',
        baseClass: 0x08,
        deviceName: 'USB Device',
        desiredPolicy: 'allow',
        present: true,
        activePolicy: 'none',
        lastSeenAt: 300,
        updatedAt: 301
      }]

      await viewModel.reloadRecords(false)

      expect(viewModel.state.records[0].editable).assertTrue()
      expect(viewModel.state.records[0].policyIndex).assertEqual(0)
    })

    it('should reject invalid device ids when changing policy', 0, async () => {
      const reason = await viewModel.setDevicePolicy('', PeripheralType.USB_STORAGE, 0)
      expect(reason).assertEqual('invalid_device_id')
    })

    it('should reject bluetooth device policies without saving local policy', 0, async () => {
      const reason = await viewModel.setDevicePolicy(
        'MAC: AA:BB:CC:DD:EE:FF',
        PeripheralType.BLUETOOTH,
        1
      )

      expect(reason).assertEqual('unsupported_device_type')
      expect(usbStates.length).assertEqual(0)
    })

    it('should reject legacy VID PID policy ids', 0, async () => {
      const reason = await viewModel.setDevicePolicy(
        'VID:1234 PID:5678',
        PeripheralType.USB_STORAGE,
        1
      )

      expect(reason).assertEqual('invalid_device_id')
    })

    it('should persist usb state deny policy', 0, async () => {
      usbStates = [{
        fingerprintKey: 'USB-WEAK:1234:5678:ABCDEF01',
        fingerprintType: 'weak',
        vendorId: 0x1234,
        productId: 0x5678,
        description: 'storage',
        baseClass: 0x08,
        deviceName: 'USB Device',
        desiredPolicy: 'allow',
        present: true,
        activePolicy: 'none',
        lastSeenAt: 300,
        updatedAt: 301
      }]

      const reason = await viewModel.setDevicePolicy(
        'USB-WEAK:1234:5678:ABCDEF01',
        PeripheralType.USB_STORAGE,
        1
      )

      expect(reason).assertNull()
      expect(usbStates[0].desiredPolicy).assertEqual('deny')
    })

    it('should restore all usb policy states to default allow', 0, async () => {
      usbStates = [{
        fingerprintKey: 'USB-WEAK:1234:5678:ABCDEF01',
        fingerprintType: 'weak',
        vendorId: 0x1234,
        productId: 0x5678,
        description: 'storage',
        baseClass: 0x08,
        deviceName: 'USB Device',
        desiredPolicy: 'deny',
        present: true,
        activePolicy: 'deny',
        lastSeenAt: 300,
        updatedAt: 301
      }]

      const success = await viewModel.clearAllPolicies()
      expect(success).assertTrue()
      expect(usbStates.length).assertEqual(1)
      expect(usbStates[0].desiredPolicy).assertEqual('allow')
      expect(usbStates[0].activePolicy).assertEqual('none')
    })

    it('should clear system usb policies even when local policy records are empty', 0, async () => {
      const success = await viewModel.clearAllPolicies()

      expect(success).assertTrue()
      expect(clearPolicyCalls).assertEqual(1)
    })

    it('should return false when clearing usb policy states fails', 0, async () => {
      usbStates = [{
        fingerprintKey: 'USB-WEAK:1234:5678:ABCDEF01',
        fingerprintType: 'weak',
        vendorId: 0x1234,
        productId: 0x5678,
        description: 'storage',
        baseClass: 0x08,
        deviceName: 'USB Device',
        desiredPolicy: 'deny',
        present: true,
        activePolicy: 'deny',
        lastSeenAt: 300,
        updatedAt: 301
      }]
      let clearUsbStatePoliciesMock = mockKit.mockFunc(UsbDevicePolicyStateService, UsbDevicePolicyStateService.clearAllPolicies)
      when(clearUsbStatePoliciesMock)().afterReturn(Promise.resolve(false))

      const success = await viewModel.clearAllPolicies()
      expect(success).assertFalse()
    })

    it('should export policy records successfully', 0, async () => {
      viewModel.state.records = [{
        deviceName: 'USB Device',
        deviceType: PeripheralType.USB_STORAGE,
        deviceId: 'VID:1234 PID:5678',
        lastSeenAt: Date.now(),
        lastSeenLabel: '2026-03-26 12:00:00',
        policyIndex: 0
      }]
      let exportMock = mockKit.mockFunc(CsvFileExportService, CsvFileExportService.saveText)
      when(exportMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(createSuccessfulCsvFileExportResult(
        'peripheral_policy_list_20260326_120000.csv',
        '/mock/peripheral_policy_list_20260326_120000.csv'
      )))

      const result = await viewModel.exportRecords({} as common.UIAbilityContext)
      expect(result.success).assertTrue()
    })
  })
}
