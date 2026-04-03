import { describe, expect, it } from '@ohos/hypium'
import {
  LogEventResult,
  PeripheralConnectionRecord,
  PeripheralType
} from '../../main/ets/models/DataModels'
import {
  buildConnectionHistoryItems,
  formatPeripheralTimestamp
} from '../../main/ets/viewmodels/PeripheralRecordPresentationMapper'
import { PeripheralPolicyService } from '../../main/ets/services/PeripheralPolicyService'

describe('PeripheralRecordViewDataUtils', () => {
  it('should format invalid timestamps as placeholder', 0, () => {
    expect(formatPeripheralTimestamp(0)).assertEqual('--')
  })

  it('should return empty history when selected record is missing', 0, () => {
    expect(buildConnectionHistoryItems([], null).length).assertEqual(0)
  })

  it('should format valid timestamps with a concrete value', 0, () => {
    const label = formatPeripheralTimestamp(1712000000000)
    expect(label === '--').assertFalse()
    expect(label.length > 0).assertTrue()
  })

  it('should build connection history items for normalized device ids without deduplication', 0, () => {
    const timestamp = Date.now()
    const record: PeripheralConnectionRecord = {
      id: 'record-1',
      timestamp: timestamp,
      deviceId: ' VID:1234  PID:5678 ',
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      action: 'connect',
      result: LogEventResult.SUCCESS,
      policyHit: 'allow',
      source: 'runtime_event',
      summary: 'connected'
    }

    const blockedRecord: PeripheralConnectionRecord = {
      ...record,
      id: 'record-2',
      timestamp: timestamp + 1,
      deviceId: 'VID:1234 PID:5678',
      result: LogEventResult.BLOCKED,
      policyHit: 'deny',
      matchedPolicyKind: 'device_deny',
      summary: 'blocked'
    }
    const differentDeviceRecord: PeripheralConnectionRecord = {
      ...record,
      id: 'record-3',
      timestamp: timestamp + 2,
      deviceId: 'VID:9999 PID:9999',
      summary: 'other-device'
    }

    const history = buildConnectionHistoryItems([record, blockedRecord, differentDeviceRecord], record)
    expect(history.length).assertEqual(2)
    expect(history[0].policy).assertEqual('允许')
    expect(history[0].result).assertEqual('成功')
    expect(history[1].policy).assertEqual('命中单设备禁止接入')
    expect(history[1].result).assertEqual('已阻止')
  })

  it('should skip records with invalid timestamps when building history', 0, () => {
    const selectedRecord: PeripheralConnectionRecord = {
      id: 'record-selected',
      timestamp: 100,
      deviceId: 'VID:1234 PID:5678',
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      action: 'connect',
      result: LogEventResult.SUCCESS,
      policyHit: 'allow',
      source: 'runtime_event',
      summary: 'selected'
    }
    const invalidTimestampRecord: PeripheralConnectionRecord = {
      ...selectedRecord,
      id: 'record-invalid',
      timestamp: 0
    }
    const validTimestampRecord: PeripheralConnectionRecord = {
      ...selectedRecord,
      id: 'record-valid',
      timestamp: 200
    }

    const history = buildConnectionHistoryItems([invalidTimestampRecord, validTimestampRecord], selectedRecord)
    expect(history.length).assertEqual(1)
    expect(history[0].time === '--').assertFalse()
  })

  it('should build latest usb policy records from connection candidates by default', 0, () => {
    const records: PeripheralConnectionRecord[] = [
      {
        id: 'record-1',
        timestamp: 100,
        deviceId: 'VID:1234 PID:5678',
        deviceName: 'Older USB Device',
        deviceType: PeripheralType.USB_STORAGE,
        action: 'connect',
        result: LogEventResult.SUCCESS,
        policyHit: 'allow',
        source: 'runtime_event',
        summary: 'older'
      },
      {
        id: 'record-2',
        timestamp: 200,
        deviceId: 'VID:1234 PID:5678',
        deviceName: 'Latest USB Device',
        deviceType: PeripheralType.USB_STORAGE,
        action: 'connect',
        result: LogEventResult.SUCCESS,
        policyHit: 'allow',
        source: 'runtime_event',
        summary: 'latest'
      },
      {
        id: 'record-3',
        timestamp: 150,
        deviceId: 'MAC: AA:BB:CC:DD:EE:FF',
        deviceName: 'Bluetooth Device',
        deviceType: PeripheralType.BLUETOOTH,
        action: 'connect',
        result: LogEventResult.SUCCESS,
        policyHit: 'allow',
        source: 'runtime_event',
        summary: 'bt'
      }
    ]

    const defaultPolicyRecords = PeripheralPolicyService.buildPolicyRecords(records, [])
    expect(defaultPolicyRecords.length).assertEqual(1)
    expect(defaultPolicyRecords[0].deviceName).assertEqual('Latest USB Device')
    expect(defaultPolicyRecords[0].policyIndex).assertEqual(0)

    const policyRecords = PeripheralPolicyService.buildPolicyRecords(records, [{
      deviceId: 'VID:1234 PID:5678',
      policy: 'deny',
      updatedAt: Date.now()
    }])

    expect(policyRecords.length).assertEqual(1)
    expect(policyRecords[0].deviceName).assertEqual('Latest USB Device')
    expect(policyRecords[0].policyIndex).assertEqual(1)
  })
})
