import { commonEventManager } from '@kit.BasicServicesKit'
import { PeripheralTraceRecord } from '../../../models/DataModels'
import { PeripheralRuntimeEventService } from '../../PeripheralRuntimeEventService'
import {
  PeripheralConnectionRecordConsumer,
  PeripheralConnectionRecordProducerEvent
} from './peripheral_connection_record_producer_contract'

export class PeripheralConnectionRecordUsbConsumer implements PeripheralConnectionRecordConsumer {
  canHandle(event: PeripheralConnectionRecordProducerEvent): boolean {
    return event.channel === 'usb'
  }

  async consume(event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralTraceRecord | null> {
    if (!this.canHandle(event)) {
      return null
    }
    return PeripheralRuntimeEventService.mapUsbCommonEventToTraceRecord(
      event.rawData as commonEventManager.CommonEventData
    )
  }
}
