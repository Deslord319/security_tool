import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { LogEventResult } from '../../main/ets/models/LogModels'
import {
  PeripheralDevicePolicyRecord,
  PeripheralType
} from '../../main/ets/models/PeripheralModels'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/peripheral/device-policy/PeripheralDevicePolicyRepository'
import {
  PeripheralDevicePolicyDispatchService,
  PeripheralPolicyDispatchRequest,
  PeripheralPolicyDispatchResult
} from '../../main/ets/services/peripheral/device-policy/peripheral_device_policy_dispatch_service'
import {
  CsvFileExportService
} from '../../main/ets/services/common/export/CsvFileExportService'
import { createSuccessfulCsvFileExportResult } from '../common/CsvExportResultFactory'
import { PeripheralPolicyViewModel } from '../../main/ets/viewmodels/peripheral/device-policy/PeripheralPolicyViewModel'

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
    })

    afterEach(async () => {
      mockKit.clearAll()
    })

    it('should rebuild policy records from connection records and explicit device policies', 0, async () => {
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
        result: LogEventResult.SUCCESS,
        policyHit: 'allow',
        summary: 'connected'
      }])

      expect(viewModel.state.records.length).assertEqual(1)
      expect(viewModel.state.records[0].policyIndex).assertEqual(1)
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

    it('should reject invalid device ids when changing policy', 0, async () => {
      const reason = await viewModel.setDevicePolicy('', 'USB Device', PeripheralType.USB_STORAGE, 0)
      expect(reason).assertEqual('invalid_device_id')
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

    it('should normalize bluetooth device ids when persisting policy', 0, async () => {
      const reason = await viewModel.setDevicePolicy(
        'aa-bb-cc-dd-ee-ff',
        'Bluetooth Device',
        PeripheralType.BLUETOOTH,
        1
      )

      expect(reason).assertNull()
      expect(records[0].deviceId).assertEqual('MAC: AA:BB:CC:DD:EE:FF')
      expect(records[0].policy).assertEqual('deny')
    })

    it('should restore bluetooth device allow policy with normalized id', 0, async () => {
      records = [{
        deviceId: 'MAC: AA:BB:CC:DD:EE:FF',
        policy: 'deny',
        updatedAt: Date.now(),
        deviceName: 'Bluetooth Device',
        deviceType: PeripheralType.BLUETOOTH
      }]

      const reason = await viewModel.setDevicePolicy(
        'aa-bb-cc-dd-ee-ff',
        'Bluetooth Device',
        PeripheralType.BLUETOOTH,
        0
      )

      expect(reason).assertNull()
      expect(records.length).assertEqual(1)
      expect(records[0].deviceId).assertEqual('MAC: AA:BB:CC:DD:EE:FF')
      expect(records[0].policy).assertEqual('allow')
    })

    it('should rebuild bluetooth policy records with normalized ids', 0, async () => {
      records = [{
        deviceId: 'aa-bb-cc-dd-ee-ff',
        policy: 'deny',
        updatedAt: Date.now(),
        deviceName: 'Bluetooth Device',
        deviceType: PeripheralType.BLUETOOTH
      }]

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
    })

    it('should map usb global interface conflict when changing single-device policy', 0, async () => {
      let dispatchMock = mockKit.mockFunc(PeripheralDevicePolicyDispatchService, PeripheralDevicePolicyDispatchService.dispatch)
      when(dispatchMock)(ArgumentMatchers.any).afterReturn(createDispatchResult(false, 'usb_conflict_global_disabled'))

      const reason = await viewModel.setDevicePolicy(
        'VID:1234 PID:5678',
        'USB Device',
        PeripheralType.USB_STORAGE,
        1
      )

      expect(reason).assertEqual('usb_conflict_global_disabled')
      expect(records.length).assertEqual(0)
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
        deviceId: 'MAC: AA:BB:CC:DD:EE:FF',
        policy: 'deny',
        updatedAt: Date.now() + 1,
        deviceType: PeripheralType.BLUETOOTH
      }]
      records = seededRecords.slice()

      const dispatchCalls: string[] = []
      let dispatchMock = mockKit.mockFunc(PeripheralDevicePolicyDispatchService, PeripheralDevicePolicyDispatchService.dispatch)
      when(dispatchMock)(ArgumentMatchers.any).afterAction((request: PeripheralPolicyDispatchRequest): PeripheralPolicyDispatchResult => {
        dispatchCalls.push(`${request.deviceId}:${request.policy}`)
        if (request.deviceId === 'MAC: AA:BB:CC:DD:EE:FF' && request.policy === 'allow') {
          return createDispatchResult(false, 'bluetooth_dispatch_failed')
        }
        return createDispatchResult(true)
      })

      const success = await viewModel.clearAllPolicies()
      expect(success).assertFalse()
      expect(PeripheralDevicePolicyRepository.getAll().length).assertEqual(2)
      expect(dispatchCalls).assertDeepEquals([
        'VID:1234 PID:5678:allow',
        'MAC: AA:BB:CC:DD:EE:FF:allow',
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
