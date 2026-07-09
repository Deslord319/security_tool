import { describe, expect, it } from '@ohos/hypium'
import { SecurityEventResult } from '../../main/ets/models/CommonModels'
import {
  PeripheralConnectionRecord,
  PeripheralType,
  UsbDevicePolicyStateRecord
} from '../../main/ets/models/PeripheralModels'
import {
  buildConnectionHistoryItems,
  formatPeripheralTimestamp,
  getPeripheralConnectionListPolicyLabel
} from '../../main/ets/viewmodels/peripheral/connection-record/PeripheralRecordPresentationMapper'
import { PeripheralPolicyService } from '../../main/ets/services/peripheral/device-policy/PeripheralPolicyService'

function createConnectionRecord(id: string, timestamp: number): PeripheralConnectionRecord {
  return {
    id,
    timestamp,
    deviceId: 'VID:1234 PID:5678',
    deviceName: 'USB Device',
    deviceType: PeripheralType.USB_STORAGE,
    action: 'connect',
    result: SecurityEventResult.SUCCESS,
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
      blockedRecord.result = SecurityEventResult.BLOCKED
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

    it('should map device deny records to disabled list policy label', 0, () => {
      const record = createConnectionRecord('record-deny', 300)
      record.policyHit = 'deny'
      record.matchedPolicyKind = 'device_deny'

      const label = getPeripheralConnectionListPolicyLabel(record)

      expect(label).assertEqual('已禁用')
    })

    it('should map bluetooth records without explicit label to enabled list policy label', 0, () => {
      const record = createConnectionRecord('record-bt', 301)
      record.deviceType = PeripheralType.BLUETOOTH
      record.deviceId = 'MAC: 11:22:33:44:55:66'
      record.effectivePolicyLabel = ''

      const label = getPeripheralConnectionListPolicyLabel(record)

      expect(label).assertEqual('已启用')
    })

    it('should use explicit effective policy label for list policy label', 0, () => {
      const record = createConnectionRecord('record-explicit', 302)
      record.effectivePolicyLabel = '已禁用'

      const label = getPeripheralConnectionListPolicyLabel(record)

      expect(label).assertEqual('已禁用')
    })

    it('should build usb policy records only from usb policy state records', 0, () => {
      const defaultPolicyRecords = PeripheralPolicyService.buildPolicyRecords([])
      expect(defaultPolicyRecords.length).assertEqual(0)

      const states: UsbDevicePolicyStateRecord[] = [{
        fingerprintKey: 'USB-WEAK:1234:5678:ABCDEF01',
        fingerprintType: 'weak',
        vendorId: 0x1234,
        productId: 0x5678,
        description: 'storage',
        baseClass: 0x08,
        deviceName: 'Latest USB Device',
        desiredPolicy: 'deny',
        present: true,
        activePolicy: 'deny',
        lastSeenAt: 200,
        updatedAt: 201
      }]
      const policyRecords = PeripheralPolicyService.buildPolicyRecords(states)

      expect(policyRecords.length).assertEqual(1)
      expect(policyRecords[0].deviceName).assertEqual('Latest USB Device')
      expect(policyRecords[0].policyIndex).assertEqual(1)
      expect(policyRecords[0].editable).assertTrue()
    })
  })
}
