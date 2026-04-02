import { describe, expect, it } from '@ohos/hypium'
import { PeripheralType } from '../../main/ets/models/DataModels'
import { PeripheralConnectionRecordBluetoothAclConsumer } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_bluetooth_acl_consumer'
import { PeripheralConnectionRecordProducerEvent } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_producer_contract'

export default function peripheralConnectionRecordBluetoothAclConsumerTest() {
  describe('PeripheralConnectionRecordBluetoothAclConsumer', () => {
    it('should map bluetooth acl producer event to trace record with key fields', 0, async (done: Function) => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      const event: PeripheralConnectionRecordProducerEvent = {
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
            timestamp: 200
          }
        }
      }

      const record = await consumer.consume(event)
      expect(record !== null).assertTrue()
      expect(record?.action).assertEqual('connect')
      expect(record?.summary).assertEqual('蓝牙设备已连接')
      expect(record?.matchedPolicyKind).assertEqual('bluetooth_connection_event')
      expect(record?.effectivePolicyLabel).assertEqual('--')
      expect(record?.deviceType).assertEqual(PeripheralType.BLUETOOTH)
      done()
    })
  })
}
