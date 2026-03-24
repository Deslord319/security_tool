import { describe, it, expect } from '@ohos/hypium'
import {
  LogEntry,
  LogEventResult,
  LogEventType,
  PeripheralTraceRecord,
  PeripheralType
} from '../../main/ets/models/DataModels'
import { PeripheralConnectionRecordService } from '../../main/ets/services/PeripheralConnectionRecordService'

interface TestUsbDeviceId {
  vendorId: number
  productId: number
}

function createUsbAuditEntry(
  id: string,
  timestamp: number,
  result: LogEventResult,
  detail: string
): LogEntry {
  return {
    id: id,
    timestamp: timestamp,
    eventType: LogEventType.FILE,
    detail: detail,
    result: result,
    processName: 'usb-daemon',
    sourceEventId: 5001
  }
}

export default function peripheralConnectionRecordServiceTest() {
  describe('PeripheralConnectionRecordService', () => {
    it('should merge audit events and policy snapshots without duplicate usb records', 0, () => {
      let auditEntries: LogEntry[] = [
        createUsbAuditEntry(
          'audit_1',
          1700000000000,
          LogEventResult.SUCCESS,
          'USB storage attached VID:0781 PID:5583'
        )
      ]
      let usbWhitelist: TestUsbDeviceId[] = [
        { vendorId: 0x0781, productId: 0x5583 },
        { vendorId: 0x03F0, productId: 0x0C17 }
      ]
      let btWhitelist: string[] = ['AA:BB:CC:DD:EE:01']

      let records = PeripheralConnectionRecordService.buildRecords(
        auditEntries,
        usbWhitelist,
        btWhitelist
      )

      expect(records.length).assertEqual(3)
      expect(records.filter((record) => record.source === 'audit_event').length).assertEqual(1)
      expect(records.filter((record) => record.source === 'policy_snapshot').length).assertEqual(2)
      expect(records.filter((record) => record.deviceId === 'VID:0781 PID:5583').length).assertEqual(1)
      expect(records.filter((record) => record.source === 'policy_snapshot' && record.policyHit === 'unknown').length)
        .assertEqual(2)
    })

    it('should filter by result and device type', 0, () => {
      let auditEntries: LogEntry[] = [
        createUsbAuditEntry(
          'audit_2',
          1700000000001,
          LogEventResult.SUCCESS,
          'USB storage attached VID:1111 PID:0001'
        ),
        createUsbAuditEntry(
          'audit_3',
          1700000001000,
          LogEventResult.BLOCKED,
          'USB camera blocked VID:2B7E PID:B5A2'
        )
      ]

      let records = PeripheralConnectionRecordService.buildRecords(
        auditEntries,
        [],
        [],
        {
          deviceTypes: [PeripheralType.USB_CAMERA],
          results: [LogEventResult.BLOCKED]
        }
      )

      expect(records.length).assertEqual(1)
      expect(records[0].result).assertEqual(LogEventResult.BLOCKED)
      expect(records[0].deviceType).assertEqual(PeripheralType.USB_CAMERA)
      expect(records[0].action).assertEqual('intercept')
      expect(records[0].policyHit).assertEqual('deny')
    })

    it('should classify mount signal as connect and allow', 0, () => {
      let auditEntries: LogEntry[] = [
        createUsbAuditEntry(
          'audit_mount_1',
          1700000001500,
          LogEventResult.SUCCESS,
          'Mass storage mounted VID:1111 PID:0002'
        )
      ]

      let records = PeripheralConnectionRecordService.buildRecords(auditEntries, [], [])
      expect(records.length).assertEqual(1)
      expect(records[0].action).assertEqual('connect')
      expect(records[0].policyHit).assertEqual('allow')
    })

    it('should classify unmount signal as disconnect even when result is success', 0, () => {
      let auditEntries: LogEntry[] = [
        createUsbAuditEntry(
          'audit_unmount_1',
          1700000001600,
          LogEventResult.SUCCESS,
          'USB disk unmounted VID:1111 PID:0003'
        )
      ]

      let records = PeripheralConnectionRecordService.buildRecords(auditEntries, [], [])
      expect(records.length).assertEqual(1)
      expect(records[0].action).assertEqual('disconnect')
      expect(records[0].policyHit).assertEqual('unknown')
    })

    it('should classify disconnect by rawAction when detail has no explicit keyword', 0, () => {
      let auditEntries: LogEntry[] = [
        {
          id: 'audit_action_1',
          timestamp: 1700000001650,
          eventType: LogEventType.FILE,
          detail: 'VID:1111 PID:0004',
          rawAction: 'unplug',
          result: LogEventResult.SUCCESS
        }
      ]

      let records = PeripheralConnectionRecordService.buildRecords(auditEntries, [], [])
      expect(records.length).assertEqual(1)
      expect(records[0].action).assertEqual('disconnect')
      expect(records[0].policyHit).assertEqual('unknown')
    })

    it('should keep action unknown when success has no action signal', 0, () => {
      let auditEntries: LogEntry[] = [
        {
          id: 'audit_unknown_1',
          timestamp: 1700000001675,
          eventType: LogEventType.FILE,
          detail: 'VID:1111 PID:0005',
          result: LogEventResult.SUCCESS
        }
      ]

      let records = PeripheralConnectionRecordService.buildRecords(auditEntries, [], [])
      expect(records.length).assertEqual(1)
      expect(records[0].action).assertEqual('unknown')
      expect(records[0].policyHit).assertEqual('unknown')
    })

    it('should keep nearby audit records when raw metadata differs', 0, () => {
      let auditEntries: LogEntry[] = [
        {
          id: 'audit_meta_1',
          timestamp: 1700000001700,
          eventType: LogEventType.FILE,
          detail: 'VID:0781 PID:5583',
          rawEventName: 'volume_attach',
          sourceEventId: 6001,
          result: LogEventResult.SUCCESS
        },
        {
          id: 'audit_meta_2',
          timestamp: 1700000002300,
          eventType: LogEventType.FILE,
          detail: 'VID:0781 PID:5583',
          rawEventName: 'volume_changed',
          sourceEventId: 6002,
          result: LogEventResult.SUCCESS
        }
      ]

      let records = PeripheralConnectionRecordService.buildRecords(auditEntries, [], [])
      expect(records.length).assertEqual(2)
      expect(records[0].id).assertEqual('peripheral_audit_audit_meta_2')
      expect(records[1].id).assertEqual('peripheral_audit_audit_meta_1')
    })

    it('should return empty records for invalid time range', 0, () => {
      let auditEntries: LogEntry[] = [
        createUsbAuditEntry(
          'audit_4',
          1700000002000,
          LogEventResult.SUCCESS,
          'USB printer attached VID:03F0 PID:0C17'
        )
      ]

      let records = PeripheralConnectionRecordService.buildRecords(
        auditEntries,
        [],
        [],
        {
          startTime: 1700000003000,
          endTime: 1700000001000
        }
      )

      expect(records.length).assertEqual(0)
    })

    it('should support keyword filtering on detail and process fields', 0, () => {
      let auditEntries: LogEntry[] = [
        {
          id: 'audit_5',
          timestamp: 1700000004000,
          eventType: LogEventType.FILE,
          detail: 'Mass storage mounted VID:046D PID:C52B',
          result: LogEventResult.SUCCESS,
          processName: 'storage-service'
        },
        {
          id: 'audit_6',
          timestamp: 1700000005000,
          eventType: LogEventType.FILE,
          detail: 'Camera blocked VID:2B7E PID:B5A2',
          result: LogEventResult.BLOCKED,
          processName: 'camera-guard'
        }
      ]

      let byProcess = PeripheralConnectionRecordService.buildRecords(
        auditEntries,
        [],
        [],
        { keyword: 'camera-guard' }
      )
      let byDetail = PeripheralConnectionRecordService.buildRecords(
        auditEntries,
        [],
        [],
        { keyword: 'mass storage' }
      )

      expect(byProcess.length).assertEqual(1)
      expect(byProcess[0].id).assertEqual('peripheral_audit_audit_6')
      expect(byDetail.length).assertEqual(1)
      expect(byDetail[0].id).assertEqual('peripheral_audit_audit_5')
    })

    it('should include runtime records when runtime source is selected', 0, () => {
      let runtimeRecords: PeripheralTraceRecord[] = [
        {
          recordId: 'runtime_1',
          occurAt: 1700000007000,
          collectAt: 1700000007001,
          deviceName: 'Test Runtime USB',
          deviceType: PeripheralType.USB_OTHER,
          deviceId: 'VID:1234 PID:5678',
          action: 'disconnect',
          decision: 'unknown',
          result: LogEventResult.SUCCESS,
          source: 'runtime_event',
          summary: 'Runtime disconnect'
        }
      ]

      let records = PeripheralConnectionRecordService.buildRecords(
        [],
        [],
        [],
        {
          sources: ['runtime_event']
        },
        runtimeRecords
      )

      expect(records.length).assertEqual(1)
      expect(records[0].source).assertEqual('runtime_event')
      expect(records[0].action).assertEqual('disconnect')
    })

    it('should correlate audit and runtime records by device and time window', 0, () => {
      let auditEntries: LogEntry[] = [
        createUsbAuditEntry(
          'audit_corr_1',
          1700000008000,
          LogEventResult.BLOCKED,
          'USB camera blocked VID:2B7E PID:B5A2'
        )
      ]
      let runtimeRecords: PeripheralTraceRecord[] = [
        {
          recordId: 'runtime_corr_1',
          occurAt: 1700000007500,
          collectAt: 1700000007501,
          deviceName: 'Runtime Camera',
          deviceType: PeripheralType.USB_CAMERA,
          deviceId: 'VID:2B7E PID:B5A2',
          action: 'connect',
          decision: 'unknown',
          result: LogEventResult.SUCCESS,
          source: 'runtime_event',
          summary: 'Runtime connect'
        }
      ]

      let records = PeripheralConnectionRecordService.buildRecords(
        auditEntries,
        [],
        [],
        undefined,
        runtimeRecords
      )

      let auditRecord = records.find((record) => record.source === 'audit_event')
      let runtimeRecord = records.find((record) => record.source === 'runtime_event')
      expect(auditRecord).not().assertUndefined()
      expect(runtimeRecord).not().assertUndefined()
      expect(auditRecord!.correlationId).not().assertUndefined()
      expect(runtimeRecord!.correlationId).assertEqual(auditRecord!.correlationId as string)
    })
  })
}
