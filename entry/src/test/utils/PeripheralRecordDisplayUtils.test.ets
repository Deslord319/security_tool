import { describe, expect, it } from '@ohos/hypium'
import { LogEventResult, PeripheralConnectionRecord, PeripheralType } from '../../main/ets/models/DataModels'
import {
  getPeripheralConnectionPolicyLabel,
  getPeripheralConnectionResultLabel,
  getPeripheralMatchedPolicyKindLabel
} from '../../main/ets/viewmodels/PeripheralRecordPresentationMapper'

function createConnectionRecord(): PeripheralConnectionRecord {
  return {
    id: 'runtime-base',
    timestamp: Date.now(),
    deviceName: 'USB Device',
    deviceType: PeripheralType.USB_STORAGE,
    deviceId: 'VID:1234 PID:5678',
    action: 'connect',
    result: LogEventResult.SUCCESS,
    policyHit: 'allow',
    source: 'runtime_event',
    summary: 'base'
  }
}

function createUnexpectedResultRecord(): PeripheralConnectionRecord {
  let record = createConnectionRecord()
  record.id = 'runtime-unexpected'
  record.result = -1 as LogEventResult
  return record
}

export default function peripheralRecordDisplayUtilsTest() {
  describe('PeripheralRecordDisplayUtils', () => {
    it('should expose stable labels for all matched policy kinds', 0, () => {
      expect(getPeripheralMatchedPolicyKindLabel('usb_disabled')).assertEqual('USB 接口已禁用')
      expect(getPeripheralMatchedPolicyKindLabel('usb_storage_disabled')).assertEqual('USB 存储已禁用')
      expect(getPeripheralMatchedPolicyKindLabel('usb_storage_read_only')).assertEqual('USB 存储只读')
      expect(getPeripheralMatchedPolicyKindLabel('device_deny')).assertEqual('命中单设备禁止接入')
      expect(getPeripheralMatchedPolicyKindLabel('bluetooth_connection_event')).assertEqual('蓝牙连接事件')
      expect(getPeripheralMatchedPolicyKindLabel('bluetooth_discovery')).assertEqual('蓝牙运行期发现')
      expect(getPeripheralMatchedPolicyKindLabel('default_allow')).assertEqual('默认允许接入')
      expect(getPeripheralMatchedPolicyKindLabel('disconnect_event')).assertEqual('设备断开连接')
      expect(getPeripheralMatchedPolicyKindLabel('unknown')).assertEqual('--')
    })

    it('should prefer matched policy kind labels', 0, () => {
      const record = createConnectionRecord()
      record.id = 'runtime-1'
      record.result = LogEventResult.BLOCKED
      record.policyHit = 'deny'
      record.summary = 'runtime'
      record.matchedPolicyKind = 'device_deny'

      expect(getPeripheralConnectionPolicyLabel(record)).assertEqual('命中单设备禁止接入')
      expect(getPeripheralMatchedPolicyKindLabel(record.matchedPolicyKind)).assertEqual('命中单设备禁止接入')
      expect(getPeripheralConnectionResultLabel(record)).assertEqual('已阻止')
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
      denyRecord.result = LogEventResult.BLOCKED
      denyRecord.summary = 'deny'
      const unknownRecord = createConnectionRecord()
      unknownRecord.id = 'runtime-unknown'
      unknownRecord.deviceId = 'VID:0001 PID:0001'
      unknownRecord.policyHit = 'unknown'
      unknownRecord.summary = 'unknown'

      expect(getPeripheralConnectionPolicyLabel(allowRecord)).assertEqual('允许')
      expect(getPeripheralConnectionPolicyLabel(denyRecord)).assertEqual('禁止')
      expect(getPeripheralConnectionPolicyLabel(unknownRecord)).assertEqual('未知')
    })

    it('should render policy snapshot specific labels', 0, () => {
      const record = createConnectionRecord()
      record.id = 'snapshot-1'
      record.source = 'policy_snapshot'
      record.summary = 'snapshot'

      expect(getPeripheralConnectionPolicyLabel(record)).assertEqual('策略待判定')
      expect(getPeripheralConnectionResultLabel(record)).assertEqual('策略快照')
    })

    it('should render bluetooth discovery labels', 0, () => {
      const record = createConnectionRecord()
      record.id = 'runtime-bt-1'
      record.deviceName = 'Bluetooth Headset'
      record.deviceType = PeripheralType.BLUETOOTH
      record.deviceId = 'MAC: AA:BB:CC:DD:EE:FF'
      record.action = 'discover'
      record.policyHit = 'unknown'
      record.summary = '发现蓝牙设备'
      record.matchedPolicyKind = 'bluetooth_discovery'

      expect(getPeripheralConnectionPolicyLabel(record)).assertEqual('蓝牙运行期发现')
      expect(getPeripheralMatchedPolicyKindLabel(record.matchedPolicyKind)).assertEqual('蓝牙运行期发现')
      expect(getPeripheralConnectionResultLabel(record)).assertEqual('成功')
    })

    it('should render bluetooth acl connection labels', 0, () => {
      const record = createConnectionRecord()
      record.id = 'runtime-bt-acl-1'
      record.deviceName = 'Bluetooth Mouse'
      record.deviceType = PeripheralType.BLUETOOTH
      record.deviceId = 'MAC: 11:22:33:44:55:66'
      record.policyHit = 'unknown'
      record.summary = '蓝牙设备已连接'
      record.matchedPolicyKind = 'bluetooth_connection_event'

      expect(getPeripheralConnectionPolicyLabel(record)).assertEqual('蓝牙连接事件')
      expect(getPeripheralMatchedPolicyKindLabel(record.matchedPolicyKind)).assertEqual('蓝牙连接事件')
      expect(getPeripheralConnectionResultLabel(record)).assertEqual('成功')
    })

    it('should map all result states to stable labels', 0, () => {
      const baseRecord = createConnectionRecord()
      const blockedRecord = createConnectionRecord()
      blockedRecord.result = LogEventResult.BLOCKED
      const failedRecord = createConnectionRecord()
      failedRecord.result = LogEventResult.FAILED
      const unexpectedRecord = createUnexpectedResultRecord()

      expect(getPeripheralConnectionResultLabel(baseRecord)).assertEqual('成功')
      expect(getPeripheralConnectionResultLabel(blockedRecord)).assertEqual('已阻止')
      expect(getPeripheralConnectionResultLabel(failedRecord)).assertEqual('失败')
      expect(getPeripheralConnectionResultLabel(unexpectedRecord)).assertEqual('未知')
    })
  })
}
