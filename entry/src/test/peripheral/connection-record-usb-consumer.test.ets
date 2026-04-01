import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { LogEventResult, PeripheralTraceRecord, PeripheralType } from '../../main/ets/models/DataModels'
import { PeripheralRuntimeEventService } from '../../main/ets/services/PeripheralRuntimeEventService'
import { PeripheralConnectionRecordUsbConsumer } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_usb_consumer'
import { PeripheralConnectionRecordProducerEvent } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_producer_contract'

export default function peripheralConnectionRecordUsbConsumerTest() {
  describe('PeripheralConnectionRecordUsbConsumer', () => {
    let originalMapper: (data: Object) => PeripheralTraceRecord | null

    beforeEach(() => {
      originalMapper = PeripheralRuntimeEventService.mapUsbCommonEventToTraceRecord
      PeripheralRuntimeEventService.mapUsbCommonEventToTraceRecord = (_data: Object): PeripheralTraceRecord | null => {
        return {
          recordId: 'runtime_usb_1',
          occurAt: 100,
          collectAt: 101,
          deviceName: 'USB Storage',
          deviceType: PeripheralType.USB_STORAGE,
          deviceId: 'VID:1234 PID:5678',
          action: 'connect',
          decision: 'allow',
          result: LogEventResult.SUCCESS,
          source: 'runtime_event',
          summary: 'USB 存储只读',
          rawEventName: 'usual.event.USB_ATTACHED',
          rawAction: 'connect',
          detail: 'USB 存储策略为只读模式。',
          effectivePolicyLabel: '只读',
          matchedPolicyKind: 'usb_storage_read_only'
        }
      }
    })

    afterEach(() => {
      PeripheralRuntimeEventService.mapUsbCommonEventToTraceRecord = originalMapper
    })

    it('should map usb producer event to trace record with key fields', 0, async (done: Function) => {
      const consumer = new PeripheralConnectionRecordUsbConsumer()
      const event: PeripheralConnectionRecordProducerEvent = {
        source: 'runtime',
        channel: 'usb',
        eventName: 'usual.event.USB_ATTACHED',
        rawData: {}
      }

      const record = await consumer.consume(event)
      expect(record !== null).assertTrue()
      expect(record?.action).assertEqual('connect')
      expect(record?.summary).assertEqual('USB 存储只读')
      expect(record?.matchedPolicyKind).assertEqual('usb_storage_read_only')
      expect(record?.effectivePolicyLabel).assertEqual('只读')
      done()
    })
  })
}
