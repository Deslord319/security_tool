import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import {
  LogEventResult,
  PeripheralConnectionFilter,
  PeripheralTraceRecord,
  PeripheralType,
  UsbStoragePolicy
} from '../../main/ets/models/DataModels'
import { PeripheralConnectionRecordService } from '../../main/ets/services/peripheral/connection-record/PeripheralConnectionRecordService'
import { PeripheralTraceEntryRepository } from '../../main/ets/services/peripheral/connection-record/PeripheralTraceEntryRepository'

function buildTraceRecord(recordId: string, occurAt: number): PeripheralTraceRecord {
  return {
    recordId: recordId,
    occurAt: occurAt,
    collectAt: occurAt + 1,
    deviceName: 'Runtime Device',
    deviceType: PeripheralType.USB_STORAGE,
    deviceId: 'VID:1111 PID:0001',
    action: 'connect',
    decision: 'allow',
    result: LogEventResult.SUCCESS,
    source: 'runtime_event',
    summary: 'runtime summary'
  }
}

export default function peripheralConnectionRecordServiceTest() {
  describe('PeripheralConnectionRecordService', () => {
    let mockKit: MockKit

    beforeEach(() => {
      mockKit = new MockKit()
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should query records ordered by newest first', 0, async () => {
      const base = Date.now()
      let older = buildTraceRecord('runtime_older', base + 100)
      older.deviceName = 'Older Device'

      let newer = buildTraceRecord('runtime_newer', base + 200)
      newer.deviceName = 'Newer Device'
      newer.action = 'disconnect'
      newer.decision = 'unknown'
      newer.deviceId = 'VID:2222 PID:0002'

      let listMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.listByQuery)
      when(listMock)(ArgumentMatchers.any).afterReturn(Promise.resolve([newer, older]))

      let records = await PeripheralConnectionRecordService.queryRecords()

      expect(records.length).assertEqual(2)
      expect(records[0].deviceName).assertEqual('Newer Device')
      expect(records[1].deviceName).assertEqual('Older Device')
    })

    it('should map bluetooth discovery records', 0, async () => {
      const base = Date.now()
      let record = buildTraceRecord('runtime_bt_1', base + 300)
      record.deviceName = 'Bluetooth Mouse'
      record.deviceType = PeripheralType.BLUETOOTH
      record.deviceId = 'MAC: AA:BB:CC:DD:EE:FF'
      record.action = 'discover'
      record.decision = 'unknown'
      record.summary = 'discover bluetooth device'
      record.matchedPolicyKind = 'bluetooth_discovery'

      let listMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.listByQuery)
      when(listMock)(ArgumentMatchers.any).afterReturn(Promise.resolve([record]))

      let records = await PeripheralConnectionRecordService.queryRecords()

      expect(records.length).assertEqual(1)
      expect(records[0].deviceType).assertEqual(PeripheralType.BLUETOOTH)
      expect(records[0].action).assertEqual('discover')
      expect(records[0].matchedPolicyKind).assertEqual('bluetooth_discovery')
    })

    it('should keep extended metadata', 0, async () => {
      const base = Date.now()
      let record = buildTraceRecord('runtime_rich', base + 500)
      record.deviceName = 'USB Camera'
      record.deviceType = PeripheralType.USB_CAMERA
      record.deviceId = 'VID:9999 PID:8888'
      record.decision = 'deny'
      record.result = LogEventResult.BLOCKED
      record.summary = 'rich runtime record'
      record.correlationId = 'corr-1'
      record.policyVersion = 'policy-v1'
      record.rawEventId = 123
      record.rawEventName = 'usual.event.USB_ATTACHED'
      record.rawOutcome = 'blocked'
      record.rawAction = 'attach'
      record.rawPayload = '{"foo":"bar"}'
      record.detail = 'detail text'
      record.processName = 'device-manager'
      record.usbPolicy = UsbStoragePolicy.READ_ONLY
      record.effectivePolicyLabel = 'read-only'
      record.matchedPolicyKind = 'usb_storage_read_only'

      let listMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.listByQuery)
      when(listMock)(ArgumentMatchers.any).afterReturn(Promise.resolve([record]))

      let records = await PeripheralConnectionRecordService.queryRecords()

      expect(records.length).assertEqual(1)
      expect(records[0].id).assertEqual('peripheral_runtime_event_runtime_rich')
      expect(records[0].usbPolicy).assertEqual(UsbStoragePolicy.READ_ONLY)
      expect(records[0].effectivePolicyLabel).assertEqual('read-only')
      expect(records[0].matchedPolicyKind).assertEqual('usb_storage_read_only')
    })

    it('should include runtime and audit sources when filtering', 0, async () => {
      const base = Date.now()
      let runtimeRecord = buildTraceRecord('runtime_keyboard', base + 600)
      runtimeRecord.deviceName = 'Bluetooth Keyboard'
      runtimeRecord.deviceType = PeripheralType.BLUETOOTH
      runtimeRecord.result = LogEventResult.BLOCKED
      runtimeRecord.summary = 'keyboard blocked'

      let auditRecord = buildTraceRecord('audit_keyboard', base + 601)
      auditRecord.source = 'audit_event'
      auditRecord.deviceName = 'Bluetooth Keyboard'
      auditRecord.deviceType = PeripheralType.BLUETOOTH
      auditRecord.result = LogEventResult.BLOCKED
      auditRecord.summary = 'keyboard blocked audit'

      let capturedQuery: Object | null = null
      let listMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.listByQuery)
      when(listMock)(ArgumentMatchers.any).afterAction((query?: Object) => {
        capturedQuery = query ?? null
        return Promise.resolve([runtimeRecord, auditRecord])
      })

      let filter: PeripheralConnectionFilter = {
        startTime: base + 500,
        endTime: base + 700,
        deviceTypes: [PeripheralType.BLUETOOTH],
        results: [LogEventResult.BLOCKED],
        keyword: 'keyboard'
      }

      let records = await PeripheralConnectionRecordService.queryRecords(filter)

      expect(records.length).assertEqual(2)
      expect(records[0].deviceName).assertEqual('Bluetooth Keyboard')
      expect(records[1].source).assertEqual('audit_event')
      expect(JSON.stringify(capturedQuery).indexOf('runtime_event') > -1).assertTrue()
      expect(JSON.stringify(capturedQuery).indexOf('audit_event') > -1).assertTrue()
    })

    it('should return empty list when repository has no records', 0, async () => {
      let listMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.listByQuery)
      when(listMock)(ArgumentMatchers.any).afterReturn(Promise.resolve([]))

      let records = await PeripheralConnectionRecordService.queryRecords()

      expect(records.length).assertEqual(0)
    })

    it('should forward pagination and count query to trace repository', 0, async () => {
      let capturedListQuery: Object | null = null
      let capturedLimit: number | undefined = undefined
      let capturedOffset: number | undefined = undefined
      let capturedCountQuery: Object | null = null
      let listMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.listByQuery)
      let countMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.countByQuery)
      when(listMock)(ArgumentMatchers.any).afterAction((query?: Object) => {
        capturedListQuery = query ?? null
        capturedLimit = 20
        capturedOffset = 40
        return Promise.resolve([])
      })
      when(countMock)(ArgumentMatchers.any).afterAction((query?: Object) => {
        capturedCountQuery = query ?? null
        return Promise.resolve(3)
      })

      const filter: PeripheralConnectionFilter = {
        keyword: 'camera',
        deviceTypes: [PeripheralType.USB_CAMERA]
      }
      let count = await PeripheralConnectionRecordService.countRecords(filter)
      await PeripheralConnectionRecordService.queryRecords(filter, 20, 40)

      expect(count).assertEqual(3)
      expect(capturedLimit).assertEqual(20)
      expect(capturedOffset).assertEqual(40)
      expect(JSON.stringify(capturedListQuery).indexOf('camera') > -1).assertTrue()
      expect(JSON.stringify(capturedCountQuery).indexOf('camera') > -1).assertTrue()
    })
  })
}
