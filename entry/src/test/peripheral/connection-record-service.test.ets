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

const DEFAULT_RETENTION_DAYS = 180
const DEFAULT_MAX_ENTRIES = 200000

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

async function resetTraceRepository(): Promise<void> {
  await PeripheralTraceRepository.configure(DEFAULT_RETENTION_DAYS, DEFAULT_MAX_ENTRIES)
  await PeripheralTraceRepository.clearAll()
}

async function seedTraceRecords(records: PeripheralTraceRecord[]): Promise<void> {
  await resetTraceRepository()
  if (records.length <= 0) {
    return
  }
  const sorted = records.slice().sort((left: PeripheralTraceRecord, right: PeripheralTraceRecord) => right.occurAt - left.occurAt)
  await PeripheralTraceRepository.appendBatch(sorted)
}

export default function peripheralConnectionRecordServiceTest() {
  describe('PeripheralConnectionRecordService', () => {
    it('should query runtime records ordered by newest first', 0, async (done: Function) => {
      const base = Date.now()
      let older = buildTraceRecord('runtime_older', base + 100)
      older.deviceName = 'Older Device'
      older.deviceId = 'VID:1111 PID:0001'

      let newer = buildTraceRecord('runtime_newer', base + 200)
      newer.deviceName = 'Newer Device'
      newer.action = 'disconnect'
      newer.decision = 'unknown'
      newer.deviceId = 'VID:2222 PID:0002'

      await seedTraceRecords([older, newer])

      let records = PeripheralConnectionRecordService.queryRecords()

      expect(records.length).assertEqual(2)
      expect(records[0].deviceName).assertEqual('Newer Device')
      expect(records[1].deviceName).assertEqual('Older Device')
      done()
    })

    it('should map bluetooth discovery runtime records', 0, async (done: Function) => {
      const base = Date.now()
      let record = buildTraceRecord('runtime_bt_1', base + 300)
      record.deviceName = 'Bluetooth Mouse'
      record.deviceType = PeripheralType.BLUETOOTH
      record.deviceId = 'MAC: AA:BB:CC:DD:EE:FF'
      record.action = 'discover'
      record.decision = 'unknown'
      record.summary = 'discover bluetooth device'
      record.matchedPolicyKind = 'bluetooth_discovery'

      await seedTraceRecords([record])

      let records = PeripheralConnectionRecordService.queryRecords()

      expect(records.length).assertEqual(1)
      expect(records[0].deviceType).assertEqual(PeripheralType.BLUETOOTH)
      expect(records[0].action).assertEqual('unknown')
      expect(records[0].matchedPolicyKind).assertEqual('bluetooth_discovery')
      done()
    })

    it('should map bluetooth acl runtime records', 0, async (done: Function) => {
      const base = Date.now()
      let record = buildTraceRecord('runtime_bt_acl_1', base + 400)
      record.deviceName = 'Bluetooth Keyboard'
      record.deviceType = PeripheralType.BLUETOOTH
      record.deviceId = 'MAC: 11:22:33:44:55:66'
      record.action = 'connect'
      record.decision = 'unknown'
      record.summary = 'bluetooth device connected'
      record.matchedPolicyKind = 'bluetooth_connection_event'

      await seedTraceRecords([record])

      let records = PeripheralConnectionRecordService.queryRecords()

      expect(records.length).assertEqual(1)
      expect(records[0].deviceType).assertEqual(PeripheralType.BLUETOOTH)
      expect(records[0].action).assertEqual('connect')
      expect(records[0].matchedPolicyKind).assertEqual('bluetooth_connection_event')
      done()
    })

    it('should map all runtime fields without dropping extended metadata', 0, async (done: Function) => {
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

      await seedTraceRecords([record])

      let records = PeripheralConnectionRecordService.queryRecords()

      expect(records.length).assertEqual(1)
      expect(records[0].id).assertEqual('peripheral_runtime_runtime_rich')
      expect(records[0].timestamp).assertEqual(base + 500)
      expect(records[0].collectAt).assertEqual(base + 501)
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
      done()
    })

    it('should pass filter fields to repository query and always pin runtime_event source', 0, async (done: Function) => {
      const base = Date.now()
      let runtimeRecord = buildTraceRecord('runtime_keyboard', base + 600)
      runtimeRecord.deviceName = 'Bluetooth Keyboard'
      runtimeRecord.deviceType = PeripheralType.BLUETOOTH
      runtimeRecord.result = LogEventResult.BLOCKED
      runtimeRecord.summary = 'keyboard blocked'

      let ignoredRecord = buildTraceRecord('audit_keyboard', base + 601)
      ignoredRecord.source = 'audit_event'
      ignoredRecord.deviceName = 'Bluetooth Keyboard'
      ignoredRecord.deviceType = PeripheralType.BLUETOOTH
      ignoredRecord.result = LogEventResult.BLOCKED
      ignoredRecord.summary = 'keyboard blocked audit'

      await seedTraceRecords([runtimeRecord, ignoredRecord])

      let filter: PeripheralConnectionFilter = {
        startTime: base + 500,
        endTime: base + 700,
        deviceTypes: [PeripheralType.BLUETOOTH],
        results: [LogEventResult.BLOCKED],
        keyword: 'keyboard'
      }

      let records = PeripheralConnectionRecordService.queryRecords(filter)

      expect(records.length).assertEqual(1)
      expect(records[0].source).assertEqual('runtime_event')
      expect(records[0].deviceName).assertEqual('Bluetooth Keyboard')
      done()
    })

    it('should return empty list when repository has no runtime records', 0, async (done: Function) => {
      const base = Date.now()
      let auditRecord = buildTraceRecord('audit_only', base + 700)
      auditRecord.source = 'audit_event'

      await seedTraceRecords([auditRecord])

      let records = PeripheralConnectionRecordService.queryRecords()

      expect(records.length).assertEqual(0)
      done()
    })
  })
}
