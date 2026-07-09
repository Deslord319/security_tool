import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { SecurityEventResult } from '../../main/ets/models/CommonModels'
import {
  PeripheralDevicePolicyRecord,
  PeripheralType,
  UsbDevicePolicyStateRecord
} from '../../main/ets/models/PeripheralModels'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/peripheral/device-policy/PeripheralDevicePolicyRepository'
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

function clonePolicyRecord(record: PeripheralDevicePolicyRecord): PeripheralDevicePolicyRecord {
  let cloned: PeripheralDevicePolicyRecord = {
    deviceId: record.deviceId,
    policy: record.policy,
    updatedAt: record.updatedAt
  }
  if (record.deviceName !== undefined) {
    cloned.deviceName = record.deviceName
  }
  if (record.deviceType !== undefined) {
    cloned.deviceType = record.deviceType
  }
  return cloned
}

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
    let records: PeripheralDevicePolicyRecord[]
    let usbStates: UsbDevicePolicyStateRecord[]

    beforeEach(async () => {
      viewModel = new PeripheralPolicyViewModel()
      mockKit = new MockKit()
      records = []
      usbStates = []
      let getAllMock = mockKit.mockFunc(PeripheralDevicePolicyRepository, PeripheralDevicePolicyRepository.getAll)
      let getMock = mockKit.mockFunc(PeripheralDevicePolicyRepository, PeripheralDevicePolicyRepository.get)
      let setMock = mockKit.mockFunc(PeripheralDevicePolicyRepository, PeripheralDevicePolicyRepository.set)
      let clearAllMock = mockKit.mockFunc(PeripheralDevicePolicyRepository, PeripheralDevicePolicyRepository.clearAll)
      let listUsbStateMock = mockKit.mockFunc(UsbDevicePolicyStateRepository, UsbDevicePolicyStateRepository.listAll)
      let getUsbStateMock = mockKit.mockFunc(UsbDevicePolicyStateRepository, UsbDevicePolicyStateRepository.get)
      let setUsbStatePolicyMock = mockKit.mockFunc(UsbDevicePolicyStateService, UsbDevicePolicyStateService.setPolicy)
      let clearUsbStatePoliciesMock = mockKit.mockFunc(UsbDevicePolicyStateService, UsbDevicePolicyStateService.clearAllPolicies)
      let clearUsbStateMock = mockKit.mockFunc(UsbDevicePolicyStateRepository, UsbDevicePolicyStateRepository.clearAll)
      let dispatchMock = mockKit.mockFunc(PeripheralDevicePolicyDispatchService, PeripheralDevicePolicyDispatchService.dispatch)
      let appendSnapshotMock = mockKit.mockFunc(
        PeripheralPolicySnapshotTraceService,
        PeripheralPolicySnapshotTraceService.appendDevicePolicySnapshot
      )

      when(getAllMock)().afterAction(() => {
        return records.map((item: PeripheralDevicePolicyRecord) => clonePolicyRecord(item))
      })
      when(getMock)(ArgumentMatchers.any).afterAction((deviceId: string) => {
        let found = records.find((item: PeripheralDevicePolicyRecord) => item.deviceId === deviceId)
        return found ? clonePolicyRecord(found) : null
      })
      when(setMock)(ArgumentMatchers.any).afterAction((record: PeripheralDevicePolicyRecord) => {
        let index = records.findIndex((item: PeripheralDevicePolicyRecord) => item.deviceId === record.deviceId)
        if (index >= 0) {
          records[index] = clonePolicyRecord(record)
        } else {
          records = [clonePolicyRecord(record)].concat(records)
        }
        return Promise.resolve(true)
      })
      when(clearAllMock)().afterAction(() => {
        records = []
        return Promise.resolve(true)
      })
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
        usbStates = []
        return Promise.resolve(true)
      })
      when(clearUsbStateMock)().afterReturn(Promise.resolve(true))
      when(dispatchMock)(ArgumentMatchers.any).afterReturn(createDispatchResult(true))
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

      await viewModel.reloadRecords([{
        id: 'record-1',
        timestamp: 200,
        deviceId: 'VID:1234 PID:5678',
        deviceName: 'USB Device',
        deviceType: PeripheralType.USB_STORAGE,
        source: 'runtime_event',
        action: 'connect',
        result: SecurityEventResult.SUCCESS,
        policyHit: 'allow',
        summary: 'connected'
      }])

      expect(viewModel.state.records.length).assertEqual(1)
      expect(viewModel.state.records[0].policyIndex).assertEqual(1)
      expect(viewModel.state.records[0].deviceId).assertEqual('USB-WEAK:1234:5678:ABCDEF01')
    })

    it('should not expose connection records as policy candidates', 0, async () => {
      await viewModel.reloadRecords([{
        id: 'record-usb-1',
        timestamp: 300,
        deviceId: 'VID:1234 PID:5678',
        deviceName: 'USB Device',
        deviceType: PeripheralType.USB_STORAGE,
        source: 'runtime_event',
        action: 'connect',
        result: SecurityEventResult.SUCCESS,
        policyHit: 'allow',
        summary: 'connected'
      }, {
        id: 'record-bt-1',
        timestamp: 400,
        deviceId: 'MAC: AA:BB:CC:DD:EE:FF',
        deviceName: 'Bluetooth Device',
        deviceType: PeripheralType.BLUETOOTH,
        source: 'runtime_event',
        action: 'connect',
        result: SecurityEventResult.SUCCESS,
        policyHit: 'allow',
        summary: 'connected'
      }])

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
      await viewModel.reloadRecords([{
        id: 'record-2',
        timestamp: 300,
        deviceId: 'VID:1234 PID:5678',
        deviceName: 'USB Device',
        deviceType: PeripheralType.USB_STORAGE,
        source: 'runtime_event',
        action: 'connect',
        result: SecurityEventResult.SUCCESS,
        policyHit: 'allow',
        summary: 'connected'
      }])

      expect(viewModel.state.records.length).assertEqual(1)
      expect(viewModel.state.records[0].policyIndex).assertEqual(0)
    })

    it('should reject invalid device ids when changing policy', 0, async () => {
      const reason = await viewModel.setDevicePolicy('', 'USB Device', PeripheralType.USB_STORAGE, 0)
      expect(reason).assertEqual('invalid_device_id')
    })

    it('should reject bluetooth device policies without saving local policy', 0, async () => {
      const reason = await viewModel.setDevicePolicy(
        'MAC: AA:BB:CC:DD:EE:FF',
        'Bluetooth Device',
        PeripheralType.BLUETOOTH,
        1
      )

      expect(reason).assertEqual('unsupported_device_type')
      expect(records.length).assertEqual(0)
    })

    it('should reject legacy VID PID policy ids', 0, async () => {
      const reason = await viewModel.setDevicePolicy(
        'VID:1234 PID:5678',
        'USB Device',
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
        'USB Device',
        PeripheralType.USB_STORAGE,
        1
      )

      expect(reason).assertNull()
      expect(usbStates[0].desiredPolicy).assertEqual('deny')
    })

    it('should clear all usb policy states', 0, async () => {
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
      expect(usbStates.length).assertEqual(0)
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
