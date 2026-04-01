import { hilog } from '@kit.PerformanceAnalysisKit'
import { PeripheralTraceRecord } from '../../../models/DataModels'
import { PeripheralTraceRepository } from '../../PeripheralTraceRepository'
import {
  PeripheralConnectionRecordConsumer,
  PeripheralConnectionRecordPipeline,
  PeripheralConnectionRecordProducer,
  PeripheralConnectionRecordProducerEvent
} from './peripheral_connection_record_producer_contract'

const DOMAIN = 0x000A
const TAG = 'ConnectionRecordPipeline'
const USB_DEDUPE_WINDOW_MS = 1500

export class PeripheralConnectionRecordPipelineImpl implements PeripheralConnectionRecordPipeline {
  private producerListenerId: number = 0
  private lastSeenByKey: Map<string, number> = new Map()

  constructor(
    private readonly producer: PeripheralConnectionRecordProducer,
    private readonly consumers: PeripheralConnectionRecordConsumer[]
  ) {
  }

  async start(): Promise<boolean> {
    if (this.producerListenerId > 0) {
      return true
    }
    this.producerListenerId = this.producer.subscribe((event: PeripheralConnectionRecordProducerEvent) => {
      void this.push(event)
    })
    const started = await this.producer.start()
    if (!started) {
      this.producer.unsubscribe(this.producerListenerId)
      this.producerListenerId = 0
    }
    return started
  }

  stop(): void {
    if (this.producerListenerId > 0) {
      this.producer.unsubscribe(this.producerListenerId)
      this.producerListenerId = 0
    }
    this.producer.stop()
  }

  async push(event: PeripheralConnectionRecordProducerEvent): Promise<boolean> {
    let handled: boolean = false
    for (let index = 0; index < this.consumers.length; index++) {
      const consumer = this.consumers[index]
      if (!consumer.canHandle(event)) {
        continue
      }
      const record = await consumer.consume(event)
      if (!record) {
        continue
      }
      handled = true
      if (this.shouldSkipByDedupe(event, record)) {
        continue
      }
      const appended = await PeripheralTraceRepository.append(record)
      if (!appended) {
        hilog.warn(DOMAIN, TAG, `append failed: channel=${event.channel}, deviceId=${record.deviceId}`)
      }
    }
    return handled
  }

  private shouldSkipByDedupe(event: PeripheralConnectionRecordProducerEvent, record: PeripheralTraceRecord): boolean {
    if (event.channel !== 'usb') {
      return false
    }
    const now = Date.now()
    const dedupeKey = `${record.deviceId}|${record.action}|${record.rawEventName ?? ''}`
    const lastSeen = this.lastSeenByKey.get(dedupeKey) || 0
    if (now - lastSeen < USB_DEDUPE_WINDOW_MS) {
      return true
    }
    this.lastSeenByKey.set(dedupeKey, now)
    return false
  }
}
