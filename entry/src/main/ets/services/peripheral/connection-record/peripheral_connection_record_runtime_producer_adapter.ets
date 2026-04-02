import {
  PeripheralRuntimeCommonEvent,
  PeripheralRuntimeEventService
} from '../../PeripheralRuntimeEventService'
import {
  PeripheralConnectionRecordProducer,
  PeripheralConnectionRecordProducerEvent,
  PeripheralConnectionRecordProducerListener,
  PeripheralConnectionRecordProducerStatus
} from './peripheral_connection_record_producer_contract'

export class PeripheralConnectionRecordRuntimeProducerAdapter implements PeripheralConnectionRecordProducer {
  private nextListenerId: number = 1
  private listeners: Map<number, PeripheralConnectionRecordProducerListener> = new Map()
  private runtimeCommonListenerId: number = 0

  async start(): Promise<boolean> {
    this.ensureRuntimeBridgeListener()
    return PeripheralRuntimeEventService.start()
  }

  stop(): void {
    this.releaseRuntimeBridgeListener()
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

  private ensureRuntimeBridgeListener(): void {
    if (this.runtimeCommonListenerId > 0) {
      return
    }
    this.runtimeCommonListenerId = PeripheralRuntimeEventService.addRuntimeCommonEventListener(
      (event: PeripheralRuntimeCommonEvent) => {
        this.emit(event)
      }
    )
  }

  private releaseRuntimeBridgeListener(): void {
    if (this.runtimeCommonListenerId <= 0) {
      return
    }
    PeripheralRuntimeEventService.removeRuntimeCommonEventListener(this.runtimeCommonListenerId)
    this.runtimeCommonListenerId = 0
  }

  private emit(event: PeripheralRuntimeCommonEvent): void {
    if (this.listeners.size <= 0) {
      return
    }
    const producerEvent: PeripheralConnectionRecordProducerEvent = {
      source: 'runtime' as const,
      channel: event.channel,
      eventName: event.eventName,
      payload: event.payload,
      rawData: event.rawData
    }
    this.listeners.forEach((listener: PeripheralConnectionRecordProducerListener) => {
      try {
        listener(producerEvent)
      } catch (_err) {
      }
    })
  }
}
