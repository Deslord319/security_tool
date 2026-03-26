import { describe, expect, it } from '@ohos/hypium'
import { LogEventResult, PeripheralConnectionRecord, PeripheralType } from '../../main/ets/models/DataModels'
import {
  getPeripheralConnectionPolicyLabel,
  getPeripheralConnectionResultLabel,
  getPeripheralMatchedPolicyKindLabel
} from '../../main/ets/utils/PeripheralRecordDisplayUtils'

describe('PeripheralRecordDisplayUtils', () => {
  it('should return snapshot labels for policy snapshot records', 0, () => {
    const record: PeripheralConnectionRecord = {
      id: 'snapshot-1',
      timestamp: Date.now(),
      deviceName: 'Snapshot Device',
      deviceType: PeripheralType.USB_STORAGE,
      deviceId: 'VID:1234 PID:5678',
      action: 'unknown',
      result: LogEventResult.SUCCESS,
      policyHit: 'unknown',
      source: 'policy_snapshot',
      summary: 'snapshot'
    }

    expect(getPeripheralConnectionPolicyLabel(record)).assertEqual('未审计')
    expect(getPeripheralConnectionResultLabel(record)).assertEqual('快照')
  })

  it('should prefer matched policy kind labels', 0, () => {
    const record: PeripheralConnectionRecord = {
      id: 'runtime-1',
      timestamp: Date.now(),
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      deviceId: 'VID:1234 PID:5678',
      action: 'connect',
      result: LogEventResult.SUCCESS,
      policyHit: 'allow',
      source: 'runtime_event',
      summary: 'runtime',
      matchedPolicyKind: 'usb_blacklist'
    }

    expect(getPeripheralConnectionPolicyLabel(record)).assertEqual('命中 USB 黑名单')
    expect(getPeripheralMatchedPolicyKindLabel(record.matchedPolicyKind)).assertEqual('命中 USB 黑名单')
  })

  it('should fall back to default labels when no matched kind exists', 0, () => {
    const record: PeripheralConnectionRecord = {
      id: 'runtime-2',
      timestamp: Date.now(),
      deviceName: 'USB Device',
      deviceType: PeripheralType.USB_STORAGE,
      deviceId: 'VID:1234 PID:5678',
      action: 'disconnect',
      result: LogEventResult.FAILED,
      policyHit: 'deny',
      source: 'runtime_event',
      summary: 'runtime'
    }

    expect(getPeripheralConnectionPolicyLabel(record)).assertEqual('阻止')
    expect(getPeripheralConnectionResultLabel(record)).assertEqual('失败')
    expect(getPeripheralMatchedPolicyKindLabel(undefined)).assertEqual('--')
  })
})
