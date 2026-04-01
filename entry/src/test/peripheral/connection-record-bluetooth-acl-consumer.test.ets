import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { LogEventResult, PeripheralTraceRecord, PeripheralType } from '../../main/ets/models/DataModels'
import { PeripheralRuntimeEventService } from '../../main/ets/services/PeripheralRuntimeEventService'
import { PeripheralConnectionRecordBluetoothAclConsumer } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_bluetooth_acl_consumer'
import { PeripheralConnectionRecordProducerEvent } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_producer_contract'

export default function peripheralConnectionRecordBluetoothAclConsumerTest() {
  describe('PeripheralConnectionRecordBluetoothAclConsumer', () => {
    let originalMapper: (data: Object) => Promise<PeripheralTraceRecord | null>

    beforeEach(() => {
      originalMapper = PeripheralRuntimeEventService.mapBluetoothAclCommonEventToTraceRecord
      PeripheralRuntimeEventService.mapBluetoothAclCommonEventToTraceRecord = async (_data: Object): Promise<PeripheralTraceRecord | null> => {
        return {
          recordId: 'runtime_bt_acl_1',
          occurAt: 200,
          collectAt: 201,
          deviceName: 'Bluetooth Keyboard',
          deviceType: PeripheralType.BLUETOOTH,
          deviceId: 'MAC: 11:22:33:44:55:66',
          action: 'connect',
          decision: 'unknown',
          result: LogEventResult.SUCCESS,
          source: 'runtime_event',
          summary: '蓝牙设备已连接',
          rawEventName: 'usual.event.BLUETOOTH_ACL',
          rawAction: 'connect',
          detail: 'aclState=CONNECTED, reason=SUCCESS',
          effectivePolicyLabel: '--',
          matchedPolicyKind: 'bluetooth_connection_event'
        }
      }
    })

    afterEach(() => {
      PeripheralRuntimeEventService.mapBluetoothAclCommonEventToTraceRecord = originalMapper
    })

    it('should map bluetooth acl producer event to trace record with key fields', 0, async (done: Function) => {
      const consumer = new PeripheralConnectionRecordBluetoothAclConsumer()
      const event: PeripheralConnectionRecordProducerEvent = {
        source: 'runtime',
        channel: 'bluetooth_acl',
        eventName: 'usual.event.BLUETOOTH_ACL',
        rawData: {}
      }

      const record = await consumer.consume(event)
      expect(record !== null).assertTrue()
      expect(record?.action).assertEqual('connect')
      expect(record?.summary).assertEqual('蓝牙设备已连接')
      expect(record?.matchedPolicyKind).assertEqual('bluetooth_connection_event')
      expect(record?.effectivePolicyLabel).assertEqual('--')
      done()
    })
  })
}
