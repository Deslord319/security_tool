import { describe, expect, it } from '@ohos/hypium'
import {
  LogEventResult,
  PeripheralConnectionRecord,
  PeripheralDevicePolicyRecord,
  PeripheralType
} from '../../main/ets/models/DataModels'
import {
  buildConnectionHistoryItems,
  formatPeripheralTimestamp
} from '../../main/ets/viewmodels/PeripheralRecordPresentationMapper'
import { PeripheralPolicyService } from '../../main/ets/services/peripheral/device-policy/PeripheralPolicyService'

function createConnectionRecord(id: string, timestamp: number): PeripheralConnectionRecord {
  return {
    id,
    timestamp,
    deviceId: 'VID:1234 PID:5678',
    deviceName: 'USB Device',
    deviceType: PeripheralType.USB_STORAGE,
    action: 'connect',
    result: LogEventResult.SUCCESS,
    policyHit: 'allow',
    source: 'runtime_event',
    summary: 'connected'
  }
}

export default function peripheralRecordViewDataUtilsTest() {
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
      const record = createConnectionRecord('record-1', timestamp)
      record.deviceId = ' VID:1234  PID:5678 '
      const blockedRecord = createConnectionRecord('record-2', timestamp + 1)
      blockedRecord.deviceId = 'VID:1234 PID:5678'
      blockedRecord.result = LogEventResult.BLOCKED
      blockedRecord.policyHit = 'deny'
      blockedRecord.matchedPolicyKind = 'device_deny'
      blockedRecord.summary = 'blocked'
      const differentDeviceRecord = createConnectionRecord('record-3', timestamp + 2)
      differentDeviceRecord.deviceId = 'VID:9999 PID:9999'
      differentDeviceRecord.summary = 'other-device'

      const history = buildConnectionHistoryItems([record, blockedRecord, differentDeviceRecord], record)
      expect(history.length).assertEqual(2)
      expect(history[0].policy).assertEqual('允许')
      expect(history[0].result).assertEqual('成功')
      expect(history[1].policy).assertEqual('命中单设备禁止接入')
      expect(history[1].result).assertEqual('已阻止')
    })

    it('should skip records with invalid timestamps when building history', 0, () => {
      const selectedRecord = createConnectionRecord('record-selected', 100)
      selectedRecord.summary = 'selected'
      const invalidTimestampRecord = createConnectionRecord('record-invalid', 0)
      const validTimestampRecord = createConnectionRecord('record-valid', 200)

      const history = buildConnectionHistoryItems([invalidTimestampRecord, validTimestampRecord], selectedRecord)
      expect(history.length).assertEqual(1)
      expect(history[0].time === '--').assertFalse()
    })

    it('should build latest usb and bluetooth policy records from connection candidates by default', 0, () => {
      const olderRecord = createConnectionRecord('record-1', 100)
      olderRecord.deviceName = 'Older USB Device'
      olderRecord.summary = 'older'
      const latestRecord = createConnectionRecord('record-2', 200)
      latestRecord.deviceName = 'Latest USB Device'
      latestRecord.summary = 'latest'
      const bluetoothRecord = createConnectionRecord('record-3', 150)
      bluetoothRecord.deviceId = 'MAC: AA:BB:CC:DD:EE:FF'
      bluetoothRecord.deviceName = 'Bluetooth Device'
      bluetoothRecord.deviceType = PeripheralType.BLUETOOTH
      bluetoothRecord.summary = 'bt'
      const bluetoothDuplicate = createConnectionRecord('record-4', 250)
      bluetoothDuplicate.deviceId = 'aa-bb-cc-dd-ee-ff'
      bluetoothDuplicate.deviceName = 'Bluetooth Device Latest'
      bluetoothDuplicate.deviceType = PeripheralType.BLUETOOTH
      bluetoothDuplicate.summary = 'bt-latest'
      const records: PeripheralConnectionRecord[] = [olderRecord, latestRecord, bluetoothRecord, bluetoothDuplicate]

      const defaultPolicyRecords = PeripheralPolicyService.buildPolicyRecords(records, [])
      expect(defaultPolicyRecords.length).assertEqual(2)
      expect(defaultPolicyRecords[0].deviceName).assertEqual('Bluetooth Device Latest')
      expect(defaultPolicyRecords[0].deviceId).assertEqual('MAC: AA:BB:CC:DD:EE:FF')
      expect(defaultPolicyRecords[0].policyIndex).assertEqual(0)
      expect(defaultPolicyRecords[1].deviceName).assertEqual('Latest USB Device')
      expect(defaultPolicyRecords[1].policyIndex).assertEqual(0)

      const policies: PeripheralDevicePolicyRecord[] = [
        {
          deviceId: 'VID:1234 PID:5678',
          policy: 'deny',
          updatedAt: Date.now()
        },
        {
          deviceId: 'aa-bb-cc-dd-ee-ff',
          deviceType: PeripheralType.BLUETOOTH,
          policy: 'deny',
          updatedAt: Date.now()
        }
      ]
      const policyRecords = PeripheralPolicyService.buildPolicyRecords(records, policies)

      expect(policyRecords.length).assertEqual(2)
      expect(policyRecords[0].deviceName).assertEqual('Bluetooth Device Latest')
      expect(policyRecords[0].policyIndex).assertEqual(1)
      expect(policyRecords[1].deviceName).assertEqual('Latest USB Device')
      expect(policyRecords[1].policyIndex).assertEqual(1)
    })
  })
}
