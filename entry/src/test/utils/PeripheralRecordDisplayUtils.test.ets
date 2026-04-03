import { describe, expect, it } from '@ohos/hypium'
import { LogEventResult, PeripheralConnectionRecord, PeripheralType } from '../../main/ets/models/DataModels'
import {
  getPeripheralConnectionPolicyLabel,
  getPeripheralConnectionResultLabel,
  getPeripheralMatchedPolicyKindLabel
} from '../../main/ets/viewmodels/PeripheralRecordPresentationMapper'

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
    const record: PeripheralConnectionRecord = {
      id: 'runtime-1',
      timestamp: Date.now(),
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      deviceId: 'VID:1234 PID:5678',
      action: 'connect',
      result: LogEventResult.BLOCKED,
      policyHit: 'deny',
      source: 'runtime_event',
      summary: 'runtime',
      matchedPolicyKind: 'device_deny'
    }

    expect(getPeripheralConnectionPolicyLabel(record)).assertEqual('命中单设备禁止接入')
    expect(getPeripheralMatchedPolicyKindLabel(record.matchedPolicyKind)).assertEqual('命中单设备禁止接入')
    expect(getPeripheralConnectionResultLabel(record)).assertEqual('已阻止')
  })

  it('should fallback to policy hit labels when matched policy kind is missing', 0, () => {
    const allowRecord: PeripheralConnectionRecord = {
      id: 'runtime-allow',
      timestamp: Date.now(),
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      deviceId: 'VID:0001 PID:0001',
      action: 'connect',
      result: LogEventResult.SUCCESS,
      policyHit: 'allow',
      source: 'runtime_event',
      summary: 'allow'
    }
    const denyRecord: PeripheralConnectionRecord = {
      ...allowRecord,
      id: 'runtime-deny',
      policyHit: 'deny',
      result: LogEventResult.BLOCKED,
      summary: 'deny'
    }
    const unknownRecord: PeripheralConnectionRecord = {
      ...allowRecord,
      id: 'runtime-unknown',
      policyHit: 'unknown',
      result: LogEventResult.SUCCESS,
      summary: 'unknown'
    }

    expect(getPeripheralConnectionPolicyLabel(allowRecord)).assertEqual('允许')
    expect(getPeripheralConnectionPolicyLabel(denyRecord)).assertEqual('禁止')
    expect(getPeripheralConnectionPolicyLabel(unknownRecord)).assertEqual('未知')
  })

  it('should render policy snapshot specific labels', 0, () => {
    const record: PeripheralConnectionRecord = {
      id: 'snapshot-1',
      timestamp: Date.now(),
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      deviceId: 'VID:1234 PID:5678',
      action: 'connect',
      result: LogEventResult.SUCCESS,
      policyHit: 'allow',
      source: 'policy_snapshot',
      summary: 'snapshot'
    }

    expect(getPeripheralConnectionPolicyLabel(record)).assertEqual('策略待判定')
    expect(getPeripheralConnectionResultLabel(record)).assertEqual('策略快照')
  })

  it('should render bluetooth discovery labels', 0, () => {
    const record: PeripheralConnectionRecord = {
      id: 'runtime-bt-1',
      timestamp: Date.now(),
      deviceName: 'Bluetooth Headset',
      deviceType: PeripheralType.BLUETOOTH,
      deviceId: 'MAC: AA:BB:CC:DD:EE:FF',
      action: 'discover',
      result: LogEventResult.SUCCESS,
      policyHit: 'unknown',
      source: 'runtime_event',
      summary: '发现蓝牙设备',
      matchedPolicyKind: 'bluetooth_discovery'
    }

    expect(getPeripheralConnectionPolicyLabel(record)).assertEqual('蓝牙运行期发现')
    expect(getPeripheralMatchedPolicyKindLabel(record.matchedPolicyKind)).assertEqual('蓝牙运行期发现')
    expect(getPeripheralConnectionResultLabel(record)).assertEqual('成功')
  })

  it('should render bluetooth acl connection labels', 0, () => {
    const record: PeripheralConnectionRecord = {
      id: 'runtime-bt-acl-1',
      timestamp: Date.now(),
      deviceName: 'Bluetooth Mouse',
      deviceType: PeripheralType.BLUETOOTH,
      deviceId: 'MAC: 11:22:33:44:55:66',
      action: 'connect',
      result: LogEventResult.SUCCESS,
      policyHit: 'unknown',
      source: 'runtime_event',
      summary: '蓝牙设备已连接',
      matchedPolicyKind: 'bluetooth_connection_event'
    }

    expect(getPeripheralConnectionPolicyLabel(record)).assertEqual('蓝牙连接事件')
    expect(getPeripheralMatchedPolicyKindLabel(record.matchedPolicyKind)).assertEqual('蓝牙连接事件')
    expect(getPeripheralConnectionResultLabel(record)).assertEqual('成功')
  })

  it('should map all result states to stable labels', 0, () => {
    const baseRecord: PeripheralConnectionRecord = {
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

    expect(getPeripheralConnectionResultLabel(baseRecord)).assertEqual('成功')
    expect(getPeripheralConnectionResultLabel({ ...baseRecord, result: LogEventResult.BLOCKED })).assertEqual('已阻止')
    expect(getPeripheralConnectionResultLabel({ ...baseRecord, result: LogEventResult.FAILED })).assertEqual('失败')
    expect(getPeripheralConnectionResultLabel({ ...baseRecord, result: 'unexpected' as LogEventResult })).assertEqual('未知')
  })
})
