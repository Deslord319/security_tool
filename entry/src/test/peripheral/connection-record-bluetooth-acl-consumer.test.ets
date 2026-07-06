import { afterEach, describe, expect, it } from '@ohos/hypium'
import { commonEventManager } from '@kit.BasicServicesKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { SecurityEventResult } from '../../main/ets/models/CommonModels'
import { PeripheralTraceRecord, PeripheralType } from '../../main/ets/models/PeripheralModels'
import { PeripheralConnectionRecordBluetoothAclConsumer } from '../../main/ets/services/peripheral/connection-record/PeripheralConnectionRecordBluetoothAclConsumer'
import { PeripheralConnectionRecordProducerEvent } from '../../main/ets/services/peripheral/connection-record/PeripheralConnectionRecordProducerContract'
import {
  BluetoothConnectedDeviceSnapshot,
  BluetoothPolicySnapshotTraceService
} from '../../main/ets/services/peripheral/connection-record/BluetoothPolicySnapshotTraceService'
import {
  PeripheralTraceMaintenanceService,
  PeripheralTraceMutationResult
} from '../../main/ets/services/peripheral/connection-record/PeripheralTraceMaintenanceService'

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
  connectionState?: number
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
  connectionState?: number
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
  if (overrides.connectionState !== undefined) {
    parameters.connectionState = overrides.connectionState
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

export default function peripheralConnectionRecordBluetoothAclConsumerTest() {
  describe('PeripheralConnectionRecordBluetoothAclConsumer', () => {
    afterEach(() => {
      BluetoothPolicySnapshotTraceService.resetForTest()
    })

    it('U-BT-001 should map bluetooth acl connect event to allow record', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()

      const record = await consumer.consume(buildBluetoothAclEvent())

      expect(record !== null).assertTrue()
      expect(record?.action).assertEqual('connect')
      expect(record?.decision).assertEqual('allow')
      expect(record?.result).assertEqual(SecurityEventResult.SUCCESS)
      expect(record?.summary).assertEqual('蓝牙设备已连接')
      expect(record?.matchedPolicyKind).assertEqual('bluetooth_connection_event')
      expect(record?.effectivePolicyLabel).assertEqual('已启用')
      expect(record?.deviceType).assertEqual(PeripheralType.BLUETOOTH)
      expect(record?.detail).assertEqual('aclState=STATE_CONNECTED, reason=SUCCESS')
    })

    it('U-BT-001A should cache acl connected device for bluetooth policy snapshot diff', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()

      await consumer.consume(buildBluetoothAclEvent({
        deviceName: 'Cached Headset',
        deviceId: 'AA:BB:CC:DD:EE:FF'
      }))
      const snapshots = BluetoothPolicySnapshotTraceService.captureCurrentConnectedDevices()

      expect(snapshots.length).assertEqual(1)
      expect(snapshots[0].deviceId).assertEqual('MAC: AA:BB:CC:DD:EE:FF')
      expect(snapshots[0].deviceName).assertEqual('Cached Headset')
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

    it('U-BT-003A should ignore bluetooth acl transition state labels', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()

      const connectingRecord = await consumer.consume(buildBluetoothAclEvent({
        stateName: 'STATE_CONNECTING'
      }))
      const disconnectingRecord = await consumer.consume(buildBluetoothAclEvent({
        stateName: 'STATE_DISCONNECTING'
      }))

      expect(connectingRecord === null).assertTrue()
      expect(disconnectingRecord === null).assertTrue()
    })

    it('U-BT-003B should only map numeric final acl states', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()

      const connectedRecord = await consumer.consume(buildBluetoothAclEvent({
        stateName: '',
        connectionState: 1
      }))
      const disconnectedRecord = await consumer.consume(buildBluetoothAclEvent({
        stateName: '',
        connectionState: 0
      }))
      const connectingRecord = await consumer.consume(buildBluetoothAclEvent({
        stateName: '',
        connectionState: 2
      }))
      const disconnectingRecord = await consumer.consume(buildBluetoothAclEvent({
        stateName: '',
        connectionState: 3
      }))

      expect(connectedRecord !== null).assertTrue()
      expect(connectedRecord?.action).assertEqual('connect')
      expect(connectedRecord?.detail).assertEqual('aclState=STATE_CONNECTED, reason=SUCCESS')
      expect(disconnectedRecord !== null).assertTrue()
      expect(disconnectedRecord?.action).assertEqual('disconnect')
      expect(disconnectedRecord?.detail).assertEqual('aclState=STATE_DISCONNECTED, reason=SUCCESS')
      expect(connectingRecord === null).assertTrue()
      expect(disconnectingRecord === null).assertTrue()
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

    it('U-BT-009 should keep bluetooth disconnect events as allow records without policy details', 0, async () => {
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
      expect(record?.effectivePolicyLabel).assertEqual('已启用')
      expect(record?.matchedPolicyKind).assertEqual('bluetooth_connection_event')
      expect(record?.detail).assertEqual('aclState=STATE_DISCONNECTED, reason=REMOTE_DISCONNECT')
    })

    it('U-BT-010 should suppress policy-triggered bluetooth disconnect after snapshot', 0, async () => {
      const mockKit = new MockKit()
      try {
        BluetoothPolicySnapshotTraceService.setNowProviderForTest(() => 1700000000000)
        let appendMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.appendEntries)
        when(appendMock)(ArgumentMatchers.any).afterAction((_records: PeripheralTraceRecord[]) => {
          return Promise.resolve({ success: true, code: 'ok' } as PeripheralTraceMutationResult)
        })
        await BluetoothPolicySnapshotTraceService.appendBluetoothDisabledPolicySnapshot([{
          rawDeviceId: '11:22:33:44:55:66',
          deviceId: 'MAC: 11:22:33:44:55:66',
          deviceName: 'Bluetooth Keyboard',
          rawPayload: '{}'
        } as BluetoothConnectedDeviceSnapshot])
        const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()

        const record = await consumer.consume(buildBluetoothAclEvent({
          stateName: 'STATE_DISCONNECTED',
          reason: 'POLICY_DISABLED'
        }))

        expect(record === null).assertTrue()
      } finally {
        BluetoothPolicySnapshotTraceService.resetForTest()
        mockKit.clearAll()
      }
    })
  })
}
