import { describe, expect, it } from '@ohos/hypium'
import { LogEventResult, PeripheralConnectionRecord, PeripheralType } from '../../main/ets/models/DataModels'
import {
  getPeripheralConnectionPolicyLabel,
  getPeripheralConnectionResultLabel,
  getPeripheralMatchedPolicyKindLabel
} from '../../main/ets/viewmodels/PeripheralRecordPresentationMapper'

describe('PeripheralRecordDisplayUtils', () => {
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
})
