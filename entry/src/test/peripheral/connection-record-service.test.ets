import { describe, expect, it } from '@ohos/hypium'
import {
  LogEventResult,
  PeripheralConnectionFilter,
  PeripheralTraceRecord,
  PeripheralType,
  UsbStoragePolicy
} from '../../main/ets/models/DataModels'
import { PeripheralConnectionRecordService } from '../../main/ets/services/peripheral/connection-record/PeripheralConnectionRecordService'
import { PeripheralTraceRepository } from '../../main/ets/services/peripheral/connection-record/PeripheralTraceRepository'

function buildTraceRecord(recordId: string, occurAt: number): PeripheralTraceRecord {
  let record: PeripheralTraceRecord = {
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
  return record
}

export default function peripheralConnectionRecordServiceTest() {
  describe('PeripheralConnectionRecordService', () => {
    it('should query runtime records ordered by newest first', 0, () => {
      let older = buildTraceRecord('runtime_older', 100)
      older.deviceName = 'Older Device'
      older.deviceId = 'VID:1111 PID:0001'

      let newer = buildTraceRecord('runtime_newer', 200)
      newer.deviceName = 'Newer Device'
      newer.action = 'disconnect'
      newer.decision = 'unknown'
      newer.deviceId = 'VID:2222 PID:0002'

      PeripheralTraceRepository.resetForTest()
      PeripheralTraceRepository.setRecordsForTest([older, newer])

      let records = PeripheralConnectionRecordService.queryRecords()

      expect(records.length).assertEqual(2)
      expect(records[0].deviceName).assertEqual('Newer Device')
      expect(records[1].deviceName).assertEqual('Older Device')
    })

    it('should map bluetooth discovery runtime records', 0, () => {
      let record = buildTraceRecord('runtime_bt_1', 300)
      record.deviceName = 'Bluetooth Mouse'
      record.deviceType = PeripheralType.BLUETOOTH
      record.deviceId = 'MAC: AA:BB:CC:DD:EE:FF'
      record.action = 'discover'
      record.decision = 'unknown'
      record.summary = 'discover bluetooth device'
      record.matchedPolicyKind = 'bluetooth_discovery'

      PeripheralTraceRepository.resetForTest()
      PeripheralTraceRepository.setRecordsForTest([record])

      let records = PeripheralConnectionRecordService.queryRecords()

      expect(records.length).assertEqual(1)
      expect(records[0].deviceType).assertEqual(PeripheralType.BLUETOOTH)
      expect(records[0].action).assertEqual('discover')
      expect(records[0].matchedPolicyKind).assertEqual('bluetooth_discovery')
    })

    it('should map bluetooth acl runtime records', 0, () => {
      let record = buildTraceRecord('runtime_bt_acl_1', 400)
      record.deviceName = 'Bluetooth Keyboard'
      record.deviceType = PeripheralType.BLUETOOTH
      record.deviceId = 'MAC: 11:22:33:44:55:66'
      record.action = 'connect'
      record.decision = 'unknown'
      record.summary = 'bluetooth device connected'
      record.matchedPolicyKind = 'bluetooth_connection_event'

      PeripheralTraceRepository.resetForTest()
      PeripheralTraceRepository.setRecordsForTest([record])

      let records = PeripheralConnectionRecordService.queryRecords()

      expect(records.length).assertEqual(1)
      expect(records[0].deviceType).assertEqual(PeripheralType.BLUETOOTH)
      expect(records[0].action).assertEqual('connect')
      expect(records[0].matchedPolicyKind).assertEqual('bluetooth_connection_event')
    })

    it('should map all runtime fields without dropping extended metadata', 0, () => {
      let record = buildTraceRecord('runtime_rich', 500)
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

      PeripheralTraceRepository.resetForTest()
      PeripheralTraceRepository.setRecordsForTest([record])

      let records = PeripheralConnectionRecordService.queryRecords()

      expect(records.length).assertEqual(1)
      expect(records[0].id).assertEqual('peripheral_runtime_runtime_rich')
      expect(records[0].timestamp).assertEqual(500)
      expect(records[0].collectAt).assertEqual(501)
      expect(records[0].policyHit).assertEqual('deny')
      expect(records[0].correlationId).assertEqual('corr-1')
      expect(records[0].policyVersion).assertEqual('policy-v1')
      expect(records[0].rawEventId).assertEqual(123)
      expect(records[0].rawEventName).assertEqual('usual.event.USB_ATTACHED')
      expect(records[0].rawOutcome).assertEqual('blocked')
      expect(records[0].rawAction).assertEqual('attach')
      expect(records[0].rawPayload).assertEqual('{"foo":"bar"}')
      expect(records[0].detail).assertEqual('detail text')
      expect(records[0].processName).assertEqual('device-manager')
      expect(records[0].usbPolicy).assertEqual(UsbStoragePolicy.READ_ONLY)
      expect(records[0].effectivePolicyLabel).assertEqual('read-only')
      expect(records[0].matchedPolicyKind).assertEqual('usb_storage_read_only')
    })

    it('should pass filter fields to repository query and always pin runtime_event source', 0, () => {
      let runtimeRecord = buildTraceRecord('runtime_keyboard', 600)
      runtimeRecord.deviceName = 'Bluetooth Keyboard'
      runtimeRecord.deviceType = PeripheralType.BLUETOOTH
      runtimeRecord.result = LogEventResult.BLOCKED
      runtimeRecord.summary = 'keyboard blocked'

      let ignoredRecord = buildTraceRecord('audit_keyboard', 601)
      ignoredRecord.source = 'audit_event'
      ignoredRecord.deviceName = 'Bluetooth Keyboard'
      ignoredRecord.deviceType = PeripheralType.BLUETOOTH
      ignoredRecord.result = LogEventResult.BLOCKED
      ignoredRecord.summary = 'keyboard blocked audit'

      PeripheralTraceRepository.resetForTest()
      PeripheralTraceRepository.setRecordsForTest([runtimeRecord, ignoredRecord])

      let filter: PeripheralConnectionFilter = {
        startTime: 500,
        endTime: 700,
        deviceTypes: [PeripheralType.BLUETOOTH],
        results: [LogEventResult.BLOCKED],
        keyword: 'keyboard'
      }

      let records = PeripheralConnectionRecordService.queryRecords(filter)

      expect(records.length).assertEqual(1)
      expect(records[0].source).assertEqual('runtime_event')
      expect(records[0].deviceName).assertEqual('Bluetooth Keyboard')
    })

    it('should return empty list when repository has no runtime records', 0, () => {
      let auditRecord = buildTraceRecord('audit_only', 700)
      auditRecord.source = 'audit_event'

      PeripheralTraceRepository.resetForTest()
      PeripheralTraceRepository.setRecordsForTest([auditRecord])

      let records = PeripheralConnectionRecordService.queryRecords()

      expect(records.length).assertEqual(0)
    })
  })
}
