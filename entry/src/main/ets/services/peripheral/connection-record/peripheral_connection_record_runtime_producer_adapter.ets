import { PeripheralRuntimeEventService } from '../../PeripheralRuntimeEventService'
import {
  PeripheralConnectionRecordProducer,
  PeripheralConnectionRecordProducerListener,
  PeripheralConnectionRecordProducerStatus
} from './peripheral_connection_record_producer_contract'

export class PeripheralConnectionRecordRuntimeProducerAdapter implements PeripheralConnectionRecordProducer {
  private nextListenerId: number = 1
  private listeners: Map<number, PeripheralConnectionRecordProducerListener> = new Map()

  async start(): Promise<boolean> {
    return PeripheralRuntimeEventService.start()
  }

  stop(): void {
    PeripheralRuntimeEventService.stop()
  }

  subscribe(listener: PeripheralConnectionRecordProducerListener): number {
    const listenerId = this.nextListenerId++
    this.listeners.set(listenerId, listener)
    return listenerId
  }

  unsubscribe(listenerId: number): void {
    this.listeners.delete(listenerId)
  }

  getStatus(): PeripheralConnectionRecordProducerStatus {
    const runtimeStatus = PeripheralRuntimeEventService.getStatus()
    return {
      running: runtimeStatus.running,
      capabilities: {
        usbRuntimeEvents: runtimeStatus.capabilities.usbRuntimeEvents,
        bluetoothRuntimeEvents: runtimeStatus.capabilities.bluetoothRuntimeEvents,
        degradedReason: runtimeStatus.capabilities.degradedReason
      }
    }
  }
}
