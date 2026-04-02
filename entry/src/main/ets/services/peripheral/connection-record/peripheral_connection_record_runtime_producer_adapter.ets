import type { common } from '@kit.AbilityKit'
import {
  PeripheralConnectionRecordProducer,
  PeripheralConnectionRecordProducerEvent,
  PeripheralConnectionRecordProducerListener,
  PeripheralConnectionRecordProducerStatus
} from './peripheral_connection_record_producer_contract'

export class PeripheralConnectionRecordRuntimeProducerAdapter implements PeripheralConnectionRecordProducer {
  private nextListenerId: number = 1
  private listeners: Map<number, PeripheralConnectionRecordProducerListener> = new Map()
  private context: common.UIAbilityContext | null = null
  private status: PeripheralConnectionRecordProducerStatus = {
    running: false,
    capabilities: {
      usbRuntimeEvents: false,
      bluetoothRuntimeEvents: false,
      degradedReason: 'event_source_not_integrated'
    }
  }

  bindContext(context: common.UIAbilityContext): void {
    this.context = context
  }

  async start(): Promise<boolean> {
    if (!this.context) {
      this.status = {
        running: false,
        capabilities: {
          usbRuntimeEvents: false,
          bluetoothRuntimeEvents: false,
          degradedReason: 'not_initialized'
        }
      }
      return false
    }
    this.status = {
      running: false,
      capabilities: {
        usbRuntimeEvents: false,
        bluetoothRuntimeEvents: false,
        degradedReason: 'event_source_not_integrated'
      }
    }
    return false
  }

  stop(): void {
    this.status = {
      running: false,
      capabilities: {
        usbRuntimeEvents: false,
        bluetoothRuntimeEvents: false,
        degradedReason: this.context ? 'event_source_not_integrated' : 'not_initialized'
      }
    }
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
    return this.status
  }

  // Step 1 only prepares the producer-side handoff point. Runtime event source
  // ownership is switched in later steps by wiring subscriptions into this adapter.
  emitRuntimeEvent(event: PeripheralConnectionRecordProducerEvent): void {
    if (this.listeners.size <= 0) {
      return
    }
    this.listeners.forEach((listener: PeripheralConnectionRecordProducerListener) => {
      try {
        listener(event)
      } catch (_err) {
      }
    })
  }

  markStatus(status: PeripheralConnectionRecordProducerStatus): void {
    this.status = status
  }
}
