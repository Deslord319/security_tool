import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { connection } from '@kit.ConnectivityKit'
import { LogEventResult, PeripheralType } from '../../main/ets/models/DataModels'
import { PeripheralConnectionRecordBluetoothAclConsumer } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_bluetooth_acl_consumer'
import { PeripheralConnectionRecordProducerEvent } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_producer_contract'

type EventField = Object | string | number | boolean

function buildBluetoothAclEvent(
  parameterOverrides: Record<string, EventField> = {},
  rawDataOverrides: Record<string, EventField> = {}
): PeripheralConnectionRecordProducerEvent {
  return {
    source: 'runtime',
    channel: 'bluetooth_acl',
    eventName: 'usual.event.BLUETOOTH_ACL',
    rawData: {
      event: 'usual.event.BLUETOOTH_ACL',
      parameters: {
        deviceId: '11:22:33:44:55:66',
        deviceName: 'Bluetooth Keyboard',
        stateName: 'STATE_CONNECTED',
        reason: 'SUCCESS',
        timestamp: 200,
        ...parameterOverrides
      },
      ...rawDataOverrides
    }
  }
}

export default function peripheralConnectionRecordBluetoothAclConsumerTest() {
  describe('PeripheralConnectionRecordBluetoothAclConsumer', () => {
    let originalGetRemoteDeviceName: typeof connection.getRemoteDeviceName
    let remoteDeviceNameResult: string

    beforeEach(() => {
      originalGetRemoteDeviceName = connection.getRemoteDeviceName
      remoteDeviceNameResult = ''
      connection.getRemoteDeviceName = (_deviceId: string, _useCache: boolean): string => remoteDeviceNameResult
    })

    afterEach(() => {
      connection.getRemoteDeviceName = originalGetRemoteDeviceName
    })

    it('U-BT-001 should map bluetooth acl connect event to connection record', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()

      const record = await consumer.consume(buildBluetoothAclEvent())

      expect(record !== null).assertTrue()
      expect(record?.action).assertEqual('connect')
      expect(record?.summary).assertEqual('蓝牙设备已连接')
      expect(record?.matchedPolicyKind).assertEqual('bluetooth_connection_event')
      expect(record?.effectivePolicyLabel).assertEqual('--')
      expect(record?.deviceType).assertEqual(PeripheralType.BLUETOOTH)
    })

    it('U-BT-002 should map bluetooth acl disconnect event to disconnect record', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()

      const record = await consumer.consume(buildBluetoothAclEvent({
        stateName: 'STATE_DISCONNECTED',
        reason: 'REMOTE_DISCONNECT'
      }))

      expect(record !== null).assertTrue()
      expect(record?.action).assertEqual('disconnect')
      expect(record?.result).assertEqual(LogEventResult.SUCCESS)
      expect(record?.summary).assertEqual('蓝牙设备已断开')
      expect(record?.detail).assertEqual('aclState=STATE_DISCONNECTED, reason=REMOTE_DISCONNECT')
    })

    it('U-BT-003 should ignore bluetooth acl events with unknown state', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()

      const record = await consumer.consume(buildBluetoothAclEvent({
        stateName: 'STATE_IDLE'
      }))

      expect(record === null).assertTrue()
    })

    it('U-BT-004 should ignore bluetooth acl events without deviceId', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      const event = buildBluetoothAclEvent({
        stateName: 'STATE_CONNECTED',
        deviceId: '' as Object,
        deviceAddr: '' as Object,
        address: '' as Object
      })

      const record = await consumer.consume(event)

      expect(record === null).assertTrue()
    })

    it('U-BT-005 should prefer payload device name over remote lookup result', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      remoteDeviceNameResult = 'Remote Device Name'

      const record = await consumer.consume(buildBluetoothAclEvent({
        deviceName: 'Payload Device Name'
      }))

      expect(record !== null).assertTrue()
      expect(record?.deviceName).assertEqual('Payload Device Name')
    })

    it('U-BT-006 should use fallback bluetooth name when no name can be resolved', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      remoteDeviceNameResult = ''

      const record = await consumer.consume(buildBluetoothAclEvent({
        deviceName: '' as Object,
        remoteName: '' as Object,
        alias: '' as Object
      }))

      expect(record !== null).assertTrue()
      expect(record?.deviceName).assertEqual('未命名蓝牙设备')
    })

    it('U-BT-007 should normalize bluetooth device id format', 0, async () => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()

      const record = await consumer.consume(buildBluetoothAclEvent({
        deviceId: 'aa-bb-cc-dd-ee-ff'
      }))

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
  })
}
