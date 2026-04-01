import { describe, expect, it } from '@ohos/hypium'
import { LogEventResult, PeripheralType } from '../../main/ets/models/DataModels'
import { PeripheralConnectionRecordService } from '../../main/ets/services/PeripheralConnectionRecordService'
import { PeripheralTraceRepository } from '../../main/ets/services/PeripheralTraceRepository'

describe('PeripheralConnectionRecordService', () => {
  it('should query runtime records ordered by newest first', 0, () => {
    PeripheralTraceRepository.resetForTest()
    PeripheralTraceRepository.setRecordsForTest([
      {
        recordId: 'runtime_older',
        occurAt: 100,
        collectAt: 101,
        deviceName: 'Older Device',
        deviceType: PeripheralType.USB_STORAGE,
        deviceId: 'VID:1111 PID:0001',
        action: 'connect',
        decision: 'allow',
        result: LogEventResult.SUCCESS,
        source: 'runtime_event',
        summary: 'older'
      },
      {
        recordId: 'runtime_newer',
        occurAt: 200,
        collectAt: 201,
        deviceName: 'Newer Device',
        deviceType: PeripheralType.USB_STORAGE,
        deviceId: 'VID:2222 PID:0002',
        action: 'disconnect',
        decision: 'unknown',
        result: LogEventResult.SUCCESS,
        source: 'runtime_event',
        summary: 'newer'
      }
    ])

    const records = PeripheralConnectionRecordService.queryRecords()
    expect(records.length).assertEqual(2)
    expect(records[0].deviceName).assertEqual('Newer Device')
    expect(records[1].deviceName).assertEqual('Older Device')
  })

  it('should map bluetooth discovery runtime records', 0, () => {
    PeripheralTraceRepository.resetForTest()
    PeripheralTraceRepository.setRecordsForTest([
      {
        recordId: 'runtime_bt_1',
        occurAt: 300,
        collectAt: 301,
        deviceName: 'Bluetooth Mouse',
        deviceType: PeripheralType.BLUETOOTH,
        deviceId: 'MAC: AA:BB:CC:DD:EE:FF',
        action: 'discover',
        decision: 'unknown',
        result: LogEventResult.SUCCESS,
        source: 'runtime_event',
        summary: '发现蓝牙设备',
        matchedPolicyKind: 'bluetooth_discovery'
      }
    ])

    const records = PeripheralConnectionRecordService.queryRecords()
    expect(records.length).assertEqual(1)
    expect(records[0].deviceType).assertEqual(PeripheralType.BLUETOOTH)
    expect(records[0].action).assertEqual('discover')
    expect(records[0].matchedPolicyKind).assertEqual('bluetooth_discovery')
  })

  it('should map bluetooth acl runtime records', 0, () => {
    PeripheralTraceRepository.resetForTest()
    PeripheralTraceRepository.setRecordsForTest([
      {
        recordId: 'runtime_bt_acl_1',
        occurAt: 400,
        collectAt: 401,
        deviceName: 'Bluetooth Keyboard',
        deviceType: PeripheralType.BLUETOOTH,
        deviceId: 'MAC: 11:22:33:44:55:66',
        action: 'connect',
        decision: 'unknown',
        result: LogEventResult.SUCCESS,
        source: 'runtime_event',
        summary: '蓝牙设备已连接',
        matchedPolicyKind: 'bluetooth_connection_event'
      }
    ])

    const records = PeripheralConnectionRecordService.queryRecords()
    expect(records.length).assertEqual(1)
    expect(records[0].deviceType).assertEqual(PeripheralType.BLUETOOTH)
    expect(records[0].action).assertEqual('connect')
    expect(records[0].matchedPolicyKind).assertEqual('bluetooth_connection_event')
  })
})
