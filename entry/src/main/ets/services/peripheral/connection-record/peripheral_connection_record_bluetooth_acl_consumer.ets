import { commonEventManager } from '@kit.BasicServicesKit'
import { PeripheralRuntimeEventService } from '../../PeripheralRuntimeEventService'
import {
  PeripheralConnectionRecordConsumeResult,
  PeripheralConnectionRecordConsumer,
  PeripheralConnectionRecordProducerEvent
} from './peripheral_connection_record_producer_contract'

export class PeripheralConnectionRecordBluetoothAclConsumer implements PeripheralConnectionRecordConsumer {
  canHandle(event: PeripheralConnectionRecordProducerEvent): boolean {
    return event.channel === 'bluetooth_acl'
  }

  async consume(event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralConnectionRecordConsumeResult> {
    if (!this.canHandle(event)) {
      return null
    }
    const rawData = event.rawData as commonEventManager.CommonEventData | undefined
    if (!rawData) {
      return null
    }
    return PeripheralRuntimeEventService.mapBluetoothAclCommonEventToTraceRecord(rawData)
  }
}
