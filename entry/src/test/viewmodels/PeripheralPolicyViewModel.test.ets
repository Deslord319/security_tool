import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { SecurityEventResult } from '../../main/ets/models/CommonModels'
import {
  PeripheralDevicePolicyRecord,
  PeripheralType
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

    beforeEach(async () => {
      viewModel = new PeripheralPolicyViewModel()
      mockKit = new MockKit()
      records = []
      let getAllMock = mockKit.mockFunc(PeripheralDevicePolicyRepository, PeripheralDevicePolicyRepository.getAll)
      let getMock = mockKit.mockFunc(PeripheralDevicePolicyRepository, PeripheralDevicePolicyRepository.get)
      let setMock = mockKit.mockFunc(PeripheralDevicePolicyRepository, PeripheralDevicePolicyRepository.set)
      let clearAllMock = mockKit.mockFunc(PeripheralDevicePolicyRepository, PeripheralDevicePolicyRepository.clearAll)
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
      when(dispatchMock)(ArgumentMatchers.any).afterReturn(createDispatchResult(true))
      when(appendSnapshotMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(createTraceMutationResult()))
    })

    afterEach(async () => {
      mockKit.clearAll()
    })

    it('should rebuild usb policy records from connection records and explicit device policies', 0, async () => {
      records = [{
        deviceId: 'VID:1234 PID:5678',
        policy: 'deny',
        updatedAt: Date.now(),
        deviceName: 'USB Device',
        deviceType: PeripheralType.USB_STORAGE
      }]

      viewModel.reloadRecords([{
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
    })

    it('should exclude bluetooth connection records from device policy candidates', 0, () => {
      viewModel.reloadRecords([{
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

      expect(viewModel.state.records.length).assertEqual(1)
      expect(viewModel.state.records[0].deviceType).assertEqual(PeripheralType.USB_STORAGE)
      expect(viewModel.state.records[0].deviceId).assertEqual('VID:1234 PID:5678')
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

    it('should persist single-device deny policy', 0, async () => {
      const reason = await viewModel.setDevicePolicy(
        'VID:1234 PID:5678',
        'USB Device',
        PeripheralType.USB_STORAGE,
        1
      )

      expect(reason).assertNull()
      expect(records[0].policy).assertEqual('deny')
    })

    it('should clear all explicit device policies', 0, async () => {
      records = [{
        deviceId: 'VID:1234 PID:5678',
        policy: 'deny',
        updatedAt: Date.now()
      }]

      const success = await viewModel.clearAllPolicies()
      expect(success).assertTrue()
      expect(PeripheralDevicePolicyRepository.getAll().length).assertEqual(0)
    })

    it('should rollback dispatched policies when clearing explicit policies fails midway', 0, async () => {
      const seededRecords: PeripheralDevicePolicyRecord[] = [{
        deviceId: 'VID:1234 PID:5678',
        policy: 'deny',
        updatedAt: Date.now(),
        deviceType: PeripheralType.USB_STORAGE
      }, {
        deviceId: 'VID:1111 PID:2222',
        policy: 'deny',
        updatedAt: Date.now() + 1,
        deviceType: PeripheralType.USB_CAMERA
      }]
      records = seededRecords.slice()

      const dispatchCalls: string[] = []
      let dispatchMock = mockKit.mockFunc(PeripheralDevicePolicyDispatchService, PeripheralDevicePolicyDispatchService.dispatch)
      when(dispatchMock)(ArgumentMatchers.any).afterAction((request: PeripheralPolicyDispatchRequest): PeripheralPolicyDispatchResult => {
        dispatchCalls.push(`${request.deviceId}:${request.policy}`)
        if (request.deviceId === 'VID:1111 PID:2222' && request.policy === 'allow') {
          return createDispatchResult(false, 'usb_dispatch_failed')
        }
        return createDispatchResult(true)
      })

      const success = await viewModel.clearAllPolicies()
      expect(success).assertFalse()
      expect(PeripheralDevicePolicyRepository.getAll().length).assertEqual(2)
      expect(dispatchCalls).assertDeepEquals([
        'VID:1234 PID:5678:allow',
        'VID:1111 PID:2222:allow',
        'VID:1234 PID:5678:deny'
      ])
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
