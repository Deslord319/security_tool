import { describe, expect, it } from '@ohos/hypium'
import { SecurityEventResult } from '../../main/ets/models/CommonModels'
import { ResultText, LabelText } from '../../main/ets/constants/StringCatalog'
import {
  PeripheralConnectionRecord,
  PeripheralType
} from '../../main/ets/models/PeripheralModels'
import { PeripheralConnectionRecordStrings, PeripheralMatchedPolicyStrings, PeripheralRecordActionPresentationStrings, PeripheralRecordResultPresentationStrings } from '../../main/ets/constants/modules/PeripheralStrings'
import { FirewallDialogStrings } from '../../main/ets/constants/modules/FirewallStrings'
import {
  getPeripheralConnectionActionLabel,
  getPeripheralConnectionPolicyLabel,
  getPeripheralConnectionResultLabel,
  getPeripheralMatchedPolicyKindLabel,
  getPeripheralRecordActionLabel,
  getPeripheralRecordSourceLabel
} from '../../main/ets/presentation/peripheral/PeripheralRecordPresentationMapper'

function createConnectionRecord(): PeripheralConnectionRecord {
  return {
    id: 'runtime-base',
    timestamp: Date.now(),
    deviceName: 'USB Device',
    deviceType: PeripheralType.USB_STORAGE,
    deviceId: 'VID:1234 PID:5678',
    action: 'connect',
    result: SecurityEventResult.SUCCESS,
    policyHit: 'allow',
    source: 'runtime_event',
    summary: 'base'
  }
}

function createUnexpectedResultRecord(): PeripheralConnectionRecord {
  let record = createConnectionRecord()
  record.id = 'runtime-unexpected'
  record.result = -1 as SecurityEventResult
  return record
}

export default function peripheralRecordDisplayUtilsTest() {
  describe('PeripheralRecordDisplayUtils', () => {
    it('should keep current action and source labels populated', 0, () => {
      expect(getPeripheralRecordActionLabel('discover').length > 0).assertTrue()
      expect(getPeripheralRecordActionLabel('intercept').length > 0).assertTrue()
      expect(getPeripheralRecordSourceLabel('runtime_event').length > 0).assertTrue()
      expect(getPeripheralRecordSourceLabel('audit_event').length > 0).assertTrue()
      expect(getPeripheralRecordSourceLabel('policy_snapshot').length > 0).assertTrue()
    })

    it('should expose stable labels for all matched policy kinds', 0, () => {
      expect(getPeripheralMatchedPolicyKindLabel('usb_disabled')).assertEqual(PeripheralMatchedPolicyStrings.USB_DISABLED)
      expect(getPeripheralMatchedPolicyKindLabel('usb_storage_disabled')).assertEqual(PeripheralMatchedPolicyStrings.USB_STORAGE_DISABLED)
      expect(getPeripheralMatchedPolicyKindLabel('usb_storage_read_only')).assertEqual(PeripheralMatchedPolicyStrings.USB_STORAGE_READ_ONLY)
      expect(getPeripheralMatchedPolicyKindLabel('device_deny')).assertEqual(PeripheralMatchedPolicyStrings.DEVICE_DENY)
      expect(getPeripheralMatchedPolicyKindLabel('bluetooth_disabled')).assertEqual(PeripheralMatchedPolicyStrings.BLUETOOTH_DISABLED)
      expect(getPeripheralMatchedPolicyKindLabel('bluetooth_connection')).assertEqual(PeripheralMatchedPolicyStrings.BLUETOOTH_CONNECTION)
      expect(getPeripheralMatchedPolicyKindLabel('default_allow')).assertEqual(PeripheralMatchedPolicyStrings.DEFAULT_ALLOW)
      expect(getPeripheralMatchedPolicyKindLabel('disconnect_event')).assertEqual(PeripheralMatchedPolicyStrings.DISCONNECT_EVENT)
      expect(getPeripheralMatchedPolicyKindLabel('unknown')).assertEqual('--')
    })

    it('should prefer matched policy kind labels', 0, () => {
      const record = createConnectionRecord()
      record.id = 'runtime-1'
      record.result = SecurityEventResult.BLOCKED
      record.policyHit = 'deny'
      record.summary = 'runtime'
      record.matchedPolicyKind = 'device_deny'

      expect(getPeripheralConnectionPolicyLabel(record)).assertEqual(PeripheralMatchedPolicyStrings.DEVICE_DENY)
      expect(getPeripheralMatchedPolicyKindLabel(record.matchedPolicyKind)).assertEqual(PeripheralMatchedPolicyStrings.DEVICE_DENY)
      expect(getPeripheralConnectionResultLabel(record)).assertEqual(PeripheralRecordResultPresentationStrings.BLOCKED)
    })

    it('should fallback to policy hit labels when matched policy kind is missing', 0, () => {
      const allowRecord = createConnectionRecord()
      allowRecord.id = 'runtime-allow'
      allowRecord.deviceId = 'VID:0001 PID:0001'
      allowRecord.summary = 'allow'
      const denyRecord = createConnectionRecord()
      denyRecord.id = 'runtime-deny'
      denyRecord.deviceId = 'VID:0001 PID:0001'
      denyRecord.policyHit = 'deny'
      denyRecord.result = SecurityEventResult.BLOCKED
      denyRecord.summary = 'deny'
      const unknownRecord = createConnectionRecord()
      unknownRecord.id = 'runtime-unknown'
      unknownRecord.deviceId = 'VID:0001 PID:0001'
      unknownRecord.policyHit = 'unknown'
      unknownRecord.summary = 'unknown'

      expect(getPeripheralConnectionPolicyLabel(allowRecord)).assertEqual(FirewallDialogStrings.ACTION_ALLOW)
      expect(getPeripheralConnectionPolicyLabel(denyRecord)).assertEqual(FirewallDialogStrings.ACTION_DENY)
      expect(getPeripheralConnectionPolicyLabel(unknownRecord)).assertEqual(LabelText.UNKNOWN)
    })

    it('should render policy snapshot labels from actual policy and operation result', 0, () => {
      const record = createConnectionRecord()
      record.id = 'snapshot-1'
      record.source = 'policy_snapshot'
      record.action = 'discover'
      record.summary = 'snapshot'

      expect(getPeripheralConnectionActionLabel(record)).assertEqual(PeripheralRecordActionPresentationStrings.POLICY_CHANGE)
      expect(getPeripheralConnectionPolicyLabel(record)).assertEqual(FirewallDialogStrings.ACTION_ALLOW)
      expect(getPeripheralConnectionResultLabel(record)).assertEqual(ResultText.SUCCESS)
    })

    it('should render usb storage policy snapshots as policy changes', 0, () => {
      const disabledRecord = createConnectionRecord()
      disabledRecord.id = 'snapshot-storage-disabled'
      disabledRecord.source = 'policy_snapshot'
      disabledRecord.action = 'discover'
      disabledRecord.policyHit = 'deny'
      disabledRecord.result = SecurityEventResult.BLOCKED
      const enabledRecord = createConnectionRecord()
      enabledRecord.id = 'snapshot-storage-enabled'
      enabledRecord.source = 'policy_snapshot'
      enabledRecord.action = 'discover'

      expect(getPeripheralConnectionActionLabel(disabledRecord)).assertEqual(PeripheralRecordActionPresentationStrings.POLICY_CHANGE)
      expect(getPeripheralConnectionPolicyLabel(disabledRecord)).assertEqual(FirewallDialogStrings.ACTION_DENY)
      expect(getPeripheralConnectionResultLabel(disabledRecord)).assertEqual(PeripheralRecordResultPresentationStrings.BLOCKED)
      expect(getPeripheralConnectionActionLabel(enabledRecord)).assertEqual(PeripheralRecordActionPresentationStrings.POLICY_CHANGE)
    })

    it('should render bluetooth acl connection labels', 0, () => {
      const record = createConnectionRecord()
      record.id = 'runtime-bt-acl-1'
      record.deviceName = 'Bluetooth Mouse'
      record.deviceType = PeripheralType.BLUETOOTH
      record.deviceId = 'MAC: 11:22:33:44:55:66'
      record.policyHit = 'unknown'
      record.summary = PeripheralConnectionRecordStrings.BLUETOOTH_CONNECTED
      record.matchedPolicyKind = 'bluetooth_connection'

      expect(getPeripheralConnectionPolicyLabel(record)).assertEqual(PeripheralMatchedPolicyStrings.BLUETOOTH_CONNECTION)
      expect(getPeripheralMatchedPolicyKindLabel(record.matchedPolicyKind)).assertEqual(PeripheralMatchedPolicyStrings.BLUETOOTH_CONNECTION)
      expect(getPeripheralConnectionResultLabel(record)).assertEqual(ResultText.SUCCESS)
    })

    it('should map all result states to stable labels', 0, () => {
      const baseRecord = createConnectionRecord()
      const blockedRecord = createConnectionRecord()
      blockedRecord.result = SecurityEventResult.BLOCKED
      const failedRecord = createConnectionRecord()
      failedRecord.result = SecurityEventResult.FAILED
      const unexpectedRecord = createUnexpectedResultRecord()

      expect(getPeripheralConnectionResultLabel(baseRecord)).assertEqual(ResultText.SUCCESS)
      expect(getPeripheralConnectionResultLabel(blockedRecord)).assertEqual(PeripheralRecordResultPresentationStrings.BLOCKED)
      expect(getPeripheralConnectionResultLabel(failedRecord)).assertEqual(ResultText.FAILED)
      expect(getPeripheralConnectionResultLabel(unexpectedRecord)).assertEqual(LabelText.UNKNOWN)
    })
  })
}
