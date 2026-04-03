import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import {
  LogEventResult,
  PeripheralConnectionFilter,
  PeripheralTraceQuery,
  PeripheralTraceRecord,
  PeripheralType,
  UsbStoragePolicy
} from '../../main/ets/models/DataModels'
import { PeripheralConnectionRecordService } from '../../main/ets/services/PeripheralConnectionRecordService'
import { PeripheralTraceRepository } from '../../main/ets/services/PeripheralTraceRepository'

function createTraceRecord(overrides?: Partial<PeripheralTraceRecord>): PeripheralTraceRecord {
  return {
    recordId: 'runtime_record',
    occurAt: 100,
    collectAt: 101,
    deviceName: 'Runtime Device',
    deviceType: PeripheralType.USB_STORAGE,
    deviceId: 'VID:1111 PID:0001',
    action: 'connect',
    decision: 'allow',
    result: LogEventResult.SUCCESS,
    source: 'runtime_event',
    summary: 'runtime summary',
    ...overrides
  }
}

describe('PeripheralConnectionRecordService', () => {
  let originalQuery: (query?: PeripheralTraceQuery) => PeripheralTraceRecord[]
  let capturedQuery: PeripheralTraceQuery | undefined

  beforeEach(() => {
    originalQuery = PeripheralTraceRepository.query
    capturedQuery = undefined
  })

  afterEach(() => {
    PeripheralTraceRepository.query = originalQuery
    PeripheralTraceRepository.resetForTest()
  })

  it('should query runtime records ordered by newest first', 0, () => {
    PeripheralTraceRepository.query = (query?: PeripheralTraceQuery): PeripheralTraceRecord[] => {
      capturedQuery = query
      return [
        createTraceRecord({
          recordId: 'runtime_older',
          occurAt: 100,
          collectAt: 101,
          deviceName: 'Older Device',
          deviceId: 'VID:1111 PID:0001'
        }),
        createTraceRecord({
          recordId: 'runtime_newer',
          occurAt: 200,
          collectAt: 201,
          deviceName: 'Newer Device',
          action: 'disconnect',
          decision: 'unknown',
          deviceId: 'VID:2222 PID:0002'
        })
      ]
    }

    const records = PeripheralConnectionRecordService.queryRecords()

    expect(capturedQuery?.sources?.length ?? 0).assertEqual(1)
    expect(capturedQuery?.sources?.[0]).assertEqual('runtime_event')
    expect(records.length).assertEqual(2)
    expect(records[0].deviceName).assertEqual('Newer Device')
    expect(records[1].deviceName).assertEqual('Older Device')
  })

  it('should map bluetooth discovery runtime records', 0, () => {
    PeripheralTraceRepository.query = (_query?: PeripheralTraceQuery): PeripheralTraceRecord[] => {
      return [
        createTraceRecord({
          recordId: 'runtime_bt_1',
          occurAt: 300,
          collectAt: 301,
          deviceName: 'Bluetooth Mouse',
          deviceType: PeripheralType.BLUETOOTH,
          deviceId: 'MAC: AA:BB:CC:DD:EE:FF',
          action: 'discover',
          decision: 'unknown',
          summary: 'discover bluetooth device',
          matchedPolicyKind: 'bluetooth_discovery'
        })
      ]
    }

    const records = PeripheralConnectionRecordService.queryRecords()

    expect(records.length).assertEqual(1)
    expect(records[0].deviceType).assertEqual(PeripheralType.BLUETOOTH)
    expect(records[0].action).assertEqual('discover')
    expect(records[0].matchedPolicyKind).assertEqual('bluetooth_discovery')
  })

  it('should map bluetooth acl runtime records', 0, () => {
    PeripheralTraceRepository.query = (_query?: PeripheralTraceQuery): PeripheralTraceRecord[] => {
      return [
        createTraceRecord({
          recordId: 'runtime_bt_acl_1',
          occurAt: 400,
          collectAt: 401,
          deviceName: 'Bluetooth Keyboard',
          deviceType: PeripheralType.BLUETOOTH,
          deviceId: 'MAC: 11:22:33:44:55:66',
          action: 'connect',
          decision: 'unknown',
          summary: 'bluetooth device connected',
          matchedPolicyKind: 'bluetooth_connection_event'
        })
      ]
    }

    const records = PeripheralConnectionRecordService.queryRecords()

    expect(records.length).assertEqual(1)
    expect(records[0].deviceType).assertEqual(PeripheralType.BLUETOOTH)
    expect(records[0].action).assertEqual('connect')
    expect(records[0].matchedPolicyKind).assertEqual('bluetooth_connection_event')
  })

  it('should map all runtime fields without dropping extended metadata', 0, () => {
    PeripheralTraceRepository.query = (_query?: PeripheralTraceQuery): PeripheralTraceRecord[] => {
      return [
        createTraceRecord({
          recordId: 'runtime_rich',
          occurAt: 500,
          collectAt: 501,
          deviceName: 'USB Camera',
          deviceType: PeripheralType.USB_CAMERA,
          deviceId: 'VID:9999 PID:8888',
          action: 'connect',
          decision: 'deny',
          result: LogEventResult.BLOCKED,
          summary: 'rich runtime record',
          correlationId: 'corr-1',
          policyVersion: 'policy-v1',
          rawEventId: 123,
          rawEventName: 'usual.event.USB_ATTACHED',
          rawOutcome: 'blocked',
          rawAction: 'attach',
          rawPayload: '{\"foo\":\"bar\"}',
          detail: 'detail text',
          processName: 'device-manager',
          usbPolicy: UsbStoragePolicy.READ_ONLY,
          effectivePolicyLabel: 'read-only',
          matchedPolicyKind: 'usb_storage_read_only'
        })
      ]
    }

    const records = PeripheralConnectionRecordService.queryRecords()

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
    expect(records[0].rawPayload).assertEqual('{\"foo\":\"bar\"}')
    expect(records[0].detail).assertEqual('detail text')
    expect(records[0].processName).assertEqual('device-manager')
    expect(records[0].usbPolicy).assertEqual(UsbStoragePolicy.READ_ONLY)
    expect(records[0].effectivePolicyLabel).assertEqual('read-only')
    expect(records[0].matchedPolicyKind).assertEqual('usb_storage_read_only')
  })

  it('should pass filter fields to repository query and always pin runtime_event source', 0, () => {
    PeripheralTraceRepository.query = (query?: PeripheralTraceQuery): PeripheralTraceRecord[] => {
      capturedQuery = query
      return []
    }
    const filter: PeripheralConnectionFilter = {
      startTime: 1000,
      endTime: 2000,
      deviceTypes: [PeripheralType.BLUETOOTH],
      results: [LogEventResult.BLOCKED],
      keyword: 'keyboard'
    }

    const records = PeripheralConnectionRecordService.queryRecords(filter)

    expect(records.length).assertEqual(0)
    expect(capturedQuery?.startTime).assertEqual(1000)
    expect(capturedQuery?.endTime).assertEqual(2000)
    expect(capturedQuery?.deviceTypes?.length ?? 0).assertEqual(1)
    expect(capturedQuery?.deviceTypes?.[0]).assertEqual(PeripheralType.BLUETOOTH)
    expect(capturedQuery?.results?.length ?? 0).assertEqual(1)
    expect(capturedQuery?.results?.[0]).assertEqual(LogEventResult.BLOCKED)
    expect(capturedQuery?.keyword).assertEqual('keyboard')
    expect(capturedQuery?.sources?.length ?? 0).assertEqual(1)
    expect(capturedQuery?.sources?.[0]).assertEqual('runtime_event')
  })

  it('should return empty list when repository query throws', 0, () => {
    PeripheralTraceRepository.query = (_query?: PeripheralTraceQuery): PeripheralTraceRecord[] => {
      throw new Error('query failed')
    }

    const records = PeripheralConnectionRecordService.queryRecords()

    expect(records.length).assertEqual(0)
  })
})
