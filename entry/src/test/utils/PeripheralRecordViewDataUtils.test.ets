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

  it('should build deduplicated connection history items', 0, () => {
    const timestamp = Date.now()
    const record: PeripheralConnectionRecord = {
      id: 'record-1',
      timestamp: timestamp,
      deviceId: 'VID:1234 PID:5678',
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      action: 'connect',
      result: LogEventResult.SUCCESS,
      policyHit: 'allow',
      source: 'runtime_event',
      summary: 'connected'
    }

    const history = buildConnectionHistoryItems([record, { ...record, id: 'record-2' }], record)
    expect(history.length).assertEqual(1)
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
