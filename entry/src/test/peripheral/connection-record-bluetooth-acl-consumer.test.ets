import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { commonEventManager } from '@kit.BasicServicesKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { SecurityEventResult } from '../../main/ets/models/CommonModels'
import {
  PeripheralDevicePolicyRecord,
  PeripheralType
} from '../../main/ets/models/PeripheralModels'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/peripheral/device-policy/PeripheralDevicePolicyRepository'
import {
  PeripheralDevicePolicyDispatchService,
  PeripheralPolicyDispatchResult
} from '../../main/ets/services/peripheral/device-policy/peripheral_device_policy_dispatch_service'
import { PeripheralConnectionRecordBluetoothAclConsumer } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_bluetooth_acl_consumer'
import { PeripheralConnectionRecordProducerEvent } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_producer_contract'

interface BluetoothAclParameters {
  deviceId: string
  deviceName: string
  stateName: string
  reason: string
  timestamp: number
  deviceAddr?: string
  address?: string
  remoteName?: string
  alias?: string
}

interface BluetoothAclParameterOverrides {
  deviceId?: string
  deviceName?: string
  stateName?: string
  reason?: string
  timestamp?: number
  deviceAddr?: string
  address?: string
  remoteName?: string
  alias?: string
}

class BluetoothAclRawData {
  event: string
  parameters: Object
  constructor(event: string, parameters: Object) {
    this.event = event
    this.parameters = parameters
  }
}

function buildBluetoothAclParameters(overrides?: BluetoothAclParameterOverrides): BluetoothAclParameters {
  let parameters: BluetoothAclParameters = {
    deviceId: '11:22:33:44:55:66',
    deviceName: 'Bluetooth Keyboard',
    stateName: 'STATE_CONNECTED',
    reason: 'SUCCESS',
    timestamp: 200
  }
  if (!overrides) {
    return parameters
  }
  if (overrides.deviceId !== undefined) {
    parameters.deviceId = overrides.deviceId
  }
  if (overrides.deviceName !== undefined) {
    parameters.deviceName = overrides.deviceName
  }
  if (overrides.stateName !== undefined) {
    parameters.stateName = overrides.stateName
  }
  if (overrides.reason !== undefined) {
    parameters.reason = overrides.reason
  }
  if (overrides.timestamp !== undefined) {
    parameters.timestamp = overrides.timestamp
  }
  if (overrides.deviceAddr !== undefined) {
    parameters.deviceAddr = overrides.deviceAddr
  }
  if (overrides.address !== undefined) {
    parameters.address = overrides.address
  }
  if (overrides.remoteName !== undefined) {
    parameters.remoteName = overrides.remoteName
  }
  if (overrides.alias !== undefined) {
    parameters.alias = overrides.alias
  }
  return parameters
}

function buildBluetoothAclEvent(
  parameterOverrides?: BluetoothAclParameterOverrides
): PeripheralConnectionRecordProducerEvent {
  let rawData = new BluetoothAclRawData('usual.event.BLUETOOTH_ACL', buildBluetoothAclParameters(parameterOverrides) as Object)
  let event: PeripheralConnectionRecordProducerEvent = {
    source: 'runtime',
    channel: 'bluetooth_acl',
    eventName: 'usual.event.BLUETOOTH_ACL',
    rawData: rawData as commonEventManager.CommonEventData
  }
  return event
}

function createDispatchResult(success: boolean, reason?: string): PeripheralPolicyDispatchResult {
  let result: PeripheralPolicyDispatchResult = {
    success: success
  }
  if (reason !== undefined) {
    result.reason = reason as never
  }
  return result
}

export default function peripheralConnectionRecordBluetoothAclConsumerTest() {
  describe('PeripheralConnectionRecordBluetoothAclConsumer', () => {
    let mockKit: MockKit
    let dispatchResult: PeripheralPolicyDispatchResult
    let dispatchCount: number

    beforeEach(async () => {
      mockKit = new MockKit()
      dispatchResult = createDispatchResult(true)
      dispatchCount = 0
      await PeripheralDevicePolicyRepository.clearAll()
      const dispatchMock = mockKit.mockFunc(PeripheralDevicePolicyDispatchService, PeripheralDevicePolicyDispatchService.dispatch)
      when(dispatchMock)(ArgumentMatchers.any).afterAction(() => {
        dispatchCount += 1
        return Promise.resolve(dispatchResult)
      })
    })

    afterEach(async () => {
      mockKit.clear(PeripheralDevicePolicyDispatchService)
      mockKit.clearAll()
      await PeripheralDevicePolicyRepository.clearAll()
    })

    it('U-BT-001 should auto deny first bluetooth acl connect event', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()

      const record = await consumer.consume(buildBluetoothAclEvent())

      expect(record !== null).assertTrue()
      expect(record?.action).assertEqual('connect')
      expect(record?.decision).assertEqual('deny')
      expect(record?.result).assertEqual(SecurityEventResult.BLOCKED)
      expect(record?.summary).assertEqual('蓝牙设备已连接')
      expect(record?.matchedPolicyKind).assertEqual('bluetooth_connection_event')
      expect(record?.effectivePolicyLabel).assertEqual('已禁用')
      expect(record?.deviceType).assertEqual(PeripheralType.BLUETOOTH)
      expect(record?.detail?.includes('首次接入已自动加入黑名单')).assertTrue()
      expect(dispatchCount).assertEqual(1)
      expect(PeripheralDevicePolicyRepository.get('MAC: 11:22:33:44:55:66')?.policy).assertEqual('deny')
    })

    it('U-BT-002 should map bluetooth acl disconnect event to disconnect record', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      let disconnectOverrides: BluetoothAclParameterOverrides = {
        stateName: 'STATE_DISCONNECTED',
        reason: 'REMOTE_DISCONNECT'
      }

      const record = await consumer.consume(buildBluetoothAclEvent(disconnectOverrides))

      expect(record !== null).assertTrue()
      expect(record?.action).assertEqual('disconnect')
      expect(record?.decision).assertEqual('allow')
      expect(record?.result).assertEqual(SecurityEventResult.SUCCESS)
      expect(record?.summary).assertEqual('蓝牙设备已断开')
      expect(record?.effectivePolicyLabel).assertEqual('已启用')
      expect(record?.detail).assertEqual('aclState=STATE_DISCONNECTED, reason=REMOTE_DISCONNECT')
    })

    it('U-BT-003 should ignore bluetooth acl events with unknown state', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      let unknownStateOverrides: BluetoothAclParameterOverrides = {
        stateName: 'STATE_IDLE'
      }

      const record = await consumer.consume(buildBluetoothAclEvent(unknownStateOverrides))

      expect(record === null).assertTrue()
    })

    it('U-BT-004 should ignore bluetooth acl events without deviceId', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      let missingDeviceIdOverrides: BluetoothAclParameterOverrides = {
        stateName: 'STATE_CONNECTED',
        deviceId: '',
        deviceAddr: '',
        address: ''
      }
      const event = buildBluetoothAclEvent(missingDeviceIdOverrides)

      const record = await consumer.consume(event)

      expect(record === null).assertTrue()
    })

    it('U-BT-005 should prefer payload device name over remote lookup result', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      let payloadNameOverrides: BluetoothAclParameterOverrides = {
        deviceName: 'Payload Device Name'
      }

      const record = await consumer.consume(buildBluetoothAclEvent(payloadNameOverrides))

      expect(record !== null).assertTrue()
      expect(record?.deviceName).assertEqual('Payload Device Name')
    })

    it('U-BT-006 should use fallback bluetooth name when no name can be resolved', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      let fallbackNameOverrides: BluetoothAclParameterOverrides = {
        deviceName: '',
        remoteName: '',
        alias: ''
      }

      const record = await consumer.consume(buildBluetoothAclEvent(fallbackNameOverrides))

      expect(record !== null).assertTrue()
      expect(record?.deviceName).assertEqual('未命名蓝牙设备')
    })

    it('U-BT-007 should normalize bluetooth device id format', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      let normalizeIdOverrides: BluetoothAclParameterOverrides = {
        deviceId: 'aa-bb-cc-dd-ee-ff'
      }

      const record = await consumer.consume(buildBluetoothAclEvent(normalizeIdOverrides))

      expect(record !== null).assertTrue()
      expect(record?.deviceId).assertEqual('MAC: AA:BB:CC:DD:EE:FF')
    })

    it('U-BT-008 should serialize raw bluetooth payload into rawPayload', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      const event = buildBluetoothAclEvent()

      const record = await consumer.consume(event)

      expect(record !== null).assertTrue()
      expect((record?.rawPayload?.length ?? 0) > 0).assertTrue()
      expect(record?.rawPayload?.includes('"deviceId":"11:22:33:44:55:66"')).assertTrue()
      expect(record?.rawPayload?.includes('"stateName":"STATE_CONNECTED"')).assertTrue()
    })

    it('U-BT-009 should mark bluetooth record disabled when device policy is deny', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      const deniedPolicy: PeripheralDevicePolicyRecord = {
        deviceId: 'MAC: 11:22:33:44:55:66',
        policy: 'deny',
        updatedAt: 1,
        deviceType: PeripheralType.BLUETOOTH,
        deviceName: 'Bluetooth Keyboard'
      }
      await PeripheralDevicePolicyRepository.set(deniedPolicy)

      const record = await consumer.consume(buildBluetoothAclEvent())

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('deny')
      expect(record?.effectivePolicyLabel).assertEqual('已禁用')
      expect(record?.matchedPolicyKind).assertEqual('bluetooth_connection_event')
    })

    it('U-BT-010 should keep explicit allow policy and skip auto deny dispatch', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      await PeripheralDevicePolicyRepository.set({
        deviceId: 'MAC: 11:22:33:44:55:66',
        policy: 'allow',
        updatedAt: 1,
        deviceType: PeripheralType.BLUETOOTH,
        deviceName: 'Bluetooth Keyboard'
      })
      dispatchCount = 0

      const record = await consumer.consume(buildBluetoothAclEvent())

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('allow')
      expect(record?.effectivePolicyLabel).assertEqual('已启用')
      expect(dispatchCount).assertEqual(0)
      expect(PeripheralDevicePolicyRepository.get('MAC: 11:22:33:44:55:66')?.policy).assertEqual('allow')
    })

    it('U-BT-011 should keep explicit deny policy and skip repeated auto deny dispatch', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      await PeripheralDevicePolicyRepository.set({
        deviceId: 'MAC: 11:22:33:44:55:66',
        policy: 'deny',
        updatedAt: 1,
        deviceType: PeripheralType.BLUETOOTH,
        deviceName: 'Bluetooth Keyboard'
      })
      dispatchCount = 0

      const record = await consumer.consume(buildBluetoothAclEvent())

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('deny')
      expect(record?.effectivePolicyLabel).assertEqual('已禁用')
      expect(dispatchCount).assertEqual(0)
      expect(PeripheralDevicePolicyRepository.get('MAC: 11:22:33:44:55:66')?.policy).assertEqual('deny')
    })

    it('U-BT-012 should not save local deny when auto deny dispatch fails', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      dispatchResult = createDispatchResult(false, 'bluetooth_dispatch_failed')

      const record = await consumer.consume(buildBluetoothAclEvent())

      expect(record !== null).assertTrue()
      expect(record?.decision).assertEqual('allow')
      expect(record?.effectivePolicyLabel).assertEqual('已启用')
      expect(record?.detail?.includes('自动加入黑名单失败：bluetooth_dispatch_failed')).assertTrue()
      expect(dispatchCount).assertEqual(1)
      expect(PeripheralDevicePolicyRepository.get('MAC: 11:22:33:44:55:66') === null).assertTrue()
    })

    it('U-BT-013 should not trigger auto deny for bluetooth disconnect events', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      let disconnectOverrides: BluetoothAclParameterOverrides = {
        stateName: 'STATE_DISCONNECTED',
        reason: 'REMOTE_DISCONNECT'
      }

      const record = await consumer.consume(buildBluetoothAclEvent(disconnectOverrides))

      expect(record !== null).assertTrue()
      expect(record?.action).assertEqual('disconnect')
      expect(dispatchCount).assertEqual(0)
      expect(PeripheralDevicePolicyRepository.get('MAC: 11:22:33:44:55:66') === null).assertTrue()
    })
  })
}
